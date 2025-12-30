//
//  PreviewContainer.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 2/21/25.
//

import SwiftUI
import SwiftData

struct SampleDataTransactions: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let container = try ModelContainer(for: Transaction.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

        let transaction1 = Transaction(transactionType: .incoming, invoice: "lnbc2500u1pne092fdqqnp4qt6nmjr96e7ctnh2t2v55yaxcrl7pw447pj4838ktkdxhvl5mmr9qpp572k5dv9mv2ykz53wcfk8w256ffgm9e3nvp7t2z35r3rus9gqgvessp5vrxy6tm24qrk3f6c3pgve648xxtdycz908s07lqrz04663z56r7q9qyysgqcqpcxqyz5vqrzjqw9fu4j39mycmg440ztkraa03u5qhtuc5zfgydsv6ml38qd4azymlapyqqqqqqqfnvqqqqlgqqqq86qqjqxkn27rj0qxr03p33ls4j7ze6cc6l9tk0438jquf8f6zx5058ukdksljcprvamtxa22rfvpdsr77n3qmucsgnjs9zcq0dg9w32jcjrccp934797", transactionDescription: "", descriptionHash: "", preimage: "407ae08f820cdc81b54deebde412f7abe36dee72747644236a646d3743d1c21e", paymentHash: "f2ad46b0bb628961522ec26c772a9a4a51b2e633607cb50a341c47c815004333", amount: 250000000, feesPaid: 0, createdAt: 1737987401, expiresAt: 1738073801, settledAt: 1737987436)

        let transaction2 = Transaction(transactionType: .incoming, invoice: "lnbc210n1pnhs9mcdzju2d2zv33ypr8yet9ypfkzarnu2d2z4mfdcsryvfsxqs9xct5w03f4g2yv95kc7fq2e5kggzrdah8getnwsnp4qt6nmjr96e7ctnh2t2v55yaxcrl7pw447pj4838ktkdxhvl5mmr9qpp5kahxg04sx0x9cmmszxerp2as8a4u0d5h05mg08dncevn43h4asyssp5d4nvsag2mtendrl3yg5h5pqt2wmfa79vzynte53fryw8tqau3a9q9qyysgqcqpcxqyz5vqrzjqvdnqyc82a9maxu6c7mee0shqr33u4z9z04wpdwhf96gxzpln8jcrapyqqqqqqpryuqqqqlgqqqp8zqq2qwjdl4q89ngjs4mhnxw4zqywz4jsg75wv2cfxalfflhfht7hqr9m5pfa6djfagx6grqnv7vryu6cexv2tha86fm252n9nwwcs0py54hsqzyar4k", transactionDescription: "21 Free Sats Win 2100 Sats Daily Vid Contest", descriptionHash: "eec13e18cef51bfa974926039756c4e7a1a7807e6e4cff8994fe9ac59dcc5b28", preimage: "1401df1bdbadaff099dfe4b6c0c4040500399c63144fa8f7c4f96bd3eb6e0a62", paymentHash: "b76e643eb033cc5c6f7011b230abb03f6bc7b6977d36879db3c6593ac6f5ec09", amount: 21000, feesPaid: 0, createdAt: 1735923576, expiresAt: 1736009976, settledAt: 1735923614)

        let transaction3 = Transaction(transactionType: .outgoing, invoice: "lnbc80n1pnh0aacdzzffskgefq2pk82ue6ypqkganpde3kjmn8yppxjarrda5kugznv4kxvt2rw4ehgmmy0ynp4qt6nmjr96e7ctnh2t2v55yaxcrl7pw447pj4838ktkdxhvl5mmr9qpp5yyndl0h8pfts7ells8g2gtwzej2k47307vvam60zkk44d95wkylqsp5tuyl6ede0ym26klgatykpl26834x45aq685fvne7djn9wr0pqmzq9qyysgqcqpcxqyz5vqrzjqvdnqyc82a9maxu6c7mee0shqr33u4z9z04wpdwhf96gxzpln8jcrapyqqqqqqpryuqqqqlgqqqp8zqq2quc4yqzxfmdmarqjj2de55330auku48q07lpy4j39s7gjjxzzheqjq6qeqk2a8z2fd8pl5qd0saa5mwg6cgu3zpnttpyhns33pwyquegpe37mtv", transactionDescription: "Pay for alby hub", descriptionHash: "fgfdgmjfdkng3r9i4rojr4", preimage: "fldsfjrnto48j", paymentHash: "fkjndu4r93irk", amount: 345000, feesPaid: 0, createdAt: 1735923576, expiresAt: 1736009976, settledAt: 1735923614)

        container.mainContext.insert(transaction1)
        container.mainContext.insert(transaction2)
        container.mainContext.insert(transaction3)

        try container.mainContext.save()
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

struct SampleDataWallet: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let container = try ModelContainer(for: Wallet.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let wallet = Wallet(balance: 234553, alias: "My Wallet", blockHash: "ereijr03r4i8", blockHeight: 3452234, color: "0x34534", methods: [.getBalance, .listTransactions], network: "wowow", pubkey: "efjngfdg492")
        container.mainContext.insert(wallet)
        do {
            try container.mainContext.save()
            return container
        } catch {
            print("FAIL: \(error)")
            return container
        }
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

struct SampleCompositeData: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let container = try ModelContainer(for: Transaction.self, Wallet.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

        let transaction1 = Transaction(transactionType: .incoming, invoice: "lnbc2500u1pne092fdqqnp4qt6nmjr96e7ctnh2t2v55yaxcrl7pw447pj4838ktkdxhvl5mmr9qpp572k5dv9mv2ykz53wcfk8w256ffgm9e3nvp7t2z35r3rus9gqgvessp5vrxy6tm24qrk3f6c3pgve648xxtdycz908s07lqrz04663z56r7q9qyysgqcqpcxqyz5vqrzjqw9fu4j39mycmg440ztkraa03u5qhtuc5zfgydsv6ml38qd4azymlapyqqqqqqqfnvqqqqlgqqqq86qqjqxkn27rj0qxr03p33ls4j7ze6cc6l9tk0438jquf8f6zx5058ukdksljcprvamtxa22rfvpdsr77n3qmucsgnjs9zcq0dg9w32jcjrccp934797", transactionDescription: "", descriptionHash: "", preimage: "407ae08f820cdc81b54deebde412f7abe36dee72747644236a646d3743d1c21e", paymentHash: "f2ad46b0bb628961522ec26c772a9a4a51b2e633607cb50a341c47c815004333", amount: 250000000, feesPaid: 0, createdAt: 1737987401, expiresAt: 1738073801, settledAt: 1737987436)

        let transaction2 = Transaction(transactionType: .incoming, invoice: "lnbc210n1pnhs9mcdzju2d2zv33ypr8yet9ypfkzarnu2d2z4mfdcsryvfsxqs9xct5w03f4g2yv95kc7fq2e5kggzrdah8getnwsnp4qt6nmjr96e7ctnh2t2v55yaxcrl7pw447pj4838ktkdxhvl5mmr9qpp5kahxg04sx0x9cmmszxerp2as8a4u0d5h05mg08dncevn43h4asyssp5d4nvsag2mtendrl3yg5h5pqt2wmfa79vzynte53fryw8tqau3a9q9qyysgqcqpcxqyz5vqrzjqvdnqyc82a9maxu6c7mee0shqr33u4z9z04wpdwhf96gxzpln8jcrapyqqqqqqpryuqqqqlgqqqp8zqq2qwjdl4q89ngjs4mhnxw4zqywz4jsg75wv2cfxalfflhfht7hqr9m5pfa6djfagx6grqnv7vryu6cexv2tha86fm252n9nwwcs0py54hsqzyar4k", transactionDescription: "21 Free Sats Win 2100 Sats Daily Vid Contest", descriptionHash: "eec13e18cef51bfa974926039756c4e7a1a7807e6e4cff8994fe9ac59dcc5b28", preimage: "1401df1bdbadaff099dfe4b6c0c4040500399c63144fa8f7c4f96bd3eb6e0a62", paymentHash: "b76e643eb033cc5c6f7011b230abb03f6bc7b6977d36879db3c6593ac6f5ec09", amount: 21000, feesPaid: 0, createdAt: 1735923576, expiresAt: 1736009976, settledAt: 1735923614)

        let transaction3 = Transaction(transactionType: .outgoing, invoice: "lnbc80n1pnh0aacdzzffskgefq2pk82ue6ypqkganpde3kjmn8yppxjarrda5kugznv4kxvt2rw4ehgmmy0ynp4qt6nmjr96e7ctnh2t2v55yaxcrl7pw447pj4838ktkdxhvl5mmr9qpp5yyndl0h8pfts7ells8g2gtwzej2k47307vvam60zkk44d95wkylqsp5tuyl6ede0ym26klgatykpl26834x45aq685fvne7djn9wr0pqmzq9qyysgqcqpcxqyz5vqrzjqvdnqyc82a9maxu6c7mee0shqr33u4z9z04wpdwhf96gxzpln8jcrapyqqqqqqpryuqqqqlgqqqp8zqq2quc4yqzxfmdmarqjj2de55330auku48q07lpy4j39s7gjjxzzheqjq6qeqk2a8z2fd8pl5qd0saa5mwg6cgu3zpnttpyhns33pwyquegpe37mtv", transactionDescription: "Pay for alby hub", descriptionHash: "fgfdgmjfdkng3r9i4rojr4", preimage: "fldsfjrnto48j", paymentHash: "fkjndu4r93irk", amount: 345000, feesPaid: 0, createdAt: 1735923576, expiresAt: 1736009976, settledAt: 1735923614)

        container.mainContext.insert(transaction1)
        container.mainContext.insert(transaction2)
        container.mainContext.insert(transaction3)

        let wallet = Wallet(balance: 234553, alias: "My Wallet", blockHash: "ereijr03r4i8", blockHeight: 3452234, color: "0x34534", methods: [.getBalance, .listTransactions], network: "wowow", pubkey: "efjngfdg492")
        container.mainContext.insert(wallet)

        try container.mainContext.save()
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var sampleTransactions: Self = .modifier(SampleDataTransactions())
    @MainActor static var sampleWallet: Self = .modifier(SampleDataWallet())
    @MainActor static var sampleComposite: Self = .modifier(SampleCompositeData())
}

fileprivate func object<c: Codable>(resourceName: String) -> c? {
    guard let file = Bundle.main.url(forResource: resourceName, withExtension: "json"),
          let data = try? Data(contentsOf: file) else { return nil }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try? decoder.decode(c.self, from: data)
}
