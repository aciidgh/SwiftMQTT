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
        self.withUnsafeBytes { (buffer: UnsafePointer<UInt8>) in
            repeat {
                let b = UnsafeMutablePointer(mutating: buffer) + readLength
                let bytesRead = read(b, totalLength - readLength)
                if bytesRead < 0 {
                    break
                }
                readLength += bytesRead
            } while readLength < totalLength
        }
        return readLength == totalLength
    }
    
    func write(to write: StreamWriter) -> Bool {
        let totalLength = self.count
        guard totalLength <= 128*128*128 else { return false }
        var writeLength: Int = 0
        self.withUnsafeBytes { (buffer: UnsafePointer<UInt8>) in
            repeat {
                let b = UnsafeMutablePointer(mutating: buffer) + writeLength
                let byteWritten = write(b, totalLength - writeLength)
                if byteWritten < 0 {
                    break
                }
                writeLength += byteWritten
            } while writeLength < totalLength
        }
        return writeLength == totalLength
    }
}

/*

// TODO: create a file strategy for large messages

extension FileHandle: MQTTStreamable {

    static let chunkSize: Int = 1024 * 64

    private func read(from read: StreamReader, totalLength: UInt64) -> Bool {
        var readLength: UInt64 = 0
        repeat {
            if let data = Data(len: FileHandle.chunkSize, from: read) {
                self.write(data)
                readLength += UInt64(FileHandle.chunkSize)
            }
            else {
                break
            }
        } while readLength == totalLength
        return readLength == totalLength
    }
    
    func write(to write: StreamWriter) -> Bool {
        let totalLength = self.seekToEndOfFile()
        self.seek(toFileOffset: 0)
        guard totalLength <= 128*128*128 else { return false }
        var writeLength: UInt64 = 0
        
        repeat {
            let data = self.readData(ofLength: FileHandle.chunkSize)
            if data.count == 0 {
                break
            }
            if data.write(to: write) == false {
                break
            }
            writeLength += UInt64(data.count)
        } while writeLength < totalLength
        return writeLength == totalLength
    }
}
*/
