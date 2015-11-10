//
//  MQTTPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTPacketFixedHeader {
    
    let packetType: MQTTPacketType
    let flags: UInt8
    
    init(packetType: MQTTPacketType, flags: UInt8) {
        self.packetType = packetType
        self.flags = flags
    }
    
    init(networkByte: UInt8) {
        self.packetType = MQTTPacketType(rawValue: networkByte >> 4)!
        self.flags = networkByte & 0x0F
    }
    
    func networkPacket() -> NSData {
        var fixedHeaderFirstByte = UInt8(0)
        fixedHeaderFirstByte = (0x0F & flags) | (self.packetType.rawValue << 4)
        return NSData(bytes: &fixedHeaderFirstByte, length: 1)
    }
}

class MQTTPacket {
    
    let header: MQTTPacketFixedHeader
    
    init(header: MQTTPacketFixedHeader) {
        self.header = header
    }
    
    func networkPacket() -> NSData {
        //To be implemented in subclasses
        return NSData()
    }
    
    func finalPacket(variableHeader: NSData, payload: NSData) -> NSData {
        let remainingData = NSMutableData(data: variableHeader)
        remainingData.appendData(payload)
        
        let finalPacket = NSMutableData()
        finalPacket.appendData(self.header.networkPacket())
        finalPacket.encodeRemainingLength(remainingData.length) //Remaining Length
        finalPacket.appendData(remainingData) //Remaining Data = Variable Header + Payload
        
        return finalPacket
    }
}

public class MQTTPubMsg {
    public let topic: String
    public let message: NSData
    public let retain: Bool
    public let QoS: MQTTQoS
    
    public init(topic: String, message: NSData, retain: Bool, QoS: MQTTQoS) {
        self.topic = topic
        self.message = message
        self.retain = retain
        self.QoS = QoS
    }
}

class MQTTConnectPacket: MQTTPacket {
    
    let protocolName: String
    let protocolLevel: UInt8
    let cleanSession: Bool
    let keepAlive: UInt16
    let clientID: String
    
    var username: String? = nil
    var password: String? = nil
    var willMessage: MQTTPubMsg? = nil
    
    init(clientID: String, cleanSession: Bool, keepAlive: UInt16) {
        self.protocolName = "MQTT"
        self.protocolLevel = 0x04
        self.cleanSession = cleanSession
        self.keepAlive = keepAlive
        self.clientID = clientID
        super.init(header: MQTTPacketFixedHeader(packetType: .Connect, flags: 0))
    }
    
    func encodedConnectFlags() -> UInt8 {
        var flags = UInt8(0)
        if(self.cleanSession) {
            flags |= 0x02
        }
        
        if let willMessage = self.willMessage {
            flags |= 0x04
            
            if willMessage.retain {
                flags |= 0x20
            }
            let qos = UInt8(willMessage.QoS.rawValue)
            flags |= qos << 3
        }
        
        if let _ = self.username {
            flags |= 0x80
        }
        
        if let _ = self.password {
            flags |= 0x40
        }
        
        return flags
    }
    
    override func networkPacket() -> NSData {
        //Variable Header
        let variableHeader = NSMutableData()
        //Protocol Name
        variableHeader.appendString(self.protocolName)
        //Protocol Level
        variableHeader.appendUInt8(self.protocolLevel)
        //Connect Flags
        variableHeader.appendUInt8(self.encodedConnectFlags())
        //Keep Alive
        variableHeader.appendUInt16(self.keepAlive)
        
        //Payload
        let payload = NSMutableData()
        //Client ID
        payload.appendString(self.clientID)
        //Will Packet
        if let willMessage = self.willMessage {
            payload.appendString(willMessage.topic)
            payload.appendMQTTData(willMessage.message)
        }
        //Username
        if let username = self.username {
            payload.appendString(username)
        }
        ///Password
        if let password = self.password {
            payload.appendString(password)
        }
        
        return self.finalPacket(variableHeader, payload: payload)
    }
}

class MQTTSubPacket: MQTTPacket {
    
    let topics: [String: MQTTQoS]
    let messageID: UInt16
    
    init(topics: [String : MQTTQoS], messageID: UInt16) {
        self.topics = topics
        self.messageID = messageID
        super.init(header: MQTTPacketFixedHeader(packetType: .Subscribe, flags: 0x02))
    }
    
    override func networkPacket() -> NSData {
        //Variable Header
        let variableHeader = NSMutableData()
        variableHeader.appendUInt16(self.messageID)
        
        //Payload
        let payload = NSMutableData()
        for topic in self.topics {
            payload.appendString(topic.0)
            let qos = topic.1.rawValue & 0x03
            payload.appendUInt8(qos)
        }
        return self.finalPacket(variableHeader, payload: payload)
    }
}

class MQTTDisconnectPacket: MQTTPacket {
    
    init() {
        super.init(header: MQTTPacketFixedHeader(packetType: MQTTPacketType.Disconnect, flags: 0))
    }
    
    override func networkPacket() -> NSData {
        return self.finalPacket(NSData(), payload: NSData())
    }
}

class MQTTUnsubPacket: MQTTPacket {
    
