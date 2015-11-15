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
        let expectation = expectationWithDescription("Connection Establishment")
        mqttSession.connect {
            XCTAssertTrue($0, "could not connect, error \($1)")
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    func testSubscribe() {
        let expectation = expectationWithDescription("Subscribe")
        mqttSession.subscribe("/hey/cool", qos: MQTTQoS.AtLeastOnce) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func testMultiSubscribe() {
        let channels = [
            "/#" : MQTTQoS.AtLeastOnce,
            "/yo/sup" : MQTTQoS.AtMostOnce,
            "/yo/ok" : MQTTQoS.ExactlyOnce,
        ]
        let expectation = expectationWithDescription("Multi Subscribe")
        mqttSession.subscribe(channels) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func testUnSubscribe() {
        let expectation = expectationWithDescription("unSubscribe")
        mqttSession.unSubscribe(["/hey/cool", "/no/ok"]) { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func testMultiUnSubscribe() {
        let expectation = expectationWithDescription("Multi unSubscribe")
        mqttSession.unSubscribe("/hey/cool") { (succeeded, error) -> Void in
            XCTAssertTrue(succeeded, "could not connect, error \(error)")
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func testPublishData() {
        let expectation = expectationWithDescription("Publish")
        let jsonDict = ["hey" : "sup"]
        let data = try! NSJSONSerialization.dataWithJSONObject(jsonDict, options: NSJSONWritingOptions.PrettyPrinted)
        
        mqttSession.publishData(data, onTopic: "/hey/wassap", withQoS: MQTTQoS.AtLeastOnce, shouldRetain: false) { (succeeded, error) -> Void in
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
        let stringData = NSString(data: message, encoding: NSUTF8StringEncoding) as! String
        print("data received on topic \(topic) message \(stringData)")
    }
    
    func socketErrorOccurred(session: MQTTSession) {
        
    }
    
    func didDisconnectSession(session: MQTTSession) {
        
    }
}
