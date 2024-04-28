/**
 *****************************************************************************************
  Copyright (c) 2023 GOODIX
  All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
  * Neither the name of GOODIX nor the names of its contributors may be used
    to endorse or promote products derived from this software without
    specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDERS AND CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************************
 */

import Foundation

// [UInt8] Data NSData String 转换
// https://xingxingyueliang.blog.csdn.net/article/details/112336928
//

open class HexHandler {
    open var buffer:Data;
    open var pos:Int = 0;
    
    public var description: String { get {
        return buffer.map {
            String(format: "%02X", $0)
        }.joined();
    } }
    
    public init(_ count:Int) {
        self.buffer = Data(count: count);
    }
    
    public init(copy:Data) {
        self.buffer = copy;
    }
    
    @discardableResult
    public func setNegetivePos(negPos:Int) -> Int{
        var newPos = 0;
        if negPos < 0 {
            newPos = negPos + buffer.count;
            if newPos < 0 {
                newPos = 0;
            }
        } else {
            newPos = negPos
            if newPos > buffer.count {
                newPos = buffer.count;
            }
        }
        self.pos = newPos;
        return newPos;
    }
    
    @discardableResult
    open func put(size:UInt, uint32:UInt32, bigEndian:Bool = false) ->  HexHandler {
        var tmp = uint32;
        var count = Int(size > 4 ? 4 : size);
        let remainSpace = self.buffer.count - pos;
        if count > remainSpace {
            count = remainSpace;
        }
        for _ in 0..<count {
            buffer[pos] = (UInt8(tmp & 0xFF));
            pos += 1;
            tmp >>= 8;
        }
        return self;
    }
    
    @discardableResult
    open func put(size:UInt, uint64:UInt64, bigEndian:Bool = false) -> HexHandler {
        var tmp = uint64;
        var count = Int(size > 8 ? 8 : size);
        let remainSpace = self.buffer.count - pos;
        if count > remainSpace {
            count = remainSpace;
        }
        for _ in 0..<count {
            buffer[pos] = (UInt8(tmp & 0xFF));
            pos += 1;
            tmp >>= 8;
        }
        return self;
    }
    
    @discardableResult
    open func put(size:Int, bytes:[UInt8]?, fromStartPos:Int = 0) -> HexHandler {
        if size > 0 {
            if let dat = bytes {
                var startSrcPos = fromStartPos;
                if startSrcPos < 0 {
                    startSrcPos += dat.count;
                    if startSrcPos < 0 {
                        startSrcPos = 0;
                    }
                }
                
                var safeSize = size;
                if safeSize + startSrcPos > dat.count {
                    safeSize = dat.count - startSrcPos;
                }
                
                if safeSize + self.pos > self.buffer.count {
                    safeSize = self.buffer.count - self.pos;
                }
                
                let endSrcPos = startSrcPos + safeSize;
                
                for i in startSrcPos..<endSrcPos {
                    self.buffer[self.pos] = dat[i];
                    self.pos += 1;
                }
            }
        }
        return self;
    }
    
    @discardableResult
    open func putByte(dat:UInt8) -> HexHandler {
        if pos < self.buffer.count {
            self.buffer[pos] = dat;
            pos += 1;
        }
        return self;
    }
    
    @discardableResult
    open func put(size:Int, data:Data?, fromStartPos:Int = 0) -> HexHandler {
        if size > 0 {
            if let dat = data {
                var startSrcPos = fromStartPos;
                if startSrcPos < 0 {
                    startSrcPos += dat.count;
                    if startSrcPos < 0 {
                        startSrcPos = 0;
                    }
                }
                
                var safeSize = size;
                if safeSize + startSrcPos > dat.count {
                    safeSize = dat.count - startSrcPos;
                }
                
                if safeSize + self.pos > self.buffer.count {
                    safeSize = self.buffer.count - self.pos;
                }
                
                let endSrcPos = startSrcPos + safeSize;
                
                for i in startSrcPos..<endSrcPos {
                    self.buffer[self.pos] = dat[i];
                    self.pos += 1;
                }
            }
        }
        return self;
    }
    
    open func getChecksum(size:Int, fromPos:Int = 0) -> UInt32 {
        var sum:UInt32 = 0;
        
        var startPos = fromPos;
        if startPos < 0 {
            startPos = buffer.count + startPos;
            if startPos < 0 {
                startPos = 0;
            }
        }
        
        var endPos = startPos + size;
        if endPos > buffer.count {
            endPos = buffer.count;
        }
        
        if startPos < endPos {
            for i in startPos..<endPos {
                sum += UInt32(buffer[i]) & 0xFF;
            }
        }
        return sum;
    }
    
    open func get(size:UInt, bigEndian:Bool = false) -> UInt64 {
        var tmp:UInt64 = 0;
        let safeSize = Int(size > 8 ? 8 : size);
        let remainSpace = self.buffer.count - pos;
        let shiftCycleCnt = safeSize > remainSpace ? remainSpace : safeSize;
        let dumyCycleCnt = 8 - shiftCycleCnt;
        
        if shiftCycleCnt > 0 {
            for _ in 0..<shiftCycleCnt {
                let d = UInt64(self.buffer[pos]);
                tmp >>= 8;
                tmp |= d << 56;
                pos += 1;
            }
            for _ in 0..<dumyCycleCnt {
                tmp >>= 8;
            }
        }
        
        return tmp;
    }
    
    open func getByte() -> UInt8 {
        if pos < buffer.count {
            let byte = buffer[pos];
            pos += 1;
            return byte;
        }
        return 0;
    }
    
    open func getData(size:UInt) -> Data {
        let startPos = pos;
        let endPos = startPos + Int(size);
        
        if endPos > self.buffer.count {
            // 超出时需要自动补充0
            var tmp = Data(repeating: 0, count: Int(size));
            for i in 0..<Int(size) {
                tmp[i] = getByte();
            }
            return tmp;
            
        } else {
            // 没超出时直接返回一个子集
            pos = endPos;
            return self.buffer.subdata(in: startPos..<endPos);
        }
    }
}

extension Data {
    public func toHexString() -> String {
        var hex = Data(repeating: 0, count: self.count*2);
        var i = 0;
        for b in self {
            let lsb = (b & 0xF);
            let msb = (b >> 4);
            if msb < 10 {
                hex[i] = 0x30 + msb;
            } else {
                hex[i] = 0x41 - 10 + msb;
            }
            i += 1;
            if lsb < 10 {
                hex[i] = 0x30 + lsb;
            } else {
                hex[i] = 0x41 - 10 + lsb;
            }
            i += 1;
        }
        return String(data: hex, encoding: .ascii)!;
    }
    
//    public static func toHexStringTest() {
//        let test = Data(repeating: 0x66, count: 1024*1024);
//        var startTime = DispatchTime.now().uptimeNanoseconds;
//        var result1 = "\([UInt8](test))";
//        var stopTime = DispatchTime.now().uptimeNanoseconds;
//        var result2 = "\(test.toHexString())";
//        var stopTime2 = DispatchTime.now().uptimeNanoseconds;
//        let delta1 = stopTime - startTime;
//        let delta2 = stopTime2 - stopTime;
//        let delta3 = Int64(delta2) - Int64(delta1);
//        print(result1)
//        print(result2)
//        print("\(delta1)") // 452890042 @iphone7
//        print("\(delta2)") // 190957666 @iphone7
//        print("\(delta3)") //-261932376
//    }
}
