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

public class GR5xxxDFU2: DfuProfile2{
    private var log:ComxLogProtocol? = nil
    
    //设置log
    public func setLog(log:ComxLogProtocol?){
        self.log = log
    }
    //子任务
    //通用子任务
    public func getChipInfo() throws -> GetChipInfoRes{
        self.log?.d("GR5xxxDFU2", "getChipInfo: start")
        let res: GetChipInfoRes  = GetChipInfoRes()
        
        let cmd_code: UInt32 = CmdCode.GET_INFO
        //编码+发送
        let cmd = HexHandler(4)
        cmd.put(size: 2, uint32: cmd_code)
        cmd.put(size: 2, uint32: 0)
        try sendCmd(param: cmd.buffer)
        //接收+解码
        let recvCmd = try recvCmd(opcode: cmd_code)
        let data = HexHandler(copy: recvCmd)
        data.pos = 4
        let resp = data.get(size: 1)
        if resp != 1{
            throw ErrorMsg.error(msg: "getChipInfo: Command response error.")
        }
        
        data.pos = 9
        let stackSvnNum = UInt32(data.get(size: 4))
        
        if data.buffer.count >= 22{
            data.pos = 21
            res.dfuVersion = UInt32(data.get(size: 1))
        }else{
            res.dfuVersion = 0
        }
        
        switch(stackSvnNum){
        case 0x00001EA8:
            fallthrough
        case 0x00000B88:
            res.scaStartAddress = 0x01000000
        case 0xCA0F33C7:
            fallthrough
        case 0xF83A64D9:
            fallthrough
        case 0x00354083:
            res.scaStartAddress = 0x00200000
        default:
            res.scaStartAddress = 0x00200000
        }
        return res
    }
    public func getBootInfo(scaStartAddress: UInt32) throws -> GetBootInfoRes{
        self.log?.d("GR5xxxDFU2", "getBootInfo: start")
        let res: GetBootInfoRes  = GetBootInfoRes()
        
        let cmd_code: UInt32 = CmdCode.SYSTEM_COMFIG
        //编码+发送
        let cmd = HexHandler(7+4)
        cmd.put(size: 2, uint32: cmd_code)
        cmd.put(size: 2, uint32: 7)
        cmd.put(size: 1, uint32: 0)
        cmd.put(size: 4, uint32: scaStartAddress)
        cmd.put(size: 2, uint32: 24)
        try sendCmd(param: cmd.buffer)
        //接收+解码
        let recvCmd = try recvCmd(opcode: cmd_code)
        let data = HexHandler(copy: recvCmd)
        data.pos = 4
        let resp = data.get(size: 1)
        if resp != 1{
            throw ErrorMsg.error(msg: "getBootInfo: Command response error.")
        }

        let op = data.get(size: 1)
        let addr = data.get(size: 4)
        let len = data.get(size: 2)
        if (addr != scaStartAddress){
            throw ErrorMsg.error(msg: "getBootInfo: unexpected address")
        }
        if (len != 24){
            throw ErrorMsg.error(msg: "getBootInfo: unexpected data length")
        }
        res.peerEncrypted = ((op & 0xf0) != 0x00)

        data.pos=12
        res.bootInfo = Imginfo(data: data.getData(size: 24))
        
        return res
    }
    public func getExtraInfo() throws -> GetExtraInfoRes{
        self.log?.d("GR5xxxDFU2", "getExtraInfo: start")
        let res: GetExtraInfoRes  = GetExtraInfoRes()
        
        let cmd_code: UInt32 = CmdCode.GET_FW_INFO
        //编码+发送
        let cmd = HexHandler(0+4)
        cmd.put(size: 2, uint32: cmd_code)
        cmd.put(size: 2, uint32: 0)
        try sendCmd(param: cmd.buffer)
        //接收+解码
        let recvCmd = try recvCmd(opcode: cmd_code)
        let data = HexHandler(copy: recvCmd)
        data.pos = 4
        let resp = data.get(size: 1)
        if resp != 1{
            throw ErrorMsg.error(msg: "getExtraInfo: Command response error.")
        }
        
        data.pos = 5
        res.commendSaveAddress = UInt32(data.get(size: 4))
        res.position = UInt32(data.get(size: 1))
        res.appInfo = Imginfo(data: data.getData(size: 48))
        
        return res
    }
    public func getImgList(scaStartAddress:UInt32) throws -> GetImgListRes{
        self.log?.d("GR5xxxDFU2", "getImgList: start")
        let res: GetImgListRes  = GetImgListRes()
        
        let cmd_code: UInt32 = CmdCode.SYSTEM_COMFIG
        //编码+发送
        let cmd = HexHandler(7+4)
        cmd.put(size: 2, uint32: cmd_code)
        cmd.put(size: 2, uint32: 7)
        cmd.put(size: 1, uint32: 0)
        cmd.put(size: 4, uint32: scaStartAddress+64)
        cmd.put(size: 2, uint32: 400)
        try sendCmd(param: cmd.buffer)
        //接收+解码
        let recvCmd = try recvCmd(opcode: cmd_code)
        let data = HexHandler(copy: recvCmd)
        data.pos = 4
        let resp = data.get(size: 1)
        if resp != 1{
            throw ErrorMsg.error(msg: "getImgList: Command response error.")
        }
#if true
        let op = data.get(size: 1)
        let addr = data.get(size: 4)
        if (addr != (scaStartAddress + 0x40)){
            throw ErrorMsg.error(msg: "getImgList: unexpected address")
        }
        res.peerEncrypted = ((op & 0xf0) != 0x00)
#endif
        
        data.pos=10
        let len = data.get(size: 2)
        if len != 400{
            throw ErrorMsg.error(msg: "getImgList: Command response error.")
        }
        
        data.pos=12
        res.imgList = Imginfo.getImgList(data: data.getData(size: 400))
        return res
    }
    public func tidyImgList(targetBootInfo:Imginfo, bootInfo:Imginfo, imgList:[Imginfo], scaStartAddress:UInt32) throws{
        self.log?.d("GR5xxxDFU2", "tidyImgList: start")
        if imgList.isEmpty{
            return
        }
        let targetAreaStartAddress: UInt32 = targetBootInfo.loadAddr
        let targetAreaSize: UInt32 = targetBootInfo.appSize+48+856
        
        var newImgList:[Imginfo] = []
        var bootInfoInImgList:Bool = false
        for imgInfo in imgList{
            if !MemoryArea.memoryOverlap(imgInfo.loadAddr, imgInfo.appSize+48+856, targetAreaStartAddress, targetAreaSize)
            {
                newImgList.append(imgInfo)
            }
            if imgInfo.checksum == bootInfo.checksum{
                bootInfoInImgList = true
            }
        }
        if !bootInfoInImgList{
            if !MemoryArea.memoryOverlap(bootInfo.loadAddr, bootInfo.appSize+48+856, targetAreaStartAddress, targetAreaSize)
            {
                newImgList.append(bootInfo)
            }
        }
        
        if newImgList.count != imgList.count+(bootInfoInImgList ? 0 : 1){
            
            let cmd_code: UInt32 = CmdCode.SYSTEM_COMFIG
            //编码+发送
            let cmd = HexHandler(407+4)
            cmd.put(size: 2, uint32: cmd_code)
            cmd.put(size: 2, uint32: 407)
            cmd.put(size: 1, uint32: 0x01)
            cmd.put(size: 4, uint32: scaStartAddress+64)
            cmd.put(size: 2, uint32: 400)
            for imgInfo in newImgList{
                let info = imgInfo.serialize()
                cmd.put(size: info.count, data: info)
            }
            let temp:Data = Data(repeating: 0xff, count: 40)
            var n = 10 - newImgList.count
            while n>0 {
                cmd.put(size: 40, data: temp)
                n -= 1
            }
            try sendCmd(param: cmd.buffer)
            //接收+解码
            let recvCmd = try recvCmd(opcode: cmd_code)
            let data = HexHandler(copy: recvCmd)
            data.pos = 4
            let resp = data.get(size: 1)
            if resp != 1{
                throw ErrorMsg.error(msg: "tidyImgList: Command response error.")
            }
        }
    }
    
