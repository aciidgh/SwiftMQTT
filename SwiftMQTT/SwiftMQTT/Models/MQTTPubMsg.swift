//
//  MQTTPubMsg.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

open class MQTTPubMsg {
    
    open let topic: String
    open let payload: Data
    open let retain: Bool
    open let QoS: MQTTQoS
    
    public init(topic: String, payload: Data, retain: Bool, QoS: MQTTQoS) {
        self.topic = topic
        self.payload = payload
        self.retain = retain
        self.QoS = QoS
    }
}
