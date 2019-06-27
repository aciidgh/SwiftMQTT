//
//  SwiftMQTTTests.swift
//  SwiftMQTTTests
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import XCTest
import Foundation
@testable import SwiftMQTT

class SwiftMQTTTests: XCTestCase {

    var session: MQTTSession!

    var delegateMessageHandler: ((MQTTMessage) -> Void)?
    var delegatePingHandler: (() -> Void)?
    var delegateDisconnectHandler: ((_ error: MQTTSessionError) -> Void)?

    override func setUp() {
        super.setUp()

        session = MQTTSession(
            host: "test.mosquitto.org",
            port: 1883,
            clientID: "SwiftMQTT_Tests",
            cleanSession: true,
            keepAlive: 2,
            useSSL: false
        )
        session.delegate = self

        let connection = expectation(description: "Establish Connection")
        session.connect { error in
            XCTAssertEqual(error, .none)
            connection.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    override func tearDown() {
        super.tearDown()
        session.disconnect()
    }
    
    func testSuccessfulReconnection() {
        session.disconnect()
        let reconnection = expectation(description: "Restablish Connection")
        session.connect { error in
            XCTAssertEqual(error, .none)
            reconnection.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testSubscribe() {
        let subscribe = expectation(description: "Subscribe")
        session.subscribe(to: "/hey/cool", delivering: .atLeastOnce) { error in
            XCTAssertEqual(error, .none)
            subscribe.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
    
    func testMultiSubscribe() {
        let channels = [
            "/#": MQTTQoS.atLeastOnce,
            "/yo/sup": MQTTQoS.atMostOnce,
            "/yo/ok": MQTTQoS.exactlyOnce,
            ]
        let multiSubscribe = expectation(description: "Multi Subscribe")
        session.subscribe(to: channels) { error in
            XCTAssertEqual(error, .none)
            multiSubscribe.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
    
    func testPublishPacketHeader() {
        let retainPubMsg = MQTTPubMsg(topic: "test", payload: "Test".data(using: .utf8)!, retain: true, QoS: .atMostOnce)
        
        let retainPubPacket = MQTTPublishPacket(messageID: 1, message: retainPubMsg)
        
        let retainFlag = retainPubPacket.header.flags & 0x01
        
        XCTAssert(retainFlag == 1, "Header retention bit is not set")
        
        let qos0 = (retainPubPacket.header.flags & 0x06) >> 1
        
        XCTAssert(qos0 == 0, "QoS not 0 for .atMostOnce")
        
        let nonretainPubMsg = MQTTPubMsg(topic:"test", payload:"Test".data(using: .utf8)!, retain:false, QoS: .atLeastOnce)
        
        let nonretainPubPacket = MQTTPublishPacket(messageID: 2, message: nonretainPubMsg)
        
        let nonretainFlag = nonretainPubPacket.header.flags & 0x01
        
        XCTAssert(nonretainFlag == 0, "Header retention bit should not be set")
        
        let qos1 = (nonretainPubPacket.header.flags & 0x06) >> 1
        
        XCTAssert(qos1 == 1, "QoS not 1 for .atLeastOnce")
        
        let qos2PubMsg = MQTTPubMsg(topic:"test", payload:"Test".data(using: .utf8)!, retain:false, QoS: .exactlyOnce)
        
        let qos2PubPacket = MQTTPublishPacket(messageID: 3, message: qos2PubMsg)
        
        
        let qos2 = (qos2PubPacket.header.flags & 0x06) >> 1
        
        XCTAssert(qos2 == 2, "QoS not 2 for .exactlyOnce")
    }
    
    func testUnSubscribe() {
        let unsubscribe = expectation(description: "unSubscribe")
        session.unSubscribe(from: ["/hey/cool", "/no/ok"]) { error in
            XCTAssertEqual(error, .none)
            unsubscribe.fulfill()
        }
        waitForExpectations(timeout: 15)
    }
    
    func testMultiUnSubscribe() {
        let multiUnsubscribe = expectation(description: "Multi unSubscribe")
        session.unSubscribe(from: "/hey/cool") { error in
            XCTAssertEqual(error, .none)
            multiUnsubscribe.fulfill()
        }
        waitForExpectations(timeout: 5)
    }
    
    func testPublishData() {
        let json = ["hey": "sup"]
        let data = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)

        let publish = expectation(description: "Publish")
        session.publish(data, in: "/hey/wassap", delivering: .atLeastOnce, retain: false) { error in
            XCTAssertEqual(error, .none)
            publish.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func testEndToEndSubscribePublishReceive() {
        let channel = "test_channel"
        let messageData = "hello".data(using: .utf8)!

        let subscribe = expectation(description: "Subscribe")
        session.subscribe(to: channel, delivering: .atMostOnce) { error in
            XCTAssertEqual(error, .none)
            subscribe.fulfill()
        }
        waitForExpectations(timeout: 5)

        let publish = expectation(description: "Publish")
        session.publish(messageData, in: channel, delivering: .atMostOnce, retain: false) { error in
            XCTAssertEqual(error, .none)
            publish.fulfill()
        }

        let receive = expectation(description: "Receive")
        delegateMessageHandler = { (message) in
            XCTAssertEqual(message.payload, messageData)
            receive.fulfill()
        }
        wait(for: [publish, receive], timeout: 5, enforceOrder: true)
    }

    func testAcknowledgesPing() {
        delegatePingHandler = {
            XCTAssertTrue(true)
        }
    }
}

extension SwiftMQTTTests: MQTTSessionDelegate {

    func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
        delegateMessageHandler?(message)
    }
    
    func mqttDidDisconnect(session: MQTTSession, error: MQTTSessionError) {
        delegateDisconnectHandler?(error)
    }

    func mqttDidAcknowledgePing(from session: MQTTSession) {
        delegatePingHandler?()
    }
}