    //dfu相关子任务
    public func writeCtrPoint(ctrCmd:Data?) throws{
        self.log?.d("GR5xxxDFU2", "writeCtrPoint: start")
        if let data = ctrCmd{
            try sendCtrl(ctrlData: data)
        }
    }
    public func setDfuEnter() throws{
        self.log?.d("GR5xxxDFU2", "setDfuEnter: start")
        let cmd = HexHandler(4)
        cmd.put(size: 4, uint32: 0x474f4f44)
        try sendCtrl(ctrlData: cmd.buffer)
    }
    public func setDfuMode(dfuMode:Int) throws{
        self.log?.d("GR5xxxDFU2", "setDfuMode: start")
        let cmd_code: UInt32 = CmdCode.SET_DFU_MODE
        if dfuMode == 0 || dfuMode == 1{
            //编码+发送
            let cmd = HexHandler(1+4)
            cmd.put(size: 2, uint32: cmd_code)
            cmd.put(size: 2, uint32: 1)
            if dfuMode == 0{
                cmd.put(size: 1, uint32: 0x02)
            }else if dfuMode == 1{
                cmd.put(size: 1, uint32: 0x01)
            }
            try sendCmd(param: cmd.buffer)
        }
    }
    public func programStart(dfuMode:Int, dfuFw:FirmwareAndResource, address:UInt32, isExFlash:Bool, dfuVersion: UInt32 = 0x00) throws{// todo
        self.log?.d("GR5xxxDFU2", "programStart: start")
        let cmd_code: UInt32 = CmdCode.PROGRAM_START
        let cmdLength = dfuMode == 2 ? 9 : 41 // todo dfuMode enum
        //编码+发送
        let cmd = HexHandler(cmdLength+4)
        cmd.put(size: 2, uint32: cmd_code)
        cmd.put(size: 2, uint32: UInt32(cmdLength))
        if dfuMode == 2{
            cmd.put(size: 1, uint32: isExFlash ? 0x01 : 0x00)
            cmd.put(size: 4, uint32: address)
            cmd.put(size: 4, uint32: UInt32(dfuFw.frData!.count))
        }
        else if(dfuMode == 0 || dfuMode == 1){
            if dfuFw.isFirmware{
                var byte_6: UInt32 = 0
                byte_6 = isExFlash ? 0x01 : 0x00
                if (dfuVersion >= 0x02){
                    byte_6 |= dfuFw.fwEncryptAndSignState << 4
                }
                cmd.put(size: 1, uint32: byte_6)
                if dfuMode == 0{
                    cmd.put(size: 40, data: dfuFw.fwbootInfo!.serialize())
                }else{
                    let newImginfo: Imginfo = dfuFw.fwbootInfo!.clone()
                    newImginfo.loadAddr = address
                    cmd.put(size: 40, data: newImginfo.serialize())
                }
            }else{
                throw ErrorMsg.error(msg: "programStart: The incoming data is not firmware and cannot be used for DFU.")
            }
        }else{
            throw ErrorMsg.error(msg: "programStart: dfuMode value is error.")
        }
        try sendCmd(param: cmd.buffer)
        //接收+解码
        let recvCmd = try recvCmd(opcode: cmd_code)
        let data = HexHandler(copy: recvCmd)
        data.pos = 4
        let resp = data.get(size: 1)
        if resp != 1{
            throw ErrorMsg.error(msg: "programStart: Command response error.")
        }
    }
    public func programStartFast(dfuMode:Int, dfuFw:FirmwareAndResource, address:UInt32, isExFlash:Bool, dfuVersion: UInt32 = 0x00) throws{
        self.log?.d("GR5xxxDFU2", "programStartFast: start")
        let cmd_code: UInt32 = CmdCode.PROGRAM_START
        let cmdLength = dfuMode == 2 ? 9 : 41
        //编码+发送
        let cmd = HexHandler(cmdLength+4)
        cmd.put(size: 2, uint32: cmd_code)
        cmd.put(size: 2, uint32: UInt32(cmdLength))
        if dfuMode == 2{
            cmd.put(size: 1, uint32: isExFlash ? 0x03 : 0x02)
            cmd.put(size: 4, uint32: address)
            cmd.put(size: 4, uint32: UInt32(dfuFw.frData!.count))
        }
        else if(dfuMode == 0 || dfuMode == 1){
            var byte_6: UInt32 = 0
            byte_6 = isExFlash ? 0x03 : 0x02
            if (dfuVersion >= 0x02){
                byte_6 |= dfuFw.fwEncryptAndSignState << 4
            }
            cmd.put(size: 1, uint32: byte_6)
            if dfuMode == 0{
                cmd.put(size: 40, data: dfuFw.fwbootInfo!.serialize())
            }
            else{
                let newImginfo: Imginfo = dfuFw.fwbootInfo!.clone()
                newImginfo.loadAddr = address
                cmd.put(size: 40, data: newImginfo.serialize())
            }
        }
        try sendCmd(param: cmd.buffer)
        //接收+解码
        while true{
            let recvCmd = try recvCmd(opcode: cmd_code)
            let data = HexHandler(copy: recvCmd)
            data.pos = 4
            let resp = data.get(size: 1)
            if resp != 1{
                throw ErrorMsg.error(msg: "sendCmd: Command response error.")
            }
            
            data.pos = 5
            let state = data.get(size: 1)
            switch state{
            case 0x00:
                throw ErrorMsg.error(msg: "sendCmd: The starting address of the flash to be erased is not 4K aligned.")
            case 0x01:
                self.log?.d("GR5xxxDFU2", "programStartFast: Start Erasing.")
            case 0x02:
                self.log?.d("GR5xxxDFU2", "programStartFast: Erasing:" + String(data.get(size: 2)))
            case 0x03:
                self.log?.d("GR5xxxDFU2", "programStartFast: Complete Erase.")
                return
            case 0x04:
                throw ErrorMsg.error(msg: "sendCmd: The erase area overlaps with the current running firmware area.")
            case 0x05:
                throw ErrorMsg.error(msg: "sendCmd: Erase failed.")
            case 0x06:
                throw ErrorMsg.error(msg: "sendCmd: The area to be erased does not exist.")
            default:
                throw ErrorMsg.error(msg: "sendCmd: error code："+String(state))
            }
        }
    }
    public func programFlash(dfuMode:Int, dfuFw:FirmwareAndResource, address:UInt32, isExFlash:Bool, listener:RWProgressListener? = nil) throws {
        self.log?.d("GR5xxxDFU2", "programFlash: start")
        let cmd_code: UInt32 = CmdCode.PROGRAM_FLASH
        var dataWritePos:UInt32 = 0
        while dataWritePos < dfuFw.frData!.count{
            var startAddressInFlash: UInt32 = 0
            switch dfuMode{
            case 0:
                startAddressInFlash = dataWritePos + dfuFw.fwbootInfo!.loadAddr
            case 1:
                startAddressInFlash = dataWritePos + address
            case 2:
                startAddressInFlash = dataWritePos + address
            default:
                throw ErrorMsg.error(msg: "programFlash: error dfuMode")
            }
            var writeLength: UInt32 = 1024
            if UInt32(dfuFw.frData!.count) - dataWritePos < 1024{
                writeLength = UInt32(dfuFw.frData!.count) - dataWritePos
            }
            
            let cmdLength: Int = Int(7 + writeLength)
            //编码+发送
            let cmd = HexHandler(cmdLength+4)
            cmd.put(size: 2, uint32: cmd_code)
            cmd.put(size: 2, uint32: UInt32(cmdLength))
            let byte_4 = isExFlash ? 0x11 : 0x01
            cmd.put(size: 1, uint32: UInt32(byte_4))
            cmd.put(size: 4, uint32: startAddressInFlash)
            cmd.put(size: 2, uint32: writeLength)
            cmd.put(size: Int(writeLength), data: dfuFw.frData, fromStartPos: Int(dataWritePos))
            try sendCmd(param: cmd.buffer)
            //接收+解码
            let recvCmd = try recvCmd(opcode: cmd_code)
            let data = HexHandler(copy: recvCmd)
            data.pos = 4
            let resp = data.get(size: 1)
            if resp != 1{
                throw ErrorMsg.error(msg: "programFlash: Command response error.")
            }
            dataWritePos += writeLength
            if let rwlistener = listener{
                rwlistener(Int(Float(dataWritePos*100)/Float(dfuFw.frData!.count)))
            }
        }
    }
    public func programFlashFast(dfuFw:FirmwareAndResource, listener:RWProgressListener? = nil) throws{
        self.log?.d("GR5xxxDFU2", "programFlashFast: start")
        let cmd_code: UInt32 = CmdCode.PROGRAM_FLASH_FAST
        //编码+发送
        let cmd = HexHandler(dfuFw.frData!.count)
        cmd.put(size: dfuFw.frData!.count, data: dfuFw.frData)
        try sendCmd(param: cmd.buffer, needPack: false,listener: listener)
        //接收+解码
        let recvCmd = try recvCmd(opcode: cmd_code)
        let data = HexHandler(copy: recvCmd)
        data.pos = 4
        let resp = data.get(size: 1)
        if resp != 1{
            throw ErrorMsg.error(msg: "programFlashFast: Command response error.")
        }
    }
    public func programEnd(dfuMode:Int, dfuFw:FirmwareAndResource, dfuVersion:Int, isExFlash:Bool, isFastMode:Bool) throws{
        self.log?.d("GR5xxxDFU2", "programEnd: start")
        let cmd_code: UInt32 = CmdCode.PROGRAM_END
        let cmdLength: UInt32 = 5
        //编码+发送
        let cmd = HexHandler(Int(cmdLength+4))
        cmd.put(size: 2, uint32: cmd_code)
        cmd.put(size: 2, uint32: cmdLength)
        if dfuMode == 2{
            cmd.put(size: 1, uint32: (isExFlash ? 0x12 : 0x02))
        }
        else if dfuMode == 0 || dfuMode == 1{
            cmd.put(size: 1, uint32: 0x01)
        }
        cmd.put(size: 4, uint32: dfuFw.frDataChecksum)
        try sendCmd(param: cmd.buffer)
        //接收+解码
        var receiveCmd:Data? = nil
        do{
            receiveCmd = try recvCmd(opcode: cmd_code)
        }catch BlockingBleError.TimeOut(_){
            return
        }
        
        if let recvCmd = receiveCmd{
            let data = HexHandler(copy: recvCmd)
            data.pos = 4
            let resp = data.get(size: 1)
            if resp != 1{
                throw ErrorMsg.error(msg: "programEnd: Command response error.")
            }
            
            if isFastMode && dfuVersion>=2{
                if recvCmd.count < 9{
                    throw ErrorMsg.error(msg: "programEnd: Command response error.")
                }
                data.pos = 5
                let checksum: UInt32 = UInt32(data.get(size: 4))
                if checksum == dfuFw.frDataChecksum{
                    return
                }
                else{
                    throw ErrorMsg.error(msg: "programEnd: Checksum verification error："+String(checksum)+"!="+String(dfuFw.frDataChecksum))
                }
            }
        }else{
            throw ErrorMsg.error(msg: "programEnd: Received data is empty.")
        }
    }
    
