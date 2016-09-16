//
//  MQTTSession.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

public protocol MQTTSessionDelegate {
    func mqttDidReceive(message data: Data, in topic: String, from session: MQTTSession)
    func mqttDidDisconnect(session: MQTTSession)
    func mqttSocketErrorOccurred(session: MQTTSession)
}

public typealias MQTTSessionCompletionBlock = (_ succeeded: Bool, _ error: Error) -> Void

open class MQTTSession: MQTTSessionStreamDelegate {
    
    open let cleanSession: Bool
    open let keepAlive: UInt16
    open let clientID: String
    
    open var username: String?
    open var password: String?
    open var lastWillMessage: MQTTPubMsg?

    open var delegate: MQTTSessionDelegate?
    
    fileprivate var keepAliveTimer: Timer!
    fileprivate var connectionCompletionBlock: MQTTSessionCompletionBlock?
    fileprivate var messagesCompletionBlocks = [UInt16: MQTTSessionCompletionBlock]()
    fileprivate var stream: MQTTSessionStream
    
    public init(host: String, port: UInt16, clientID: String, cleanSession: Bool, keepAlive: UInt16, useSSL: Bool = false) {
        stream = MQTTSessionStream(host: host, port: port, ssl: useSSL)
        self.clientID = clientID
        self.cleanSession = cleanSession
        self.keepAlive = keepAlive
    }
    
    open func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool, completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let pubMsg = MQTTPubMsg(topic: topic, payload: data, retain: retain, QoS: qos)
        let publishPacket = MQTTPublishPacket(messageID: msgID, message: pubMsg)
        if send(publishPacket) {
            messagesCompletionBlocks[msgID] = completion
            if qos == .atMostOnce {
                completion?(true, MQTTSessionError.none)
            }
        } else {
            completion?(false, MQTTSessionError.socketError)
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
            completion?(false, MQTTSessionError.socketError)
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
            completion?(false, MQTTSessionError.socketError)
        }
    }
    
    open func connect(completion: MQTTSessionCompletionBlock?) {
        // Open Stream
        stream.delegate = self
        stream.createStreamConnection()
        
        keepAliveTimer = Timer(timeInterval: Double(keepAlive), target: self, selector: #selector(MQTTSession.keepAliveTimerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(keepAliveTimer, forMode: .defaultRunLoopMode)
        
        // Create Connect Packet
        let connectPacket = MQTTConnectPacket(clientID: clientID, cleanSession: cleanSession, keepAlive: keepAlive)
        // Set Optional vars
        connectPacket.username = username
        connectPacket.password = password
        connectPacket.lastWillMessage = lastWillMessage
        
        if send(connectPacket) {
            connectionCompletionBlock = completion
        } else {
            completion?(false, MQTTSessionError.socketError)
        }
    }
    
    open func disconnect() {
        let disconnectPacket = MQTTDisconnectPacket()
        send(disconnectPacket)
        cleanupDisconnection()
    }
    
    fileprivate func cleanupDisconnection() {
        stream.closeStreams()
        keepAliveTimer?.invalidate()
        delegate?.mqttDidDisconnect(session: self)
    }
    
    @discardableResult
    fileprivate func send(_ packet: MQTTPacket) -> Bool {
        let writtenLength = stream.send(packet)
        let didWriteSuccessfully = writtenLength != -1
        if !didWriteSuccessfully {
            delegate?.mqttSocketErrorOccurred(session: self)
            cleanupDisconnection()
        }
        return didWriteSuccessfully
    }
    
    fileprivate func parse(_ networkData: Data, header: MQTTPacketFixedHeader) {
        switch header.packetType {
        case .connAck:
            let connAckPacket = MQTTConnAckPacket(header: header, networkData: networkData)
            let success = (connAckPacket.response == .connectionAccepted)
            connectionCompletionBlock?(success, connAckPacket.response)
            connectionCompletionBlock = nil
        case .subAck:
            let subAckPacket = MQTTSubAckPacket(header: header, networkData: networkData)
            callSuccessCompletionBlock(for: subAckPacket.messageID)
        case .unSubAck:
            let unSubAckPacket = MQTTUnSubAckPacket(header: header, networkData: networkData)
            callSuccessCompletionBlock(for: unSubAckPacket.messageID)
        case .pubAck:
            let pubAck = MQTTPubAck(header: header, networkData: networkData)
            callSuccessCompletionBlock(for: pubAck.messageID)
        case .publish:
            let publishPacket = MQTTPublishPacket(header: header, networkData: networkData)
            sendPubAck(for: publishPacket.messageID)
            let payload = publishPacket.message.payload
            let topic = publishPacket.message.topic
            delegate?.mqttDidReceive(message: payload, in: topic, from: self)
        case .pingResp:
            _ = MQTTPingResp(header: header)
        default:
            return
        }
    }
    
    fileprivate func sendPubAck(for messageId: UInt16) {
        let pubAck = MQTTPubAck(messageID: messageId)
        send(pubAck)
    }
    
    fileprivate func callSuccessCompletionBlock(for messageId: UInt16) {
        let completionBlock = messagesCompletionBlocks[messageId]
        messagesCompletionBlocks[messageId] = nil
        completionBlock?(true, MQTTSessionError.none)
    }
    
    @objc fileprivate func keepAliveTimerFired() {
        let mqttPingReq = MQTTPingPacket()
        send(mqttPingReq)
    }
    
    fileprivate func nextMessageID() -> UInt16 {
        struct MessageIDHolder {
            static var messageID = UInt16(0)
        }
        MessageIDHolder.messageID += 1
        return MessageIDHolder.messageID
    }
    
    // MARK: - MQTTSessionStreamDelegate

    func mqttReceived(_ data: Data, header: MQTTPacketFixedHeader, in stream: MQTTSessionStream) {
        parse(data, header: header)
    }
    
    func mqttErrorOccurred(in stream: MQTTSessionStream) {
        delegate?.mqttSocketErrorOccurred(session: self)
    }
        
}
