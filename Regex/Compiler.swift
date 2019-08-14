// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

final class Compiler {
    private let parser: Parser
    private let options: Regex.Options
    private var symbols: Symbols
    private var captureGroups: [CaptureGroup] = []
    private var backreferences: [AST.Backreference] = []

    init(_ pattern: String, _ options: Regex.Options) {
        self.parser = Parser(pattern, options)
        self.options = options
        self.symbols = Symbols()
    }

    func compile() throws -> (CompiledRegex, Symbols) {
        let ast = try parser.parse()
        symbols.ast = ast
        let fsm = try compile(ast.expression)
        try validateBackreferences()
        return (CompiledRegex(fsm: fsm, captureGroups: captureGroups), symbols)
    }
}

private extension Compiler {
    func compile(_ unit: Unit) throws -> FSM {
        let fsm = try _compile(unit)
        if Regex.isDebugModeEnabled {
            symbols.map[fsm.start] = Symbols.Details(unit: unit, isEnd: false)
            symbols.map[fsm.end] = Symbols.Details(unit: unit, isEnd: true)
        }
        return fsm
    }

    func _compile(_ unit: Unit) throws -> FSM {
        switch unit {
        case let expression as AST.Expression:
            return .concatenate(try expression.children.map(compile))

        case let group as AST.Group:
            let fsms = try group.children.map(compile)
            let fms = FSM.group(.concatenate(fsms))
            if group.isCapturing { // Remember the group that we just compiled.
                captureGroups.append(CaptureGroup(index: group.index, start: fms.start, end: fms.end))
            }
            return fms

        case let backreference as AST.Backreference:
            backreferences.append(backreference)
            return .backreference(backreference.index)

        case let alternation as AST.Alternation:
            return .alternate(try alternation.children.map(compile))

        case let anchor as AST.Anchor:
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

        case let quantifier as AST.QuantifiedExpression:
            let expression = quantifier.expression
            switch quantifier.type {
            case .zeroOrMore: return .zeroOrMore(try compile(expression))
            case .oneOrMore: return .oneOrMore(try compile(expression))
            case .zeroOrOne: return .zeroOrOne(try compile(expression))
            case let .range(range): return try compile(expression, range)
            }

        case let match as AST.Match:
            let isCaseInsensitive = options.contains(.caseInsensitive)
            switch match.type {
            case let .character(c): return .character(c, isCaseInsensitive: isCaseInsensitive)
            case let .anyCharacter(includingNewline): return .anyCharacter(includingNewline: includingNewline)
            case let .characterSet(set): return .characterSet(set, isCaseInsensitive: isCaseInsensitive)
            }

        default:
            fatalError("Unsupported unit \(unit)")
        }
    }

    func compile(_ unit: Unit, _ range: ClosedRange<Int>) throws -> FSM {
        let prefix: FSM = try .concatenate((0..<range.lowerBound).map { _ in
            try compile(unit)
        })
        let suffix: FSM
        if range.upperBound == Int.max {
            suffix = .zeroOrOne(try compile(unit))
        } else {
            // Compile the optional matches into `x(x(x(x)?)?)?`. We use this
            // specific form with grouping to make sure that matcher can cache
            // the results during backtracking.
            suffix = try range.dropLast().reduce(FSM.empty) { result, _ in
                let expression = try compile(unit)
                return .zeroOrOne(.group(.concatenate(expression, result)))
            }
        }
        return FSM.concatenate(prefix, suffix)
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

// MARK: - CompiledRegex

struct CompiledRegex {
    /// The starting index in the compiled regular expression.
    let fsm: FSM

    /// All the capture groups with their indexes.
    let captureGroups: [CaptureGroup]
}

struct CaptureGroup {
    let index: Int
    let start: State
    let end: State
}

// MARK: - Symbols

/// Mapping between states of the finite state machine and the nodes for which
/// they were produced.
struct Symbols {
    // TODO: tidy up
    fileprivate(set) var ast: AST?
    fileprivate(set) var map = [State: Details]()

    struct Details {
        let unit: Unit
        let isEnd: Bool
    }
}