    let topics: [String]
    let messageID: UInt16
    
    init(topics: [String], messageID: UInt16) {
        self.topics = topics
        self.messageID = messageID
        super.init(header: MQTTPacketFixedHeader(packetType: .UnSubscribe, flags: 0x02))
    }
    
    override func networkPacket() -> NSData {
        //Variable Header
        let variableHeader = NSMutableData()
        variableHeader.appendUInt16(self.messageID)
        
        //Payload
        let payload = NSMutableData()
        for topic in self.topics {
            payload.appendString(topic)
        }
        return self.finalPacket(variableHeader, payload: payload)
    }
}

class MQTTPublishPacket: MQTTPacket {
    let messageID: UInt16
    let message: MQTTPubMsg
    
    init(messageID: UInt16, message: MQTTPubMsg) {
        self.messageID = messageID
        self.message = message
        super.init(header: MQTTPacketFixedHeader(packetType: .Publish, flags: MQTTPublishPacket.fixedHeaderFlagsForMessage(message)))
    }
    
    class func fixedHeaderFlagsForMessage(message: MQTTPubMsg) -> UInt8 {
        var flags = UInt8(0)
        if message.retain {
            flags |= 0x08
        }
        flags |= message.QoS.rawValue << 1
        return flags
    }
    
    override func networkPacket() -> NSData {
        //Variable Header
        let variableHeader = NSMutableData()
        variableHeader.appendString(self.message.topic)
        if self.message.QoS != .AtMostOnce {
            variableHeader.appendUInt16(self.messageID)
        }
        
        //Payload
        let payload = self.message.message
        return self.finalPacket(variableHeader, payload: payload)
    }
    
    init(header: MQTTPacketFixedHeader, networkData: NSData) {
        
        var readingData = networkData
        
        var bytes = UnsafePointer<UInt8>(readingData.bytes)
        let topicLength = 256 * Int(bytes[0]) + Int(bytes[1])
        let topic = NSString(data: readingData.subdataWithRange(NSMakeRange(2, topicLength)), encoding: NSUTF8StringEncoding) as! String
        
        readingData = readingData.subdataWithRange(NSMakeRange(2+topicLength, readingData.length - topicLength-2))
        
        let qos = MQTTQoS(rawValue: header.flags & 0x06)!
        
        if qos != .AtMostOnce { //Fixme: lol fix this
            bytes = UnsafePointer<UInt8>(readingData.bytes)
            self.messageID = 256 * UInt16(bytes[0]) + UInt16(bytes[1])
            readingData = readingData.subdataWithRange(NSMakeRange(2, readingData.length - 2)) //because we read two bytes
            
        } else {
            self.messageID = 0
        }
        
        let responseData = readingData // reamining data will be payload
        
        let retain = (header.flags & 0x01) == 0x01
        
        self.message = MQTTPubMsg(topic: topic, message: responseData, retain: retain, QoS: qos)
        
        super.init(header: header)
    }
}

class MQTTConnAckPacket: MQTTPacket {
    
    let sessionPresent: Bool
    let response: MQTTConnackResponse
    
    init(header: MQTTPacketFixedHeader, networkData: NSData) {
        //FIXME: fix
        var buffer = [UInt8](count: 2, repeatedValue: 0)
        networkData.getBytes(&buffer, range: NSMakeRange(0, 2))
        
        self.sessionPresent = (buffer[0] & 0x01) == 0x01
        self.response = MQTTConnackResponse(rawValue: buffer[1])!
        
        super.init(header: header)
    }
}

class MQTTSubAckPacket: MQTTPacket {
    
    let messageID: UInt16
    
    init(header: MQTTPacketFixedHeader, networkData: NSData) {
        //FIXME: fix
        var buffer = [UInt8](count: 1000, repeatedValue: 0)
        networkData.getBytes(&buffer, range: NSMakeRange(0, 2))
        self.messageID = (UInt16(buffer[0]) * UInt16(256)) + UInt16(buffer[1])
        super.init(header: header)
    }
}

class MQTTUnSubAckPacket: MQTTPacket {
    let messageID: UInt16
    init(header: MQTTPacketFixedHeader, networkData: NSData) {
        let buffer = UnsafePointer<UInt8>(networkData.bytes)
        self.messageID = (UInt16(buffer[0]) * UInt16(256)) + UInt16(buffer[1])
        super.init(header: header)
    }
}

class MQTTPubAck: MQTTPacket {
    let messageID: UInt16
    init(header: MQTTPacketFixedHeader, networkData: NSData) {
        let buffer = UnsafePointer<UInt8>(networkData.bytes)
        self.messageID = (UInt16(buffer[0]) * UInt16(256)) + UInt16(buffer[1])
        super.init(header: header)
    }
}

class MQTTPingResp: MQTTPacket {
    override init(header: MQTTPacketFixedHeader) {
        super.init(header: header)
    }
}

class MQTTPingPacket: MQTTPacket {
    init() {
        super.init(header: MQTTPacketFixedHeader(packetType: MQTTPacketType.PingReq, flags: 0))
    }
    override func networkPacket() -> NSData {
        return self.finalPacket(NSData(), payload: NSData())
    }
}
