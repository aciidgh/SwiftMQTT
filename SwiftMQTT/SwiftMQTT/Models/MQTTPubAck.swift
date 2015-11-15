//
//  MQTTPubAck.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTPubAck: MQTTPacket {
    let messageID: UInt16
    
    init(messageID: UInt16) {
        self.messageID = messageID
        super.init(header: MQTTPacketFixedHeader(packetType: MQTTPacketType.PubAck, flags: 0))
    }
    
    override func networkPacket() -> NSData {
        //Variable Header
        let variableHeader = NSMutableData()
        variableHeader.mqtt_appendUInt16(self.messageID)
        
        return self.finalPacket(variableHeader, payload: NSData())
    }
    
    init(header: MQTTPacketFixedHeader, networkData: NSData) {
        let buffer = UnsafePointer<UInt8>(networkData.bytes)
        self.messageID = (UInt16(buffer[0]) * UInt16(256)) + UInt16(buffer[1])
        super.init(header: header)
    }
}