    //dfu流程
    private func progress(_ listener:DfuListener?,_ msg:String, _ progress:Int){
        self.log?.d("GR5xxxDFU2", "programFlashFast: \(msg) : \(progress)")
        DispatchQueue.main.async {
            listener?.dfuProgress(msg: msg, progress: progress);
        }
    }
    public func updateFirmware(dfuData:Data, isCopyMode:Bool, copyAddress:UInt32, isFastMode:Bool=false, listener:DfuListener?=nil, ctrlCmd:Data?=nil, reconnectScanFilter:ScanFilter?=nil)throws{
        let db: DfuDatabase = DfuDatabase()
        if !isCopyMode{
            db.dfuMode = 0
            db.address = 0
        }else{
            db.dfuMode = 1
            db.address = copyAddress
        }
        db.fwFile = FirmwareAndResource(data: dfuData)
        //外部数据（来自用户）
        db.isExFlash = false
        //新版dfu
        db.isFastMode = isFastMode
        //内部数据（来自固件）
        db.scaStartAddress = 0
        db.bootInfo = nil
        db.peerEncrypted = false
        //新版dfu
        db.dfuVersion = 0
        db.position = 0
        db.commendSaveAddress = 0
        db.appInfo = nil
        //旧版dfu
        db.imgList = nil

        if (!(db.fwFile?.isFirmware ?? false)){
            DispatchQueue.main.async {
                listener?.dfuStopWithError(errorMsg: "Can't find image infomation data.");
            }
            throw ErrorMsg.error(msg: "Can't find image infomation data.")
        }

        //run
        DispatchQueue.main.async {
            listener?.dfuStart();
        }
        progress(listener, "start...", 0)
        if isSupportAppbootloaderSch{
            //发送dfuenter指令，防止固件端dfu任务未启动
            try setDfuEnter()
            //获取各种固件端信息
            progress(listener, "Loading device info...", 0)
            let getChipInfoRes:GetChipInfoRes = try getChipInfo()
            db.dfuVersion = getChipInfoRes.dfuVersion
            db.scaStartAddress = getChipInfoRes.scaStartAddress
            let getBootInfoRes:GetBootInfoRes = try getBootInfo(scaStartAddress: db.scaStartAddress)
            db.bootInfo = getBootInfoRes.bootInfo
            db.peerEncrypted = getBootInfoRes.peerEncrypted
            let getExtraInfoRes:GetExtraInfoRes = try getExtraInfo()
            db.position = getExtraInfoRes.position
            db.commendSaveAddress = getExtraInfoRes.commendSaveAddress
            db.appInfo = getExtraInfoRes.appInfo
            
            //覆盖检查
            progress(listener, "Checking memory coverage...", 0)
            try checkOverlapNew(db: db)
            
            //加密状态匹配检查
            try checkEncryptMath(dfuDatabase: db)
            
            //设置dfu mode、重连设备
            if db.dfuMode == 0 && db.position == 0x01{
                try setDfuMode(dfuMode: db.dfuMode)
                progress(listener, "Jumping to boot mode...", 5)
                Thread.sleep(forTimeInterval: 0.2)
                try self.blockBle?.disconnectPeripheral()
                Thread.sleep(forTimeInterval: 0.2)
                
                if let filter = reconnectScanFilter {
                    //根据过滤器得到可重连设备
                    try self.blockBle?.connectPeripheral(timeout: 10_000, filter: filter)
                }else{
                    //默认重连名字为Bootloader OTA的设备
                    try self.blockBle?.connectPeripheral(timeout: 10_000, deviceName: "Bootloader_OTA")
                }
                try self.blockBle?.discoverServices()
                try self.bondTo(blockingBle: blockBle!)
            }
            else if db.dfuMode == 1{
                try setDfuMode(dfuMode: db.dfuMode)
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            //下载数据
            progress(listener, "Downloading...", 0)
            if db.isFastMode{
                try programStartFast(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address, isExFlash: false, dfuVersion: db.dfuVersion)
                try programFlashFast(dfuFw: db.fwFile!, listener: { progress in
                    if (Thread.current.isCancelled){
                        DispatchQueue.main.async {
                            listener?.dfuCancelled(progress: progress)
                        }
                        Thread.exit()
                    }else {
                        self.progress(listener, "Downloading...", progress)
                    }
                })
            }
            else{
                try programStart(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address,isExFlash: false,dfuVersion: db.dfuVersion)
                try programFlash(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address, isExFlash: false,listener: { progress in
                    if (Thread.current.isCancelled){
                        DispatchQueue.main.async {
                            listener?.dfuCancelled(progress: progress)
                        }
                        Thread.exit()
                    }else {
                        self.progress(listener, "Downloading...", progress)
                    }
                })
            }
            try programEnd(dfuMode: db.dfuMode, dfuFw: db.fwFile!, dfuVersion: Int(db.dfuVersion), isExFlash: db.isExFlash, isFastMode: db.isFastMode)
            self.progress(listener, "Downloading", 100)
        }
        else{
            //写控制点，用于发送控制指令，该指令用于启动固件端DFU任务（固件端带rtos时），该指令内容用户可自定义
            try self.writeCtrPoint(ctrCmd: ctrlCmd)
            
            //获取各种固件端信息
            progress(listener, "Loading device info...", 0)
            let getChipInfoRes:GetChipInfoRes = try getChipInfo()
            db.dfuVersion = getChipInfoRes.dfuVersion
            db.scaStartAddress = getChipInfoRes.scaStartAddress
            let getBootInfoRes:GetBootInfoRes = try getBootInfo(scaStartAddress: db.scaStartAddress)
            db.bootInfo = getBootInfoRes.bootInfo
            db.peerEncrypted = getBootInfoRes.peerEncrypted
            let getImgListRes:GetImgListRes = try getImgList(scaStartAddress: db.scaStartAddress)
            db.peerEncrypted = getImgListRes.peerEncrypted
            db.imgList = getImgListRes.imgList
            
            //覆盖检查
            progress(listener, "Checking memory coverage...", 0)
            try checkOverlapOld(db: db)
            
            //加密状态匹配检查
            try checkEncryptMath(dfuDatabase: db)

            //imglist整理
            progress(listener, "Arranging image list...", 5)
            try tidyImgList(targetBootInfo: db.fwFile!.fwbootInfo!, bootInfo: db.bootInfo!, imgList: db.imgList!, scaStartAddress: db.scaStartAddress)

            //下载数据
            progress(listener, "Downloading...", 0)
            try programStart(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address, isExFlash: db.isExFlash, dfuVersion: db.dfuVersion)
            try programFlash(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address, isExFlash: false,listener: { progress in
                if (Thread.current.isCancelled){
                    DispatchQueue.main.async {
                        listener?.dfuCancelled(progress: progress)
                    }
                    Thread.exit()
                }else {
                    self.progress(listener, "Downloading...", progress)
                }
            })
            try programEnd(dfuMode: db.dfuMode, dfuFw: db.fwFile!, dfuVersion: Int(db.dfuVersion),isExFlash: db.isExFlash, isFastMode: db.isFastMode)
            progress(listener, "Downloading...", 100)
        }
        DispatchQueue.main.async {
            listener?.dfuComplete()
        }
    }
    public func updateResource(dfuData:Data, startAddress:UInt32, isFastMode:Bool=false, isExtFlash:Bool, listener:DfuListener?=nil, ctrlCmd:Data?=nil)throws{
        let db: DfuDatabase = DfuDatabase()
        
        //外部数据（来自用户）
        db.dfuMode = 2
        db.address = startAddress
        db.fwFile = FirmwareAndResource(data: dfuData)
        db.isExFlash = isExtFlash
        db.isFastMode = isFastMode
        //内部数据（来自固件）
        db.scaStartAddress = 0
        db.bootInfo = nil
        db.peerEncrypted = false
        db.dfuVersion = 0
        db.position = 0
        db.commendSaveAddress = 0
        db.appInfo = nil
        //旧版dfu
        db.imgList = nil
        
        //run
        DispatchQueue.main.async {
            listener?.dfuStart();
        }
        progress(listener, "start...", 0)
        if isSupportAppbootloaderSch{
            //发送dfuenter指令，防止固件端dfu任务未启动
            try setDfuEnter()
            //获取各种固件端信息
            progress(listener, "Loading device info...", 0)
            let getChipInfoRes:GetChipInfoRes = try getChipInfo()
            db.dfuVersion = getChipInfoRes.dfuVersion
            db.scaStartAddress = getChipInfoRes.scaStartAddress
            let getBootInfoRes:GetBootInfoRes = try getBootInfo(scaStartAddress: db.scaStartAddress)
            db.bootInfo = getBootInfoRes.bootInfo
            db.peerEncrypted = getBootInfoRes.peerEncrypted
            let getExtraInfoRes:GetExtraInfoRes = try getExtraInfo()
            db.position = getExtraInfoRes.position
            db.commendSaveAddress = getExtraInfoRes.commendSaveAddress
            db.appInfo = getExtraInfoRes.appInfo
            
            //覆盖检查
            progress(listener, "Checking memory coverage...", 0)
            try checkOverlapNew(db: db)
            
            //下载数据
            progress(listener, "Downloading...", 0)
            if db.isFastMode{
                try programStartFast(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address, isExFlash: db.isExFlash, dfuVersion: db.dfuVersion)
                try programFlashFast(dfuFw: db.fwFile!, listener: { progress in
                    if (Thread.current.isCancelled){
                        DispatchQueue.main.async {
                            listener?.dfuCancelled(progress: progress)
                        }
                        Thread.exit()
                    }else {
                        self.progress(listener, "Downloading...", progress)
                    }
                })
            }
            else{
                try programStart(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address, isExFlash: db.isExFlash, dfuVersion:db.dfuVersion)
                try programFlash(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address, isExFlash: db.isExFlash,listener: { progress in
                    if (Thread.current.isCancelled){
                        DispatchQueue.main.async {
                            listener?.dfuCancelled(progress: progress)
                        }
                        Thread.exit()
                    }else {
                        self.progress(listener, "Downloading...", progress)
                    }
                })
            }
            try programEnd(dfuMode: db.dfuMode, dfuFw: db.fwFile!, dfuVersion: Int(db.dfuVersion), isExFlash: db.isExFlash, isFastMode: db.isFastMode)
            progress(listener, "DFU Completed", 100)
        }
        else{
            //写控制点，用于发送控制指令，该指令用于启动固件端DFU任务（固件端带rtos时），该指令内容用户可自定义
            try self.writeCtrPoint(ctrCmd: ctrlCmd)
            
            //获取各种固件端信息
            progress(listener, "Loading device info...", 0)
            let getChipInfoRes:GetChipInfoRes = try getChipInfo()
            db.dfuVersion = getChipInfoRes.dfuVersion
            db.scaStartAddress = getChipInfoRes.scaStartAddress
            let getBootInfoRes:GetBootInfoRes = try getBootInfo(scaStartAddress: db.scaStartAddress)
            db.bootInfo = getBootInfoRes.bootInfo
            db.peerEncrypted = getBootInfoRes.peerEncrypted
            let getImgListRes:GetImgListRes = try getImgList(scaStartAddress: db.scaStartAddress)
            db.peerEncrypted = getImgListRes.peerEncrypted
            db.imgList = getImgListRes.imgList

            //覆盖检查
            progress(listener, "Checking memory coverage...", 0)
            try checkOverlapOld(db: db)
    
            //下载数据
            progress(listener, "Downloading...", 0)
            try programStart(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address,isExFlash: db.isExFlash, dfuVersion: db.dfuVersion)
            try programFlash(dfuMode: db.dfuMode, dfuFw: db.fwFile!, address: db.address, isExFlash: db.isExFlash,listener: { progress in
                if (Thread.current.isCancelled){
                    DispatchQueue.main.async {
                        listener?.dfuCancelled(progress: progress)
                    }
                    Thread.exit()
                }else {
                    self.progress(listener, "Downloading...", progress)
                }
            })
            try programEnd(dfuMode: db.dfuMode, dfuFw: db.fwFile!, dfuVersion: Int(db.dfuVersion), isExFlash: db.isExFlash, isFastMode: db.isFastMode)
            progress(listener, "Downloading...", 100)
        }
        DispatchQueue.main.async {
            listener?.dfuComplete()
        }
    }
    
    //tool
    private func checkOverlapNew(db: GR5xxxDFU2.DfuDatabase) throws{
        var targetArea: MemoryArea?
        if db.dfuMode == 0 || db.dfuMode == 1{ //upgrade firmware
            targetArea = MemoryArea("targetArea", db.fwFile!.fwbootInfo!.loadAddr, UInt32(db.fwFile!.frData!.count))
        }else if db.dfuMode == 2{ //upgrade resource
            targetArea = MemoryArea("targetArea", db.address, UInt32(db.fwFile!.frData!.count))
        }
        let scaArea: MemoryArea? = MemoryArea("scaArea", db.scaStartAddress, 0x0000_2000)
        let bootArea: MemoryArea? = MemoryArea("bootArea", db.bootInfo!.loadAddr, db.bootInfo!.appSize+48+856)
        var appArea: MemoryArea?
        if let availAppInfo = db.appInfo{
            if (availAppInfo.isAvailable){
                appArea = MemoryArea("appArea", availAppInfo.loadAddr, availAppInfo.appSize + 48 + 856)
            }
        }

        try MemoryArea.memoryOverlapCheck(src: scaArea!, dst: targetArea!)
        try MemoryArea.memoryOverlapCheck(src: bootArea!, dst: targetArea!)
        
        if db.dfuMode == 1{ //upgrade firmware with copy mode
            let copyArea: MemoryArea? = MemoryArea("copyArea", db.address, UInt32(db.fwFile!.frData!.count))
            try MemoryArea.memoryOverlapCheck(src: targetArea!, dst: copyArea!)
            try MemoryArea.memoryOverlapCheck(src: scaArea!, dst: copyArea!)
            try MemoryArea.memoryOverlapCheck(src: bootArea!, dst: copyArea!)
            if let availAppArea = appArea {
                try MemoryArea.memoryOverlapCheck(src: availAppArea, dst: copyArea!)
            }
        }
        else if db.dfuMode == 2{ //upgrade resource
            if !db.isExFlash{
                if let availAppArea = appArea {
                    try MemoryArea.memoryOverlapCheck(src: availAppArea, dst: targetArea!)
                }
            }
        }
    }
    private func checkOverlapOld(db: GR5xxxDFU2.DfuDatabase) throws{
        var targetArea: MemoryArea?
        if db.dfuMode == 0 || db.dfuMode == 1{
            targetArea = MemoryArea("targetArea", db.fwFile!.fwbootInfo!.loadAddr, UInt32(db.fwFile!.frData!.count))
        }else if db.dfuMode == 2{
            targetArea = MemoryArea("targetArea", db.address, UInt32(db.fwFile!.frData!.count))
        }
        let scaArea: MemoryArea = MemoryArea("scaArea", db.scaStartAddress, 0x0000_2000)
        let bootArea: MemoryArea = MemoryArea("bootArea", db.bootInfo!.loadAddr, db.bootInfo!.appSize+48+856)
        
        try MemoryArea.memoryOverlapCheck(src: scaArea, dst: targetArea!)
        if db.dfuMode == 0{
            try MemoryArea.memoryOverlapCheck(src: bootArea, dst: targetArea!)
        }else if db.dfuMode == 1{
            let copyArea: MemoryArea = MemoryArea("copyArea", db.address, UInt32(db.fwFile!.frData!.count))
            try MemoryArea.memoryOverlapCheck(src: targetArea!, dst: copyArea)
            try MemoryArea.memoryOverlapCheck(src: scaArea, dst: copyArea)
            try MemoryArea.memoryOverlapCheck(src: bootArea, dst: copyArea)
            if let list = db.imgList{
                for info in list{
                    try MemoryArea.memoryOverlapCheck(src: MemoryArea("imglistArea", info.loadAddr, info.appSize+48+856), dst: copyArea)
                }
            }
        }
        else if db.dfuMode == 2{
            try MemoryArea.memoryOverlapCheck(src: bootArea, dst: targetArea!)
            if let list = db.imgList{
                for info in list{
                    try MemoryArea.memoryOverlapCheck(src: MemoryArea("imglistArea", info.loadAddr, info.appSize+48+856), dst: targetArea!)
                }
            }
        }
    }
    private func checkEncryptMath(dfuDatabase: GR5xxxDFU2.DfuDatabase) throws{
        if dfuDatabase.dfuMode == 0 || dfuDatabase.dfuMode == 1{
            if dfuDatabase.peerEncrypted != (dfuDatabase.fwFile?.fwEncryptAndSignState == 2){
                throw ErrorMsg.error(msg: "checkEncryptMath: The new firmware and target device encryption status do not match.")
            }
        }
    }
    
    public class DfuDatabase{
        //外部数据（来自用户）
        public var fwFile:FirmwareAndResource? = nil
        public var address:UInt32 = 0
        public var dfuMode:Int = 0
        public var isExFlash:Bool = false
        //新版dfu
        public var isFastMode:Bool = false
        
        //内部数据（来自固件）
        public var scaStartAddress:UInt32 = 0
        public var bootInfo:Imginfo? = nil
        public var peerEncrypted:Bool = false
        //新版dfu
        public var dfuVersion:UInt32 = 0
        public var position:UInt32 = 0
        public var commendSaveAddress:UInt32 = 0
        public var appInfo:Imginfo?
        //旧版dfu
        public var imgList:[Imginfo]? = nil
    }
    public class CmdCode{
        static var GET_INFO:UInt32 = 0x01
        static var PROGRAM_START:UInt32 = 0x23
        static var PROGRAM_FLASH:UInt32 = 0x24
        static var PROGRAM_END:UInt32 = 0x25
        static var SYSTEM_COMFIG:UInt32 = 0x27
        static var SET_DFU_MODE:UInt32 = 0x41
        static var GET_FW_INFO:UInt32 = 0x42
        static var PROGRAM_FLASH_FAST:UInt32 = 0xff
    }
    public class Imginfo{
        static let VALIT_PATTERN = 0x4744
        var isAvailable = false
        
        var comment: String = ""
        var bootConfig: UInt32 = 0
        var spiAccessMode: UInt32 = 0
        var runAddr: UInt32 = 0
        var loadAddr: UInt32 = 0
        var checksum: UInt32 = 0
        var appSize: UInt32 = 0
        
        var version: UInt32 = 0
        var pattern: UInt32 = 0
        
        public init(){
            self.isAvailable = false
            self.comment = ""
            self.bootConfig = 0
            self.spiAccessMode = 0
            self.runAddr = 0
            self.loadAddr = 0
            self.checksum = 0
            self.appSize = 0
            self.version = 0
            self.pattern = 0
        }
        public init(data:Data){
            self.isAvailable = false
            if data.count == 24{
                let info = HexHandler(copy:data)
                self.pattern = 0x4744
                self.version = 0
                self.appSize = UInt32(info.get(size: 4))
                self.checksum = UInt32(info.get(size: 4))
                self.loadAddr = UInt32(info.get(size: 4))
                self.runAddr = UInt32(info.get(size: 4))
                self.spiAccessMode = UInt32(info.get(size: 4))
                self.bootConfig = UInt32(info.get(size: 4))
                self.comment = "bootinfo"
                self.isAvailable = true
            }
            else if data.count >= 40{
                let info = HexHandler(copy:data)
                self.pattern = UInt32(info.get(size: 2))
                self.version = UInt32(info.get(size: 2))
                self.appSize = UInt32(info.get(size: 4))
                self.checksum = UInt32(info.get(size: 4))
                self.loadAddr = UInt32(info.get(size: 4))
                self.runAddr = UInt32(info.get(size: 4))
                self.spiAccessMode = UInt32(info.get(size: 4))
                self.bootConfig = UInt32(info.get(size: 4))
                if let s = String(data: info.getData(size: 12), encoding: String.Encoding.utf8){
                    self.comment = s
                }else{
                    self.comment = "unknown"
                }
                if self.pattern == Imginfo.VALIT_PATTERN{
                    self.isAvailable = true
                }
            }
        }
        public func serialize() -> Data{
            let info: HexHandler  = HexHandler(40)
            info.put(size: 2, uint32: self.pattern)
            info.put(size: 2, uint32: self.version)
            info.put(size: 4, uint32: self.appSize)
            info.put(size: 4, uint32: self.checksum)
            info.put(size: 4, uint32: self.loadAddr)
            info.put(size: 4, uint32: self.runAddr)
            info.put(size: 4, uint32: self.spiAccessMode)
            info.put(size: 4, uint32: self.bootConfig)
            if let data = self.comment.data(using: String.Encoding.utf8){
                info.put(size: data.count, data: data )
            }
            return info.buffer
        }
        public func clone() -> Imginfo{
            let out = Imginfo(data:self.serialize())
            return out
        }
        public static func getImgList(data:Data) -> [Imginfo]?{
            if data.count % 40 != 0{
                return nil
            }
            
            var outList: [Imginfo] = []
            let dataHex: HexHandler = HexHandler(copy:data)
            let n:Int = data.count / 40
            for _ in 1...n{
                let info:Data = dataHex.getData(size: 40)
                let imgInfo:Imginfo = Imginfo(data:info)
                if imgInfo.isAvailable{
                    outList.append(imgInfo)
                }
            }
            if outList.isEmpty{
                return nil
            }else{
                return outList
            }
        }
    }
    public class FirmwareAndResource{
        public var isFirmware:Bool = false
        public var frData:Data? = nil
        public var frDataChecksum:UInt32 = 0
        public var fwbootInfo:Imginfo? = nil
        public var fwEncryptAndSignState:UInt32 = 0
        
        public init(data:Data){
            frData = data
            //计算校验和
            frDataChecksum = 0
            for value in data{
                frDataChecksum += UInt32(0xFF & value)
            }
            
            //尝试读取imginfo
            isFirmware = false
            if data.count > 48{
                let reader:HexHandler = HexHandler(copy: data)
                reader.pos = data.count - 48
                if reader.get(size: 2) == 0x4744{
                    fwEncryptAndSignState = 0 //未加密加签
                    reader.pos = data.count - 48
                    isFirmware = true
                }
                else if data.count > 48+856{
                    reader.pos = data.count - 48 - 856
                    if reader.get(size: 2) == 0x4744{//加签
                        //进一步判断是否加密
                        reader.pos = data.count - 256 - 520 - 8
                        let rsv = reader.get(size: 4)
                        if rsv == 0x4E474953{
                            fwEncryptAndSignState = 1 //仅加签
                        }else{
                            fwEncryptAndSignState = 2 //加签&加密
                        }
                        reader.pos = data.count - 48 - 856
                        isFirmware = true
                    }
                }
                if isFirmware{
                    fwbootInfo = Imginfo(data: reader.getData(size: 40))
                }
            }
        }
    }
    public class MemoryArea{
        public let name:String
        public let startAddr:UInt32
        public let size:UInt32
        
        public init(_ name: String, _ startAddr: UInt32, _ size: UInt32) {
            self.name = name
            self.startAddr = startAddr
            self.size = size
        }
        
        public static func memoryOverlapCheck(src:MemoryArea,dst:MemoryArea) throws{
            if memoryOverlap(src.startAddr, src.size, dst.startAddr, dst.size){
                throw ErrorMsg.error(msg: "memoryOverlapCheck: \(src.name)(\(String(src.startAddr, radix: 16))-\(String(src.startAddr+src.size, radix: 16))) and \(dst.name)(\(String(dst.startAddr, radix: 16))-\(String(dst.startAddr+dst.size, radix: 16))) intersect.[\(#file)->\(#line)]")
            }
        }
        public static func memoryOverlapCheck(src:MemoryArea,dst_list:[MemoryArea]) throws{
            for dst in dst_list{
                if memoryOverlap(src.startAddr, src.size, dst.startAddr, dst.size){
                    throw ErrorMsg.error(msg: "memoryOverlapCheck: \(src.name)(\(String(src.startAddr, radix: 16))-\(String(src.startAddr+src.size, radix: 16))) and \(dst.name)(\(String(dst.startAddr, radix: 16))-\(String(dst.startAddr+dst.size, radix: 16))) intersect.[\(#file)->\(#line)]")
                }
            }
        }
        public static func memoryOverlap(_ srcStart:UInt32, _ srcSize:UInt32, _ dstStart:UInt32, _ dstSize:UInt32) -> Bool{
            let dstEnd:UInt32 = dstStart + dstSize
            let srcEnd:UInt32 = srcStart + srcSize
            return srcEnd > dstStart && srcStart < dstEnd
        }
    }
    //通用子任务返回对象
    public class GetChipInfoRes{
        public var dfuVersion:UInt32 = 0;
        public var scaStartAddress:UInt32 = 0;
    }
    public class GetBootInfoRes{
        public var peerEncrypted:Bool = false;
        public var bootInfo:Imginfo? = nil;
    }
    public class GetImgListRes{
        public var peerEncrypted:Bool = false;
        public var imgList:[Imginfo]? = nil;
    }
    public class GetExtraInfoRes{
        public var position:UInt32 = 0;
        public var commendSaveAddress:UInt32 = 0;
        public var appInfo:Imginfo? = nil;
    }
}


