import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

public struct UnitOfWorkMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let body = declaration.body else { return [] }
        let wrapped: CodeBlockItemSyntax = """
            try await unitOfWork.perform { ctx in
            \(body.statements)
            }
            """
        return [wrapped]
    }
}

@main
struct AcornMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [UnitOfWorkMacro.self]
}
