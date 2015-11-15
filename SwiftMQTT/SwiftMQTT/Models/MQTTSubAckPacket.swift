//
//  MQTTSubAckPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTSubAckPacket: MQTTPacket {
    
    let messageID: UInt16
    
    init(header: MQTTPacketFixedHeader, networkData: NSData) {
        let buffer = UnsafePointer<UInt8>(networkData.bytes)
        self.messageID = (UInt16(buffer[0]) * UInt16(256)) + UInt16(buffer[1])
        super.init(header: header)
    }
}