//
//  Request.swift
//  Sendbird
//
//  Created by 이규석 on 11/4/24.
//

import Foundation
struct APIURL {
    static let user = "https://api-\(AppStatic.API.APP_ID).sendbird.com/v3/users"
}

struct RequestCreateUser: Request {
    typealias Response = SBUser
    
    var url: URL = URL(string: APIURL.user)!
    var method: String { "POST" }
    var parameters: [String : Any]?
    
    init(request: UserCreationParams) {
        self.parameters = ["user_id": request.userId,
                              "nickname": request.nickname,
                           "profile_url": request.profileURL ?? ""]
    }
}

struct RequestUpdateUser: Request {
    typealias Response = SBUser

    var url: URL
    var method: String { "PUT" }
    var parameters: [String : Any]?
    
    init(request: UserUpdateParams) {
        url = URL(string: APIURL.user + "/\(request.userId)")!
        
        self.parameters = [:]
        
        if let nickname = request.nickname {
            self.parameters?["nickname"] = nickname
        }
        if let profileURL = request.profileURL {
            self.parameters?["profile_url"] = profileURL
        }
    }
}

struct RequestGetUser: Request {
    typealias Response = SBUser
    
    var url: URL = URL(string: APIURL.user)!
    var method: String { "GET "}
    var parameters: [String : Any]?
    
    init(userId: String) {
        url = URL(string: APIURL.user + "/\(userId)")!
    }
}

struct RequestGetUsers: Request {
    typealias Response = UserResponse
    
    var url: URL = URL(string: APIURL.user)!
    var method: String { "GET"}
    var parameters: [String : Any]?
    
    init(nickname: String) {
        parameters = ["limit": 100,
                      "nickname": nickname]
    }
}
