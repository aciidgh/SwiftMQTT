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
            XCTAssertTrue(succeeded, "could not connect, error \(String(describing: error))")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        mqttSession.disconnect()
    }
    
    func testSuccessfulConnection() {
        mqttSession.disconnect()
		let expectation = self.expectation(description: "Connection Establishment")
        mqttSession.connect { (succeeded, error) -> Void in
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
        
        mqttSession.subscribe(to: "/hey/cool", delivering: .atLeastOnce) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknwon")")
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
            XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknwon")")
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
            XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknwon")")
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
            XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknwon")")
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
            XCTAssertTrue(succeeded, "could not connect, error \(error?.localizedDescription ?? "unknwon")")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5) { error in
            if let error = error {
                print("Error:", error.localizedDescription)
            }
        }
    }
	
    // MARK: MQTTSessionProtocol
    
    func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
        print("received:", message.payload.stringRep ?? "<>", "in:", message.topic)
    }
    
    func mqttDidDisconnect(session: MQTTSession, reson: MQTTSessionDisconnect, error: Error?) {
        print("did disconnect")
    }

}
