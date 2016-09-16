//
//  MQTTPingResp.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTPingResp: MQTTPacket {
    
    override init(header: MQTTPacketFixedHeader) {
        super.init(header: header)
    }
}
