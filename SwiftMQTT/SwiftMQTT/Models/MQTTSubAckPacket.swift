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
        //FIXME: fix
        var buffer = [UInt8](count: 1000, repeatedValue: 0)
        networkData.getBytes(&buffer, range: NSMakeRange(0, 2))
        self.messageID = (UInt16(buffer[0]) * UInt16(256)) + UInt16(buffer[1])
        super.init(header: header)
    }
}