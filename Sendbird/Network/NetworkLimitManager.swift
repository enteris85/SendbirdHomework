//
//  NetworkLimitManager.swift
//  Sendbird
//
//  Created by 이규석 on 11/4/24.
//

import Foundation

final class NetworkLimitManager {
    private let limit: TimeInterval = 1.0
    private var lastRequestItem: Date?
    private var isRunning: Bool = false
    private var queue: [()-> Void] = []
    private let dispatchQueue = DispatchQueue(label: "com.sendbird.limitManager", attributes: .concurrent)
    
    func enqueueAction(action: @escaping () -> Void) {
        dispatchQueue.async(flags: .barrier) {
            self.queue.append(action)
            self.dequeue()
        }
    }
    
    func dequeue() {
        guard isRunning == false, queue.isEmpty == false else { return }
        self.isRunning = true
        let action = queue.removeFirst()
        action()
        
        // 지금 요청으로 부터 1초뒤에 큐에 있는 job 요청
        DispatchQueue.global().asyncAfter(deadline: .now() + limit) {
            self.isRunning = false
            self.dequeue()
        }
    }
}
