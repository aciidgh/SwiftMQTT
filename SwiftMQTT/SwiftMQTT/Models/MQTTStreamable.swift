//
//  MQTTStreamable.swift
//  SwiftMQTT
//
//  Created by David Giovannini on 6/9/17.
//  Copyright © 2017 Ankit. All rights reserved.
//

import Foundation

typealias StreamReader = (_ buffer: UnsafeMutablePointer<UInt8>, _ len: Int) -> Int
typealias StreamWriter = (_ buffer: UnsafePointer<UInt8>, _ len: Int) -> Int

protocol MQTTStreamable {

    init?(len: Int, from read: StreamReader)
    func write(to write: StreamWriter) -> Bool
}

extension MQTTStreamable {

    static func readPackedLength(from read: StreamReader) -> Int? {
        var multiplier = 1
        var length = 0
        var encodedByte: UInt8 = 0
        repeat {
            let _ = read(&encodedByte, 1)
            length += (Int(encodedByte) & 127) * multiplier
            multiplier *= 128
            if multiplier > 128*128*128 {
                return nil
            }
        } while ((Int(encodedByte) & 128) != 0)
        return length <= 128*128*128 ? length : nil
    }
}

extension Data: MQTTStreamable {

    init?(len: Int, from read: StreamReader) {
        self.init(count: len)
        if self.read(from: read) == false {
            return nil
        }
    }
    
    mutating func read(from read: StreamReader) -> Bool {
        let totalLength = self.count
        var readLength: Int = 0
        
        let _ = self.withUnsafeMutableBytes { (buffer) -> UInt8 in
            repeat {
                let point = buffer.bindMemory(to: UInt8.self)
                let unsafePointer = point.baseAddress!
                let b = UnsafeMutablePointer(mutating: unsafePointer) + readLength
                let bytesRead = read(b, totalLength - readLength)
                if bytesRead < 0 {
                    break
                }
                readLength += bytesRead
            } while readLength < totalLength
            return 0
        }
        
        return readLength == totalLength
    }

    
    func write(to write: StreamWriter) -> Bool {
        let totalLength = self.count
        guard totalLength <= 128*128*128 else { return false }
        var writeLength: Int = 0
        
        let _ = self.withUnsafeBytes { (buffer) -> UInt8 in
            repeat {
                let point = buffer.bindMemory(to: UInt8.self)
                let unsafePointer = point.baseAddress!
                let b = UnsafeMutablePointer(mutating: unsafePointer) + writeLength
                let byteWritten = write(b, totalLength - writeLength)
                if byteWritten < 0 {
                    break
                }
                writeLength += byteWritten
            } while writeLength < totalLength
            return 0
        }
        
        return writeLength == totalLength
    }
}
