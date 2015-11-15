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
        super.init(header: MQTTPacketFixedHeader(packetType: .Connect, flags: 0))
    }
    
    func encodedConnectFlags() -> UInt8 {
        var flags = UInt8(0)
        if(self.cleanSession) {
            flags |= 0x02
        }
        
        if let willMessage = self.willMessage {
            flags |= 0x04
            
            if willMessage.retain {
                flags |= 0x20
            }
            let qos = UInt8(willMessage.QoS.rawValue)
            flags |= qos << 3
        }
        
        if let _ = self.username {
            flags |= 0x80
        }
        
        if let _ = self.password {
            flags |= 0x40
        }
        
        return flags
    }
    
    override func networkPacket() -> NSData {
        //Variable Header
        let variableHeader = NSMutableData()
        //Protocol Name
        variableHeader.mqtt_appendString(self.protocolName)
        //Protocol Level
        variableHeader.mqtt_appendUInt8(self.protocolLevel)
        //Connect Flags
        variableHeader.mqtt_appendUInt8(self.encodedConnectFlags())
        //Keep Alive
        variableHeader.mqtt_appendUInt16(self.keepAlive)
        
        //Payload
        let payload = NSMutableData()
        //Client ID
        payload.mqtt_appendString(self.clientID)
        //Will Packet
        if let willMessage = self.willMessage {
            payload.mqtt_appendString(willMessage.topic)
            payload.mqtt_appendData(willMessage.message)
        }
        //Username
        if let username = self.username {
            payload.mqtt_appendString(username)
        }
        ///Password
        if let password = self.password {
            payload.mqtt_appendString(password)
        }
        
        return self.finalPacket(variableHeader, payload: payload)
    }
}