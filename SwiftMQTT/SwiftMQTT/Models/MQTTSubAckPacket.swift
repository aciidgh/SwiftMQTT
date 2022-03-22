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
    let result: UInt8
    
    init?(header: MQTTPacketFixedHeader, networkData: Data) {
        if networkData.count >= 3 {
            messageID = (UInt16(networkData[0]) * UInt16(256)) + UInt16(networkData[1])
            result = networkData[2]
            super.init(header: header)
        } else {
            return nil
        }
    }
    
    var success: Bool {
        result <= 2
    }
}
