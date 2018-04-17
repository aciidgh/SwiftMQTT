//
//  MQTTConnectPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTConnectPacket: MQTTPacket {
    
    let protocolName: String
    let protocolLevel: UInt8
    let cleanSession: Bool
    let keepAlive: UInt16
    let clientID: String
    
    var username: String? = nil
    var password: String? = nil
    var lastWillMessage: MQTTPubMsg? = nil
    
    init(clientID: String, cleanSession: Bool, keepAlive: UInt16) {
        self.protocolName = "MQTT"
        self.protocolLevel = 0x04
        self.cleanSession = cleanSession
        self.keepAlive = keepAlive
        self.clientID = clientID
        super.init(header: MQTTPacketFixedHeader(packetType: .connect, flags: 0))
    }
    
    func encodedConnectFlags() -> UInt8 {
        var flags = UInt8(0)
        if cleanSession {
            flags |= 0x02
        }
        
        if let message = lastWillMessage {
            flags |= 0x04
            
            if message.retain {
                flags |= 0x20
            }
            let qos = message.QoS.rawValue
            flags |= qos << 3
        }
        
        if username != nil {
            flags |= 0x80
        }
        
        if password != nil {
            flags |= 0x40
        }
        
        return flags
    }
    
    override func variableHeader() -> Data {
        var variableHeader = Data(capacity: 1024)
        variableHeader.mqtt_append(protocolName)
        variableHeader.mqtt_append(protocolLevel)
        variableHeader.mqtt_append(encodedConnectFlags())
        variableHeader.mqtt_append(keepAlive)
        return variableHeader
    }
    
    override func payload() -> Data {
        var payload = Data(capacity: 1024)
        payload.mqtt_append(clientID)
        
        if let message = lastWillMessage {
            payload.mqtt_append(message.topic)
            payload.mqtt_append(message.payload)
        }
        if let username = username {
            payload.mqtt_append(username)
        }
        if let password = password {
            payload.mqtt_append(password)
        }
        return payload
    }
}
