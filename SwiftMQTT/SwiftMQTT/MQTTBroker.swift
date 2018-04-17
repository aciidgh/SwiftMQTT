//
//  MQTTBroker.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/20/17.
//  Copyright © 2017 Object Computing Inc. All rights reserved.
//

import Foundation

public protocol MQTTBroker {

    func connect(completion: MQTTSessionCompletionBlock?)

    func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool, completion: MQTTSessionCompletionBlock?)
    
    func subscribe(to topics: [String: MQTTQoS], completion: MQTTSessionCompletionBlock?)
    
    func unSubscribe(from topics: [String], completion: MQTTSessionCompletionBlock?)
    
    func disconnect()
}

public extension MQTTBroker {

    func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool) {
        publish(data, in: topic, delivering: qos, retain: retain, completion: nil)
    }
    
    func subscribe(to topics: [String: MQTTQoS]) {
        subscribe(to: topics, completion: nil)
    }

    func subscribe(to topic: String, delivering qos: MQTTQoS, completion: MQTTSessionCompletionBlock? = nil) {
        subscribe(to: [topic: qos], completion: completion)
    }
    
    func unSubscribe(from topics: [String]) {
        unSubscribe(from: topics, completion: nil)
    }
    
    func unSubscribe(from topic: String, completion: MQTTSessionCompletionBlock? = nil) {
        unSubscribe(from: [topic], completion: completion)
    }
}
