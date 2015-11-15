//
//  ViewController.swift
//  SwiftMQTTExample
//
//  Created by Ankit Aggarwal on 10/11/15.
//  Copyright © 2015 Ankit. All rights reserved.
//

import UIKit
import SwiftMQTT

class MQTTViewController: UIViewController, MQTTSessionDelegate {

    var mqttSession: MQTTSession!
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var channelTextField: UITextField!
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.textView.text = nil
        self.establishConnection()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: "hideKeyboard")
        self.view.addGestureRecognizer(tapGesture)
    }
    
    func hideKeyboard() {
        self.view.endEditing(true)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        let userInfo = notification.userInfo! as NSDictionary
        let kbHeight = userInfo.objectForKey(UIKeyboardFrameBeginUserInfoKey)?.CGRectValue.size.height
        self.bottomConstraint.constant = kbHeight!
    }
    
    func keyboardWillHide(notification: NSNotification) {
        self.bottomConstraint.constant = 0
    }
    
    func establishConnection() {
        
        let host = "192.168.1.131"
        let port:UInt16 = 1883
        let clientID = self.clientID()
        
        mqttSession = MQTTSession(host: host, port: port, clientID: clientID, cleanSession: true, keepAlive: 15)
        mqttSession.delegate = self
        
        self.appendStringToTextView("Trying to connect to \(host) on port \(port) for clientID \(clientID)")
        mqttSession.connect {
            if !$0 {
                self.appendStringToTextView("Error Occurred During connection \($1)")
                return
            }
            self.appendStringToTextView("Connected.")
            self.subscribeToChannel()
        }
    }
    
    func subscribeToChannel() {
        let subChannel = "/#"
        mqttSession.subscribe(subChannel, qos: MQTTQoS.AtLeastOnce) {
            if !$0 {
                self.appendStringToTextView("Error Occurred During subscription \($1)")
                return
            }
            self.appendStringToTextView("Subscribed to \(subChannel)")
        }
    }
    
    func appendStringToTextView(string: String) {
        self.textView.text = "\(self.textView.text)\n\(string)"
    }
    
    //MARK:- MQTTSessionDelegates

    func mqttSession(session: MQTTSession, didReceiveMessage message: NSData, onTopic topic: String) {
        let stringData = NSString(data: message, encoding: NSUTF8StringEncoding) as! String
        self.appendStringToTextView("data received on topic \(topic) message \(stringData)")
    }
    
    func socketErrorOccurred(session: MQTTSession) {
        self.appendStringToTextView("Socket Error")
    }
    
    func didDisconnectSession(session: MQTTSession) {
        self.appendStringToTextView("Session Disconnected.")
    }
    
    //MARK:- IBActions
    
    @IBAction func resetButtonPressed(sender: AnyObject) {
        self.textView.text = nil
        self.channelTextField.text = nil
        self.messageTextField.text = nil
        self.establishConnection()
    }
    
    @IBAction func sendButtonPressed(sender: AnyObject) {
        if self.channelTextField.text?.characters.count > 0 && self.messageTextField.text?.characters.count > 0 {
            let channelName = self.channelTextField.text!
            let message = self.messageTextField.text!
            let messageData = message.dataUsingEncoding(NSUTF8StringEncoding)!
            mqttSession.publishData(messageData, onTopic: channelName, withQoS: .AtLeastOnce, shouldRetain: false) {
                if !$0 {
                    self.appendStringToTextView("Error Occurred During Publish \($1)")
                    return
                }
                self.appendStringToTextView("Published \(message) on channel \(channelName)")
            }
        }
    }
    
    //MARK:- Utilities
    
    func clientID() -> String {

        let userDefaults = NSUserDefaults.standardUserDefaults()
        let clientIDPersistenceKey = "clientID"
        
        var clientID = ""
        
        if let savedClientID = userDefaults.objectForKey(clientIDPersistenceKey) as? String {
            clientID = savedClientID
        } else {
            clientID = self.randomStringWithLength(5)
            userDefaults.setObject(clientID, forKey: clientIDPersistenceKey)
            userDefaults.synchronize()
        }
        
        return clientID
    }
    
    //http://stackoverflow.com/questions/26845307/generate-random-alphanumeric-string-in-swift
    func randomStringWithLength(len: Int) -> String {
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomString : NSMutableString = NSMutableString(capacity: len)
        for (var i=0; i < len; i++){
            let length = UInt32 (letters.length)
            let rand = arc4random_uniform(length)
            randomString.appendFormat("%C", letters.characterAtIndex(Int(rand)))
        }
        return String(randomString)
    }
}
