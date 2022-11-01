//
//  BaseRequest.swift
//  AllGram
//
//  Created by Alex Agarkov on 26.07.2022.
//

import Foundation
import Combine

public enum HTTPMethod: String {
    case GET, POST, PUT, PATCH, DELETE
}

public protocol BaseRequest {

    var url: URL { get }
    var queryItems: [String: String]? { get }
    var headers: [String: String]? { get }
    var httpMethod: HTTPMethod { get }
    var httpBody: [String: Any]? { get }
    
    associatedtype ReturnType: Codable
}

extension BaseRequest {
    
    func request() -> URLRequest {
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return URLRequest(url: (url))
        }
        
        var qItems: [URLQueryItem] = []
        if let tQueryItems = queryItems  {
            for item in tQueryItems {
                qItems.append(URLQueryItem(name: item.key, value: item.value))
            }
        }
        urlComponents.queryItems = qItems
        
        var request = URLRequest(url: (urlComponents.url)!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let tHeaders = headers {
            for header in tHeaders {
                request.addValue(header.value, forHTTPHeaderField: header.key)
            }
        }

        request.httpMethod = httpMethod.rawValue
        if let httpBody = httpBody {
            let jsonData = try! JSONSerialization.data(withJSONObject: httpBody, options: [])
            request.httpBody = jsonData
        }
        return request
    }
    
}
