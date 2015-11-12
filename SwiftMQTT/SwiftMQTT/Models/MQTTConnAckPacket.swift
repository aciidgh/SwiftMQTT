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
    
    init(header: MQTTPacketFixedHeader, networkData: NSData) {
        //FIXME: fix
        var buffer = [UInt8](count: 2, repeatedValue: 0)
        networkData.getBytes(&buffer, range: NSMakeRange(0, 2))
        
        self.sessionPresent = (buffer[0] & 0x01) == 0x01
        self.response = MQTTConnackResponse(rawValue: buffer[1])!
        
        super.init(header: header)
    }
}