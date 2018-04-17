//
//  MQTTDisconnectPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTDisconnectPacket: MQTTPacket {
    
    init() {
        super.init(header: MQTTPacketFixedHeader(packetType: .disconnect, flags: 0))
    }
}
