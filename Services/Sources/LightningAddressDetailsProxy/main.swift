//
//  main.swift
//  Services
//
//  Created by Thomas Rademaker on 12/6/25.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import CloudSDK
import AWSLambdaRuntime
import AWSLambdaEvents
import AsyncHTTPClient
import HTTPTypes


let runtime = LambdaRuntime { (event: APIGatewayV2Request, context: LambdaContext) -> APIGatewayV2Response in
    return await handle(event, context: context)
}

try await runtime.run()

enum NetworkError: Error {
    case invalidLightningAddress
    case invalidURL
    case invalidResponse
    case urlSession(Error)
}

struct LNURLpResponse: Codable {
    let callback: String
}

func toUrl(identifier: String) throws (NetworkError) -> (lnurlpUrl: String, keysendUrl: String, nostrUrl: String) {
    let parts = identifier.split(separator: "@")
    guard parts.count == 2 else { throw .invalidLightningAddress }
    
    let domain = String(parts[1])
    let username = String(parts[0])
    
    let lnurlpUrl = "https://\(domain)/.well-known/lnurlp/\(username)"
    let keysendUrl = "https://\(domain)/.well-known/keysend/\(username)"
    let nostrUrl = "https://\(domain)/.well-known/nostr.json?name=\(username)"
    
    return (lnurlpUrl, keysendUrl, nostrUrl)
}

func getJSON(url: String) async throws (NetworkError) -> (data: Data, response: HTTPURLResponse) {
    guard let url = URL(string: url) else { throw .invalidURL }
    
    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InvalidResponse", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }
        
        return (data, httpResponse)
    } catch { throw .urlSession(error) }
}

func handle(_ event: APIGatewayV2Request, context: LambdaContext) async -> APIGatewayV2Response {
    guard let ln = event.queryStringParameters["ln"] else {
        return APIGatewayV2Response(statusCode: .badRequest, body: "Missing lightning address parameter")
    }
    
    do {
        let (lnurlpUrl, _, _) = try toUrl(identifier: ln)
        // Get LNURLp data
        let (lnurlpData, lnurlpResponse) = try await getJSON(url: lnurlpUrl)
        
        guard lnurlpResponse.statusCode < 300 else { return APIGatewayV2Response(statusCode: .init(code: lnurlpResponse.statusCode)) }
        
        // Decode LNURLp response
        let lnurlp = try JSONDecoder().decode(LNURLpResponse.self, from: lnurlpData)
        
        // Construct invoice URL with query parameters
        guard let callbackUrl = URL(string: lnurlp.callback) else { return APIGatewayV2Response(statusCode: .badRequest, body: "Invalid callback URL") }
        
        var components = URLComponents(url: callbackUrl, resolvingAgainstBaseURL: true)!
        components.queryItems = event.queryStringParameters.map { key, value in
            URLQueryItem(name: key, value: value)
        }
        
        guard let invoiceUrl = components.url else { return APIGatewayV2Response(statusCode: .badRequest, body: "Failed to construct invoice URL") }
        
        // Get invoice
        let (invoiceData, invoiceResponse) = try await getJSON(url: invoiceUrl.absoluteString)
        
        guard invoiceResponse.statusCode < 300 else { return APIGatewayV2Response(statusCode: .init(code: invoiceResponse.statusCode)) }
        
        // Return invoice response
        return APIGatewayV2Response(statusCode: .ok, headers: ["Content-Type": "application/json"], body: String(data: invoiceData, encoding: .utf8) ?? "{}")
        
    } catch {
        return APIGatewayV2Response(statusCode: .badRequest, body: "Error: \(error.localizedDescription)")
    }
}
