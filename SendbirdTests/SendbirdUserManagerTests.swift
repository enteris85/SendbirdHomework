//
//  SendbirdUserManagerTests.swift
//  SendbirdUserManagerTests
//
//  Created by Sendbird
//

import XCTest
@testable import Sendbird

final class UserManagerTests: UserManagerBaseTests {
    override func userManager() -> SBUserManager? {
        return UserManager()
    }
}

final class UserStorageTests: UserStorageBaseTests {
    override func userStorage() -> SBUserStorage? {
        return UserStorage()
    }
    // check nicknameList thread safety
    func testGetUserListThreadSafety() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        for i in 0..<100 {
            let user = SBUser(userId: String(i))
            storage.upsertUser(user)
        }
        
        let expectation = self.expectation(description: "GetUser with nickname from multiple threads")
        expectation.expectedFulfillmentCount = 2
        let queue1 = DispatchQueue(label: "com.test.queue1")
        let queue2 = DispatchQueue(label: "com.test.queue2")
        
        queue1.async {
            for i in 0..<100 {
                let _ = storage.getUsers(for: String(i))
            }
            expectation.fulfill()
        }
        queue2.async {
            for i in 0..<100 {
                let _ = storage.getUsers(for: String(i))
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}

final class NetworkLimitTest: XCTestCase {
    // 1초에 한개씩 요청이 전송되는지 테스트
    func testLimitManager() {
        let limitManager: NetworkLimitManager = NetworkLimitManager()
        
        let expectation = self.expectation(description: "NetworkLimitManager")
        expectation.expectedFulfillmentCount = 20
        
        let queue1 = DispatchQueue(label: "com.test.queue1")
        let queue2 = DispatchQueue(label: "com.test.queue2")
        
        queue1.async {
            for _ in 0..<10 {
                limitManager.enqueueAction {
                    print(Date())
                    expectation.fulfill()
                }
            }
        }
        
        queue2.async {
            for _ in 0..<10 {
                limitManager.enqueueAction {
                    print(Date())
                    expectation.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 23, handler: nil)
    }
}
