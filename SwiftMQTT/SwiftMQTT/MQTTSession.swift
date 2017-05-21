//
//  MQTTSession.swift
//  SwiftMQTT
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

/*
OCI Changes:
    Bug Fix - do not MQTT connect until ports are ready
    Encapsulate mqttDidReceive params into MQTTMessage struct
    Propagate error objects to delegate
    Single delegate call on errored disconnect
    Optimization in callSuccessCompletionBlock
    Move MQTTSessionStreamDelegate adherence to extension
    Make MQTTSessionDelegate var weak
    Adhere to MQTTBroker
    Make deinit force disconnect
    MQTTSessionStream is now not recycled (RAII design pattern)
*/

import Foundation

public protocol MQTTSessionDelegate: class {
    func mqttDidReceive(message: MQTTMessage, from session: MQTTSession)
    func mqttDidDisconnect(session: MQTTSession, error: Error?)
}

public typealias MQTTSessionCompletionBlock = (_ succeeded: Bool, _ error: Error?) -> Void

open class MQTTSession: MQTTBroker {
	
    let host: String
    let port: UInt16
    let connectionTimeout: TimeInterval
    let useSSL: Bool
    
    open let cleanSession: Bool
    open let keepAlive: UInt16
    open let clientID: String
    
    open var username: String?
    open var password: String?
    open var lastWillMessage: MQTTPubMsg?

    open weak var delegate: MQTTSessionDelegate?
	
    fileprivate var keepAliveTimer: Timer!
    fileprivate var connectionCompletionBlock: MQTTSessionCompletionBlock?
    fileprivate var messagesCompletionBlocks = [UInt16: MQTTSessionCompletionBlock]()
    
    fileprivate var stream: MQTTSessionStream?
    
    public init(host: String, port: UInt16, clientID: String, cleanSession: Bool, keepAlive: UInt16, connectionTimeout: TimeInterval = 1.0, useSSL: Bool = false) {
        self.host = host
        self.port = port
		self.connectionTimeout = connectionTimeout
        self.useSSL = useSSL
        self.clientID = clientID
        self.cleanSession = cleanSession
        self.keepAlive = keepAlive
    }
    
    deinit {
        disconnect()
    }
    
    open func publish(_ data: Data, in topic: String, delivering qos: MQTTQoS, retain: Bool, completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let pubMsg = MQTTPubMsg(topic: topic, payload: data, retain: retain, QoS: qos)
        let publishPacket = MQTTPublishPacket(messageID: msgID, message: pubMsg)
        if send(publishPacket) {
            messagesCompletionBlocks[msgID] = completion
            if qos == .atMostOnce {
                completion?(true, MQTTSessionError.none)
            }
        } else {
            completion?(false, MQTTSessionError.socketError)
        }
    }
    
    open func subscribe(to topics: [String: MQTTQoS], completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let subscribePacket = MQTTSubPacket(topics: topics, messageID: msgID)
        if send(subscribePacket) {
            messagesCompletionBlocks[msgID] = completion
        } else {
            completion?(false, MQTTSessionError.socketError)
        }
    }
    
    open func unSubscribe(from topics: [String], completion: MQTTSessionCompletionBlock?) {
        let msgID = nextMessageID()
        let unSubPacket = MQTTUnsubPacket(topics: topics, messageID: msgID)
        if send(unSubPacket) {
            messagesCompletionBlocks[msgID] = completion
        } else {
            completion?(false, MQTTSessionError.socketError)
        }
    }
    
