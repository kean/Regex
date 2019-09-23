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
        try validateBackreferences()
        return preprocess(fsm)
    }

    /// Creates a `CompiledRegex` instance with the given state machine.
    ///
    /// Maps a `FSM` (which is convenient for creating and combining state machines
    /// but which incurs some ARC overhead) into an array of `CompiledTransition` which
    /// state is no longer a class (reference type) but simply an index in the array.
    ///
    /// Assembles all the needed metadata and the debug symbols.
    func preprocess(_ fsm: FSM) -> CompiledRegex {
        let states = fsm.allStates()
        var indices = [State: Int]()
        for (state, index) in zip(states, states.indices) {
            indices[state] = index
        }

        let captureGroups = self.captureGroups.map {
            CompiledCaptureGroup(index: $0.index, start: indices[$0.start]!, end: indices[$0.end]!)
        }

        let transitions = ContiguousArray(states.map { state in
            ContiguousArray(state.transitions.map {
                CompiledTransition(end: indices[$0.end]!, condition: $0.condition)
            })
        })

        // Make sure states are deallocated by breaking all potential cycles.
        states.forEach { $0.transitions.removeAll() }

        // Collect all the needed debug symbols.
        #if DEBUG
        var details = [CompiledState: Symbols.Details]()
        for (key, value) in map {
            if let index = indices[key] {
                details[index] = value
            }
        }
        let symbols = Symbols(ast: ast, map: details)
        #else
        let symbols = Symbols()
        #endif

        return CompiledRegex(
            fsm: CompiledStateMachine(transitions: transitions),
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
        case let expression as ImplicitGroup: return try compile(expression)
        case let group as Group: return try compile(group)
        case let backreference as Backreference: return try compile(backreference)
        case let alternation as Alternation: return try compile(alternation)
        case let anchor as Anchor: return try compile(anchor)
        case let quantifiedExpression as QuantifiedExpression: return try compile(quantifiedExpression)
        case let match as Match: return try compile(match)
        default: fatalError("Unsupported unit \(unit)")
        }
    }

    func compile(_ expression: ImplicitGroup) throws -> FSM {
        return .concatenate(try expression.children.map(compile))
    }

    func compile(_ group: Group) throws -> FSM {
        // TODO: tidy up
        let fsms = try group.children.map(compile)
        let fsm = FSM.group(.concatenate(fsms))
        if group.isCapturing { // Remember the computed groups
            captureGroups.append(IRCaptureGroup(index: group.index!, start: fsm.start, end: fsm.end))
        }
        return fsm
    }

    func compile(_ backreference: Backreference) throws -> FSM {
        backreferences.append(backreference)
        return .backreference(backreference.index)
    }

    func compile(_ alternation: Alternation) throws -> FSM {
        return .alternate(try alternation.children.map(compile))
    }

    func compile(_ anchor: Anchor) throws -> FSM {
        switch anchor {
        case .startOfString: return options.contains(.multiline) ? .startOfString : .startOfStringOnly
        case .startOfStringOnly: return .startOfStringOnly
        case .endOfString: return options.contains(.multiline) ? .endOfString : .endOfStringOnly
        case .endOfStringOnly: return .endOfStringOnly
        case .endOfStringOnlyNotNewline: return .endOfStringOnlyNotNewline
        case .wordBoundary: return .wordBoundary
        case .nonWordBoundary: return .nonWordBoundary
        case .previousMatchEnd: return .previousMatchEnd
        }
    }

    func compile(_ quantifiedExpression: QuantifiedExpression) throws -> FSM {
        let expression = quantifiedExpression.expression
        let isLazy = quantifiedExpression.quantifier.isLazy
        if isLazy {
            containsLazyQuantifiers = true
        }
        switch quantifiedExpression.quantifier.type {
        case .zeroOrMore: return .zeroOrMore(try compile(expression), isLazy)
        case .oneOrMore: return .oneOrMore(try compile(expression), isLazy)
        case .zeroOrOne: return .zeroOrOne(try compile(expression), isLazy)
        case let .range(range): return try compile(expression, range, isLazy)
        }
    }

    func compile(_ match: Match) throws -> FSM {
        let isCaseInsensitive = options.contains(.caseInsensitive)
        let dotMatchesLineSeparators = options.contains(.dotMatchesLineSeparators)
        switch match {
        case let .character(c): return .character(c, isCaseInsensitive)
        case let .string(s): return .string(s
            , isCaseInsensitive)
        case .anyCharacter: return .anyCharacter(includingNewline: dotMatchesLineSeparators)
        case let .set(set): return .characterSet(set, isCaseInsensitive, false)
        case let .group(group): return .characterGroup(group, isCaseInsensitive)
        }
    }

    func compile(_ unit: Unit, _ quantifier: Quantifier) throws -> FSM {
        let isLazy = quantifier.isLazy
        if isLazy {
            containsLazyQuantifiers = true
        }
        switch quantifier.type {
        case .zeroOrMore: return .zeroOrMore(try compile(unit), isLazy)
        case .oneOrMore: return .oneOrMore(try compile(unit), isLazy)
        case .zeroOrOne: return .zeroOrOne(try compile(unit), isLazy)
        case let .range(range): return try compile(unit, range, isLazy)
        }
    }

    func compile(_ unit: Unit, _ range: RangeQuantifier, _ isLazy: Bool) throws -> FSM {
        let prefix = try compileRangePrefix(unit, range)
        let suffix: FSM
        if let upperBound  = range.upperBound {
            guard upperBound >= range.lowerBound else {
                throw Regex.Error("Invalid range quantifier. Upper bound must be greater than or equal than lower bound", 0)
            }

            // Compile the optional matches into `x(x(x(x)?)?)?`. This special
            // form makes sure that matcher can cache the results during backtracking.
            let count = upperBound - range.lowerBound
            suffix = try (0..<count).reduce(FSM.empty) { result, _ in
                let expression = try compile(unit)
                return .zeroOrOne(.group(.concatenate(expression, result)), isLazy)
            }
        } else {
            suffix = .zeroOrMore(try compile(unit), isLazy)
        }
        return FSM.concatenate(prefix, suffix)
    }

    func compileRangePrefix(_ unit: Unit, _ range: RangeQuantifier) throws -> FSM {
        func getString() -> String? {
            guard let match = unit as? Match else {
                return nil
            }
            switch match {
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
        return FSM.string(s, options.contains(.caseInsensitive))
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
            state.transitions = ContiguousArray(state.transitions.map {
                // [Optimization] Remove "technical" states
                if !captureGroupState.contains($0.end) &&
                    $0.end.transitions.count == 1 &&
                    $0.end.transitions[0].isUnconditionalEpsilon {
                    return Transition($0.end.transitions[0].end, $0.condition)
                }
                return $0
            })
        }
    }
}

