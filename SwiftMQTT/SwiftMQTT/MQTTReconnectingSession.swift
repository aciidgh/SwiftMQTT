//
//  MQTTReconnectingSession.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/20/17.
//  Copyright © 2017 Object Computing Inc. All rights reserved.
//

import Foundation

public protocol MQTTReconnectingSessionDelegate: class {
    func mqttDidReceive(message: MQTTMessage, from session: MQTTReconnectingSession)
    func mqttConnected(_ changed: Bool, for: MQTTReconnectingSession, error: Error?)
}

/*
    TODO: encapsulate credentials
*/

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
	
    public var timeout: TimeInterval = 1.0
    public var retryCount: Int = 3
    public var retryTimeInterval: TimeInterval = 1.0
    public var resuscitateTimeInterval: TimeInterval = 5.0
}

public extension MQTTSession {
    public convenience init(connectParams: MQTTConnectParams) {
        self.init(
			host: connectParams.host,
			port: connectParams.port,
			clientID: connectParams.clientID,
			cleanSession: connectParams.cleanSession,
			keepAlive: connectParams.keepAlive,
			connectionTimeout: connectParams.timeout,
			useSSL: connectParams.useSSL)
    }
}

public class MQTTReconnectingSession: MQTTBroker {
    fileprivate let connectParams: MQTTConnectParams
    private let batchPredicate: ([MQTTMessage])->Bool
    fileprivate var session: MQTTSession?
    
    public weak var delegate: MQTTReconnectingSessionDelegate?
    
    public init(connectParams: MQTTConnectParams, batchPredicate: @escaping ([MQTTMessage])->Bool) {
        self.batchPredicate = batchPredicate
        self.connectParams = connectParams
    }
    
    public func connect(completion: MQTTSessionCompletionBlock? = nil) {
		let session = MQTTSession(connectParams: connectParams)
        self.session = session
        session.delegate = self
        self.connectWithRetry(0, nil, completion)
    }
    
    public func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool, completion: MQTTSessionCompletionBlock?) {
        self.session?.publish(data, in: topic, delivering: qos, retain: retain, completion: completion)
    }
    
    public func subscribe(to topics: [String: MQTTQoS], completion: MQTTSessionCompletionBlock?) {
        self.session?.subscribe(to: topics, completion: completion)
    }
    
    public func unSubscribe(from topics: [String], completion: MQTTSessionCompletionBlock?) {
        self.session?.unSubscribe(from: topics, completion: completion)
    }
    
    public func disconnect() {
        self.session = nil
		self.delegate?.mqttConnected(false, for: self, error: nil)
    }
}

extension MQTTReconnectingSession {
    fileprivate func connectWithRetry(_ attempt: Int, _ error: Error?, _ completion: MQTTSessionCompletionBlock?) {
		if let session = session {
			session.connect { [weak self] success, newError in
				if success {
					completion?(success, newError)
					if let inform = self {
						inform.delegate?.mqttConnected(true, for: inform, error: newError ?? error)
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
		else {
		}
    }
    
    private func doRetry(_ attempt: Int, _ error: Error?, _ completion: MQTTSessionCompletionBlock?) {
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
            DispatchQueue.global().asyncAfter(deadline: .now() + connectParams.resuscitateTimeInterval) { [weak self] in
				self?.doResuscitate(completion)
            }
        }
    }
	
	private func doResuscitate(_ completion: MQTTSessionCompletionBlock?) {
		self.connect { [weak self] success, newError in
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

extension MQTTReconnectingSession: MQTTSessionDelegate {

    public func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
		self.delegate?.mqttDidReceive(message: message, from: self)
    }

    public func mqttDidDisconnect(session: MQTTSession, reason: MQTTSessionDisconnect, error: Error?) {
        if reason == .unexpected && connectParams.keepAlive > 0 {
            disconnect()
            connectResuscitate(nil)
        }
    }
}
