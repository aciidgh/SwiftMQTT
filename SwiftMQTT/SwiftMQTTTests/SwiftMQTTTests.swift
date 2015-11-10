//
//  SwiftMQTTTests.swift
//  SwiftMQTTTests
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import XCTest
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
        let expectation = expectationWithDescription("Connection Establishment")
        mqttSession.connect { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    
    
    //MARK: MQTT Protocols
    func mqttSession(session: MQTTSession, didReceiveMessage message: NSData, onTopic topic: String) {
        
    }
    
    func errorOccurred(session: MQTTSession) {
        
    }
    
    func didDisconnectSession(session: MQTTSession) {
        
    }
}
