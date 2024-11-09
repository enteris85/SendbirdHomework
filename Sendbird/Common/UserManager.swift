//
//  UserManager.swift
//  
//
//  Created by Sendbird
//

import Foundation

public typealias UserResult = Result<(SBUser), Error>
public typealias UsersResult = Result<[SBUser], Error>

/// Sendbird User Managent를 위한 SDK interface입니다.
public protocol SBUserManager {
    var networkClient: SBNetworkClient { get }
    var userStorage: SBUserStorage { get }
    
    /// Sendbird Application ID 및 API Token을 사용하여 SDK을 초기화합니다
    /// Init은 앱이 launching 될 때마다 불러야 합니다
    /// 만약 init의 sendbird application ID가 직전의 init에서 전달된 sendbird application ID와 다르다면 앱 내에 저장된 모든 데이터는 삭제되어야 합니다
    /// - Parameters:
    ///    - applicationId: Sendbird의 Application ID
    ///    - apiToken: 해당 Application에서 발급된 API Token
    func initApplication(applicationId: String, apiToken: String)
    
    /// UserCreationParams를 사용하여 새로운 유저를 생성합니다.
    /// Profile URL은 임의의 image URL을 사용하시면 됩니다
    /// 생성 요청이 성공한 뒤에 userStorage를 통해 캐시에 추가되어야 합니다
    /// - Parameters:
    ///    - params: User를 생성하기 위한 값들의 struct
    ///    - completionHandler: 생성이 완료된 뒤, user객체와 에러 여부를 담은 completion Handler
    func createUser(params: UserCreationParams, completionHandler: ((UserResult) -> Void)?)
    
    /// UserCreationParams List를 사용하여 새로운 유저들을 생성합니다.
    /// 한 번에 생성할 수 있는 사용자의 최대 수는 10명로 제한해야 합니다
    /// Profile URL은 임의의 image URL을 사용하시면 됩니다
    /// 생성 요청이 성공한 뒤에 userStorage를 통해 캐시에 추가되어야 합니다
    /// - Parameters:
    ///    - params: User를 생성하기 위한 값들의 struct
    ///    - completionHandler: 생성이 완료된 뒤, user객체와 에러 여부를 담은 completion Handler
    func createUsers(params: [UserCreationParams], completionHandler: ((UsersResult) -> Void)?)
    
    /// 특정 User의 nickname 또는 profileURL을 업데이트합니다
    /// 업데이트 요청이 성공한 뒤에 캐시에 upsert 되어야 합니다 
    func updateUser(params: UserUpdateParams, completionHandler: ((UserResult) -> Void)?)
    
    /// userId를 통해 특정 User의 정보를 가져옵니다
    /// 캐시에 해당 User가 있으면 캐시된 User를 반환합니다
    /// 캐시에 해당 User가 없으면 /GET API 호출하고 캐시에 저장합니다
    func getUser(userId: String, completionHandler: ((UserResult) -> Void)?)
    
    /// Nickname을 필터로 사용하여 해당 nickname을 가진 User 목록을 가져옵니다
    /// GET API를 호출하고 캐시에 저장합니다
    /// Get users API를 활용할 때 limit은 100으로 고정합니다
    func getUsers(nicknameMatches: String, completionHandler: ((UsersResult) -> Void)?)
}

final class UserManager: SBUserManager {
    var networkClient: SBNetworkClient
    var userStorage: SBUserStorage
    
    private let serialQueue = DispatchQueue(label: "com.sendbird.userQueue")
    
    init() {
        networkClient = NetworkClient()
        userStorage = UserStorage()
    }
    
    func initApplication(applicationId: String, apiToken: String) {
        if AppStatic.API.APP_ID.isEmpty == false &&
            AppStatic.API.APP_ID != applicationId {
            userStorage.removeAll()
        }
        AppStatic.API.APP_ID = applicationId
        AppStatic.API.API_TOKEN = apiToken
    }
    
    func createUser(params: UserCreationParams, completionHandler: ((UserResult) -> Void)?) {
        let request = RequestCreateUser(request: params)
        networkClient.request(request: request) { result in
            switch result {
            case .success(let response):
                self.userStorage.upsertUser(response)
                completionHandler?(.success(response))
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
    func createUsers(params: [UserCreationParams], completionHandler: ((UsersResult) -> Void)?) {
        // 10개 이상일 경우 에러 리턴
        guard params.count <= 10 else {
            completionHandler?(.failure(UserError.maxCountExceeded))
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var result = [UserResult]() // 결과 담을 배열
        
        for param in params {
            dispatchGroup.enter()
            
            serialQueue.async {
                self.createUser(params: param) { userResult in
                    result.append(userResult)
                    dispatchGroup.leave()
                }
            }
        }
        
        // 모든 request에 대한 응답 완료
        dispatchGroup.notify(queue: .main) {
            let successUsers = result.compactMap { try? $0.get() }
            // 모두 성공일 경우만 success
            let returnResult: UsersResult = successUsers.count == result.count ? .success(successUsers) :
                .failure(UserError.partialFailure)
            completionHandler?(returnResult)
        }
    }
    
    func updateUser(params: UserUpdateParams, completionHandler: ((UserResult) -> Void)?) {
        let request = RequestUpdateUser(request: params)
        
        networkClient.request(request: request) { result in
            switch result {
            case .success(let response):
                self.userStorage.upsertUser(response)
                completionHandler?(.success(response))
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
    func getUser(userId: String, completionHandler: ((UserResult) -> Void)?) {
        if let user = self.userStorage.getUser(for: userId) {
            completionHandler?(.success(user))
            return
        }
        
        let request = RequestGetUser(userId: userId)
        networkClient.request(request: request) { result in
            switch result {
            case .success(let response):
                self.userStorage.upsertUser(response)
                completionHandler?(.success(response))
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
    func getUsers(nicknameMatches: String, completionHandler: ((UsersResult) -> Void)?) {
        guard nicknameMatches.isEmpty == false else {
            completionHandler?(.failure(UserError.needNickname))
            return
        }
        let users = self.userStorage.getUsers(for: nicknameMatches)
        if users.isEmpty == false {
            completionHandler?(.success(users))
            return
        }
        
        let request = RequestGetUsers(nickname: nicknameMatches)
        networkClient.request(request: request) { result in
            switch result {
            case .success(let response):
                for item in response.users {
                    self.userStorage.upsertUser(item)
                }
                completionHandler?(.success(response.users))
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }
    
  
}