    open func connect(completion: MQTTSessionCompletionBlock?) {
        // Open Stream
		connectionCompletionBlock = completion
        stream = MQTTSessionStream(host: host, port: port, ssl: useSSL, timeout: connectionTimeout, delegate: self)
        
        keepAliveTimer = Timer(timeInterval: TimeInterval(keepAlive), target: self, selector: #selector(MQTTSession.keepAliveTimerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(keepAliveTimer, forMode: .defaultRunLoopMode)
    }
    
    open func disconnect() {
        let disconnectPacket = MQTTDisconnectPacket()
        send(disconnectPacket)
        cleanupDisconnection(nil)
    }
    
    fileprivate func cleanupDisconnection(_ error: Error?) {
        stream = nil
        keepAliveTimer?.invalidate()
        delegate?.mqttDidDisconnect(session: self, error: error)
    }
    
    @discardableResult
    fileprivate func send(_ packet: MQTTPacket) -> Bool {
        if let stream = stream {
            let writtenLength = stream.send(packet)
            let didWriteSuccessfully = writtenLength != -1
            if !didWriteSuccessfully {
                cleanupDisconnection(NSError(domain: "MQTTSession", code: 0, userInfo: nil))
            }
            return didWriteSuccessfully
        }
        return false
    }
    
    fileprivate func parse(_ networkData: Data, header: MQTTPacketFixedHeader) {
        switch header.packetType {
        case .connAck:
            let connAckPacket = MQTTConnAckPacket(header: header, networkData: networkData)
            let success = (connAckPacket.response == .connectionAccepted)
            connectionCompletionBlock?(success, connAckPacket.response)
            connectionCompletionBlock = nil
        case .subAck:
            let subAckPacket = MQTTSubAckPacket(header: header, networkData: networkData)
            callSuccessCompletionBlock(for: subAckPacket.messageID)
        case .unSubAck:
            let unSubAckPacket = MQTTUnSubAckPacket(header: header, networkData: networkData)
            callSuccessCompletionBlock(for: unSubAckPacket.messageID)
        case .pubAck:
            let pubAck = MQTTPubAck(header: header, networkData: networkData)
            callSuccessCompletionBlock(for: pubAck.messageID)
        case .publish:
            let publishPacket = MQTTPublishPacket(header: header, networkData: networkData)
            sendPubAck(for: publishPacket.messageID)
			let message = MQTTMessage(publishPacket: publishPacket)
            delegate?.mqttDidReceive(message: message, from: self)
        case .pingResp:
            _ = MQTTPingResp(header: header)
        default:
            return
        }
    }
    
    fileprivate func sendPubAck(for messageId: UInt16) {
        let pubAck = MQTTPubAck(messageID: messageId)
        send(pubAck)
    }
    
    fileprivate func callSuccessCompletionBlock(for messageId: UInt16) {
        let completionBlock = messagesCompletionBlocks.removeValue(forKey: messageId)
        completionBlock?(true, MQTTSessionError.none)
    }
    
    @objc fileprivate func keepAliveTimerFired() {
        let mqttPingReq = MQTTPingPacket()
        send(mqttPingReq)
    }
    
    fileprivate func nextMessageID() -> UInt16 {
        struct MessageIDHolder {
            static var messageID = UInt16(0)
        }
        MessageIDHolder.messageID += 1
        return MessageIDHolder.messageID
    }
}

extension MQTTSession: MQTTSessionStreamDelegate {

	func mqttReady(_ ready: Bool, in stream: MQTTSessionStream) {
		// Create Connect Packet
        let connectPacket = MQTTConnectPacket(clientID: clientID, cleanSession: cleanSession, keepAlive: keepAlive)
        // Set Optional vars
        connectPacket.username = username
        connectPacket.password = password
        connectPacket.lastWillMessage = lastWillMessage
        
        if send(connectPacket) == false {
            connectionCompletionBlock?(false, MQTTSessionError.socketError)
			connectionCompletionBlock = nil
        }
	}
	
	
	func mqttReceived(in stream: MQTTSessionStream, _ read: (_ buffer: UnsafeMutablePointer<UInt8>, _ maxLength: Int) -> Int) {
	        var headerByte = [UInt8](repeating: 0, count: 1)
        let len = read(&headerByte, 1)
		guard len > 0 else { return }
        let header = MQTTPacketFixedHeader(networkByte: headerByte[0])
        
        // Max Length is 2^28 = 268,435,455 (256 MB)
        var multiplier = 1
        var value = 0
        var encodedByte: UInt8 = 0
        repeat {
            let _ = read(&encodedByte, 1)
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
            let readLength = read(&buffer, buffer.count)
            responseData = Data(bytes: UnsafePointer<UInt8>(buffer), count: readLength)
        }
		else {
			responseData = Data()
		}
        parse(responseData, header: header)
	}
    
    func mqttErrorOccurred(in stream: MQTTSessionStream, error: Error?) {
        cleanupDisconnection(error)
    }
}
