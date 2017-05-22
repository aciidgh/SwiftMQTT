//
//  MQTTDatedSnapshot.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/22/17.
//  Copyright © 2017 Object Computing Inc. All rights reserved.
//

import Foundation

private final class ReadWriteMutex {
	private var imp = pthread_rwlock_t()

	public init() {
		pthread_rwlock_init(&imp, nil)
	}
	
	deinit {
		pthread_rwlock_destroy(&imp)
	}
	
	@discardableResult public func reading<T>(_ closure: () throws -> T) rethrows -> T {
		defer { pthread_rwlock_unlock(&imp) }
		pthread_rwlock_rdlock(&imp)
		return try closure()
	}
	
	@discardableResult public func writing<T>(_ closure: () throws -> T) rethrows-> T {
		defer { pthread_rwlock_unlock(&imp) }
		pthread_rwlock_wrlock(&imp)
		return try closure()
	}
}

public class MQTTDatedSnapshot {
	private let issueQueue: DispatchQueue
    private let sendTimer: DispatchSourceTimer!
	private let interval: TimeInterval
	private let dispatch: ([String: MQTTMessage])->()
	private let lock = ReadWriteMutex()

	private var messages : [String: MQTTMessage] = [:]
	
	public init(label: String, interval: TimeInterval = 3.0, dispatch: @escaping ([String: MQTTMessage])->()) {
		self.issueQueue = DispatchQueue(label: label, qos: .background, target: nil)
		self.interval = interval
		self.dispatch = dispatch
		
		sendTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
		sendTimer.scheduleRepeating(deadline: .now() + interval, interval: interval)
		sendTimer.setEventHandler { [weak self] in
			self?.sendNow()
		}
		sendTimer.resume()
	}
    
    deinit {
        sendTimer.cancel()
    }
    
    public func sendNow() {
		let local: [String: MQTTMessage] = lock.writing {
			let copy = messages
			messages.removeAll(keepingCapacity: true)
			return copy
		}
		if !local.isEmpty {
			self.issueQueue.async { [weak self] in
				self?.dispatch(local)
			}
		}
    }
	
	public func on(message: MQTTMessage) {
		lock.writing {
			if messages[message.topic] == nil || message.retain == false {
				messages[message.topic] = message
			}
		}
	}
}
