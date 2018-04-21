//
//  MQTTPacketFactory.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/21/17.
//  Copyright © 2017 Ankit. All rights reserved.
//

import Foundation

struct MQTTPacketFactory {

    let constructors: [MQTTPacketType : (MQTTPacketFixedHeader, Data)->MQTTPacket] = [
        .connAck : MQTTConnAckPacket.init,
        .subAck : MQTTSubAckPacket.init,
        .unSubAck : MQTTUnSubAckPacket.init,
        .pubAck : MQTTPubAck.init,
        .publish : MQTTPublishPacket.init,
        .pingResp : { h, _ in MQTTPingResp.init(header: h) }
    ]
    
    func send(_ packet: MQTTPacket, write: StreamWriter) -> Bool {
        let networkPayload = packet.networkPacket()
        if networkPayload.write(to: write) {
            return true
        }
        return false
    }

    func parse(_ read: StreamReader) -> MQTTPacket? {

        var headerByte: UInt8 = 0
        let len = read(&headerByte, 1)
        guard len > 0 else { return nil }

        let header = MQTTPacketFixedHeader(networkByte: headerByte)

        if let packetLength = Data.readPackedLength(from: read) {
            if packetLength > 0, let data = Data(len: packetLength, from: read) {
                return constructors[header.packetType]?(header, data)
            } else {
                return constructors[header.packetType]?(header, Data())
            }
        } else {
            return nil
        }
	}

}
