//
//  UserStorage.swift
//  
//
//  Created by Sendbird
//

import Foundation
import OrderedCollections


/// Sendbird User 를 관리하기 위한 storage class입니다
public protocol SBUserStorage {
    /// 해당 User를 저장 또는 업데이트합니다
    func upsertUser(_ user: SBUser)
    
    /// 현재 저장되어있는 모든 유저를 반환합니다
    func getUsers() -> [SBUser]
    /// 현재 저장되어있는 유저 중 nickname을 가진 유저들을 반환합니다
    func getUsers(for nickname: String) -> [SBUser]
    /// 현재 저장되어있는 유저들 중에 지정된 userId를 가진 유저를 반환합니다.
    func getUser(for userId: String) -> (SBUser)?
    /// 저장되어 있는 데이터 전부 삭제합니다.
    func removeAll()
}

final class UserStorage: SBUserStorage {
    private var userList: OrderedDictionary<String, SBUser> = [:]
    private var nicknameList: Set<String> = Set()
    private let queue = DispatchQueue(label: "com.sendbird.storage", attributes: .concurrent)
    
    func upsertUser(_ user: SBUser) {
        queue.sync(flags: .barrier) {
            self.userList[user.userId] = user
        }
    }
    
    func getUsers() -> [SBUser] {
        queue.sync { Array(userList.values) }
    }
    
    // interview 문서상으론 언제쓰는건지 잘 이해가 되지않아서..일단 검색했던 nickname일 경우 메모리 기반으로 리턴하도록 했습니다.
    func getUsers(for nickname: String) -> [SBUser] {
        queue.sync(flags: .barrier) {
            if nicknameList.contains(nickname) {
                return userList.values.filter { $0.nickname == nickname }
            }
            else {
                nicknameList.insert(nickname)
                return []
            }
        }
    }

    func getUser(for userId: String) -> SBUser? {
        queue.sync {
            self.userList[userId]
        }
    }
    
    func removeAll() {
        queue.sync(flags: .barrier) {
            nicknameList.removeAll()
            userList.removeAll()
        }
    }
}
