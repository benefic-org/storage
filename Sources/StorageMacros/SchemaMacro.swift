//
//  File.swift
//  
//
//  Created by Caleb Jonas on 7/3/23.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

extension String {
    func toSnakeCasing() -> String {
        var copy = ""
        self.forEach {
            if $0.isUppercase && !copy.isEmpty { copy += "_" }
            copy += $0.lowercased()
        }
        return copy
    }
}

struct StorageAttributeDecl {
    var identifier: String
    var type: String
    var nullable: Bool
}

extension StorageAttributeDecl {
    func asAttributeMetadata() -> String {
        "AttributeMetadata(name: \"\(identifier)\", type: .\(type), nullable: \(nullable), transformer: nil)"
    }
}

public struct SchemaMacro: MemberAttributeMacro, MemberMacro, ConformanceMacro, PeerMacro {
   
    public static func expansion(
      of node: AttributeSyntax,
      providingConformancesOf declaration: some DeclGroupSyntax,
      in context: some MacroExpansionContext
    ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] {
        [("SchemaRepresentable", nil)]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        var attributeDeclarations = [StorageAttributeDecl]()
        declaration.as(ClassDeclSyntax.self)?.memberBlock.members
            .compactMap { $0.as(MemberDeclListItemSyntax.self) }
            .compactMap { $0.decl.as(VariableDeclSyntax.self)?.bindings.first }
            .forEach { variableDecl in
                guard let idPattern = variableDecl.pattern.as(IdentifierPatternSyntax.self) else { return }

                let untrimmedExplicitType = variableDecl.typeAnnotation?.description
                let explicitType = untrimmedExplicitType?.trimmingCharacters(in: CharacterSet(charactersIn: " :?"))
                let isNullable = untrimmedExplicitType?.hasSuffix("?")
                
                let type: String
                if let explicitType {
                    switch explicitType.lowercased() {
                    case "string": type = "String"
                    case "int": type = "Int"
                    case "float", "double": type = "Double"
                    default: type = explicitType.lowercased()
                    }
                } else {
                    // TODO: handle the use case where we don't have an explicit type.
                    type = "date"
                }
                
                let name = idPattern.identifier.text.trimmingCharacters(in: .whitespaces)
                
                attributeDeclarations.append(StorageAttributeDecl(identifier: name, type: type, nullable: isNullable ?? false))
            }
        
        let typeName: String
        if let asStruct = declaration.as(StructDeclSyntax.self) {
            typeName = asStruct.identifier.text
        } else if let asClass = declaration.as(ClassDeclSyntax.self) {
            typeName = asClass.identifier.text
        } else {
            typeName = "SOME"
        }
        
        let variables = attributeDeclarations.map {
            "var \($0.identifier): \($0.type.capitalized) { get }"
        }
            .joined(separator: "\n")
        
        let decl: DeclSyntax = """
protocol \(raw: typeName)Protocol {
    \(raw: variables)
}
"""

        return [decl]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        var attributeDeclarations = [StorageAttributeDecl]()
        declaration.memberBlock.members
            .compactMap { $0.as(MemberDeclListItemSyntax.self) }
            .compactMap { $0.decl.as(VariableDeclSyntax.self)?.bindings.first }
            .forEach { variableDecl in
                guard let idPattern = variableDecl.pattern.as(IdentifierPatternSyntax.self) else { return }

                let untrimmedExplicitType = variableDecl.typeAnnotation?.description
                let explicitType = untrimmedExplicitType?.trimmingCharacters(in: CharacterSet(charactersIn: " :?"))
                let isNullable = untrimmedExplicitType?.hasSuffix("?")
                
                let type: String
                if let explicitType {
                    switch explicitType.lowercased() {
                    case "string": type = "string"
                    case "int": type = "integer"
                    case "float", "double": type = "float"
                    default: type = explicitType.lowercased()
                    }
                } else {
                    type = "date"
                }
                
                let name = idPattern.identifier.text.trimmingCharacters(in: .whitespaces)
                
                attributeDeclarations.append(StorageAttributeDecl(identifier: name, type: type, nullable: isNullable ?? false))
            }
        
        let typeName: String
        if let asStruct = declaration.as(StructDeclSyntax.self) {
            typeName = asStruct.identifier.text
        } else if let asClass = declaration.as(ClassDeclSyntax.self) {
            typeName = asClass.identifier.text
        } else {
            typeName = "SOME"
//            fatalError("WAT")
        }
        
        let attrMetadatasArray = attributeDeclarations.map { $0.asAttributeMetadata() }.joined(separator: ",\n")
        
        let attrSwitchBody = attributeDeclarations.map {
            "case \"\($0.identifier)\": return [\($0.asAttributeMetadata())]"
        }.joined(separator: "\n")
        
        let attributeMetadatas = DeclSyntax(stringLiteral: """
static func _attributeMetadatas(filteredBy name: String?) -> [AttributeMetadata] {
    guard let name else { return [\(attrMetadatasArray)] }
    switch name {
    \(attrSwitchBody)
    default: return []
    }
}
""")

        let currentName: DeclSyntax = """
static var _schemaName: StaticString {
    "\(raw: typeName.toSnakeCasing())"
}
"""
        let migrationBody = """
try? current.versioned(.latest("\(typeName.toSnakeCasing())", .attribute(.string, named: "string")))
"""
        let automaticMigration: DeclSyntax = """
static func _migrate(as current: ModelMigrationBuilder<\(raw: typeName)>) -> ModelOperation<\(raw: typeName)>? {
    \(raw: migrationBody)
}
"""
//        let typealiasName: DeclSyntax = "typealias Conformant = \(raw: typeName)Protocol"
        
        return [
//            typealiasName,
            currentName,
            attributeMetadatas,
            automaticMigration
        ]
    }
    
    public static func expansion(of node: AttributeSyntax,
                          attachedTo declaration: some DeclGroupSyntax,
                          providingAttributesFor member: some DeclSyntaxProtocol,
                          in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Only accept Variables (no functions etc.)
        guard let varDecl = member.as(VariableDeclSyntax.self) else { return [] }
        
        // Don't append the Schema Attribute if it begins with an underscore.
        let identifier = varDecl.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text.trimmingCharacters(in: .whitespaces)
        let isUnderscored = identifier?.hasPrefix("_") ?? false
        guard !isUnderscored else { return [] }
        
        return [AttributeSyntax(
            attributeName: SimpleTypeIdentifierSyntax(
                name: .identifier("Attribute")
            )
        )]
    }
}

@main
struct StorageMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SchemaMacro.self,
    ]
}
