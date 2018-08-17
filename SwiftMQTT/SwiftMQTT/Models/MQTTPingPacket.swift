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
        super.init(header: MQTTPacketFixedHeader(packetType: MQTTPacketType.pingReq, flags: 0))
    }
}
