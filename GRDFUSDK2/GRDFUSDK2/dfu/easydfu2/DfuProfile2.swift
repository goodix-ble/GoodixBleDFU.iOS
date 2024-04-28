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


public class DfuProfile2{
    public let svcUUID = "a6ed0401-d344-460a-8075-b9e8ec90d71b"
    public let deviceTxUUID = "a6ed0402-d344-460a-8075-b9e8ec90d71b"
    public let deviceRxUUID = "a6ed0403-d344-460a-8075-b9e8ec90d71b"
    public let controlPointUUID = "a6ed0404-d344-460a-8075-b9e8ec90d71b"

     var blockBle: BlockingBLE?
    var isSupportAppbootloaderSch: Bool = false

    var tx:CBCharacteristic? = nil
    var rx:CBCharacteristic? = nil
    var ctrlChr:CBCharacteristic? = nil
    
    private func setupChr() throws {
        if let bb = self.blockBle{
            let services = try bb.queryServices(svcUUID: svcUUID)
            if !services.isEmpty{
                let tx_chars = try bb.queryCharacteristic(service: services[0], chrUUID: deviceTxUUID)
                if !tx_chars.isEmpty{
                    tx = tx_chars[0]
                    if !tx!.isNotifying {
                        try bb.enableNotification(chr: tx!, useStreamBuffer: true);
                    }
                }else{
                    throw ErrorMsg.error(msg: "setupChr: DFU characteristic not found. Please check UUID: \(deviceTxUUID)");
                }
                
                let rx_chars = try bb.queryCharacteristic(service: services[0], chrUUID: deviceRxUUID)
                if !rx_chars.isEmpty{
                    rx = rx_chars[0]
                }else{
                    throw ErrorMsg.error(msg: "setupChr: DFU characteristic not found. Please check UUID: \(deviceRxUUID)");
                }
                
                let ctrl_chars = try bb.queryCharacteristic(service: services[0], chrUUID: controlPointUUID)
                if !ctrl_chars.isEmpty{
                    ctrlChr = ctrl_chars[0]
                    if ctrlChr!.properties.contains(.indicate){
                        isSupportAppbootloaderSch=true
                    }else{
                        isSupportAppbootloaderSch=false
                    }
                }else{
                    throw ErrorMsg.error(msg: "setupChr: DFU characteristic not found. Please check UUID: \(controlPointUUID)");
                }
            }else{
                throw ErrorMsg.error(msg: "setupChr: DFU Service not found. Please check UUID: \(svcUUID)");
            }
        }
    }
    public func bondTo(blockingBle:BlockingBLE) throws {
        self.blockBle = blockingBle
        //连接判断
        if !self.blockBle!.isConnected(){
            throw ErrorMsg.error(msg: "bondTo: The device is not connected. Please connect and try again.")
        }
        try setupChr()
    }
    
    //命令收发接口
    public func sendCtrl(ctrlData:Data) throws{//todo
        if let bb = blockBle{
            if let chr = ctrlChr{
                let paramSize = ctrlData.count;
                let builder = HexHandler(paramSize);
                builder.put(size: paramSize, data: ctrlData);
                try bb.writeChrWithoutResponse(chr: chr, data: builder.buffer);
            }else{
                throw ErrorMsg.error(msg: "sendCtrl: Parameter(ctrl) is nil.")
            }
        }
    }
    public func sendCmd(param:Data, needPack: Bool = true, listener:RWProgressListener? = nil) throws {// todo opCode
        if let bb = blockBle{
            if let chr = rx{
                let paramSize = param.count;
                if needPack{
                    let builder = HexHandler(4 + paramSize);
                    builder.put(size: 2, uint32: 0x4744);
                    builder.put(size: paramSize, data: param);
                    let checksum = builder.getChecksum(size: paramSize, fromPos: 2);
                    builder.put(size: 2, uint32: checksum);
                    try bb.writeChrWithoutResponse(chr: chr, data: builder.buffer, listener: listener);
                }else{// todo sendData
                    let builder = HexHandler(paramSize);
                    builder.put(size: paramSize, data: param);
                    try bb.writeChrWithoutResponse(chr: chr, data: builder.buffer, listener: listener);
                }
            }else{
                throw ErrorMsg.error(msg: "sendCmd: Parameter(rx) is nil.")
            }
        }
    }
    public func recvCmd(opcode:UInt32) throws -> Data {
        if let bb = blockBle{
            if let chr = tx {
                let head = try bb.readNotification(chr: chr, byteCount: 6, timeoutMS: 3_000)
                if head.count != 6 {
                    throw ErrorMsg.error(msg: "recvCmd: Cmd head receive failed.")
                }
                
                let headHex = HexHandler(copy: head)
                if Int(headHex.get(size: 2)) != 0x4744 {
                    throw ErrorMsg.error(msg: "recvCmd: Cmd head verification failed.")
                }
                
                let cmdCode: Int = Int(headHex.get(size: 2))
                let cmdLength: Int = Int(headHex.get(size: 2))
                let cmdOut = HexHandler(4+cmdLength)
                let cmdDate = try bb.readNotification(chr: chr, byteCount: cmdLength+2, timeoutMS: 3_000)
                if (cmdLength+2) != cmdDate.count
                {
                    throw ErrorMsg.error(msg: "recvCmd: Cmd body receive failed.")
                }
                cmdOut.put(size: 2, uint32: UInt32(cmdCode))
                cmdOut.put(size: 2, uint32: UInt32(cmdLength))
                cmdOut.put(size: cmdLength, data: cmdDate)
                
                if opcode != cmdCode {
                    throw ErrorMsg.error(msg: "recvCmd: Expected cmdCode not returned。")
                }
                
                //检查checksum
                let cmdDataHex = HexHandler(copy: cmdDate)
                cmdDataHex.pos = cmdLength
                let recvChecksum:Int = Int(cmdDataHex.get(size: 2))
                if recvChecksum != cmdOut.getChecksum(size: cmdOut.buffer.count)&0xffff {
                    throw ErrorMsg.error(msg: "recvCmd: Received instruction checksum verification failed.")
                }
                return cmdOut.buffer;
            }
            else{
                throw ErrorMsg.error(msg: "recvCmd: Parameter(tx) is nil.")
            }
        }else{
            throw ErrorMsg.error(msg: "recvCmd: Parameter(blockBle) is nil.")
        }
    }
}


