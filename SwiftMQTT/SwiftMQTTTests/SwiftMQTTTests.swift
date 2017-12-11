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

class SwiftMQTTTests: XCTestCase, MQTTSessionDelegate {
    
    var mqttSession: MQTTSession!
    
    override func setUp() {
        super.setUp()
		
        mqttSession = MQTTSession(host: "localhost", port: 1883, clientID: "swift", cleanSession: true, keepAlive: 15)
        mqttSession.delegate = self
    }
    
    override func tearDown() {
        super.tearDown()
        mqttSession.disconnect()
    }
    
    func testSuccessfulConnection() {
        
        let expectation = self.expectation(description: "Connection Establishment")
        
        mqttSession.disconnect()
        mqttSession.connect { succeeded, error in
            XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknwon"))")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
    }

    func testSubscribe() {
        
        let expectation = self.expectation(description: "Subscribe")

        mqttSession?.disconnect()
        mqttSession?.connect { succeeded, error in
            self.mqttSession?.subscribe(to: "/hey/cool", delivering: .atLeastOnce) { (succeeded, error) -> Void in
                XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknown")")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
        
    }
    
    func testMultiSubscribe() {
        let channels = [
            "/#": MQTTQoS.atLeastOnce,
            "/yo/sup": MQTTQoS.atMostOnce,
            "/yo/ok": MQTTQoS.exactlyOnce,
        ]
        
        let expectation = self.expectation(description: "Multi Subscribe")
        
        mqttSession?.disconnect()
        mqttSession?.connect { (succeeded, error) -> Void in
            self.mqttSession?.subscribe(to: channels) { succeeded, error in
                XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknwon")")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
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
        
        XCTAssert(nonretainFlag == 0, "Header retenion bit should not be set")
        
        let qos1 = (nonretainPubPacket.header.flags & 0x06) >> 1
        
        XCTAssert(qos1 == 1, "QoS not 1 for .atLeastOnce")
        
        let qos2PubMsg = MQTTPubMsg(topic:"test", payload:"Test".data(using: .utf8)!, retain:false, QoS: .exactlyOnce)
        
        let qos2PubPacket = MQTTPublishPacket(messageID: 3, message: qos2PubMsg)
        
        
        let qos2 = (qos2PubPacket.header.flags & 0x06) >> 1
        
        XCTAssert(qos2 == 2, "QoS not 2 for .exactlyOnce")

    }
    
    func testUnSubscribe() {
        let expectation = self.expectation(description: "unSubscribe")
        
        mqttSession?.disconnect()
        mqttSession?.connect { (succeeded, error) -> Void in
            
            self.mqttSession?.unSubscribe(from: ["/hey/cool", "/no/ok"]) { succeeded, error in
                XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknwon")")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
    }
    
    func testMultiUnSubscribe() {
        let expectation = self.expectation(description: "Multi unSubscribe")
        
        mqttSession?.disconnect()
        mqttSession?.connect { (succeeded, error) -> Void in
            self.mqttSession?.unSubscribe(from: "/hey/cool") { succeeded, error in
                XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unkmown")")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
    }
    
    func testPublishData() {
        let expectation = self.expectation(description: "Publish")
        let jsonDict = ["hey" : "sup"]
		let data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
        
        mqttSession?.disconnect()
        mqttSession?.connect { succeeded, error in
            self.mqttSession?.publish(data, in: "/hey/wassap", delivering: .atLeastOnce, retain: false) { (succeeded, error) -> Void in
                XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknown")")
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
    }
	
    // MARK: MQTTSessionProtocol
    
    func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
        print("received:", message.stringRep ?? "<>", "in:", message.topic)
    }
    
    func mqttDidDisconnect(session: MQTTSession, reson: MQTTSessionDisconnect, error: Error?) {
        print("did disconnect")
    }

}
