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
                print("Error:", error.localizedDescription)
            }
        }
    }

    func testSubscribe() {
        let expectation = self.expectation(description: "Subscribe")
        
        mqttSession.subscribe(to: "/hey/cool", delivering: .atLeastOnce) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
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
        mqttSession.subscribe(to: channels) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
    }
    
    func testUnSubscribe() {
        let expectation = self.expectation(description: "unSubscribe")
        mqttSession.unSubscribe(from: ["/hey/cool", "/no/ok"]) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
    }
    
    func testMultiUnSubscribe() {
        let expectation = self.expectation(description: "Multi unSubscribe")
        mqttSession.unSubscribe(from: "/hey/cool") { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
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
        
        mqttSession.publish(data, in: "/hey/wassap", delivering: .atLeastOnce, retain: false) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
    }
	
    // MARK: MQTTSessionProtocol
    
    func mqttDidReceive(message data: Data, in topic: String, from session: MQTTSession) {
        let stringData = String(data: data, encoding: .utf8)
        print("received:", stringData, "in:", topic)
    }
    
    func mqttDidDisconnect(session: MQTTSession) {
        print("did disconnect")
    }
    
    func mqttSocketErrorOccurred(session: MQTTSession) {
        print("socket error")
    }

}
