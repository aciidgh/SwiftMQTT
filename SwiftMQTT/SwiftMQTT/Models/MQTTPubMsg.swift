//
//  MQTTPubMsg.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

public class MQTTPubMsg {
    public let topic: String
    public let message: NSData
    public let retain: Bool
    public let QoS: MQTTQoS
    
    public init(topic: String, message: NSData, retain: Bool, QoS: MQTTQoS) {
        self.topic = topic
        self.message = message
        self.retain = retain
        self.QoS = QoS
    }
}
