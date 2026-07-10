//
//  AvocadoughModel.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/28/24.
//

import SwiftUI
@preconcurrency import SwiftData

typealias AvocadoughSchema = AvocadoughSchemaV1

enum AvocadoughSchemaV1: VersionedSchema, Sendable {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            NWCConnection.self,
            Transaction.self,
            Wallet.self,
        ]
    }
}


struct AvocadoughDataContainerViewModifier: ViewModifier {
    let container: ModelContainer
    let schema = Schema([
        NWCConnection.self,
        Transaction.self,
        Wallet.self,
    ])
    
    init(inMemory: Bool) {
        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
            container = try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            fatalError("Failed to create ModelContainer")
        }
    }
    
    func body(content: Content) -> some View {
        content
            .modelContainer(container)
    }
}

class AvocadoughModelOptions {
//    #if DEBUG
//    public static let inMemoryPersistence = true
//    #else
//    public static let inMemoryPersistence = false
//    #endif
    
    static let inMemoryPersistence = false
}


extension View {
    func setupModel(inMemory: Bool = AvocadoughModelOptions.inMemoryPersistence) -> some View {
        modifier(AvocadoughDataContainerViewModifier(inMemory: inMemory))
    }
}

