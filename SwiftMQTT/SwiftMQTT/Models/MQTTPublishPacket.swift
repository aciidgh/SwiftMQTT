//
//  MQTTPublishPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

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
        variableHeader.mqtt_appendString(self.message.topic)
        if self.message.QoS != .AtMostOnce {
            variableHeader.mqtt_appendUInt16(self.messageID)
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
