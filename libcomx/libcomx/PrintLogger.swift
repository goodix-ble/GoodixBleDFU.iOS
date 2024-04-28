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

public enum ComxLogLevel : Int{
    case VERBOSE = 2;
    case DEBUG = 3;
    case INFO = 4;
    case WARNING = 5;
    case ERROR = 6;
}

public protocol ComxLogRowProtocal{
    func logRaw(timestamp:TimeInterval, _ level:ComxLogLevel, _ tag:String, _ msg:String, _ logStr:String?)
}

public protocol ComxLogProtocol {
    func v(_ tag: String, _ msg: String);
    func d(_ tag: String, _ msg: String);
    func i(_ tag: String, _ msg: String);
    func w(_ tag: String, _ msg: String);
    func e(_ tag: String, _ msg: String);
}

open class PrintLogger : ComxLogProtocol, ComxLogRowProtocal{
    public var levelFilter = ComxLogLevel.INFO.rawValue;
    public var showThread = true;
    public var logRawListener:ComxLogRowProtocal? = nil;
    public let logDateFormatter = DateFormatter();

    public init() {
        self.logDateFormatter.locale = Locale(identifier: "en_US_POSIX");
        self.logDateFormatter.timeZone = TimeZone.current;
        self.logDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS";
    }

    open func logRaw(timestamp: TimeInterval, _ level: ComxLogLevel, _ tag: String, _ msg: String, _ logFromPreviousLogger:String?) {
        var logStr:String;
        
        if level.rawValue < levelFilter {
            return;
        }
        
        if let existLog = logFromPreviousLogger {
            logStr = existLog;
            print(existLog);
        } else {
            var currentDate:Date;
            if timestamp > 0 {
                currentDate = Date(timeIntervalSince1970: timestamp);
            } else {
                currentDate = Date();
            }
            let time = self.logDateFormatter.string(from: currentDate);

            if showThread {
                var threadId = Thread.current.name;
                if threadId == nil || threadId!.isEmpty{
                    if Thread.current.isMainThread {
                        threadId = "main";
                    } else {
                        threadId = String(format: "%d", Thread.current.hash);
                    }
                }
                
                if level.rawValue > 1 && level.rawValue < 8 {
                    logStr = String(format:"[%@] <%@> %@ %@: %@", time, threadId!, String(describing: level), tag, msg);
                    //logStr = String(format:"[%s] %04d %d %s: %s", time, threadId, level, tag, msg);
                } else {
                    logStr = String(format:"[%@] <%@> %@ %@: %@", time, threadId!, String(describing: level), tag, msg);
                }
            } else {
                if level.rawValue > 1 && level.rawValue < 8 {
                    logStr = String(format:"[%@] %@ %@: %@", time, String(describing: level), tag, msg);
                } else {
                    logStr = String(format:"[%@] %@ %@: %@", time, String(describing: level), tag, msg);
                }
            }
        }
        
        print(logStr);
        
        if let subLogger = logRawListener {
            subLogger.logRaw(timestamp: timestamp, level, tag, msg, logStr);
        }
    }
    
    public func v(_ tag: String, _ msg: String) {
        logRaw(timestamp: 0, ComxLogLevel.VERBOSE, tag, msg, nil);
    }
    
    public func d(_ tag: String, _ msg: String) {
        logRaw(timestamp: 0, ComxLogLevel.DEBUG, tag, msg, nil);
    }
    
    public func i(_ tag: String, _ msg: String) {
        logRaw(timestamp: 0, ComxLogLevel.INFO, tag, msg, nil);
    }
    
    public func w(_ tag: String, _ msg: String) {
        logRaw(timestamp: 0, ComxLogLevel.WARNING, tag, msg, nil);
    }
    
    public func e(_ tag: String, _ msg: String) {
        logRaw(timestamp: 0, ComxLogLevel.ERROR, tag, msg, nil);
    }
}
