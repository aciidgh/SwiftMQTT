//
//  MQTTBatchingSession.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/20/17.
//  Copyright © 2017 Object Computing Inc. All rights reserved.
//

import Foundation

public protocol MQTTBatchingSessionDelegate: class {
    func mqttDidReceive(messages: [MQTTMessage], from session: MQTTBatchingSession)
    func mqttConnected(_ changed: Bool, for: MQTTBatchingSession, error: Error?)
}

public struct MQTTCredentials {
    // username, password, useSSL, certs, lastWill
}

public struct MQTTConnectParams {
    public init(clientID: String) {
        self.clientID = clientID
    }
    public var clientID: String
    public var host: String = "localhost"
    public var port: UInt16 = 1883
    public var cleanSession: Bool = true
    public var keepAlive: UInt16 = 15
    public var useSSL: Bool = false
    public var retryCount: Int = 3
    public var retryTimeInterval: TimeInterval = 1.0
}

public extension MQTTSession {
    public convenience init(connectParams: MQTTConnectParams) {
        self.init(
			host: connectParams.host,
			port: connectParams.port,
			clientID: connectParams.clientID,
			cleanSession: connectParams.cleanSession,
			keepAlive: connectParams.keepAlive,
			connectionTimeout: connectParams.retryTimeInterval,
			useSSL: connectParams.useSSL)
    }
}

/*
    TODO: batch sends
    TODO: encapsulate credentials
*/

public class MQTTBatchingSession: MQTTBroker {
	fileprivate let issueQueue: DispatchQueue
    fileprivate let connectParams: MQTTConnectParams
    fileprivate let batchPredicate: ([MQTTMessage])->Bool
    fileprivate var session: MQTTSession!
    
    open weak var delegate: MQTTBatchingSessionDelegate?
    
    public init(connectParams: MQTTConnectParams, batchPredicate: @escaping ([MQTTMessage])->Bool) {
        self.batchPredicate = batchPredicate
        self.issueQueue = DispatchQueue(label: "com.SwiftMQTT.issue", qos: .background, target: nil)
        self.connectParams = connectParams
    }
    
    public func connect(completion: MQTTSessionCompletionBlock? = nil) {
        self.session = MQTTSession(connectParams: connectParams)
        self.session.delegate = self
        self.connectWithRetry(0, nil, completion)
    }
    
    public func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool, completion: MQTTSessionCompletionBlock?) {
        self.session.publish(data, in: topic, delivering: qos, retain: retain, completion: completion)
    }
    
    public func subscribe(to topics: [String: MQTTQoS], completion: MQTTSessionCompletionBlock?) {
        self.session.subscribe(to: topics, completion: completion)
    }
    
    public func unSubscribe(from topics: [String], completion: MQTTSessionCompletionBlock?) {
        self.session.unSubscribe(from: topics, completion: completion)
    }
    
    public func disconnect() {
        self.session = nil
        issueQueue.async {
            self.delegate?.mqttConnected(false, for: self, error: error)
        }
    }
}

extension MQTTBatchingSession {
    fileprivate func connectWithRetry(_ attempt: Int, _ error: Error?, _ completion: MQTTSessionCompletionBlock?) {
        self.session.connect { [weak self] success, newError in
            if success {
                completion?(success, newError)
                if let inform = self {
                    inform.issueQueue.async {
                        inform.delegate?.mqttConnected(true, for: inform, error: newError ?? error)
                    }
                }
            }
            else if let retry = self {
                retry.doRetry(attempt, newError ?? error, completion)
            }
            else {
                completion?(false, newError ?? error)
            }
        }
    }
    
    fileprivate func doRetry(_ attempt: Int, _ error: Error?, _ completion: MQTTSessionCompletionBlock?) {
        if attempt < connectParams.retryCount && connectParams.retryTimeInterval > 0.0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + connectParams.retryTimeInterval) {
                self.connectWithRetry(attempt + 1, error, completion)
            }
        }
        else {
            self.disconnect()
            connectResuscitate(nil)
        }
    }
    
    fileprivate func connectResuscitate(_ completion: MQTTSessionCompletionBlock?) {
        if connectParams.keepAlive > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + TimeInterval(connectParams.keepAlive)) { [weak self] in
                self?.connect { success, newError in
                    if success {
                        completion?(success, newError)
                    }
                    else if let retry = self {
                        retry.connectResuscitate(completion)
                    }
                    else {
                        completion?(false, newError)
                    }
                }
            }
        }
    }
}

extension MQTTBatchingSession: MQTTSessionDelegate {

    public func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
		issueQueue.async {
			self.delegate?.mqttDidReceive(messages: [message], from: self)
		}
    }

    public func mqttDidDisconnect(session: MQTTSession, reson: MQTTSessionDisconnect, error: Error?) {
        if reson == .unexpected && connectParams.keepAlive > 0 {
            disconnect()
            connectResuscitate(nil)
        }
    }
}
