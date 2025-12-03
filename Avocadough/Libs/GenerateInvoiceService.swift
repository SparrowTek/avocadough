//
//  GenerateInvoiceService.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 4/12/25.
//

import Foundation

struct GenerateInvoiceService {
    enum GenerateInvoiceError: Error {
        case badURL
        case badURLComponent
        case noStatusCode
        case badStatusCode(Int)
    }
    
    func generateInvoice(lightningAddress: String, amount: String, comment: String?) async throws -> GeneratedInvoice {
        let request = try await buildRequest(lightningAddress: lightningAddress, amount: amount, comment: comment)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw GenerateInvoiceError.noStatusCode }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(GeneratedInvoice.self, from: data)
        default:
            throw GenerateInvoiceError.badStatusCode(httpResponse.statusCode)
        }
    }
    
    private func buildRequest(lightningAddress: String, amount: String, comment: String?) async throws -> URLRequest {
        guard var urlComponents = URLComponents(string: "https://lightning-address-details-proxy.avocadough.xyz") else { throw GenerateInvoiceError.badURLComponent }
        urlComponents.queryItems = [
            URLQueryItem(name: "ln", value: lightningAddress),
            URLQueryItem(name: "amount", value: amount),
            URLQueryItem(name: "comment", value: comment ?? ""),
        ]
        
        guard let url = urlComponents.url else { throw GenerateInvoiceError.badURL }
        var request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 10.0)
        
        request.httpMethod = "get"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}
