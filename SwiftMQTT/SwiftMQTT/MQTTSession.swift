//
//  MQTTSession.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

public protocol MQTTSessionDelegate: AnyObject {
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
    private var completions = [UInt16: Completion]()
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
            if qos == .atMostOnce {
                completion?(MQTTSessionError.none)
            } else {
                completions[msgID] = Completion(publishPacket, completion)
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
            completions[msgID] = Completion(subscribePacket, completion)
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
            completions[msgID] = Completion(unSubPacket, completion)
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
            self?.cleanupDisconnectionOnDelegateQueue(error)
        }
    }
    
    private func cleanupDisconnectionOnDelegateQueue(_ error: MQTTSessionError) {
        if self.cleanSession == true {
            let callbacks = [Completion](self.completions.values)
            self.completions.removeAll()
            for c in callbacks {
                c.on(error)
            }
        }
        self.delegate?.mqttDidDisconnect(session: self, error: error)
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
            callSuccessCompletionBlock(for: subAckPacket.messageID, packet: packet)
        case let unSubAckPacket as MQTTUnSubAckPacket:
            callSuccessCompletionBlock(for: unSubAckPacket.messageID, packet: packet)
        case let pubAck as MQTTPubAck:
            callSuccessCompletionBlock(for: pubAck.messageID, packet: packet)
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
    
    private func callSuccessCompletionBlock(for messageId: UInt16, packet: MQTTPacket) {
        delegateQueue.async { [weak self] in
            if let completion = self?.completions.removeValue(forKey: messageId) {
                completion.on(MQTTSessionError.none)
            } else if messageId == 0 {
                //some server doesn't take the message id back in Ack packet
                //we need process this special case
                self?.tryCompleteAck(ackPacket: packet)
            }
        }
    }
    
    private func tryCompleteAck(ackPacket: MQTTPacket) {
        var completion: Completion?
        if ackPacket is MQTTSubAckPacket {
            for t in self.completions {
                if t.value.packet is MQTTSubPacket {
                    completion = self.completions.removeValue(forKey: t.key)
                    let subAck = ackPacket as! MQTTSubAckPacket
                    completion?.on(subAck.success ? .none : .connectionError(.badProtocol))
                    return
                }
            }
        } else if ackPacket is MQTTPubAck {
            for t in self.completions {
                if t.value.packet is MQTTPublishPacket {
                    completion = self.completions.removeValue(forKey: t.key)
                    completion?.on(.none)
                    return
                }
            }
        }
        
        
    }
    
    fileprivate func keepAliveTimerFired() {
        let mqttPingReq = MQTTPingPacket()
        send(mqttPingReq)
    }
    
    private var messageID = UInt16(123)
    
    private func nextMessageID() -> UInt16 {
        messageID += 1
        if messageID >= 32767 {
            messageID = 1 //escape 0 for special case of SubACK
        }
        return messageID
    }
}

private extension MQTTSession {
    class Completion {
        let callback: MQTTSessionCompletionBlock?
        let packet: MQTTPacket
        
        init(_ p: MQTTPacket, _ c: MQTTSessionCompletionBlock?) {
            packet = p
            callback = c
        }
        
        func on(_ error: MQTTSessionError) {
            callback?(error)
        }
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
        } else {
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
