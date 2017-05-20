//
//  MQTTBatchReceiver.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/20/17.
//  Copyright © 2017 Object Computing Inc. All rights reserved.
//

import Foundation

/*
    Reconnect logic
    multi-threaded batching of messages
*/

public protocol MQTTBatchReceiverDelegate: class {
    func mqttDidReceive(messages: [MQTTMessage], from session: MQTTSession)
    func mqttFailedToConnect(receiver: MQTTBatchReceiver, error: Error?)
    func mqttErrorOccurred(receiver: MQTTBatchReceiver, error: Error?)
}

public struct MQTTConnectParams {
/*
    host: String,
    port: UInt16,
    clientID: String,
    cleanSession: Bool,
    keepAlive: UInt16,
    useSSL: Bool = false
    queueName: String
    let retryCount = 3
    retryTimeInterval = TimeInterval(
    */
}

open class MQTTBatchReceiver {

    public init(connect: MQTTConnectParams, batchPredicate: ()->Bool) {
    }
    
    open func connect(completion: MQTTSessionCompletionBlock?) {
    }
    
    open func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool, completion: MQTTSessionCompletionBlock?) {
    }
    
    open func subscribe(to topic: String, delivering qos: MQTTQoS, completion: MQTTSessionCompletionBlock?) {
    }
    
    open func disconnect() {
    }
}

extension MQTTBatchReceiver: MQTTSessionDelegate {

    public func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
    }

    public func mqttDidDisconnect(session: MQTTSession, error: Error?) {
    }

    public func mqttSocketErrorOccurred(session: MQTTSession, error: Error?) {
    }
}
