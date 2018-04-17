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
        super.init(header: MQTTPacketFixedHeader(packetType: .publish, flags: MQTTPublishPacket.fixedHeaderFlags(for: message)))
    }
    
    class func fixedHeaderFlags(for message: MQTTPubMsg) -> UInt8 {
        var flags = UInt8(0)
        if message.retain {
            flags |= 0x01
        }
        flags |= message.QoS.rawValue << 1
        return flags
    }
    
    override func variableHeader() -> Data {
        var variableHeader = Data(capacity: 1024)
        variableHeader.mqtt_append(message.topic)
        if message.QoS != .atMostOnce {
            variableHeader.mqtt_append(messageID)
        }
        return variableHeader
    }
    
    override func payload() -> Data {
        return message.payload
    }
    
    init(header: MQTTPacketFixedHeader, networkData: Data) {
        
        let topicLength = 256 * Int(networkData[0]) + Int(networkData[1])
        let topicData = networkData.subdata(in: 2..<topicLength+2)
        let topic = String(data: topicData, encoding: .utf8)!
        
        let qos = MQTTQoS(rawValue: header.flags & 0x06)!
        var payload = networkData.subdata(in: 2+topicLength..<networkData.endIndex)
        
        if qos != .atMostOnce {
            messageID = 256 * UInt16(payload[0]) + UInt16(payload[1])
            payload = payload.subdata(in: 2..<payload.endIndex)
        } else {
            messageID = 0
        }
        
        let retain = (header.flags & 0x01) == 0x01
        message = MQTTPubMsg(topic: topic, payload: payload, retain: retain, QoS: qos)
        
        super.init(header: header)
    }
}
