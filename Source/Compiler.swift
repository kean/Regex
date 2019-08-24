// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

final class Compiler {
    private let options: Regex.Options
    private let ast: AST

    private var captureGroups: [IRCaptureGroup] = []
    private var backreferences: [Backreference] = []
    private var map = [State: Symbols.Details]()
    private var containsLazyQuantifiers = false

    init(_ ast: AST, _ options: Regex.Options) {
        self.ast = ast
        self.options = options
    }

    func compile() throws -> CompiledRegex {
        let fsm = try compile(ast.root)
        optimize(fsm)

        // Assign indices to each state/
        let states = fsm.allStates()
        var indices = [State: Int]()
        for (state, index) in zip(states, states.indices) {
            state.index = index
            indices[state] = index
        }

        let captureGroups = self.captureGroups.map {
            CaptureGroup(index: $0.index, start: indices[$0.start]!, end: indices[$0.end]!)
        }

        try validateBackreferences()

        #if DEBUG
        var details = [State.Index: Symbols.Details]()
        for (key, value) in map {
            details[indices[key]!] = value
        }
        let symbols = Symbols(ast: ast, map: details)
        #else
        let symbols = Symbols()
        #endif

        return CompiledRegex(
            states: states,
            captureGroups: captureGroups,
            isRegular: !containsLazyQuantifiers && backreferences.isEmpty,
            isFromStartOfString: ast.isFromStartOfString,
            symbols: symbols
        )
    }
}

private extension Compiler {
    func compile(_ unit: Unit) throws -> FSM {
        let fsm = try _compile(unit)
        #if DEBUG
        if Regex.isDebugModeEnabled {
            if map[fsm.start] == nil {
                map[fsm.start] = Symbols.Details(unit: unit, isEnd: false)
            }
            if map[fsm.end] == nil {
                map[fsm.end] = Symbols.Details(unit: unit, isEnd: true)
            }
        }
        #endif
        return fsm
    }

    func _compile(_ unit: Unit) throws -> FSM {
        switch unit {
        case let expression as Expression:
            return .concatenate(try expression.children.map(compile))

        case let group as Group:
            let fsms = try group.children.map(compile)
            let fms = FSM.group(.concatenate(fsms))
            if group.isCapturing { // Remember the computed groups
                captureGroups.append(IRCaptureGroup(index: group.index, start: fms.start, end: fms.end))
            }
            return fms

        case let backreference as Backreference:
            backreferences.append(backreference)
            return .backreference(backreference.index)

        case let alternation as Alternation:
            return .alternate(try alternation.children.map(compile))

        case let anchor as Anchor:
            switch anchor.type {
            case .startOfString: return options.contains(.multiline) ? .startOfString : .startOfStringOnly
            case .startOfStringOnly: return .startOfStringOnly
            case .endOfString: return options.contains(.multiline) ? .endOfString : .endOfStringOnly
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
            case let .characterSet(set, isNegative): return .characterSet(set, isCaseInsensitive, isNegative)
            case let .range(range, isNegative): return .range(range, isCaseInsensitive, isNegative)
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
            // Compile the optional matches into `x(x(x(x)?)?)?`. This special
            // form makes sure that matcher can cache the results during backtracking.
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
        guard range.lowerBound > 0 else {
            return .empty
        }
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

final class CompiledRegex {
    /// All states in the state machine.
    let states: ContiguousArray<State>

    /// All the capture groups with their indexes.
    let captureGroups: [CaptureGroup]

    /// `true` if the regex doesn't contain any of the features which can't be
    /// simulated solely by NFA and require backtracking.
    let isRegular: Bool

    /// If `true`, requires the pattern to match the start of the string.
    let isFromStartOfString: Bool

    let symbols: Symbols

    init(states: [State], captureGroups: [CaptureGroup], isRegular: Bool, isFromStartOfString: Bool, symbols: Symbols) {
        self.states = ContiguousArray(states)
        self.captureGroups = captureGroups
        self.isRegular = isRegular
        self.isFromStartOfString = isFromStartOfString
        self.symbols = symbols
    }
}

struct CaptureGroup {
    let index: Int
    let start: State.Index
    let end: State.Index
}

// MARK: - Symbols

// An intermediate representation used until assigning state indexes.
private struct IRCaptureGroup {
    let index: Int
    let start: State
    let end: State
}

/// Mapping between states of the finite state machine and the nodes for which
/// they were produced.
struct Symbols {
    #if DEBUG
    let ast: AST
    fileprivate(set) var map = [State.Index: Details]()
    #endif

    struct Details {
        let unit: Unit
        let isEnd: Bool
    }

    func description(for state: State.Index) -> String {
        #if DEBUG
        let details = map[state]

        let info: String? = details.flatMap {
            return "\($0.isEnd ? "End" : "Start"), \(ast.description(for: $0.unit))"
        }

        return "\(state) [\(info ?? "<symbol missing>")]"
        #else
        return "\(state) [<symbol missing>]"
        #endif
    }

    func description(for state: State) -> String {
        return description(for: state.index)
    }
}
