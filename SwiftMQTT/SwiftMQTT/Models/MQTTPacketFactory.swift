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
    Optimizations to receiveDataOnStream
    Fixed a bug where read needed to be in a loop
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

    func parse(_ read: (_ buffer: UnsafeMutablePointer<UInt8>, _ maxLength: Int) -> Int) -> MQTTPacket? {
        var headerByte: UInt8 = 0
        let len = read(&headerByte, 1)
		guard len > 0 else { return nil }
        let header = MQTTPacketFixedHeader(networkByte: headerByte)
        
        // Max Length is 2^28 = 268,435,455 (256 MB)
        var multiplier = 1
        var value = 0
        var encodedByte: UInt8 = 0
        repeat {
            let _ = read(&encodedByte, 1)
            value += (Int(encodedByte) & 127) * multiplier
            multiplier *= 128
            if multiplier > 128*128*128 {
                return nil
            }
        } while ((Int(encodedByte) & 128) != 0)
		
		// TODO: create a file strategy for large messages
        
        let totalLength = value
        
        var responseData: Data
        if totalLength > 0 {
            let buffer = [UInt8](repeating: 0, count: totalLength)
			var readLength: Int = 0
			repeat {
				let b = UnsafeMutablePointer(mutating: buffer) + readLength
				readLength += read(b, buffer.count - readLength)
			} while readLength < buffer.count
            responseData = Data(bytes: UnsafePointer<UInt8>(buffer), count: readLength)
        }
		else {
			responseData = Data()
		}
        return constructors[header.packetType]?(header, responseData)
	}
}
