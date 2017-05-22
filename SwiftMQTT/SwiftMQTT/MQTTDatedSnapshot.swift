//
//  MQTTDatedSnapshot.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/22/17.
//  Copyright © 2017 Object Computing Inc. All rights reserved.
//

import Foundation

public class MQTTDatedSnapshot {
	private let issueQueue: DispatchQueue
	private let interval: TimeInterval
	private let dispatch: ([String: MQTTMessage])->()
	
	private var begin = clock()
	private var messages : [String: MQTTMessage] = [:]
	
	public init(label: String, interval: TimeInterval = 3.0, dispatch: @escaping ([String: MQTTMessage])->()) {
		self.issueQueue = DispatchQueue(label: label, qos: .background, target: nil)
		self.interval = interval
		self.dispatch = dispatch
	}
	
	public func on(message: MQTTMessage) {
		messages[message.topic] = message
		let now = clock()
		let diff = TimeInterval(now - begin) / TimeInterval(CLOCKS_PER_SEC) * 10.0
		if diff > interval {
			begin = now
			let copy = messages
			messages.removeAll(keepingCapacity: true)
			self.issueQueue.async { [weak self] in
				self?.dispatch(copy)
			}
		}
	}
}
