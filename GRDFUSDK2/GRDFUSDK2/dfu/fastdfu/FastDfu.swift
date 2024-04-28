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

public class FastDfu{
    private var workThread:Thread? = nil

    //配置参数
    private var listener:DfuListener? = nil
    private var log:ComxLogProtocol = PrintLogger()
    
    //配置函数
    public init(){}
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
    //任务函数
    private func launchDfu(central:CBCentralManager?, targetDevice: CBPeripheral, dfuMode:UInt32, dfuData:Data,address:UInt32, isExtFlash:Bool){
        workThread = Thread{
            let gr5xxxFastDfu: GR5xxxFastDfu = GR5xxxFastDfu()
            let blockBle = BlockingBLE()
            do{
                blockBle.setLog(log: self.log)
                try blockBle.initCentral(central)
                try blockBle.connectPeripheral(targetDevice: targetDevice)
                try blockBle.discoverServices()
                try gr5xxxFastDfu.bondTo(blockingBle: blockBle)
                
                try gr5xxxFastDfu.updateFwRes(dfuMode: dfuMode, dfuData: dfuData, address: address, extFlash: isExtFlash,listener: self.listener)
                
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
                    self.listener?.dfuStopWithError(errorMsg: msg);
                }
            }
            catch BlockingBleError.DisConnect(let msg){
                DispatchQueue.main.async {
                    self.listener?.dfuStopWithError(errorMsg: msg);
                }
            }
            catch BlockingBleError.OtherError(let msg){
                DispatchQueue.main.async {
                    self.listener?.dfuStopWithError(errorMsg: msg);
                }
            }
            catch {
                DispatchQueue.main.async {
                    self.listener?.dfuStopWithError(errorMsg: error.localizedDescription);
                }
            }
        }
        workThread?.name = "dfuThread"
        workThread?.start()
    }

    public func cancel(){
        if let thread = workThread {
            if (!thread.isCancelled){
                thread.cancel()
            }
        }
    }
}
