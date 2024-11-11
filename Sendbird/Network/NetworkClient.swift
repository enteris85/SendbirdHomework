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

enum SBError: Error {
    case needNickname // 닉네임 필수
    case maxCountExceeded // 최대 10개까지만 호출가능
    case partialFailure // 일부만 실패
    case exceededLimit // 1초에 10번이상호출
}

final class NetworkClient: SBNetworkClient {
    private let limitManager: NetworkLimitManager = NetworkLimitManager() // 1초에 한번요청 제한
    private let rateLimitQueue = DispatchQueue(label: "com.senbird.rateLimit", attributes: .concurrent)
    private var requestTimestamps: [Date] = []  // 요청 시간 기록
    private let maxRequestCount = 10
    private let maxTimeInterval: TimeInterval = 1.0
    
    func request<R>(request: R, 
                    completionHandler: @escaping (Result<R.Response, any Error>) -> Void) where R : Request {
        rateLimitQueue.async(flags: .barrier) {
            /**
             과제 문서엔 명시되어 있지않지만 1초에 10번으로 요청을 제한해야 한다는  답변을 받아서 추가하였습니다.
            제대로 이해한 건지 모르겠지만 해당 펑션의 호출을 1초에 10번으로 제한하며, 문서에 명시된 대로 요청된 request는 1초에 1번씩 요청을 수행하도록  구현하였습니다.
             */
            let currentTime = Date()
            self.requestTimestamps.append(currentTime)
            // 1초이상된 request는 제거함
            self.requestTimestamps = self.requestTimestamps.filter { currentTime.timeIntervalSince($0) < self.maxTimeInterval }
            // 요청 횟수 체크. 10번초과일 경우 return fail
            if self.requestTimestamps.count > self.maxRequestCount {
                completionHandler(.failure(SBError.exceededLimit))
            } else {
                self.limitManager.enqueueAction {
                    self.performRequest(request: request, completionHandler: completionHandler)
                }
            }
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
