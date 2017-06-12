//
//  MQTTPacketFactory.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 5/21/17.
//  Copyright © 2017 Ankit. All rights reserved.
//

import Foundation

/*
OCI Changes:
    Moved from Session
    Do both marshal and unmarshal of MQTTPacket
    Move stream read/write loops into MQTTStreamable
*/

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
        if let len = Data.readPackedLength(from: read) {
            if let data = Data(len: len, from: read) {
                return constructors[header.packetType]?(header, data)
            }
        }
        return nil
	}
}
