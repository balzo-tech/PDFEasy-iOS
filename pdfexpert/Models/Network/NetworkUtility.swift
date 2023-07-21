//
//  NetworkUtility.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 21/07/23.
//

import Foundation

internal extension String {
    var urlEscaped: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
    
    var utf8Encoded: Data {
        return self.data(using: .utf8)!
    }
}

internal extension Optional where Wrapped == Int {
    var toString:String {
        return self != nil ? String(describing: self) : ""
    }
}

internal extension Int {
    var toString:String {
        return String(describing: self)
    }
}

internal extension Date {
    var toString:String {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.string(from: self)
    }
    
    var toDateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: self)
    }
}

internal extension Bundle {
    static func getTestData(from fileName:String) -> Data {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
                return Data()
        }
        return data
    }
}

internal extension Data {
    static func JSONResponseDataFormatter(_ data: Data) -> String {
        return JSONPrettyDataFormatter(data)
    }
    
    static func JSONRequestDataFormatter(_ data: Data) -> String {
        return JSONPrettyDataFormatter(data)
    }
    
    private static func JSONPrettyDataFormatter(_ data: Data) -> String {
        do {
            let dataAsJSON = try JSONSerialization.jsonObject(with: data)
            let prettyData =  try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
            return String(data: prettyData, encoding: .utf8) ?? ""
        } catch {
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}
