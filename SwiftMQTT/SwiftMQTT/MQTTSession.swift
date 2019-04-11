//
//  MQTTSession.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

public protocol MQTTSessionDelegate: class {
    func mqttDidReceive(message: MQTTMessage, from session: MQTTSession)
    func mqttDidAcknowledgePing(from session: MQTTSession)
    func mqttDidDisconnect(session: MQTTSession, error: MQTTSessionError)
}

public typealias MQTTSessionCompletionBlock = (_ error: MQTTSessionError) -> Void

open class MQTTSession {
	
    let host: String
    let port: UInt16
    let connectionTimeout: TimeInterval
    let useSSL: Bool
    
    public let cleanSession: Bool
    public let keepAlive: UInt16
    public let clientID: String

    open var username: String?
    open var password: String?
    open var lastWillMessage: MQTTPubMsg?

    open weak var delegate: MQTTSessionDelegate?
    open var delegateQueue = DispatchQueue.main

    private var keepAliveTimer: DispatchSourceTimer?
    private var connectionCompletionBlock: MQTTSessionCompletionBlock?
    private var messagesCompletionBlocks = [UInt16: MQTTSessionCompletionBlock]()
    private var factory: MQTTPacketFactory
    
    private var stream: MQTTSessionStream?
    
    public init(
        host: String,
        port: UInt16,
        clientID: String,
        cleanSession: Bool,
        keepAlive: UInt16,
        connectionTimeout: TimeInterval = 5.0,
        useSSL: Bool = false)
    {
        self.factory = MQTTPacketFactory()
        self.host = host
        self.port = port
        self.connectionTimeout = connectionTimeout
        self.useSSL = useSSL
        self.clientID = clientID
        self.cleanSession = cleanSession
        self.keepAlive = keepAlive
    }
    
    deinit {
        delegate = nil
        disconnect()
    }
    
