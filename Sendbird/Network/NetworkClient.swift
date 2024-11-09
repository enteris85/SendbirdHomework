//
//  NetworkClient.swift
//  
//
//  Created by Sendbird
//

import Foundation
import Alamofire

public protocol Request {
    associatedtype Response: Decodable
    var url: URL { get }
    var method: String { get }
    var parameters: [String: Any]? { get }
}

public protocol SBNetworkClient {
    /// 리퀘스트를 요청하고 리퀘스트에 대한 응답을 받아서 전달합니다
    func request<R: Request>(
        request: R,
        completionHandler: @escaping (Result<R.Response, Error>) -> Void
    )
}

enum UserError: Error {
    case needNickname
    case maxCountExceeded
    case partialFailure
}

final class NetworkClient: SBNetworkClient {
    private let limitManager: NetworkLimitManager = NetworkLimitManager()
    
    func request<R>(request: R, 
                    completionHandler: @escaping (Result<R.Response, any Error>) -> Void) where R : Request {
        limitManager.enqueueAction {
            self.performRequest(request: request, completionHandler: completionHandler)
        }
    }
    
    private func performRequest<R: Request>(
        request: R,
        completionHandler: @escaping (Result<R.Response, Error>) -> Void
    ) {
        let headers: HTTPHeaders = [
            "Api-Token": AppStatic.API.API_TOKEN
        ]
        let method = HTTPMethod(rawValue: request.method)
        
        let encoding: ParameterEncoding = (method == .get) ? URLEncoding.default : JSONEncoding.default
        
        AF.request(
            request.url,
            method: method,
            parameters: request.parameters,
            encoding: encoding,
            headers: headers
        )
        .validate()
        .responseData { response in
            switch response.result {
            case .success(let data):
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    let decodedResponse = try decoder.decode(R.Response.self, from: data)
                    completionHandler(.success(decodedResponse))
                } catch {
                    completionHandler(.failure(error))
                }
                
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}
