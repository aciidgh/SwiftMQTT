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
    var willMessage: MQTTPubMsg? = nil
    
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
        if(cleanSession) {
            flags |= 0x02
        }
        
        if let willMessage = willMessage {
            flags |= 0x04
            
            if willMessage.retain {
                flags |= 0x20
            }
            let qos = UInt8(willMessage.QoS.rawValue)
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
    
    override func networkPacket() -> Data {
        // Variable Header
        var variableHeader = Data()
        // Protocol Name
        variableHeader.mqtt_append(protocolName)
        // Protocol Level
        variableHeader.mqtt_append(protocolLevel)
        // Connect Flags
        variableHeader.mqtt_append(encodedConnectFlags())
        // Keep Alive
        variableHeader.mqtt_append(keepAlive)
        
        // Payload
        var payload = Data()
        // Client ID
        payload.mqtt_append(clientID)
        // Will Packet
        if let willMessage = willMessage {
            payload.mqtt_append(willMessage.topic)
            payload.mqtt_append(willMessage.message)
        }
        // Username
        if let username = username {
            payload.mqtt_append(username)
        }
        // Password
        if let password = password {
            payload.mqtt_append(password)
        }
        
        return finalPacket(variableHeader, payload: payload)
    }
}
