//
//  MQTTSessionStream.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

/*
OCI Changes:
    Bug Fix - do not MQTT connect until ports are ready
    Changed name of file to match primary class
    Propagate error object to delegate
    Optimizations to receiveDataOnStream
    Make MQTTSessionStreamDelegate var weak
    MQTTSessionStream is now not recycled (RAII design pattern)
*/

import Foundation

protocol MQTTSessionStreamDelegate: class {
    func mqttReady(_ ready: Bool, in stream: MQTTSessionStream)
    func mqttErrorOccurred(in stream: MQTTSessionStream, error: Error?)
    func mqttReceived(_ data: Data, header: MQTTPacketFixedHeader, in stream: MQTTSessionStream)
}

class MQTTSessionStream: NSObject, StreamDelegate {
    
    private let inputStream: InputStream?
    private let outputStream: OutputStream?
    private weak var delegate: MQTTSessionStreamDelegate?
	
	private var inputReady = false
	private var outputReady = false
    
    init(host: String, port: UInt16, ssl: Bool, timeout: TimeInterval, delegate: MQTTSessionStreamDelegate?) {
        var inputStream: InputStream?
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: Int(port), inputStream: &inputStream, outputStream: &outputStream)
        self.delegate = delegate
        self.inputStream = inputStream
        self.outputStream = outputStream
        super.init()
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
		DispatchQueue.global().asyncAfter(deadline: .now() +  timeout) { [weak self] in
			self?.connectTimeout()
		}
    }
    
    deinit {
        inputStream?.close()
        inputStream?.remove(from: .current, forMode: .defaultRunLoopMode)
        outputStream?.close()
        outputStream?.remove(from: .current, forMode: .defaultRunLoopMode)
    }
    
    func send(_ packet: MQTTPacket) -> Int {
        let networkPacket = packet.networkPacket()
        var bytes = [UInt8](repeating: 0, count: networkPacket.count)
        networkPacket.copyBytes(to: &bytes, count: networkPacket.count)
		if let outputStream = outputStream, outputReady {
			return outputStream.write(bytes, maxLength: networkPacket.count)
		}
        return -1
    }
	
	internal func connectTimeout() {
		if inputReady == false || outputReady == false {
			delegate?.mqttReady(false, in: self)
		}
	}
    
    internal func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.openCompleted:
			let wasReady = inputReady && outputReady
            if aStream == inputStream {
				inputReady = true
            }
            else if aStream == outputStream {
				// output almost ready
            }
			if !wasReady && inputReady && outputReady {
				delegate?.mqttReady(true, in: self)
			}
			break
        case Stream.Event.hasBytesAvailable:
            if aStream == inputStream {
                receiveDataOnStream(aStream)
            }
			break
        case Stream.Event.errorOccurred:
            delegate?.mqttErrorOccurred(in: self, error: aStream.streamError)
			break
        case Stream.Event.endEncountered:
            delegate?.mqttErrorOccurred(in: self, error: aStream.streamError)
			break
        case Stream.Event.hasSpaceAvailable:
			let wasReady = inputReady && outputReady
            if aStream == outputStream {
                outputReady = true
            }
			if !wasReady && inputReady && outputReady {
				delegate?.mqttReady(true, in: self)
			}
			break
        default:
			break
        }
    }
    
    fileprivate func receiveDataOnStream(_ stream: Stream) {
        var headerByte = [UInt8](repeating: 0, count: 1)
		guard let inputStream = self.inputStream else { return }
        let len = inputStream.read(&headerByte, maxLength: 1)
		guard len > 0 else { return }
        let header = MQTTPacketFixedHeader(networkByte: headerByte[0])
        
        // Max Length is 2^28 = 268,435,455 (256 MB)
        var multiplier = 1
        var value = 0
        var encodedByte: UInt8 = 0
        repeat {
            inputStream.read(&encodedByte, maxLength: 1)
            value += (Int(encodedByte) & 127) * multiplier
            multiplier *= 128
            if multiplier > 128*128*128 {
                return
            }
        } while ((Int(encodedByte) & 128) != 0)
        
        let totalLength = value
        
        var responseData: Data
        if totalLength > 0 {
            var buffer = [UInt8](repeating: 0, count: totalLength)
            // TODO: Do we need to loop until maxLength is met?
            // TODO: Should we recycle previous responseData buffer?
            let readLength = inputStream.read(&buffer, maxLength: buffer.count)
            responseData = Data(bytes: UnsafePointer<UInt8>(buffer), count: readLength)
        }
		else {
			responseData = Data()
		}
        delegate?.mqttReceived(responseData, header: header, in: self)
    }
}
