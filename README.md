# SwiftMQTT

MQTT Client

[![Build Status](https://travis-ci.org/aciidb0mb3r/SwiftMQTT.svg)](https://travis-ci.org/aciidb0mb3r/SwiftMQTT)
[![Version](https://img.shields.io/cocoapods/v/SwiftMQTT.svg?style=flat)](http://cocoapods.org/pods/SwiftMQTT)
[![License](https://img.shields.io/cocoapods/l/SwiftMQTT.svg?style=flat)](http://cocoapods.org/pods/SwiftMQTT)

* Fully written in Swift 4
* Robust error handling
* Performant
* Based on [MQTT 3.1.1 Specification](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html)

## Usage

### Create Session
```swift
mqttSession = MQTTSession(
	host: "localhost",
	port: 1883,
	clientID: "swift", // must be unique to the client
	cleanSession: true,
	keepAlive: 15,
	useSSL: false
)
```

### Connect
```swift
mqttSession.connect { error in
    if error == .none {
        print("Connected!")
    } else {
        print(error.description)
    }
}
```

### Subscribe
```swift
let topic = "mytopic" 
mqttSession.subscribe(to: topic, delivering: .atLeastOnce) { error in
    if error == .none {
        print("Subscribed to \(topic)!")
    } else {
        print(error.description)
    }
}
```

### Unsubscribe
```swift
let topic = "mytopic"
mqttSession.unSubscribe(from: topic) { error in
    if error == .none {
        print("Unsubscribed from \(topic)!")
    } else {
        print(error.description)
    }
}
```

### Publish

```swift
let json = ["key" : "value"]
let data = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
let topic = "mytopic"

mqttSession.publish(data, in: topic, delivering: .atLeastOnce, retain: false) { error in
    if error == .none {
        print("Published data in \(topic)!")
    } else {
        print(error.description)
    }
}
```

### Conform to `MQTTSessionDelegate` to receive messages 
```swift
mqttSession.delegate = self
```
```swift
func mqttDidReceive(message: MQTTMessage, from session: MQTTSession) {
    print(message.topic)
    print(message.stringRepresentation)
}
```
```swift
func mqttDidDisconnect(session: MQTTSession, error: MQTTSessionError) {
    if error == .none {
        print("Successfully disconnected from MQTT broker")
    } else {
        print(error.description)
    }
}
```

## Installation

### CocoaPods

Install using [CocoaPods](http://cocoapods.org) by adding the following lines to your Podfile:

````ruby
target 'MyApp' do
    use_frameworks!
    pod 'SwiftMQTT'
end
````

### Carthage

```
github "aciidb0mb3r/SwiftMQTT"
```

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/aciidb0mb3r/SwiftMQTT.git", from: "3.0.0")
]
```
## License
MIT