    open func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool, completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let pubMsg = MQTTPubMsg(topic: topic, payload: data, retain: retain, QoS: qos)
        let publishPacket = MQTTPublishPacket(messageID: msgID, message: pubMsg)
        if send(publishPacket) {
            messagesCompletionBlocks[msgID] = completion
            if qos == .atMostOnce {
                completion?(MQTTSessionError.none)
            }
        } else {
            completion?(MQTTSessionError.socketError)
        }
    }

    open func subscribe(to topic: String, delivering qos: MQTTQoS, completion: MQTTSessionCompletionBlock?) {
        subscribe(to: [topic: qos], completion: completion)
    }
    
    open func subscribe(to topics: [String: MQTTQoS], completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let subscribePacket = MQTTSubPacket(topics: topics, messageID: msgID)
        if send(subscribePacket) {
            messagesCompletionBlocks[msgID] = completion
        } else {
            completion?(MQTTSessionError.socketError)
        }
    }

    open func unSubscribe(from topic: String, completion: MQTTSessionCompletionBlock?) {
        unSubscribe(from: [topic], completion: completion)
    }
    
    open func unSubscribe(from topics: [String], completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let unSubPacket = MQTTUnsubPacket(topics: topics, messageID: msgID)
        if send(unSubPacket) {
            messagesCompletionBlocks[msgID] = completion
        } else {
            completion?(MQTTSessionError.socketError)
        }
    }
    
    open func connect(completion: MQTTSessionCompletionBlock?) {
        connectionCompletionBlock = completion
        stream = MQTTSessionStream(host: host, port: port, ssl: useSSL, timeout: connectionTimeout, delegate: self)
    }

    open func disconnect() {
        let disconnectPacket = MQTTDisconnectPacket()
        send(disconnectPacket)
        cleanupDisconnection(.none)
    }
    
    private func cleanupDisconnection(_ error: MQTTSessionError) {
        stream = nil
        keepAliveTimer?.cancel()
        delegateQueue.async { [weak self] in
            self?.delegate?.mqttDidDisconnect(session: self!, error: error)
        }
    }

    @discardableResult
    private func send(_ packet: MQTTPacket) -> Bool {
        if let write = stream?.write {
            let didWriteSuccessfully = factory.send(packet, write: write)
            if !didWriteSuccessfully {
                cleanupDisconnection(.socketError)
            }
            return didWriteSuccessfully
        }
        return false
    }
    
    private func handle(_ packet: MQTTPacket) {

        switch packet {
        case let connAckPacket as MQTTConnAckPacket:
            delegateQueue.async { [weak self] in
                if connAckPacket.response == .connectionAccepted {
                    self?.connectionCompletionBlock?(MQTTSessionError.none)
                } else {
                    self?.connectionCompletionBlock?(MQTTSessionError.connectionError(connAckPacket.response))
                }
                self?.connectionCompletionBlock = nil
            }
        case let subAckPacket as MQTTSubAckPacket:
            callSuccessCompletionBlock(for: subAckPacket.messageID)
        case let unSubAckPacket as MQTTUnSubAckPacket:
            callSuccessCompletionBlock(for: unSubAckPacket.messageID)
        case let pubAck as MQTTPubAck:
            callSuccessCompletionBlock(for: pubAck.messageID)
        case let publishPacket as MQTTPublishPacket:
            sendPubAck(for: publishPacket.messageID)
            let message = MQTTMessage(publishPacket: publishPacket)
            delegateQueue.async { [weak self] in
                self?.delegate?.mqttDidReceive(message: message, from: self!)
            }
        case _ as MQTTPingResp:
            delegateQueue.async { [weak self] in
                self?.delegate?.mqttDidAcknowledgePing(from: self!)
            }
        default:
            return
        }
    }
    
    private func sendPubAck(for messageId: UInt16) {
        let pubAck = MQTTPubAck(messageID: messageId)
        send(pubAck)
    }
    
    private func callSuccessCompletionBlock(for messageId: UInt16) {
        delegateQueue.async { [weak self] in
            let completionBlock = self?.messagesCompletionBlocks.removeValue(forKey: messageId)
            completionBlock?(MQTTSessionError.none)
        }
    }
    
    fileprivate func keepAliveTimerFired() {
        let mqttPingReq = MQTTPingPacket()
        send(mqttPingReq)
    }
    
    private var messageID = UInt16(0)
    
    private func nextMessageID() -> UInt16 {
        messageID += 1
        return messageID
    }
}

extension MQTTSession: MQTTSessionStreamDelegate {
    
    func mqttReady(_ ready: Bool, in stream: MQTTSessionStream) {
        if ready {
            // Create Connect Packet
            let connectPacket = MQTTConnectPacket(clientID: clientID, cleanSession: cleanSession, keepAlive: keepAlive)
            // Set Optional vars
            connectPacket.username = username
            connectPacket.password = password
            connectPacket.lastWillMessage = lastWillMessage

            if send(connectPacket) == false {
                delegateQueue.async { [weak self] in
                    self?.connectionCompletionBlock?(MQTTSessionError.socketError)
                    self?.connectionCompletionBlock = nil
                }
            }

            keepAliveTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            keepAliveTimer!.schedule(deadline: .now() + .seconds(Int(keepAlive)), repeating: .seconds(Int(keepAlive)), leeway: .seconds(1))
            keepAliveTimer!.setEventHandler { [weak self] in
                self?.keepAliveTimerFired()
            }
            keepAliveTimer!.resume()
        }
        else {
            cleanupDisconnection(.socketError)
            delegateQueue.async { [weak self] in
                self?.connectionCompletionBlock?(MQTTSessionError.socketError)
            }
        }
    }

    func mqttReceived(in stream: MQTTSessionStream, _ read: StreamReader) {
        if let packet = factory.parse(read) {
            handle(packet)
        }
    }
    
    func mqttErrorOccurred(in stream: MQTTSessionStream, error: Error?) {
        cleanupDisconnection(.streamError(error))
    }
}
