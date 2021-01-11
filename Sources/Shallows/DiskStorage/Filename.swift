//
//  Filename.swift
//  Shallows
//
//  Created by Олег on 13.02.2018.
//  Copyright © 2018 Shallows. All rights reserved.
//

import Foundation

public struct Filename : RawRepresentable, Hashable, ExpressibleByStringLiteral {
    
    public var hashValue: Int {
        return rawValue.hashValue
    }
    
    public var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
    
    public init(unicodeScalarLiteral value: String) {
        self.init(rawValue: value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(rawValue: value)
    }
    
    public func base64Encoded() -> String {
        guard let data = rawValue.data(using: .utf8) else {
            print("Something is very, very wrong: string \(rawValue) cannot be encoded with utf8")
            return rawValue
        }
        return data.base64EncodedString()
    }
    
    public func base64URLEncoded() -> String {
        return base64Encoded()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
    
    public struct Encoder {
        
        private let encode: (Filename) -> String
        
        private init(encode: @escaping (Filename) -> String) {
            self.encode = encode
        }
        
        @available(*, deprecated, message: "for any new storages, please use .base64URL")
        public static let base64: Encoder = Encoder(encode: { $0.base64Encoded() })
        public static let base64URL: Encoder = Encoder(encode: { $0.base64URLEncoded() })
        public static let noEncoding: Encoder = Encoder(encode: { $0.rawValue })
        public static func custom(_ encode: @escaping (Filename) -> String) -> Encoder {
            return Encoder(encode: encode)
        }
        
        public func encodedString(representing filename: Filename) -> String {
            return encode(filename)
        }
        
    }
    
}
