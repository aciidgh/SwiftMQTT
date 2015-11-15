//
//  MQTTExtensions.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

enum MQTTSessionError: ErrorType {
    case None
    case SocketError
}

enum MQTTPacketType: UInt8 {
    case Connect        = 0x01
    case Connack        = 0x02
    case Publish        = 0x03
    case PubAck         = 0x04
    case PubRec         = 0x05
    case PubRel         = 0x06
    case PubComp        = 0x07
    case Subscribe      = 0x08
    case SubAck         = 0x09
    case UnSubscribe    = 0x0A
    case UnSubAck       = 0x0B
    case PingReq        = 0x0C
    case PingResp       = 0x0D
    case Disconnect     = 0x0E
    
}

public enum MQTTQoS: UInt8 {
    case AtMostOnce     = 0x0
    case AtLeastOnce    = 0x01
    case ExactlyOnce    = 0x02
}

enum MQTTConnackResponse: UInt8, ErrorType {
    case ConnectionAccepted     = 0x00
    case BadProtocol            = 0x01
    case ClientIDRejected       = 0x02
    case ServerUnavailable      = 0x03
    case BadUsernameOrPassword  = 0x04
    case NotAuthorized          = 0x05
}

extension NSMutableData {
    
    func mqtt_encodeRemainingLength(length: Int) {
        var lengthOfRemainingData = length
        repeat {
            var digit = UInt8(lengthOfRemainingData % 128);
            lengthOfRemainingData /= 128;
            if (lengthOfRemainingData > 0) {
                digit |= 0x80;
            }
            self.appendBytes(&digit, length: 1)
        } while (lengthOfRemainingData > 0);
    }
    
    func mqtt_appendUInt8(data: UInt8) {
        var varData = data
        self.appendBytes(&varData, length: 1)
    }
    
    ///Appends two bytes
    ///Big Endian
    func mqtt_appendUInt16(data: UInt16) {
        let byteOne = UInt8(data / 256)
        let byteTwo = UInt8(data % 256)
        self.mqtt_appendUInt8(byteOne)
        self.mqtt_appendUInt8(byteTwo)
    }
    
    func mqtt_appendData(data: NSData) {
        self.mqtt_appendUInt16(UInt16(data.length))
        self.appendData(data)
    }
    
    func mqtt_appendString(string: String) {
        self.mqtt_appendUInt16(UInt16(string.characters.count))
        self.appendData(string.dataUsingEncoding(NSUTF8StringEncoding)!)
    }
}
