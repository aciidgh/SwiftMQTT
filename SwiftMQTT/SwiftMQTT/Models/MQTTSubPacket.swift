//
//  MQTTSubPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

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
        variableHeader.mqtt_appendUInt16(self.messageID)
        
        //Payload
        let payload = NSMutableData()
        for topic in self.topics {
            payload.mqtt_appendString(topic.0)
            let qos = topic.1.rawValue & 0x03
            payload.mqtt_appendUInt8(qos)
        }
        return self.finalPacket(variableHeader, payload: payload)
    }
}
