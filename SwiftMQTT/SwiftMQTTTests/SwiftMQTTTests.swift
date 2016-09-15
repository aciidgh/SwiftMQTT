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
        mqttSession.connect { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        mqttSession.disconnect()
    }
    
    func testSuccessfulConnection() {
        mqttSession.disconnect()
		let expectation = self.expectation(description: "Connection Establishment")
        mqttSession.connect {
            XCTAssertTrue($0, "could not connect, error \($1)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    func testSubscribe() {
        let expectation = self.expectation(description: "Subscribe")
        mqttSession.subscribe("/hey/cool", qos: .atLeastOnce) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func testMultiSubscribe() {
        let channels = [
            "/#" : MQTTQoS.atLeastOnce,
            "/yo/sup" : MQTTQoS.atMostOnce,
            "/yo/ok" : MQTTQoS.exactlyOnce,
        ]
        let expectation = self.expectation(description: "Multi Subscribe")
        mqttSession.subscribe(channels) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func testUnSubscribe() {
        let expectation = self.expectation(description: "unSubscribe")
        mqttSession.unSubscribe(["/hey/cool", "/no/ok"]) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func testMultiUnSubscribe() {
        let expectation = self.expectation(description: "Multi unSubscribe")
        mqttSession.unSubscribe("/hey/cool") { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func testPublishData() {
        let expectation = self.expectation(description: "Publish")
        let jsonDict = ["hey" : "sup"]
		let data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
        
        mqttSession.publishData(data, onTopic: "/hey/wassap", withQoS: .atLeastOnce, shouldRetain: false) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
	
    // MARK: MQTT Protocols
    func mqttSession(_ session: MQTTSession, didReceiveMessage message: Data, onTopic topic: String) {
		let stringData = String(data: message, encoding: .utf8)
        print("data received on topic \(topic) message \(stringData)")
    }
    
    func socketErrorOccurred(_ session: MQTTSession) {
        
    }
    
    func didDisconnectSession(_ session: MQTTSession) {
        
    }
}
