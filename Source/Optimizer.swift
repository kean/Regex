// The MIT License (MIT)
//
// Copyright (c) 2019 Alexander Grebenyuk (github.com/kean).

import Foundation

final class Optimizer {
    private var groupIndex = 1
    private var nextGroupIndex: Int {
        defer { groupIndex += 1 }
        return groupIndex
    }

    func optimize(_ ast: AST) -> AST {
        return AST(isFromStartOfString: ast.isFromStartOfString, root: optimize(ast.root))
    }

    func optimize(_ unit: Unit) -> Unit {
        switch unit {
        case let expression as ImplicitGroup: return optimize(expression)
        case let group as Group: return optimize(group)
        case let alternation as Alternation: return optimize(alternation)
        case let quantifier as QuantifiedExpression: return optimize(quantifier)
        default: return unit
        }
    }

    func optimize(_ expression: ImplicitGroup) -> Unit {
        var input = Array(expression.children.reversed())
        var output = [Unit]()

        while let unit = input.popLast() {
            switch unit {
            // [Optimization] Collapse multiple string into a single string
            case let match as Match:
                guard case let .character(c) = match else {
                    output.append(match)
                    continue
                }

                var chars = [c]
                while let match = input.last as? Match, case let .character(c) = match {
                    input.removeLast()
                    chars.append(c)
                }
                if chars.count > 1 {
                    output.append(Match.string(String(chars)))
                } else {
                    output.append(Match.character(chars[0]))
                }
            default:
                output.append(optimize(unit))
            }
        }
        return output.count > 1 ? ImplicitGroup(children: output) : output[0]
    }

    func optimize(_ group: Group) -> Group {
        return Group(
            index: nextGroupIndex, // TODO: this is not the right place to do this
            isCapturing: group.isCapturing,
            children: group.children.map(optimize)
        )
    }

    func optimize(_ alternation: Alternation) -> Alternation {
        // Flatten alternations to make AST prettier
        let children = alternation.children.flatMap { child -> [Unit] in
            (child as? Alternation)?.children ?? [child]
        }
        return Alternation(children: children.map(optimize))
    }

    func optimize(_ expression: QuantifiedExpression) -> QuantifiedExpression {
        return QuantifiedExpression(expression: optimize(expression.expression), quantifier: expression.quantifier)
    }
}
