//
//  MQTTUnsubPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

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
        variableHeader.mqtt_appendUInt16(self.messageID)
        
        //Payload
        let payload = NSMutableData()
        for topic in self.topics {
            payload.mqtt_appendString(topic)
        }
        return self.finalPacket(variableHeader, payload: payload)
    }
}