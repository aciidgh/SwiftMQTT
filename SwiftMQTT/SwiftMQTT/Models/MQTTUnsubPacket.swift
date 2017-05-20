//
//  MQTTUnsubPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

/*
OCI Changes:
    Preallocate Data to avoid low-level realloc calls
*/

import Foundation

class MQTTUnsubPacket: MQTTPacket {
    
    let topics: [String]
    let messageID: UInt16
    
    init(topics: [String], messageID: UInt16) {
        self.topics = topics
        self.messageID = messageID
        super.init(header: MQTTPacketFixedHeader(packetType: .unSubscribe, flags: 0x02))
    }
    
    override func networkPacket() -> Data {
        // Variable Header
        var variableHeader = Data()
        variableHeader.mqtt_append(messageID)
        
        // Payload
        var payload = Data(capacity: 1024)
        for topic in topics {
            payload.mqtt_append(topic)
        }
        return finalPacket(variableHeader, payload: payload)
    }
}
