//
//  JSONDecoder.swift
//  Services
//
//  Created by Thomas Rademaker on 12/6/25.
//

import Foundation

extension JSONDecoder {
    public static var btcPriceDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return decoder
    }
}
