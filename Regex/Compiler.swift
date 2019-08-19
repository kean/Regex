// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

final class Compiler {
    private let ast: AST
    private let options: Regex.Options

    private var symbols: Symbols
    private var captureGroups: [IndermediateCaptureGroup] = []
    private var backreferences: [Backreference] = []
    private var containsLazyQuantifiers = false

    init(_ ast: AST, _ options: Regex.Options) {
        self.ast = ast
        self.options = options
        self.symbols = Symbols(ast: ast)
    }

    func compile() throws -> (CompiledRegex, Symbols) {
        let fsm = try compile(ast.root)
        optimize(fsm)

        let allStates = fsm.allStates()
        var map = [State: Int]()
        for (state, index) in zip(allStates, allStates.indices) {
            state.id = index
            map[state] = index
        }

        let captureGroups = self.captureGroups.map {
            CaptureGroup(index: $0.index, start: map[$0.start]!, end: map[$0.end]!)
        }

        try validateBackreferences()
        let regex = CompiledRegex(
            fsm: fsm,
            states: allStates,
            captureGroups: captureGroups,
            isRegular: !containsLazyQuantifiers && backreferences.isEmpty,
            isFromStartOfString: ast.isFromStartOfString
        )
        return (regex, symbols)
    }
}

private extension Compiler {
    func compile(_ unit: Unit) throws -> FSM {
        let fsm = try _compile(unit)
        if Regex.isDebugModeEnabled {
            if symbols.map[fsm.start] == nil {
                symbols.map[fsm.start] = Symbols.Details(unit: unit, isEnd: false)
            }
            if symbols.map[fsm.end] == nil {
                symbols.map[fsm.end] = Symbols.Details(unit: unit, isEnd: true)
            }
        }
        return fsm
    }

    func _compile(_ unit: Unit) throws -> FSM {
        switch unit {
        case let expression as Expression:
            return .concatenate(try expression.children.map(compile))

        case let group as Group:
            let fsms = try group.children.map(compile)
            let fms = FSM.group(.concatenate(fsms))
            if group.isCapturing { // Remember the group that we just compiled.
                captureGroups.append(IndermediateCaptureGroup(index: group.index, start: fms.start, end: fms.end))
            }
            return fms

        case let backreference as Backreference:
            backreferences.append(backreference)
            return .backreference(backreference.index)

        case let alternation as Alternation:
            return .alternate(try alternation.children.map(compile))

        case let anchor as Anchor:
            switch anchor.type {
            case .startOfString: return .startOfString
            case .startOfStringOnly: return .startOfStringOnly
            case .endOfString: return .endOfString
            case .endOfStringOnly: return .endOfStringOnly
            case .endOfStringOnlyNotNewline: return .endOfStringOnlyNotNewline
            case .wordBoundary: return .wordBoundary
            case .nonWordBoundary: return .nonWordBoundary
            case .previousMatchEnd: return .previousMatchEnd
            }

        case let quantifier as QuantifiedExpression:
            let expression = quantifier.expression
            let isLazy = quantifier.isLazy
            if isLazy {
                containsLazyQuantifiers = true
            }
            switch quantifier.type {
            case .zeroOrMore: return .zeroOrMore(try compile(expression), isLazy)
            case .oneOrMore: return .oneOrMore(try compile(expression), isLazy)
            case .zeroOrOne: return .zeroOrOne(try compile(expression), isLazy)
            case let .range(range): return try compile(expression, range, isLazy)
            }

        case let match as Match:
            let isCaseInsensitive = options.contains(.caseInsensitive)
            let dotMatchesLineSeparators = options.contains(.dotMatchesLineSeparators)
            switch match.type {
            case let .character(c): return .character(c, isCaseInsensitive: isCaseInsensitive)
            case let .string(s): return .string(s
                , isCaseInsensitive: isCaseInsensitive)
            case .anyCharacter: return .anyCharacter(includingNewline: dotMatchesLineSeparators)
            case let .characterSet(set): return .characterSet(set, isCaseInsensitive: isCaseInsensitive)
            }

        default:
            fatalError("Unsupported unit \(unit)")
        }
    }

    func compile(_ unit: Unit, _ range: ClosedRange<Int>, _ isLazy: Bool) throws -> FSM {
        let prefix = try compileRangePrefix(unit, range)
        let suffix: FSM
        if range.upperBound == Int.max {
            suffix = .zeroOrMore(try compile(unit), isLazy)
        } else {
            // Compile the optional matches into `x(x(x(x)?)?)?`. We use this
            // specific form with grouping to make sure that matcher can cache
            // the results during backtracking.
            suffix = try range.dropLast().reduce(FSM.empty) { result, _ in
                let expression = try compile(unit)
                return .zeroOrOne(.group(.concatenate(expression, result)), isLazy)
            }
        }
        return FSM.concatenate(prefix, suffix)
    }

    func compileRangePrefix(_ unit: Unit, _ range: ClosedRange<Int>) throws -> FSM {
        func getString() -> String? {
            guard let match = unit as? Match else {
                return nil
            }
            switch match.type {
            case let .character(c): return String(c)
            case let .string(s): return s
            default: return nil
            }
        }

        guard let string = getString() else {
            return try .concatenate((0..<range.lowerBound).map { _ in
                try compile(unit)
            })
        }

        // [Optimization] compile a{4} as if it was .string("aaaa")
        let s = String(repeating: string, count: (0..<range.lowerBound).count)
        return FSM.string(s, isCaseInsensitive: options.contains(.caseInsensitive))
    }

    func validateBackreferences() throws {
        for backreference in backreferences {
            // TODO: move validation to parser?
            guard captureGroups.contains(where: { $0.index == backreference.index }) else {
                throw Regex.Error("The token '\\\(backreference.index)' references a non-existent or invalid subpattern", 0)
            }
        }
    }
}

private extension Compiler {
    func optimize(_ fsm: FSM) {
        let captureGroupState = Set(captureGroups.flatMap { [$0.start, $0.end] })

        for state in fsm.allStates() {
            state.transitions = state.transitions.map {
                // [Optimization] Remove "technical" states
                if !captureGroupState.contains($0.end) &&
                    $0.end.transitions.count == 1 &&
                    $0.end.transitions[0].isUnconditionalEpsilon {
                    return Transition($0.end.transitions[0].end, $0.condition)
                }
                return $0
            }
        }
    }
}

// MARK: - CompiledRegex

struct CompiledRegex {
    /// The starting index in the compiled regular expression.
    let fsm: FSM

    /// All states in the state machine.
    let states: [State]

    /// All the capture groups with their indexes.
    let captureGroups: [CaptureGroup]

    /// `true` if the regex doesn't contain any of the features which can't be
    /// simulated solely by NFA and require backtracking.
    let isRegular: Bool

    /// If `true`, requires the pattern to match the start of the string.
    let isFromStartOfString: Bool
}

// An intermediate representation which we use until we assign state IDs.
private struct IndermediateCaptureGroup {
    let index: Int
    let start: State
    let end: State
}

struct CaptureGroup {
    let index: Int
    let start: StateId
    let end: StateId
}

// MARK: - Symbols

/// Mapping between states of the finite state machine and the nodes for which
/// they were produced.
struct Symbols {
    let ast: AST
    fileprivate(set) var map = [State: Details]()

    struct Details {
        let unit: Unit
        let isEnd: Bool
    }

    func description(for state: State) -> String {
        let details = map[state]

        let info: String? = details.flatMap {
            return "\($0.isEnd ? "End" : "Start"), \(ast.description(for: $0.unit))"
        }

        return "\(state) [\(info ?? "<symbol missing>")]"
    }
}
