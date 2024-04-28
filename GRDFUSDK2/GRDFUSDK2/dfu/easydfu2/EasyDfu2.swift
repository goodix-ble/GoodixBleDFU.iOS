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

public class EasyDfu2{
    private var workThread:Thread? = nil
    private var log:ComxLogProtocol = PrintLogger()
    //配置参数
    private var listener:DfuListener? = nil
    private var reconnectScanFilter:ScanFilter? = nil
    private var ctrlCmd:Data? = nil
    private var isFastMode:Bool = false
    //配置函数
    public init(){}
    public func setFastMode(isFastMode:Bool){
        self.isFastMode = isFastMode
    }
    public func setCtrlCmd(ctrlCmd:Data){
        self.ctrlCmd=ctrlCmd
    }
    public func setReconnectScanFilter(reconnectScanFilter:@escaping ScanFilter){
        self.reconnectScanFilter=reconnectScanFilter
    }
    public func setListener(listener:DfuListener){
        self.listener=listener
    }

    public func setLogListener(listener:ComxLogRowProtocal){
        if let defaultLog = log as? PrintLogger{
            defaultLog.logRawListener = listener
        }
    }

    //接口函数
    public func startDfu(central:CBCentralManager?, target: CBPeripheral, dfuData:Data){
        launchDfu(central: central, targetDevice: target, dfuMode: 0, dfuData: dfuData, address: 0, isExtFlash: false)
    }
    public func startDfuInCopyMode(central:CBCentralManager?, target: CBPeripheral, dfuData:Data, copyAddr:UInt32){
        launchDfu(central: central, targetDevice: target, dfuMode: 1, dfuData: dfuData, address: copyAddr, isExtFlash: false)
    }
    public func startResourceUpdate(central:CBCentralManager?, target: CBPeripheral, dfuData:Data, extFlash:Bool, startAddr:UInt32){
        launchDfu(central: central, targetDevice: target, dfuMode: 2, dfuData: dfuData, address: startAddr, isExtFlash: extFlash)
    }
    public func startDfuWithDfuBoot(central:CBCentralManager?, target: CBPeripheral, dfuData:Data){
        launchDfu(central: central, targetDevice: target, dfuMode: 3, dfuData: dfuData, address: 0, isExtFlash: false)
    }

    //dfu任务
    private func launchDfu(central:CBCentralManager?, targetDevice: CBPeripheral, dfuMode:Int, dfuData:Data,address:UInt32, isExtFlash:Bool){
        workThread = Thread{
            let gr5xxxDfu2: GR5xxxDFU2 = GR5xxxDFU2()
            let blockBle = BlockingBLE()
            do{
                blockBle.setLog(log: self.log)
                gr5xxxDfu2.setLog(log: self.log)
                try blockBle.initCentral(central)
                try blockBle.connectPeripheral(targetDevice: targetDevice)
                try blockBle.discoverServices()
                try gr5xxxDfu2.bondTo(blockingBle: blockBle)
                
                if dfuMode == 0{
                    try gr5xxxDfu2.updateFirmware(dfuData: dfuData, isCopyMode: false, copyAddress: 0, isFastMode: self.isFastMode, listener: self.listener, ctrlCmd: self.ctrlCmd, reconnectScanFilter: self.reconnectScanFilter)
                }else if dfuMode == 1{
                    try gr5xxxDfu2.updateFirmware(dfuData: dfuData, isCopyMode: true, copyAddress: address, isFastMode: self.isFastMode, listener: self.listener, ctrlCmd: self.ctrlCmd)
                }else if dfuMode == 2{
                    try gr5xxxDfu2.updateResource(dfuData: dfuData, startAddress: address, isFastMode: self.isFastMode, isExtFlash: isExtFlash, listener: self.listener, ctrlCmd: self.ctrlCmd)
                }else if dfuMode == 3{
                    //发送命令跳转到Boot模式，并重连设备（BOOT模式）
                    try gr5xxxDfu2.setDfuEnter()
                    Thread.sleep(forTimeInterval: 0.2)
                    try blockBle.disconnectPeripheral()
                    Thread.sleep(forTimeInterval: 0.2)
                    if let filter = self.reconnectScanFilter {
                        try blockBle.connectPeripheral(timeout: 10_000, filter: filter)
                    }else{
                        //警告：因IOS不能取得蓝牙地址，所以重连时是依据DFU BOOT模式时的默认设备名连接的，这里是不可靠的。
                        try blockBle.connectPeripheral(timeout: 10_000, deviceName: "Goodix_DFU")
                    }
                    try blockBle.discoverServices()
                    try gr5xxxDfu2.bondTo(blockingBle: blockBle)
                    
                    try gr5xxxDfu2.updateFirmware(dfuData: dfuData, isCopyMode: false, copyAddress: 0, isFastMode: self.isFastMode, listener: self.listener, ctrlCmd: self.ctrlCmd, reconnectScanFilter: nil)
                }
                
                try blockBle.disconnectPeripheral()
                
            }
            catch ErrorMsg.error(let msg){
                try? blockBle.disconnectPeripheral()
                DispatchQueue.main.async {
                    self.listener?.dfuStopWithError(errorMsg: msg);
                }
            }
            catch BlockingBleError.TimeOut(let msg){
                DispatchQueue.main.async {
                    self.listener?.dfuStopWithError(errorMsg: msg.isEmpty ? "communication timeout" : msg);
                }
            }
            catch BlockingBleError.DisConnect(let msg){
                DispatchQueue.main.async {
                    self.listener?.dfuStopWithError(errorMsg: msg.isEmpty ? "disconnect error" : msg);
                }
            }
            catch BlockingBleError.OtherError(let msg){
                DispatchQueue.main.async {
                    self.listener?.dfuStopWithError(errorMsg: msg.isEmpty ? "unknown other error" : msg);
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.listener?.dfuStopWithError(errorMsg: error.localizedDescription);
                }
            }
        }
        workThread!.name = "dfuThread"
        workThread!.start()
    }
    
    public func cancel(){
        if let thread = workThread {
            if (!thread.isCancelled){
                thread.cancel()
            }
        }
    }
}