// MARK: - CompiledRegex

final class CompiledRegex {
    // MARK: State Machine

    /// All possible transitions between all states of the state machine.
    let fsm: CompiledStateMachine

    // MARK: Metadata

    /// All the capture groups with their indexes.
    let captureGroups: ContiguousArray<CompiledCaptureGroup>

    /// `true` if the regex doesn't contain any of the features which can't be
    /// simulated solely by NFA and require backtracking.
    let isRegular: Bool

    /// If `true`, requires the pattern to match the start of the string.
    let isFromStartOfString: Bool

    let symbols: Symbols

    init(fsm: CompiledStateMachine, captureGroups: [CompiledCaptureGroup], isRegular: Bool, isFromStartOfString: Bool, symbols: Symbols) {
        self.fsm = fsm
        self.captureGroups = ContiguousArray(captureGroups)
        self.isRegular = isRegular
        self.isFromStartOfString = isFromStartOfString
        self.symbols = symbols
    }
}

typealias CompiledState = Int

struct CompiledStateMachine {
    let transitions: ContiguousArray<ContiguousArray<CompiledTransition>>
}

struct CompiledTransition {
    let end: CompiledState
    let condition: Condition
}

struct CompiledCaptureGroup {
    let index: Int
    let start: CompiledState
    let end: CompiledState
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
    fileprivate(set) var map = [CompiledState: Details]()
    #endif

    struct Details {
        let unit: Unit
        let isEnd: Bool
    }

    func description(for state: CompiledState) -> String {
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
}
