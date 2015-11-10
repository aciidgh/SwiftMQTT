//
//  ViewController.swift
//  SwiftMQTTExample
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import UIKit
import SwiftMQTT

class ViewController: UIViewController, MQTTSessionDelegate {

    var mqttSession: MQTTSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mqttSession = MQTTSession(host: "localhost", port: 1883, clientID: "swift", cleanSession: true, keepAlive: 15)
        mqttSession.delegate = self
    }

    func mqttSession(session: MQTTSession, didReceiveMessage message: NSData, onTopic topic: String) {

    }
    
    func errorOccurred(session: MQTTSession) {
            
    }
    
    func didDisconnectSession(session: MQTTSession) {
        
    }
}

