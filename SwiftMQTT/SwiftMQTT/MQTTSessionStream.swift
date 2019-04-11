//
//  MQTTSessionStream.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 12/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import Foundation

protocol MQTTSessionStreamDelegate: class {
    func mqttReady(_ ready: Bool, in stream: MQTTSessionStream)
    func mqttErrorOccurred(in stream: MQTTSessionStream, error: Error?)
    func mqttReceived(in stream: MQTTSessionStream, _ read: StreamReader)
}

class MQTTSessionStream: NSObject {
    
    private var currentRunLoop: RunLoop!
    private let inputStream: InputStream?
    private let outputStream: OutputStream?
    private var sessionQueue: DispatchQueue
    private weak var delegate: MQTTSessionStreamDelegate?

    private var inputReady = false
    private var outputReady = false
    
    init(host: String, port: UInt16, ssl: Bool, timeout: TimeInterval, delegate: MQTTSessionStreamDelegate?) {
        var inputStream: InputStream?
        var outputStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: Int(port), inputStream: &inputStream, outputStream: &outputStream)
        
        let queueLabel = host.components(separatedBy: ".").reversed().joined(separator: ".") + ".stream\(port)"
        self.sessionQueue = DispatchQueue(label: queueLabel, qos: .background, target: nil)
        self.delegate = delegate
        self.inputStream = inputStream
        self.outputStream = outputStream

        super.init()
        
        inputStream?.delegate = self
        outputStream?.delegate = self

        sessionQueue.async { [weak self] in

            guard let `self` = self else {
                return
            }

            self.currentRunLoop = RunLoop.current
            inputStream?.schedule(in: self.currentRunLoop, forMode: .defaultRunLoopMode)
            outputStream?.schedule(in: self.currentRunLoop, forMode: .defaultRunLoopMode)

            inputStream?.open()
            outputStream?.open()
            if ssl {
                let securityLevel = StreamSocketSecurityLevel.negotiatedSSL.rawValue
                inputStream?.setProperty(securityLevel, forKey: .socketSecurityLevelKey)
                outputStream?.setProperty(securityLevel, forKey: .socketSecurityLevelKey)
            }
            if timeout > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() +  timeout) {
                    self.connectTimeout()
                }
            }
            self.currentRunLoop.run()
        }
    }
    
    deinit {
        delegate = nil
        inputStream?.close()
        inputStream?.remove(from: currentRunLoop, forMode: .defaultRunLoopMode)
        outputStream?.close()
        outputStream?.remove(from: currentRunLoop, forMode: .defaultRunLoopMode)
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

    @objc internal func stream(_ aStream: Stream, handle eventCode: Stream.Event) {

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

        case Stream.Event.hasBytesAvailable:
            if aStream == inputStream {
                delegate?.mqttReceived(in: self, inputStream!.read)
            }

        case Stream.Event.errorOccurred:
            delegate?.mqttErrorOccurred(in: self, error: aStream.streamError)

        case Stream.Event.endEncountered:
            if aStream.streamError != nil {
                delegate?.mqttErrorOccurred(in: self, error: aStream.streamError)
            }

        case Stream.Event.hasSpaceAvailable:
            let wasReady = inputReady && outputReady
            if aStream == outputStream {
                outputReady = true
            }
            if !wasReady && inputReady && outputReady {
                delegate?.mqttReady(true, in: self)
            }

        default:
            break
        }
    }
}
