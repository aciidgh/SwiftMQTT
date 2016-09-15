//
//  MQTTSession.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

public protocol MQTTSessionDelegate {
    func mqttSession(_ session: MQTTSession, didReceiveMessage message: Data, onTopic topic: String)
    func didDisconnectSession(_ session: MQTTSession)
    func socketErrorOccurred(_ session: MQTTSession)
}

public typealias MQTTSessionCompletionBlock = (_ succeeded: Bool, _ error: Error) -> Void

open class MQTTSession: MQTTSessionStreamDelegate {
    
    open let cleanSession: Bool
    open let keepAlive: UInt16
    open let clientID: String
    
    open var username: String?
    open var password: String?
    open var willMessage: MQTTPubMsg?
    open var delegate: MQTTSessionDelegate?
    
    fileprivate var keepAliveTimer: Timer!
    fileprivate var connectionCompletionBlock: MQTTSessionCompletionBlock?
    fileprivate var messagesCompletionBlocks = [UInt16 : MQTTSessionCompletionBlock]()
    fileprivate var stream: MQTTSessionStream
    
    public init(host: String, port: UInt16, clientID: String, cleanSession: Bool, keepAlive: UInt16, useSSL: Bool = false) {
        stream = MQTTSessionStream(host: host, port: port, ssl: useSSL)
        self.clientID = clientID
        self.cleanSession = cleanSession
        self.keepAlive = keepAlive
    }
    
    open func publishData(_ data: Data, onTopic: String, withQoS: MQTTQoS, shouldRetain: Bool, completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let pubMsg = MQTTPubMsg(topic: onTopic, message: data, retain: shouldRetain, QoS: withQoS)
        let publishPacket = MQTTPublishPacket(messageID: msgID, message: pubMsg)
        if sendPacket(publishPacket) {
            messagesCompletionBlocks[msgID] = completion
            if withQoS == .atMostOnce {
                completion?(true, MQTTSessionError.none)
            }
        } else {
            completion?(false, MQTTSessionError.socketError)
        }
    }
    
    open func subscribe(_ topic: String, qos: MQTTQoS, completion: MQTTSessionCompletionBlock?) {
        subscribe([topic : qos], completion: completion)
    }
    
    open func subscribe(_ topics: [String : MQTTQoS], completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let subscribePacket = MQTTSubPacket(topics: topics, messageID: msgID)
        if sendPacket(subscribePacket) {
            messagesCompletionBlocks[msgID] = completion
        } else {
            completion?(false, MQTTSessionError.socketError)
        }
        
    }
    
    open func unSubscribe(_ topic: String, completion: MQTTSessionCompletionBlock?) {
        unSubscribe([topic], completion: completion)
    }
    
    open func unSubscribe(_ topics: [String], completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let unSubPacket = MQTTUnsubPacket(topics: topics, messageID: msgID)
        if sendPacket(unSubPacket) {
            messagesCompletionBlocks[msgID] = completion
        } else {
            completion?(false, MQTTSessionError.socketError)
        }
    }
    
    open func connect(_ completion: MQTTSessionCompletionBlock?) {
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
        connectPacket.willMessage = willMessage
        
        if sendPacket(connectPacket) {
            connectionCompletionBlock = completion
        } else {
            completion?(false, MQTTSessionError.socketError)
        }
    }
    
    open func disconnect() {
        let disconnectPacket = MQTTDisconnectPacket()
        sendPacket(disconnectPacket)
        disconnectionCleanup()
    }
    
    fileprivate func disconnectionCleanup() {
        stream.closeStreams()
        keepAliveTimer?.invalidate()
        delegate?.didDisconnectSession(self)
    }
    
    @discardableResult
    fileprivate func sendPacket(_ packet: MQTTPacket) -> Bool {
        let writtenLength = stream.sendPacket(packet)
        let didWriteSuccessfully = writtenLength != -1
        if !didWriteSuccessfully {
            delegate?.socketErrorOccurred(self)
            disconnectionCleanup()
        }
        return didWriteSuccessfully
    }
    
    fileprivate func parseReceivedData(_ data: Data, mqttHeader: MQTTPacketFixedHeader) {
        if mqttHeader.packetType == .connack {
            let connackPacket = MQTTConnAckPacket(header: mqttHeader, networkData: data)
            let success = (connackPacket.response == .connectionAccepted)
            connectionCompletionBlock?(success, connackPacket.response)
            connectionCompletionBlock = nil
        }
        if mqttHeader.packetType == .subAck {
            let subAckPacket = MQTTSubAckPacket(header: mqttHeader, networkData: data)
            callSuccessCompletionBlockForMessageID(subAckPacket.messageID)
        }
        if mqttHeader.packetType == .unSubAck {
            let unSubAckPacket = MQTTUnSubAckPacket(header: mqttHeader, networkData: data)
            callSuccessCompletionBlockForMessageID(unSubAckPacket.messageID)
        }
        if mqttHeader.packetType == .pubAck {
            let pubAck = MQTTPubAck(header: mqttHeader, networkData: data)
            callSuccessCompletionBlockForMessageID(pubAck.messageID)
        }
        if mqttHeader.packetType == .publish {
            let publishPacket = MQTTPublishPacket(header: mqttHeader, networkData: data)
            sendPubAckForMessageID(publishPacket.messageID)
            delegate?.mqttSession(self, didReceiveMessage: publishPacket.message.message, onTopic: publishPacket.message.topic)
        }
        if mqttHeader.packetType == .pingResp {
            _ = MQTTPingResp(header: mqttHeader)
        }
    }
    
    fileprivate func sendPubAckForMessageID(_ mid: UInt16) {
        let pubAck = MQTTPubAck(messageID: mid)
        sendPacket(pubAck)
    }
    
    fileprivate func callSuccessCompletionBlockForMessageID(_ mid: UInt16) {
        let completionBlock = messagesCompletionBlocks[mid]
        messagesCompletionBlocks[mid] = nil
        completionBlock?(true, MQTTSessionError.none)
    }
    
    @objc fileprivate func keepAliveTimerFired() {
        let mqttPingReq = MQTTPingPacket()
        sendPacket(mqttPingReq)
    }
    
    fileprivate func nextMessageID() -> UInt16 {
        struct MessageIDHolder {
            static var messageID = UInt16(0)
        }
        MessageIDHolder.messageID += 1
        return MessageIDHolder.messageID
    }
    
    // MARK:- MQTTSessionStreamDelegates
    
    func streamErrorOccurred(_ stream: MQTTSessionStream) {
        delegate?.socketErrorOccurred(self)
    }
    
    func receivedData(_ stream: MQTTSessionStream, data: Data, withMQTTHeader header: MQTTPacketFixedHeader) {
        parseReceivedData(data, mqttHeader: header)
    }
    
}
