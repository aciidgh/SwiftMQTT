//
//  MQTTSessionStreamDelegate.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

protocol MQTTSessionStreamDelegate {
    func streamErrorOccurred(stream: MQTTSessionStream)
    func receivedData(stream: MQTTSessionStream, data: NSData, withMQTTHeader header: MQTTPacketFixedHeader)
}

class MQTTSessionStream: NSObject, NSStreamDelegate {
   
    internal let host: String
    internal let port: UInt16
    
    private var inputStream:NSInputStream?
    private var outputStream:NSOutputStream?
    
    internal var delegate: MQTTSessionStreamDelegate?
    
    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
    
    func createStreamConnection() {
        NSStream.getStreamsToHostWithName(host, port: NSInteger(port), inputStream: &inputStream, outputStream: &outputStream)
        inputStream?.delegate = self
        outputStream?.delegate = self
        inputStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream?.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream?.open()
        outputStream?.open()
    }
    
    func closeStreams() {
        inputStream?.close()
        inputStream?.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream?.close()
        outputStream?.removeFromRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    func sendPacket(packet: MQTTPacket) -> NSInteger {
        let networkPacket = packet.networkPacket()
        if let writtenLength = outputStream?.write(UnsafePointer<UInt8>(networkPacket.bytes), maxLength: networkPacket.length) {
            return writtenLength;
        }
        return -1
    }
    
    internal func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
        case NSStreamEvent.None: break
        case NSStreamEvent.OpenCompleted: break
        case NSStreamEvent.HasBytesAvailable:
            if aStream == inputStream {
                self.receiveDataOnStream(aStream)
            }
        case NSStreamEvent.ErrorOccurred:
            self.closeStreams()
            self.delegate?.streamErrorOccurred(self)
        case NSStreamEvent.EndEncountered:
            self.closeStreams()
        case NSStreamEvent.HasSpaceAvailable: break
        default:
            print("unknown")
        }
    }
    
    private func receiveDataOnStream(stream: NSStream) {
        
        var headerByte = [UInt8](count: 1, repeatedValue: 0)
        let len = inputStream?.read(&headerByte, maxLength: 1)
        if !(len > 0) { return; }
        let header = MQTTPacketFixedHeader(networkByte: headerByte[0])
        
        ///Max Length is 2^28 = 268,435,455 (256 MB)
        var multiplier = 1
        var value = 0
        var encodedByte: UInt8 = 0
        repeat {
            var readByte = [UInt8](count: 1, repeatedValue: 0)
            inputStream?.read(&readByte, maxLength: 1)
            encodedByte = readByte[0]
            value += (Int(encodedByte) & 127) * multiplier
            multiplier *= 128
            if multiplier > 128*128*128 {
                return;
            }
        } while ((Int(encodedByte) & 128) != 0)
        
        let totalLength = value
        
        var responseData: NSData = NSData()
        if totalLength > 0 {
            var buffer = [UInt8](count: totalLength, repeatedValue: 0)
            let readLength = inputStream?.read(&buffer, maxLength: buffer.count)
            responseData = NSData(bytes: buffer, length: readLength!)
        }
        self.delegate?.receivedData(self, data: responseData, withMQTTHeader: header)
    }
}