# SwiftMQTT

MQTT Client in Swift

[![Build Status](https://travis-ci.org/aciidb0mb3r/SwiftMQTT.svg)](https://travis-ci.org/aciidb0mb3r/SwiftMQTT)
[![Version](https://img.shields.io/cocoapods/v/SwiftMQTT.svg?style=flat)](http://cocoapods.org/pods/SwiftMQTT)
[![License](https://img.shields.io/cocoapods/l/SwiftMQTT.svg?style=flat)](http://cocoapods.org/pods/SwiftMQTT)

## Info
* Fully written in Swift
* Robust error handling
* Reconnection logic
* Performant

![Sample Project Screenshot](http://i.imgur.com/9lefVmVl.png)

## How to use

### Create Session
```swift
mqttSession = MQTTSession(host: "localhost", port: 1883, clientID: "swift", cleanSession: true, keepAlive: 15, useSSL: false)
```

### Connect
```swift
mqttSession.connect { (succeeded, error) -> Void in
  if succeeded {
    print("Connected!")
  }
}
```

### Subscribe
```swift
mqttSession.subscribe(to: "/hey/cool", delivering: .atLeastOnce) { (succeeded, error) -> Void in
 if succeeded {
    print("Subscribed!")
  }
}
```

### Unsubscribe
```swift
 mqttSession.unSubscribe(from: ["/ok/cool", "/no/ok"]) { (succeeded, error) -> Void in
  if succeeded {
    print("unSubscribed!")
  }
}
```

### Publish
```swift
let jsonDict = ["hey" : "sup"]
let data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)

mqttSession.publish(data, in: "/hey/wassap", delivering: .atLeastOnce, retain: false) { (succeeded, error) -> Void in
  if succeeded {
    print("Published!")
  }
}

```
### Conform to `MQTTSessionDelegate` to receive messages 
```swift
mqttSession.delegate = self
```
```swift
func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
	let string = message.stringRepresentation
}
```
```swift
func mqttDidDisconnect(session: MQTTSession, reson: MQTTSessionDisconnect, error: Error?) {
}
```

## Installation

### CocoaPods

Install using [CocoaPods](http://cocoapods.org) by adding the following lines to your Podfile:

````ruby
use_frameworks!
pod 'SwiftMQTT', :git => 'https://github.com/oci-pronghorn/SwiftMQTT'
````

## License
MIT
