//
//  MQTTPacket.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

class MQTTPacket {
    
    let header: MQTTPacketFixedHeader
    
    init(header: MQTTPacketFixedHeader) {
        self.header = header
    }
        
    func networkPacket() -> NSData {
        //To be implemented in subclasses
        return NSData()
    }
    
    //Creates the actual packet to be sent using fixed header, variable header and payload
    //Automatically encodes remaining length
    func finalPacket(variableHeader: NSData, payload: NSData) -> NSData {
        let remainingData = NSMutableData(data: variableHeader)
        remainingData.appendData(payload)
        
        let finalPacket = NSMutableData()
        finalPacket.appendData(self.header.networkPacket())
        finalPacket.mqtt_encodeRemainingLength(remainingData.length) //Remaining Length
        finalPacket.appendData(remainingData) //Remaining Data = Variable Header + Payload
        
        return finalPacket
    }
}
