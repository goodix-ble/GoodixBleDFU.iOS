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
import UIKit

public typealias ScanFilter = (_ peripheral: CBPeripheral, _ advertisementData: [String : Any], _ rssi: NSNumber)->Bool;
public typealias RWProgressListener = (_ progress:Int)->Void;
public enum BlockingBleError:Error {// todo :comxerror
    case TimeOut(where:String)
    case DisConnect(where:String)
    case OtherError(msg:String)
}

open class BlockingBLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate{
    //数据区
    private var central:CBCentralManager? = nil;
    private var targetDevice:CBPeripheral? = nil;
    private var bufferPool = [CBCharacteristic : CmdBuffer]()
    
    //扫描相关数据
    private var scanFilter:ScanFilter? = nil;
    private var scanResultList = [(peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber)]();
    //服务发现相关数据
    private var serv_total:Int = 0
    private var serv_discovered:Int = 0
    private var char_total:Int = 0
    private var char_discovered:Int = 0
    private var desc_total:Int = 0
    private var desc_discovered:Int = 0
    //同步机制相关数据
    private var result:Result = Result()
    //其他数据
    private var log:ComxLogProtocol? = nil
    let PACKET_MAX_SIZE:Int = 244 //限制BLE发送的单个包的大小
    
    //操作函数：
    //设置log
    public func setLog(log:ComxLogProtocol?){
        self.log = log
    }
    //CBCentralManager初始化
    public func initCentral(_ existedMgr:CBCentralManager? = nil) throws {
        if let mgr = existedMgr {
            self.central = mgr;
            mgr.delegate = self;
        } else {
            self.central = CBCentralManager(delegate: self, queue: nil);
        }
        if self.central?.state == CBManagerState.poweredOn{
            return
        }else{
            let res = try result.waitResult(targetCodes: [Result.BLE_POWERON], timeout: 30_000)
            if res.resultCode == Result.BLE_POWERON{
                if res.resultSuccess{
                    return
                }else{
                    throw BlockingBleError.OtherError(msg: "initCentral: Bluetooth initialization failed.")// todo
                }
            }
        }
    }
    //扫描
    public func scanPeripherals(timeout: Int,filter:@escaping ScanFilter)throws -> CBPeripheral?{
        self.scanResultList.removeAll()
        self.scanFilter = filter
        self.central?.scanForPeripherals(withServices: nil);
        defer{
            self.central?.stopScan()
        }
        let res = try result.waitResult(targetCodes: [Result.TIMEOUT], timeout: timeout)
        if res.resultCode == Result.TIMEOUT && !self.scanResultList.isEmpty{
            self.central?.stopScan()
            var max_rssi:Int = self.scanResultList[0].rssi.intValue
            var out_peripheral:CBPeripheral? = self.scanResultList[0].peripheral
            for item in self.scanResultList{
                if item.rssi.intValue > max_rssi{
                    max_rssi = item.rssi.intValue
                    out_peripheral = item.peripheral
                }
            }
            self.scanResultList.removeAll()
            return out_peripheral
        }else{
            self.scanResultList.removeAll()
            return nil
        }
        
        
    }
    public func scanPeripheral(timeout: Int,filter:@escaping ScanFilter)throws -> CBPeripheral?{
        self.scanResultList.removeAll()
        self.scanFilter = filter
        self.central?.scanForPeripherals(withServices: nil);
        defer{
            self.central?.stopScan()
        }
        let res = try result.waitResult(targetCodes: [Result.DISCOVER_DEVICE], timeout: timeout,waiter: "scanPeripheral")
        if res.resultCode == Result.DISCOVER_DEVICE{
            if res.resultSuccess{
                if let out = res.resultData{
                    return out as? CBPeripheral
                }else{
                    return nil
                }
            }else{
                throw BlockingBleError.OtherError(msg: "scanPeripheral: Scan device failed.")
            }
        }else{
            return nil
        }
    }
    //连接
    public func connectPeripheral(targetDevice:CBPeripheral?)throws{
        if let bleManager = self.central{
            if let device = targetDevice{
                if let prvDev = self.targetDevice {
                    if prvDev.delegate === self {
                        prvDev.delegate = nil;
                    }
                }
                self.central = bleManager
                self.central!.delegate = self
                self.targetDevice = device
                self.targetDevice!.delegate = self
                bleManager.connect(device)
                //等待信号，超时时间3000毫秒
                let res = try result.waitResult(targetCodes: [Result.CONNECTED], timeout: 3000)
                if res.resultCode == Result.CONNECTED{
                    if res.resultSuccess{
                        return
                    }else{
                        throw BlockingBleError.OtherError(msg: "connectPeripheral: Connecting device failed.")
                    }
                }
            }else{
                throw BlockingBleError.OtherError(msg: "connectPeripheral: Parameter(CBPeripheral) is nil.")
            }
        }else{
            throw BlockingBleError.OtherError(msg: "connectPeripheral: Parameter(CBCentralManager) is nil.")
        }
    }
    public func connectPeripheral(timeout: Int, deviceName:String)throws{
        if let device = try scanPeripheral(timeout: timeout, filter: {(_ peripheral: CBPeripheral, _ advertisementData: [String : Any], _ rssi: NSNumber) -> Bool in
            if peripheral.name == deviceName{
                self.log?.d("BlockingBLE", "ScanFilter: peer_name = \(peripheral.name ?? "errorname")")
                return true
            }else{
                return false
            }
        }){
            try connectPeripheral(targetDevice: device)
        }
    }
    public func connectPeripheral(timeout: Int,filter:@escaping ScanFilter)throws{
        if let device = try scanPeripheral(timeout: timeout, filter: filter){
            try connectPeripheral(targetDevice: device)
        }else {
            throw BlockingBleError.OtherError(msg: "connectPeripheral: failed to scan device")
        }
    }
    //查询连接状态
    public func isConnected() -> Bool{
        if let device = self.targetDevice{
            return device.state == CBPeripheralState.connected
        }else{
            return false
        }
    }
    //断开
    public func disconnectPeripheral()throws{
        if let bleManager = self.central {
            if let device = self.targetDevice {
                if device.state != CBPeripheralState.disconnected {
                    bleManager.cancelPeripheralConnection(device);
                    // wait disconnected
                    let res = try result.waitResult(targetCodes: [Result.DISCONNECTED], timeout: 31_000)
                    if res.resultCode == Result.DISCONNECTED{
                        if !res.resultSuccess{
                            throw BlockingBleError.OtherError(msg: "disconnectPeripheral: Disconnect failed.")
                        }
                    }
                }
                //清理buffer
                for v in bufferPool.values{
                    if let chunk = v as? chunkBuffer{
                        chunk.clear()
                    }else if let stream = v as? streamBuffer{
                        stream.clear()
                    }
                }
                bufferPool.removeAll()
                if device.delegate === self {
                    device.delegate = nil;
                }
            }
        } else {
            throw BlockingBleError.OtherError(msg: "disconnectPeripheral: Parameter(CBCentralManager) is nil.");
        }
    }
    //设置mtu
    //设置连接间隔
    //发现服务
    public func discoverServices()throws{
        if let device = self.targetDevice {
            if device.state == CBPeripheralState.connected {
                //发现服务
                self.serv_total = 0
                self.serv_discovered = 0
                self.char_total = 0
                self.char_discovered = 0
                self.desc_total = 0
                self.desc_discovered = 0
                device.discoverServices(nil);
                let res = try result.waitResult(targetCodes: [Result.DISCOVERSERVICES], timeout: 10_000)
                if res.resultCode == Result.DISCOVERSERVICES{
                    if !res.resultSuccess{
                        throw BlockingBleError.OtherError(msg: "discoverServices: Service Discovery Failure.")
                    }
                    else{
                        if let services = self.targetDevice?.services{
                            self.log?.i("BlockingBLE", "fond services:")
                            for svc in services{
                                self.log?.i("BlockingBLE", "    s:\(svc.uuid)")
                                if let chars = svc.characteristics{
                                    for char in chars{
                                        self.log?.i("BlockingBLE", "        c:\(char.uuid)")
                                        if let descs = char.descriptors{
                                            for desc in descs{
                                                self.log?.i("BlockingBLE", "            d:\(desc.uuid)")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                throw BlockingBleError.OtherError(msg: "discoverServices: Device not connected.");
            }
            
        } else {
            throw BlockingBleError.OtherError(msg: "discoverServices: Parameter(CBPeripheral) is nil.");
        }
    }
    //查询服务
    public func queryServices(svcUUID:String?)throws -> [CBService]{//输入为nil时返回全部服务
        var outList = [CBService]()
        if let device = self.targetDevice{
            if device.state == CBPeripheralState.connected{
                if let svcList = device.services{
                    if let svcUuisString = svcUUID?.uppercased(){
                        for svc in svcList{
                            if svcUuisString == svc.uuid.uuidString{
                                outList.append(svc)
                            }
                        }
                    }else{
                        for svc in svcList{
                            outList.append(svc)
                        }
                    }
                }
            }else{
                throw BlockingBleError.OtherError(msg: "queryServices: Device not connected.");
            }
        }else{
            throw BlockingBleError.OtherError(msg: "queryServices: Parameter(CBPeripheral) is nil.");
        }
        return outList
    }
    //查询特性
    public func queryCharacteristic(service:CBService, chrUUID:String)throws -> [CBCharacteristic]{
        var outList = [CBCharacteristic]()
        if let device = self.targetDevice{
            if device.state == CBPeripheralState.connected{
                if let chrList = service.characteristics {
                    let chrUuidString = chrUUID.uppercased();
                    for chr in chrList {
                        if chrUuidString == chr.uuid.uuidString {
                            outList.append(chr);
                        }
                    }
                }
            }else{
                throw BlockingBleError.OtherError(msg: "queryCharacteristic: Device not connected.");
            }
        }else{
            throw BlockingBleError.OtherError(msg: "queryCharacteristic: Parameter(CBPeripheral) is nil.");
        }
        return outList
    }
    //打开/关闭：indicate、notify
    public func enableNotification(chr:CBCharacteristic, useStreamBuffer:Bool) throws {
        if let device = self.targetDevice {
            if device.state == CBPeripheralState.connected {
                device.setNotifyValue(true, for: chr);
                let res = try result.waitResult(targetCodes: [Result.SET_NOTIFY], timeout: 31_000)
                if res.resultCode == Result.SET_NOTIFY{
                    if !res.resultSuccess{
                        throw BlockingBleError.OtherError(msg: "enableNotification: Failed to open notify.")
                    }else{
                        if bufferPool[chr] == nil{
                            if useStreamBuffer{
                                bufferPool[chr] = streamBuffer(bufferCapacity: 8192)
                            }else{
                                bufferPool[chr] = chunkBuffer(bufferCapacity: 256)
                            }
                        }
                    }
                }else{
                    throw BlockingBleError.OtherError(msg: "enableNotification: The waitResult return value is abnormal.")
                }
            } else {
                throw BlockingBleError.OtherError(msg: "enableNotification: Device not connected.")
            }
        } else {
            throw BlockingBleError.OtherError(msg: "enableNotification: Parameter(CBPeripheral) is nil.")
        }
    }
    public func disableNotification(chr:CBCharacteristic) throws {
        if let device = self.targetDevice {
            if device.state == CBPeripheralState.connected {
                device.setNotifyValue(false, for: chr);
                let res = try result.waitResult(targetCodes: [Result.SET_NOTIFY], timeout: 31_000)
                if res.resultCode == Result.SET_NOTIFY{
                    if !res.resultSuccess{
                        throw BlockingBleError.OtherError(msg: "disableNotification: Failed to close notify.")
                    }
                }
            } else {
                throw BlockingBleError.OtherError(msg: "disableNotification: Device not connected.")
            }
        } else {
            throw BlockingBleError.OtherError(msg: "disableNotification: Parameter(CBPeripheral) is nil.")
        }
    }
    //特性写
    public func writeChrWithoutResponse(chr: CBCharacteristic, data: Data, listener: RWProgressListener? = nil)throws{
        try writeCharacteristic(chr: chr, data: data, type: CBCharacteristicWriteType.withoutResponse, listener: listener)
    }
    public func writeChrWithResponse(chr: CBCharacteristic, data: Data, listener: RWProgressListener? = nil)throws{
        try writeCharacteristic(chr: chr, data: data, type: CBCharacteristicWriteType.withResponse, listener: listener)
    }
    public func writeCharacteristic(chr:CBCharacteristic, data:Data, type: CBCharacteristicWriteType, listener: RWProgressListener?) throws {
        if let device = self.targetDevice {
            if device.state == CBPeripheralState.connected {
                let mtu = device.maximumWriteValueLength(for:type);
                var maxSegmentSize = mtu - 3;
                // xxx客户遇到的问题，mtu太大的时候，SetImageInfoList命令有问题。
                if maxSegmentSize > PACKET_MAX_SIZE {
                    maxSegmentSize = PACKET_MAX_SIZE
                }
                let dataLength = data.count;
                var dataPos = 0;
                while dataPos < dataLength{
                    //取一帧数据
                    var frameLength = 0
                    if dataPos+maxSegmentSize < dataLength{
                        frameLength = maxSegmentSize
                    }else{
                        frameLength = dataLength - dataPos
                    }
                    var frame = Data(count: frameLength) // todo
                    for i in 0..<frameLength{
                        frame[i] = data[dataPos+i]
                    }
                    //发送数据
                    let hexString = frame.map{String(format: "%02hhx", $0)}.joined()
                    device.writeValue(frame, for: chr, type: type);
                    if type == CBCharacteristicWriteType.withResponse{
                        let res = try result.waitResult(targetCodes: [Result.WRITE_CHAR], timeout: 1_000)
                        if res.resultCode == Result.WRITE_CHAR{
                            if !res.resultSuccess{
                                throw BlockingBleError.OtherError(msg: "writeCharacteristic: Writing Characteristic failed.")
                            }else{
                                self.log?.i("BlockingBLE", "writeCharacteristic[\(chr.uuid)][withResponse]: [\(frame.count)]")
                                self.log?.d("BlockingBLE", "writeCharacteristic[\(chr.uuid)][withResponse]: [\(frame.count)]: \(hexString)")
                            }
                        }
                    }else if type == CBCharacteristicWriteType.withoutResponse{
                        let res = try result.waitResult(targetCodes: [Result.WRITE_CHAR,Result.TIMEOUT], timeout: 100)
                        if res.resultCode == Result.WRITE_CHAR{
                            if !res.resultSuccess{
                                throw BlockingBleError.OtherError(msg: "writeCharacteristic: Writing Characteristic failed.")
                            }else{
                                self.log?.i("BlockingBLE", "writeCharacteristic[\(chr.uuid)][withoutResponse]: [\(frame.count)]")
                                self.log?.d("BlockingBLE", "writeCharacteristic[\(chr.uuid)][withoutResponse]: [\(frame.count)]: \(hexString)")
                            }
                        } else if res.resultCode == Result.TIMEOUT{
                            let values = UIDevice.current.systemVersion.components(separatedBy: ".")
                            if values.count >= 2{
                                let version:Double = Double(values[0])! + Double(values[1])!*0.1
                                if version < 11.0{
                                    self.log?.i("BlockingBLE", "writeCharacteristic[\(chr.uuid)][withoutResponse]: [\(frame.count)]")
                                    self.log?.d("BlockingBLE", "writeCharacteristic[\(chr.uuid)][withoutResponse]: [\(frame.count)]: \(hexString)")
                                    self.log?.w("BlockingBLE", "writeCharacteristic[\(chr.uuid)][withoutResponse]: Perhaps \(frame.count) bytes of data were lost")
                                }
                            }
                        }
                    }
                    dataPos += frameLength
                    if let rwlistener = listener{
                        rwlistener(Int(Float(dataPos*100)/Float(dataLength)))
                    }
                }
            } else {
                throw BlockingBleError.OtherError(msg: "Not connected.");
            }
        } else {
            throw BlockingBleError.OtherError(msg: "Parameter(CBPeripheral) is nil.");
        }
    }
    //特性读notify
    public func readNotification(chr:CBCharacteristic, byteCount:Int, timeoutMS:Int) throws -> Data {
        if let device = self.targetDevice {
            if device.state == CBPeripheralState.connected {
                if let stream = bufferPool[chr]{
                    if let buf = stream as? streamBuffer{
                        if let array = buf.read(length: byteCount, timeout: timeoutMS){
                            return Data(array)
                        }else{
                            throw BlockingBleError.TimeOut(where: "readNotification: Timeout")
                        }
                    }else{
                        throw BlockingBleError.OtherError(msg: "readNotification: Buffer type is error.")
                    }
                }else{
                    throw BlockingBleError.OtherError(msg: "readNotification: Parameter(buffer) is nil.")
                }
            } else {
                throw BlockingBleError.OtherError(msg: "readNotification: Device not connected.");
            }
        } else {
            throw BlockingBleError.OtherError(msg: "readNotification: Parameter(CBPeripheral) is nil.");
        }
    }
    public func readNotificationByChunk(chr:CBCharacteristic, timeoutMS:Int) throws -> Data {
        if let device = self.targetDevice {
            if device.state == CBPeripheralState.connected {
                if let stream = bufferPool[chr]{
                    if let buf = stream as? chunkBuffer{
                        if let array = buf.read(timeout: timeoutMS){
                            return Data(array)
                        }else{
                            throw BlockingBleError.TimeOut(where: "readNotificationByChunk: Timeout")
                        }
                    }else{
                        throw BlockingBleError.OtherError(msg: "readNotificationByChunk: Buffer type is error.")
                    }
                }else{
                    throw BlockingBleError.OtherError(msg: "readNotificationByChunk: Parameter(buffer) is nil.")
                }
            } else {
                throw BlockingBleError.OtherError(msg: "readNotification: Device not connected.");
            }
        } else {
            throw BlockingBleError.OtherError(msg: "readNotification: Parameter(CBPeripheral) is nil.");
        }
    }
    //描述符操作函数*
    
    //回调函数区
    //centralManager回调
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.log?.i("BlockingBLE", "centralManagerDidUpdateState:\(central.state)")
        result.sendResult(resultCode: Result.BLE_POWERON, resultSuccess: central.state == CBManagerState.poweredOn, resultData: nil)
    }
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.log?.i("BlockingBLE", "didConnect:\(String(describing: peripheral.name))")
        result.sendResult(resultCode: Result.CONNECTED, resultSuccess: true, resultData: peripheral)
    }
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if error == nil{
            self.log?.i("BlockingBLE", "didFailToConnect:\(String(describing: peripheral.name))")
            result.sendResult(resultCode: Result.CONNECTED, resultSuccess: false, resultData: error)
        }else{
            self.log?.i("BlockingBLE", "didFailToConnect:\(String(describing: peripheral.name))")
            result.sendResult(resultCode: Result.CONNECTED, resultSuccess: false, resultData: error)
        }
    }
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error == nil{
            self.log?.i("BlockingBLE", "didDisconnectPeripheral:\(String(describing: peripheral.name))")
            result.sendResult(resultCode: Result.DISCONNECTED, resultSuccess: true, resultData: nil)
        }else{
            self.log?.e("BlockingBLE", "didDisconnectPeripheral:\(error?.localizedDescription ?? "error")")
            result.sendResult(resultCode: Result.DISCONNECTED, resultSuccess: false, resultData: error)
        }
    }
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.log?.v("BlockingBLE", "didDiscoverPeripheral:\(String(describing: peripheral.name))-\(peripheral.identifier)")
        if let filter = scanFilter{
            if filter(peripheral, advertisementData, RSSI){
                self.scanResultList.append((peripheral, advertisementData, RSSI))
                result.sendResult(resultCode: Result.DISCOVER_DEVICE, resultSuccess: true, resultData: peripheral)
            }
        }else{
            self.scanResultList.append((peripheral, advertisementData, RSSI))
        }
    }
    
    //peripheral回调
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error == nil{
            if let services = peripheral.services{
                if services.isEmpty{
                    result.sendResult(resultCode: Result.DISCOVERSERVICES, resultSuccess: true, resultData: peripheral)
                }else{
                    self.serv_total = services.count
                    for svc in services {
                        peripheral.discoverCharacteristics(nil, for: svc);
                    }
                }
            }
        }else{
            self.log?.e("BlockingBLE", "didDiscoverServices:\(error?.localizedDescription ?? "error")")
            result.sendResult(resultCode: Result.DISCOVERSERVICES, resultSuccess: false, resultData: error)
        }
    }
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error == nil{
            self.serv_discovered += 1
            if self.serv_total == self.serv_discovered{
                if let services = peripheral.services{
                    for svs in services{
                        if let chars = svs.characteristics{
                            self.char_total += chars.count
                            for char in chars{
                                peripheral.discoverDescriptors(for: char)
                            }
                        }
                    }
                }
            }
        }else{
            self.log?.e("BlockingBLE", "didDiscoverCharacteristicsFor:\(error?.localizedDescription ?? "error")")
            result.sendResult(resultCode: Result.DISCOVERSERVICES, resultSuccess: false, resultData: error)
        }
    }
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil{
            self.char_discovered += 1
            if self.char_total == self.char_discovered{
                result.sendResult(resultCode: Result.DISCOVERSERVICES, resultSuccess: true, resultData: peripheral)
            }
        }else{
            self.log?.e("BlockingBLE", "didDiscoverDescriptorsFor:\(error?.localizedDescription ?? "error")")
            result.sendResult(resultCode: Result.DISCOVERSERVICES, resultSuccess: false, resultData: error)
        }
    }
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil{
            self.log?.i("BlockingBLE", "didUpdateNotificationStateFor: characteristic[\(characteristic.uuid)].isNotifying = \(characteristic.isNotifying)")
            result.sendResult(resultCode: Result.SET_NOTIFY, resultSuccess: true, resultData: characteristic)
        }else{
            self.log?.e("BlockingBLE", "didUpdateNotificationStateFor:\(error?.localizedDescription ?? "error")")
            result.sendResult(resultCode: Result.SET_NOTIFY, resultSuccess: false, resultData: error)
        }
    }
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil{
            if let value = characteristic.value {
                let hexString = value.map{String(format: "%02hhx", $0)}.joined()
                self.log?.i("BlockingBLE", "didUpdateValueFor: [\(value.count)]")
                self.log?.d("BlockingBLE", "didUpdateValueFor: [\(value.count)]: \(hexString)")
                if let buff = bufferPool[characteristic] {
                    if let stream = buff as? streamBuffer{
                        if !stream.write(data: value){
                            self.log?.w("BlockingBLE", "didUpdateValueFor: \(value.count) byte data enqueue failed!")
                        }
                    }
                    else if let chunk = buff as? chunkBuffer{
                        if !chunk.write(data: value){
                            self.log?.w("BlockingBLE", "didUpdateValueFor: \(value.count) byte data enqueue failed!")
                        }
                    }
                }
            }
        }else{
            self.log?.e("BlockingBLE", "didUpdateValueFor:\(error?.localizedDescription ?? "error")")
        }
    }
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil{
            self.log?.d("BlockingBLE", "didWriteValueFor:\(String(describing: characteristic.value))")
            result.sendResult(resultCode: Result.WRITE_CHAR, resultSuccess: true, resultData: nil)
        }else{
            self.log?.e("BlockingBLE", "didWriteValueFor:\(error?.localizedDescription ?? "error")")
            result.sendResult(resultCode: Result.WRITE_CHAR, resultSuccess: false, resultData: error)
        }
    }
    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        self.log?.v("BlockingBLE", "peripheralIsReady:\(peripheral.canSendWriteWithoutResponse)")
        result.sendResult(resultCode: Result.WRITE_CHAR, resultSuccess: true, resultData: peripheral)
    }
    
    //tool
    private class Result{
        public static let TIMEOUT:Int = 100
        public static let BLE_POWERON:Int = 101
        public static let CONNECTED:Int = 102
        public static let DISCONNECTED:Int = 103
        public static let DISCOVERSERVICES:Int = 104
        public static let SET_NOTIFY:Int = 105
        public static let WRITE_CHAR:Int = 106
        public static let DISCOVER_DEVICE:Int = 107
        
        private var condition:NSCondition = NSCondition()
        private var aimCodes:[Int] = [];
        private var resultCode:Int = 0;
        private var resultSuccess:Bool = false;
        private var resultData:Any? = nil;
        
        public func waitResult(targetCodes:[Int], timeout:Int, waiter:String="")throws -> (resultCode:Int, resultSuccess:Bool, resultData:Any?){
            condition.lock()
            self.aimCodes = targetCodes
            self.resultCode = 0
            self.resultSuccess = false
            self.resultData = nil
            if condition.wait(until: Date(timeIntervalSinceNow: Double(timeout)/1000.0)){
                self.aimCodes = []
                condition.unlock()
                if self.resultCode==Result.DISCONNECTED && !targetCodes.contains(Result.DISCONNECTED){
                    throw BlockingBleError.DisConnect(where: waiter)
                }
                return (resultCode,resultSuccess,resultData)
            }else{
                self.aimCodes = []
                condition.unlock()
                if targetCodes.contains(Result.TIMEOUT){
                    return (Result.TIMEOUT,true,nil)
                }else{
                    throw BlockingBleError.TimeOut(where: waiter)
                }
            }
        }
        public func sendResult(resultCode:Int, resultSuccess:Bool, resultData:Any?){
            if self.aimCodes.contains(resultCode) || resultCode == Result.DISCONNECTED{
                condition.lock()
                self.resultCode = resultCode
                self.resultSuccess = resultSuccess
                self.resultData = resultData
                condition.signal()
                condition.unlock()
            }
        }
    }
    class ArrayBlockingQueue<T>{
        private var queueArray: [T?]
        private var queueCapacity: Int
        private var takeIndex = 0
        private var putIndex = 0
        private let lock = NSLock()
        private var objSemaphore:DispatchSemaphore?
        private var emptySemaphore:DispatchSemaphore?
        
        init(_ queueCapacity: Int) {
            self.putIndex = 0
            self.takeIndex = 0
            self.queueArray = [T?](repeating: nil, count: queueCapacity)
            self.queueCapacity = queueCapacity
            self.objSemaphore = DispatchSemaphore(value: 0)
            self.emptySemaphore = DispatchSemaphore(value: queueCapacity)
        }
        public func put(_ item: T, timeout: Int) -> Bool{
            let timeoutResult = emptySemaphore?.wait(timeout: .now() + .milliseconds(timeout))
            if timeoutResult == .success{
                lock.lock()
                if isNotFull(){
                    enqueue(item)
                    objSemaphore?.signal()
                    lock.unlock()
                    return true
                }else{
                    lock.unlock()
                    return false
                }
            }else{
                return false
            }
        }
        
        public func take(timeout: Int) -> T?{
            let timeoutResult = objSemaphore?.wait(timeout: .now() + .milliseconds(timeout)) // todo 中断
            if timeoutResult == .success{
                lock.lock()
                if isNotEmpty(){
                    let res:T = dequeue()
                    emptySemaphore?.signal()
                    lock.unlock()
                    return res
                }else{
                    lock.unlock()
                    return nil
                }
            }else{
                return nil
            }
        }
        
        public func clear(){
            lock.lock()
            
            for i in 0..<queueArray.count{
                queueArray[i] = nil
            }
            self.putIndex = 0
            self.takeIndex = 0
            self.queueArray = Array<T?>(repeating: nil, count: queueCapacity)
            self.objSemaphore = DispatchSemaphore(value: 0)
            self.emptySemaphore = DispatchSemaphore(value: queueCapacity) // todo
            lock.unlock()
        }
        
        private func enqueue(_ item: T){
            queueArray[putIndex] = item
            putIndex = (putIndex + 1) % queueCapacity
        }
        
        private func dequeue() -> T{
            let item = queueArray[takeIndex]
            queueArray[takeIndex] = nil
            takeIndex = (takeIndex + 1) % queueCapacity
            return item!
        }
        
        private func isNotEmpty() -> Bool{
            return takeIndex != putIndex || queueArray[takeIndex] != nil
        }
        
        private func isNotFull() -> Bool{
            return (putIndex + 1) % queueCapacity != takeIndex
        }
    }
    class CmdBuffer{
        private let bufferType: Int //0-streamBuffer 1-chunkBuffer
        init(bufferType: Int) {
            self.bufferType = bufferType
        }
        public func getBufferType() -> Int{
            return bufferType
        }
    }
    class chunkBuffer:CmdBuffer{
        private let buffer:ArrayBlockingQueue<Data>
        
        init(bufferCapacity:Int) {
            self.buffer = ArrayBlockingQueue(bufferCapacity)
            super.init(bufferType: 1)
        }
        public func write(data:Data) -> Bool{
            return buffer.put(data, timeout: 2000)
        }
        public func read(timeout:Int) -> Data?{
            if let data:Data = buffer.take(timeout: timeout){
                return data
            }else{
                return nil
            }
        }
        public func clear(){
            buffer.clear()
        }
    }
    class streamBuffer:CmdBuffer{
        private let buffer:ArrayBlockingQueue<UInt8>
        
        init(bufferCapacity:Int) {
            self.buffer = ArrayBlockingQueue(bufferCapacity)
            super.init(bufferType: 0)
        }
        public func write(data:Data) -> Bool{ // todo data
            for item in data{
                if !buffer.put(item, timeout: 2000){
                    return false
                }
            }
            return true
        }
        public func read(length:Int, timeout:Int) -> Data?{
            if length <= 0 {
                return nil
            }
            var out:Data = Data()//todo Data
            for _ in 1...length{
                if let res = buffer.take(timeout: timeout){
                    out.append(res)
                }else{
                    return nil
                }
            }
            return out
        }
        public func clear(){
            buffer.clear()
        }
    }
}
