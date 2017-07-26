//
//  MQTTSessionStream.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

/*
OCI Changes:
    Bug Fix - do not handshake until ports are ready
    Changed name of file to match primary class
    Propagate error object to delegate
    Make MQTTSessionStreamDelegate var weak
    MQTTSessionStream is now not recycled (RAII design pattern)
	Move the little bit of parsing out of this class. This only manages the stream.
    Always use dedicated queue for streams
    Remove all MQTT model dependencies
*/

import Foundation

protocol MQTTSessionStreamDelegate: class {
    func mqttReady(_ ready: Bool, in stream: MQTTSessionStream)
    func mqttErrorOccurred(in stream: MQTTSessionStream, error: Error?)
	func mqttReceived(in stream: MQTTSessionStream, _ read: StreamReader)
}

class MQTTSessionStream: NSObject {
    
    fileprivate let inputStream: InputStream?
    fileprivate let outputStream: OutputStream?
    fileprivate weak var delegate: MQTTSessionStreamDelegate?
	private var sessionQueue: DispatchQueue
	
	fileprivate var inputReady = false
	fileprivate var outputReady = false
    
    init(host: String, port: UInt16, ssl: Bool, timeout: TimeInterval, delegate: MQTTSessionStreamDelegate?) {
        var inputStream: InputStream?
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: Int(port), inputStream: &inputStream, outputStream: &outputStream)
        
        var parts = host.components(separatedBy: ".")
        parts.insert("stream\(port)", at: 0)
        let label = parts.reversed().joined(separator: ".")
        
        self.sessionQueue = DispatchQueue(label: label, qos: .background, target: nil)
        self.delegate = delegate
        self.inputStream = inputStream
        self.outputStream = outputStream
        super.init()
        
        inputStream?.delegate = self
        outputStream?.delegate = self
        
        sessionQueue.async { [weak self] in
            let currentRunLoop = RunLoop.current
            inputStream?.schedule(in: currentRunLoop, forMode: .defaultRunLoopMode)
            outputStream?.schedule(in: currentRunLoop, forMode: .defaultRunLoopMode)
            inputStream?.open()
            outputStream?.open()
            if ssl {
                let securityLevel = StreamSocketSecurityLevel.negotiatedSSL.rawValue
                inputStream?.setProperty(securityLevel, forKey: Stream.PropertyKey.socketSecurityLevelKey)
                outputStream?.setProperty(securityLevel, forKey: Stream.PropertyKey.socketSecurityLevelKey)
            }
			if timeout > 0 {
				DispatchQueue.global().asyncAfter(deadline: .now() +  timeout) {
					self?.connectTimeout()
				}
			}
            currentRunLoop.run()
        }
    }
    
    deinit {
        inputStream?.close()
        inputStream?.remove(from: .current, forMode: .defaultRunLoopMode)
        outputStream?.close()
        outputStream?.remove(from: .current, forMode: .defaultRunLoopMode)
    }
    
    var write: StreamWriter? {
		if let outputStream = outputStream, outputReady {
			return outputStream.write
		}
        return nil
    }
	
	internal func connectTimeout() {
		if inputReady == false || outputReady == false {
			delegate?.mqttReady(false, in: self)
		}
	}
}

extension MQTTSessionStream: StreamDelegate {
    @objc
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
                delegate?.mqttReceived(in: self, inputStream!.read)
            }
            break
        case Stream.Event.errorOccurred:
            delegate?.mqttErrorOccurred(in: self, error: aStream.streamError)
            break
        case Stream.Event.endEncountered:
			if aStream.streamError != nil {
				delegate?.mqttErrorOccurred(in: self, error: aStream.streamError)
			}
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
}
