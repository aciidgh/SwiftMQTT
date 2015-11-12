//
//  MQTTSession.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

public protocol MQTTSessionDelegate {
    func mqttSession(session: MQTTSession, didReceiveMessage message: NSData, onTopic topic: String)
    func didDisconnectSession(session: MQTTSession)
    func errorOccurred(session: MQTTSession)
}

public typealias MQTTSessionCompletionBlock = (succeeded: Bool, error: ErrorType) -> Void

public class MQTTSession: MQTTSessionStreamDelegate {

    public var username: String?
    public var password: String?
    public let cleanSession: Bool
    public let keepAlive: UInt16

    public let clientID: String
    
    public var willMessage: MQTTPubMsg?
    public var delegate: MQTTSessionDelegate?
    
    private var keepAliveTimer: NSTimer!
    private var connectionCompletionBlock: MQTTSessionCompletionBlock?
    private var messagesCompletionBlocks = [UInt16 : MQTTSessionCompletionBlock]()
    private var stream: MQTTSessionStream
    
    public init(host: String, port: UInt16, clientID: String, cleanSession: Bool, keepAlive: UInt16) {
        stream = MQTTSessionStream(host: host, port: port)
        self.clientID = clientID
        self.cleanSession = cleanSession
        self.keepAlive = keepAlive
    }
    
    func publishData(data: NSData, onTopic: String, withQoS: MQTTQoS, shouldRetain: Bool, completion: MQTTSessionCompletionBlock?) {
        let msgID = self.nextMessageID()
        let pubMsg = MQTTPubMsg(topic: onTopic, message: data, retain: shouldRetain, QoS: withQoS)
        let publishPacket = MQTTPublishPacket(messageID: msgID, message: pubMsg)
        self.sendPacket(publishPacket)
        self.messagesCompletionBlocks[msgID] = completion
        if withQoS == MQTTQoS.AtMostOnce {
            completion?(succeeded: true, error: MQTTSessionError.None)
        }
    }
    
    func subscribe(topic: String, qos: MQTTQoS, completion: MQTTSessionCompletionBlock?) {
        self.subscribe([topic : qos], completion: completion)
    }
    
    func subscribe(topics: [String : MQTTQoS], completion: MQTTSessionCompletionBlock?) {
        let msgID = self.nextMessageID()
        let subscribePacket = MQTTSubPacket(topics: topics, messageID: msgID)
        self.sendPacket(subscribePacket)
        self.messagesCompletionBlocks[msgID] = completion
    }
    
    func unSubscribe(topics: [String], completion: MQTTSessionCompletionBlock?) {
        let msgID = self.nextMessageID()
        let unSubPacket = MQTTUnsubPacket(topics: topics, messageID: msgID)
        self.sendPacket(unSubPacket)
        self.messagesCompletionBlocks[msgID] = completion
    }
    
    func connect(completion: MQTTSessionCompletionBlock?) {
        self.connectionCompletionBlock = completion
        //Open Stream
        stream.createStreamConnection()
        
        keepAliveTimer = NSTimer(timeInterval: Double(self.keepAlive), target: self, selector: Selector("keepAliveTimerFired"), userInfo: nil, repeats: true)
        NSRunLoop.mainRunLoop().addTimer(keepAliveTimer, forMode: NSDefaultRunLoopMode)
        
        //Create Connect Packet
        let connectPacket = MQTTConnectPacket(clientID: self.clientID, cleanSession: self.cleanSession, keepAlive: self.keepAlive)
        //Set Optional vars
        connectPacket.username = self.username
        connectPacket.password = self.password
        connectPacket.willMessage = self.willMessage
        
        self.sendPacket(connectPacket)
    }
    
    func disconnect() {
        let disconnectPacket = MQTTDisconnectPacket()
        self.sendPacket(disconnectPacket)
        stream.closeStreams()
        keepAliveTimer.invalidate()
        self.delegate?.didDisconnectSession(self)
    }
    
    private func sendPacket(packet: MQTTPacket) {
        let writtenLength = stream.sendPacket(packet)
        if writtenLength == -1 {
            if packet.header.packetType == .Connect {
                self.connectionCompletionBlock?(succeeded: false, error: MQTTSessionError.SocketError)
                self.connectionCompletionBlock = nil
            }
        }
    }
    
    private func parseReceivedData(data: NSData, mqttHeader: MQTTPacketFixedHeader) {
        if mqttHeader.packetType == .Connack {
            let connackPacket = MQTTConnAckPacket(header: mqttHeader, networkData: data)
            let success = (connackPacket.response == .ConnectionAccepted)
            self.connectionCompletionBlock?(succeeded: success, error: connackPacket.response)
            self.connectionCompletionBlock = nil
        }
        if mqttHeader.packetType == .SubAck {
            let subAckPacket = MQTTSubAckPacket(header: mqttHeader, networkData: data)
            let completionBlock = self.messagesCompletionBlocks[subAckPacket.messageID]
            self.messagesCompletionBlocks[subAckPacket.messageID] = nil
            completionBlock?(succeeded: true, error: MQTTSessionError.None)
        }
        if mqttHeader.packetType == .UnSubAck {
            let unSubAckPacket = MQTTUnSubAckPacket(header: mqttHeader, networkData: data)
            let completionBlock = self.messagesCompletionBlocks[unSubAckPacket.messageID]
            self.messagesCompletionBlocks[unSubAckPacket.messageID] = nil
            completionBlock?(succeeded: true, error: MQTTSessionError.None)
        }
        if mqttHeader.packetType == .Publish {
            let publishPacket = MQTTPublishPacket(header: mqttHeader, networkData: data)
            self.delegate?.mqttSession(self, didReceiveMessage: publishPacket.message.message, onTopic: publishPacket.message.topic)
        }
        if mqttHeader.packetType == .PubAck {
            let pubAck = MQTTPubAck(header: mqttHeader, networkData: data)
            let completionBlock = self.messagesCompletionBlocks[pubAck.messageID]
            self.messagesCompletionBlocks[pubAck.messageID] = nil
            completionBlock?(succeeded: true, error: MQTTSessionError.None)
        }
        if mqttHeader.packetType == .PingResp {
            _ = MQTTPingResp(header: mqttHeader)
        }
    }
    
    func keepAliveTimerFired() {
        let mqttPingReq = MQTTPingPacket()
        self.sendPacket(mqttPingReq)
    }
    
    private func nextMessageID() -> UInt16 {
        struct MessageIDHolder {
            static var messageID = UInt16(0)
        }
        MessageIDHolder.messageID++
        return MessageIDHolder.messageID;
    }
    
    func streamErrorOccurred(stream: MQTTSessionStream) {
        self.delegate?.errorOccurred(self)
    }
    
    func receivedData(stream: MQTTSessionStream, data: NSData, withMQTTHeader header: MQTTPacketFixedHeader) {
        self.parseReceivedData(data, mqttHeader: header)
    }

}
