//
//  MQTTPingPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTPingPacket: MQTTPacket {
    init() {
        super.init(header: MQTTPacketFixedHeader(packetType: MQTTPacketType.PingReq, flags: 0))
    }
    override func networkPacket() -> NSData {
        return self.finalPacket(NSData(), payload: NSData())
    }
}
