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
        mqttSession = MQTTSession(host: "localhost", port: 1883, clientID: "swift", cleanSession: true, keepAlive: 5)
        mqttSession.delegate = self
        
        mqttSession.connect { (succeeded, error) -> Void in
            if !succeeded {
                print("Error Occurred During connection \(error)")
                return
            }
            print("Connected")
            self.subscribeToChannel()
        }
    }
    
    func subscribeToChannel() {
        mqttSession.subscribe("/#", qos: MQTTQoS.AtLeastOnce) { (succeeded, error) -> Void in
            if !succeeded {
                print("Error Occurred During subscription \(error)")
                return
            }
            print("Subscribed")
        }
    }
    
    //MARK:- MQTTSessionDelegates

    func mqttSession(session: MQTTSession, didReceiveMessage message: NSData, onTopic topic: String) {
        let stringData = NSString(data: message, encoding: NSUTF8StringEncoding) as! String
        print("data received on topic \(topic) message \(stringData)")
    }
    
    func socketErrorOccurred(session: MQTTSession) {
            
    }
    
    func didDisconnectSession(session: MQTTSession) {
        
    }
}

