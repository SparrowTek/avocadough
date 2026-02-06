//
//  GenerateInvoiceService.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 4/12/25.
//

import Foundation

struct GenerateInvoiceService {
    enum GenerateInvoiceError: Error {
        case invalidLightningAddress
        case badURL
        case invalidCallbackURL
        case noStatusCode
        case badStatusCode(Int)
    }

    func generateInvoice(lightningAddress: String, amount: String, comment: String?) async throws -> GeneratedInvoice {
        let callbackURL = try await fetchCallbackURL(lightningAddress: lightningAddress)
        return try await fetchInvoice(callbackURL: callbackURL, amount: amount, comment: comment)
    }

    private func fetchCallbackURL(lightningAddress: String) async throws -> String {
        let components = lightningAddress.split(separator: "@")
        guard components.count == 2,
              let user = components.first,
              let domain = components.last else {
            throw GenerateInvoiceError.invalidLightningAddress
        }

        guard let url = URL(string: "https://\(domain)/.well-known/lnurlp/\(user)") else {
            throw GenerateInvoiceError.badURL
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw GenerateInvoiceError.noStatusCode }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GenerateInvoiceError.badStatusCode(httpResponse.statusCode)
        }

        let lnurlpResponse = try JSONDecoder().decode(LNURLpResponse.self, from: data)
        return lnurlpResponse.callback
    }

    private func fetchInvoice(callbackURL: String, amount: String, comment: String?) async throws -> GeneratedInvoice {
        guard var urlComponents = URLComponents(string: callbackURL) else {
            throw GenerateInvoiceError.invalidCallbackURL
        }

        var queryItems = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "amount", value: amount))
        queryItems.append(URLQueryItem(name: "comment", value: comment ?? ""))
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else { throw GenerateInvoiceError.badURL }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw GenerateInvoiceError.noStatusCode }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw GenerateInvoiceError.badStatusCode(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GeneratedInvoice.self, from: data)
    }
}
