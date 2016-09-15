//
//  MQTTConnAckPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTConnAckPacket: MQTTPacket {
    
    let sessionPresent: Bool
    let response: MQTTConnackResponse
    
    init(header: MQTTPacketFixedHeader, networkData: Data) {
        // FIXME: fix
        var buffer = [UInt8](repeating: 0, count: 2)
        (networkData as NSData).getBytes(&buffer, range: NSMakeRange(0, 2))
        
        sessionPresent = (buffer[0] & 0x01) == 0x01
        response = MQTTConnackResponse(rawValue: buffer[1])!
        
        super.init(header: header)
    }
}
