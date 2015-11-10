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

public class MQTTSession: NSObject, NSStreamDelegate {

    public var username: String?
    public var password: String?
    public let cleanSession: Bool
    public let keepAlive: UInt16
    public let host: String
    public let port: UInt16
    public let clientID: String
    
    public var willMessage: MQTTPubMsg?
    public var delegate: MQTTSessionDelegate?
    
    private var keepAliveTimer: NSTimer!
    private var connectionCompletionBlock: MQTTSessionCompletionBlock?
    private var messagesCompletionBlocks = [UInt16 : MQTTSessionCompletionBlock]()
    private var inputStream:NSInputStream?
    private var outputStream:NSOutputStream?
    
    public init(host: String, port: UInt16, clientID: String, cleanSession: Bool, keepAlive: UInt16) {
        self.host = host
        self.port = port
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
        NSStream.getStreamsToHostWithName(host, port: NSInteger(port), inputStream: &inputStream, outputStream: &outputStream)
        self.createStreamConnection()
        
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
        self.closeStreams()
    }
    
    private func createStreamConnection() {
        inputStream?.delegate = self
        outputStream?.delegate = self
        inputStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream?.open()
        outputStream?.open()
    }
    
    private func sendPacket(packet: MQTTPacket) {
        let networkPacket = packet.networkPacket()
        let writtenLength = outputStream?.write(UnsafePointer<UInt8>(networkPacket.bytes), maxLength: networkPacket.length)
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
    
    public func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None: break
        case NSStreamEvent.OpenCompleted: break
        case NSStreamEvent.HasBytesAvailable:
            if aStream == inputStream {
                self.receiveDataOnStream(aStream)
            }
        case NSStreamEvent.ErrorOccurred:
            self.delegate?.errorOccurred(self)
            self.closeStreams()
        case NSStreamEvent.EndEncountered:
            self.closeStreams()
        case NSStreamEvent.HasSpaceAvailable: break
        default:
            print("unknown")
        }
    }
    
    private func closeStreams() {
        keepAliveTimer.invalidate()
        inputStream?.close()
        inputStream?.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream?.close()
        outputStream?.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.delegate?.didDisconnectSession(self)
    }
    
    private func receiveDataOnStream(stream: NSStream) {
        
        var headerByte = [UInt8](count: 1, repeatedValue: 0)
        let len = inputStream?.read(&headerByte, maxLength: 1)
        if !(len > 0) { return; }
        let header = MQTTPacketFixedHeader(networkByte: headerByte[0])
        
        ///Max Length is 2^28 = 268,435,455 (256 MB)
        var multiplier = 1
        var value = 0
        var encodedByte: UInt8 = 0
        repeat {
            var readByte = [UInt8](count: 1, repeatedValue: 0)
            inputStream?.read(&readByte, maxLength: 1)
            encodedByte = readByte[0]
            value += (Int(encodedByte) & 127) * multiplier
            multiplier *= 128
            if multiplier > 128*128*128 {
                return;
            }
        } while ((Int(encodedByte) & 128) != 0)
        
        let totalLength = value
        
        var responseData: NSData = NSData()
        if totalLength > 0 {
            var buffer = [UInt8](count: totalLength, repeatedValue: 0)
            let readLength = inputStream?.read(&buffer, maxLength: buffer.count)
            responseData = NSData(bytes: buffer, length: readLength!)
        }
        self.parseReceivedData(responseData, mqttHeader: header)
    }
    
    private func nextMessageID() -> UInt16 {
        struct MessageIDHolder {
            static var messageID = UInt16(0)
        }
        MessageIDHolder.messageID++
        return MessageIDHolder.messageID;
    }
}
