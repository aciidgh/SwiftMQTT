//
//  MQTTSessionStreamDelegate.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

protocol MQTTSessionStreamDelegate {
    func mqttErrorOccurred(in stream: MQTTSessionStream)
    func mqttReceived(_ data: Data, header: MQTTPacketFixedHeader, in stream: MQTTSessionStream)
}

class MQTTSessionStream: NSObject, StreamDelegate {
    
    internal let host: String
    internal let port: UInt16
    internal let ssl: Bool
    
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    
    private var readMessage = Data()
    // minimal size: 1 byte for fixed header and 1 byte for length of remaining message
    private var expectedHeaderSize = 2
    
    internal var delegate: MQTTSessionStreamDelegate?
    
    init(host: String, port: UInt16, ssl: Bool) {
        self.host = host
        self.port = port
        self.ssl = ssl
    }
    
    func createStreamConnection() {
        Stream.getStreamsToHost(withName: host, port: Int(port), inputStream: &inputStream, outputStream: &outputStream)
        inputStream?.delegate = self
        outputStream?.delegate = self
        inputStream?.schedule(in: .current, forMode: .defaultRunLoopMode)
        outputStream?.schedule(in: .current, forMode: .defaultRunLoopMode)
        inputStream?.open()
        outputStream?.open()
        if ssl {
            let securityLevel = StreamSocketSecurityLevel.negotiatedSSL.rawValue
            inputStream?.setProperty(securityLevel, forKey: Stream.PropertyKey.socketSecurityLevelKey)
            outputStream?.setProperty(securityLevel, forKey: Stream.PropertyKey.socketSecurityLevelKey)
        }
    }
    
    func closeStreams() {
        inputStream?.close()
        inputStream?.remove(from: .current, forMode: .defaultRunLoopMode)
        outputStream?.close()
        outputStream?.remove(from: .current, forMode: .defaultRunLoopMode)
        
        readMessage = Data()
        expectedHeaderSize = 2
    }
    
    func send(_ packet: MQTTPacket) -> Int {
        let networkPacket = packet.networkPacket()
        var bytes = [UInt8](repeating: 0, count: networkPacket.count)
        networkPacket.copyBytes(to: &bytes, count: networkPacket.count)
        if let writtenLength = outputStream?.write(bytes, maxLength: networkPacket.count) {
            return writtenLength;
        }
        return -1
    }
    
    internal func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event(): break
        case Stream.Event.openCompleted: break
        case Stream.Event.hasBytesAvailable:
            if aStream == inputStream {
                receiveDataOnStream(inputStream!)
            }
        case Stream.Event.errorOccurred:
            closeStreams()
            delegate?.mqttErrorOccurred(in: self)
        case Stream.Event.endEncountered:
            closeStreams()
        case Stream.Event.hasSpaceAvailable: break
        default:
            print("unknown")
        }
    }
    
    private func receiveDataOnStream(_ stream: InputStream) {
        var buffer = [UInt8](repeating: 0, count: 1)
        var readLength = 0
        repeat {
            readLength = stream.read(&buffer, maxLength: 1)
            guard readLength > 0 else {
                return
            }
            readMessage.append(buffer, count: readLength)
            
            if readMessage.count >= expectedHeaderSize {
                if let (header, messageBody) = parse(readMessage) {
                    // move to next message and reset minimal header size
                    readMessage = readMessage.subdata(in: expectedHeaderSize+messageBody.count..<readMessage.count)
                    expectedHeaderSize = 2
                    
                    // we should call delegate only after we have received full message
                    delegate?.mqttReceived(messageBody, header: header, in: self)
                }
            }
        } while (stream.hasBytesAvailable)
    }
    
    private func parse(_ message: Data) -> (MQTTPacketFixedHeader, Data)? {
        let header = MQTTPacketFixedHeader(networkByte: message[0])
        guard let messageLength = parseLength(message.subdata(in: 1..<message.count)) else {
            expectedHeaderSize += 1
            return nil
        }
        guard message.count >= messageLength + expectedHeaderSize else {
            return nil
        }
        
        let messageBody = message.subdata(in: expectedHeaderSize..<expectedHeaderSize+messageLength)
        
        return (header, messageBody)
    }
    
    private func parseLength(_ message: Data) -> Int? {
        var message = message
        var multiplier = 1
        var value  = 0
        var byte = UInt8(0x00)
        
        repeat {
            guard message.count > 0 else {
                return nil
            }
            
            byte = UInt8(message[0])
            message = message.subdata(in: 1..<message.count)
            value += Int(byte & 127) * multiplier
            multiplier *= 128
            // Max Length is 2^28 = 268,435,455 (256 MB)
            if (multiplier) > 128*128*128 {
                break
            }
        } while (byte & 0x80 != 0)
        
        return value
    }
}
