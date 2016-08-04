# SwiftMQTT
MQTT Client in pure swift ❤️

Master:
[![Build Status](https://travis-ci.org/aciidb0mb3r/SwiftMQTT.svg)](https://travis-ci.org/aciidb0mb3r/SwiftMQTT)

# Info
* Fully written in swift from ground up
* Closures everywhere :D
* Includes test cases and sample project
* Based on MQTT Version 3.1.1 (http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718043)

![Sample Project Screenshot](http://i.imgur.com/9lefVmVl.png)

# How to use

## Create MQTTSession object:
```swift
mqttSession = MQTTSession(host: "localhost", port: 1883, clientID: "swift", cleanSession: true, keepAlive: 15)
```

## Connect
```swift
mqttSession.connect { (succeeded, error) -> Void in
  if succeeded {
    print("Connected!")
  }
}
```

## Subscribe
```swift
mqttSession.subscribe("/hey/cool", qos: MQTTQoS.AtLeastOnce) { (succeeded, error) -> Void in
 if succeeded {
    print("Subscribed!")
  }
}
```

## Unsubscribe
```swift
 mqttSession.unSubscribe(["/ok/cool", "/no/ok"]) { (succeeded, error) -> Void in
  if succeeded {
    print("unSubscribed!")
  }
}
```
## Publish
```swift
let jsonDict = ["hey" : "sup"]
let data = try! NSJSONSerialization.dataWithJSONObject(jsonDict, options: NSJSONWritingOptions.PrettyPrinted)

mqttSession.publishData(data, onTopic: "/hey/wassap", withQoS: MQTTQoS.AtLeastOnce, shouldRetain: false) { (succeeded, error) -> Void in
  if succeeded {
    print("Published!")
  }
}
```

## Conform to `MQTTSessionDelegate` to receive messages 
```swift
mqttSession.delegate = self
```
```swift
func mqttSession(session: MQTTSession, didReceiveMessage message: NSData, onTopic topic: String) {
	let stringData = NSString(data: message, encoding: NSUTF8StringEncoding) as! String
	print("data received on topic \(topic) message \(stringData)")
}
```

# Installation

## CocoaPods

Install using [CocoaPods](http://cocoapods.org) by adding the following lines to your Podfile:

````ruby
use_frameworks!
pod 'SwiftMQTT'  
````

# License
MIT
