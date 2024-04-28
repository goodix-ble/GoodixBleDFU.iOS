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
import CoreBluetooth
import libcomx

public class FastDfuProfile{
    public let svcUUID = "a6ed0701-d344-460a-8075-b9e8ec90d71b";
    public let deviceCmdUUID = "a6ed0702-d344-460a-8075-b9e8ec90d71b";
    public let deviceDatUUID = "a6ed0703-d344-460a-8075-b9e8ec90d71b";
    
    var central: CBCentralManager?
    var target: CBPeripheral?
    var blockBle: BlockingBLE?  = nil
        
    var fastDfuService:CBService? = nil;
    var cmdChr:CBCharacteristic? = nil;
    var dataChr:CBCharacteristic? = nil;
    
    private func setupChr() throws {
        if let bb = self.blockBle{
            let services = try bb.queryServices(svcUUID: svcUUID)
            if !services.isEmpty{
                let cmd_chars = try bb.queryCharacteristic(service: services[0], chrUUID: deviceCmdUUID)
                if !cmd_chars.isEmpty{
                    cmdChr = cmd_chars[0]
                    if !cmdChr!.isNotifying {
                        try bb.enableNotification(chr: cmdChr!, useStreamBuffer: false);
                    }
                }else{
                    throw ErrorMsg.error(msg: "DFU characteristic not found. Please check UUID: \(deviceCmdUUID)");
                }
                
                let data_chars = try bb.queryCharacteristic(service: services[0], chrUUID: deviceDatUUID)
                if !data_chars.isEmpty{
                    dataChr = data_chars[0]
                }else{
                    throw ErrorMsg.error(msg: "DFU characteristic not found. Please check UUID: \(deviceDatUUID)");
                }
            }else{
                throw ErrorMsg.error(msg: "DFU Service not found. Please check UUID: \(svcUUID)");
            }
        }else{
            throw ErrorMsg.error(msg: "blockBle is nil.")
        }
    }
    public func bondTo(blockingBle:BlockingBLE) throws {
        self.blockBle = blockingBle
        //连接判断
        if !self.blockBle!.isConnected(){
            throw ErrorMsg.error(msg: "设备未连接，请连接后重试.")
        }
        try setupChr()
    }
    
    //命令收发接口
    public func sendCmd(data:Data)throws{
        if let bb = self.blockBle{
            if let chr = cmdChr{
                try bb.writeChrWithoutResponse(chr: chr, data: data)
            }else{
                throw ErrorMsg.error(msg: "cmdChr is nil.")
            }
        }else{
            throw ErrorMsg.error(msg: "blockBle is nil.")
        }
    }
    public func recvCmd()throws -> Data{
        if let bb = self.blockBle{
            if let chr = cmdChr{
                return try bb.readNotificationByChunk(chr: chr, timeoutMS: 6000)
            }else{
                throw ErrorMsg.error(msg: "cmdChr is nil.")
            }
        }else{
            throw ErrorMsg.error(msg: "blockBle is nil.")
        }
    }
    public func sendData(data:Data, listener:RWProgressListener? = nil)throws{
        if let bb = self.blockBle{
            if let chr = dataChr{
                try bb.writeChrWithoutResponse(chr: chr, data: data, listener: listener)
            }else{
                throw ErrorMsg.error(msg: "dataChr is nil.")
            }
        }else{
            throw ErrorMsg.error(msg: "blockBle is nil.")
        }
    }
}
