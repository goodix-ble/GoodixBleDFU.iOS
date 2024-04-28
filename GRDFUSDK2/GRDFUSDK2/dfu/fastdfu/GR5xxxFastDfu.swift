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
import libcomx
 
public class GR5xxxFastDfu:FastDfuProfile{
    //DFU任务
    public func getFastDfuVersion()throws -> UInt32{
        //编码+发送
        let cmd = HexHandler(4+1)
        cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
        cmd.put(size: 1, uint32: CmdCode.GET_VERSION)
        try sendCmd(data: cmd.buffer)
        //接收+解码
        let data = try recvCmd()
        if data[0] != CmdCode.GET_VERSION || data.count < 2{
            throw ErrorMsg.error(msg: "getFastDfuVersion error")
        }
        return UInt32(data[1])
    }
    public func selectAimFlash(isExFlash:Bool) throws{
        //编码+发送
        let cmd = HexHandler(4+2)
        cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
        cmd.put(size: 1, uint32: CmdCode.SELECT_AIM_FLASH)
        if isExFlash{
            cmd.put(size: 1, uint32: 0x01)
        }else{
            cmd.put(size: 1, uint32: 0x00)
        }
        try sendCmd(data: cmd.buffer)
        //接收+解码
        let data = try recvCmd()
        if data[0] != CmdCode.SELECT_AIM_FLASH{
            throw ErrorMsg.error(msg: "selectAimFlash error")
        }
    }
    public func eraseFlash(dfuMode:UInt32,fwFile:FirmwareAndResource,address:UInt32) throws{
        let sectorsize:UInt32 = 4*1024
        var eraseSectorNum:Int = 0
        var eraseStartAddress:UInt32 = 0
        var eraseAreaSize:UInt32 = 0
        if dfuMode == 0{
            eraseStartAddress = fwFile.fwbootInfo!.loadAddr
            eraseAreaSize = UInt32(fwFile.frData!.count)
        }else if dfuMode == 1 || dfuMode == 2{
            eraseStartAddress = address
            eraseAreaSize = UInt32(fwFile.frData!.count)
        }
        eraseSectorNum = Int(Float(eraseAreaSize + sectorsize - 1)/Float(sectorsize))
        
        //编码+发送
        let cmd = HexHandler(4+9)
        cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
        cmd.put(size: 1, uint32: CmdCode.ERASE_FLASH)
        cmd.put(size: 4, uint32: eraseStartAddress)
        cmd.put(size: 4, uint32: eraseAreaSize)
        try sendCmd(data: cmd.buffer)
        while(true){
            //接收+解码
            let data = try recvCmd()
            if data[0] != CmdCode.ERASE_FLASH || data.count < 2{
                throw ErrorMsg.error(msg: "eraseFlash error.")
            }
            let hexData:HexHandler = HexHandler(copy:data)
            hexData.pos = 1
            switch hexData.get(size: 1){
            case 0x00:
                throw ErrorMsg.error(msg: "eraseFlash: address is not 4K aligned.")
            case 0x01:
                print("eraseFlash: start erase...")
            case 0x02:
                let progress = hexData.get(size: 2)
                print("eraseFlash: erase progress = \(progress)/\(eraseSectorNum)")
            case 0x03:
                print("eraseFlash: erased.")
                return
            case 0x04:
                throw ErrorMsg.error(msg: "eraseFlash: Overlap running firmware.")
            case 0x05:
                throw ErrorMsg.error(msg: "eraseFlash: Filed to erase.")
            case 0x06:
                throw ErrorMsg.error(msg: "eraseFlash: No ext flash.")
            default:
                throw ErrorMsg.error(msg: "eraseFlash: unknown code.")
            }
        }
    }
    public func getBufferSize(fastDfuVersion:UInt32) throws -> UInt32{
        if fastDfuVersion<3{
            //编码+发送
            let cmd = HexHandler(4+1)
            cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
            cmd.put(size: 1, uint32: CmdCode.GET_BUFFER_SIZE)
            try sendCmd(data: cmd.buffer)
            //接收+解码
            let data = try recvCmd()
            if data[0] != CmdCode.GET_BUFFER_SIZE || data.count < 5{
                throw ErrorMsg.error(msg: "getBufferSize error")
            }
            let hexData:HexHandler = HexHandler(copy:data)
            return UInt32(hexData.get(size: 4))
        }else{
            return 4096
        }
    }
    public func downloadData(fastDfuVersion:UInt32, fwFile:FirmwareAndResource, bufferSize:UInt32, listener:RWProgressListener? = nil) throws{
        if fastDfuVersion >= 3{
            try sendData(data: fwFile.frData!, listener: listener)
            //编码+发送
            let cmd = HexHandler(4+1)
            cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
            cmd.put(size: 1, uint32: CmdCode.FLUSH_FLASH)
            try sendCmd(data: cmd.buffer)
            //接收+解码
            let data = try recvCmd()
            if data[0] != CmdCode.FLUSH_FLASH{
                throw ErrorMsg.error(msg: "downloadData error")
            }
        }else{
            //编码+发送
            let cmd = HexHandler(4+1)
            cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
            cmd.put(size: 1, uint32: CmdCode.FLUSH_FLASH)
            try sendCmd(data: cmd.buffer)
            var dfuDataWritePos:UInt32 = 0
            while(true){
                //接收+解码
                let data = try recvCmd()
                switch(UInt32(data[0])){
                case CmdCode.FLUSH_FLASH:
                    return
                case CmdCode.FLOW_CTRL_PAUSE:
                    throw ErrorMsg.error(msg: "FlowCtrl = true, buffer overflowed.")
                case CmdCode.FLOW_CTRL_RESUME:
                    throw ErrorMsg.error(msg: "FlowCtrl = false, not allowed.")
                case CmdCode.NEXT_BUFFER:
                    //发送下一帧数据
                    if dfuDataWritePos < fwFile.frData!.count{
                        var sendLength = bufferSize
                        if UInt32(fwFile.frData!.count)-dfuDataWritePos < bufferSize{
                            sendLength = UInt32(fwFile.frData!.count)-dfuDataWritePos
                        }
                        let cmd = HexHandler(Int(sendLength))
                        cmd.put(size: Int(sendLength), data: fwFile.frData,fromStartPos: Int(dfuDataWritePos))
                        try sendData(data: cmd.buffer)
                        dfuDataWritePos += UInt32(sendLength)
                        if let progress = listener{
                            progress(Int(Float(dfuDataWritePos*100)/Float(fwFile.frData!.count)))
                        }
                    }
                default:
                    throw ErrorMsg.error(msg: "downloadData：receive unknown code.")
                }
            }
        }
    }
    public func checkChecksum(fwFile:FirmwareAndResource) throws{
        //编码+发送
        let cmd = HexHandler(4+5)
        cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
        cmd.put(size: 1, uint32: CmdCode.CHECK_CHECKSUM)
        cmd.put(size: 4, uint32: fwFile.frDataChecksum)
        try sendCmd(data: cmd.buffer)
        //接收+解码
        let data = try recvCmd()
        if data[0] != CmdCode.CHECK_CHECKSUM || data.count < 5{
            throw ErrorMsg.error(msg: "checkChecksum: error")
        }
        let hexData:HexHandler = HexHandler(copy:data)
        hexData.pos=1
        let recvChecksum:UInt32 = UInt32(hexData.get(size: 4))
        if fwFile.frDataChecksum != recvChecksum{
            throw ErrorMsg.error(msg: "checkChecksum: sendChecksum != recvChecksum")
        }
    }
    public func postprogressing(dfuMode:UInt32,fwFile:FirmwareAndResource,address:UInt32) throws{
        if dfuMode == 0{
            //编码+发送
            let cmd = HexHandler(4+41)
            cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
            cmd.put(size: 1, uint32: CmdCode.WRITE_BOOT)
            let boot = fwFile.fwbootInfo!.serialize()
            cmd.put(size: boot.count, data: boot)
            try sendCmd(data: cmd.buffer)
        }else if dfuMode == 1{
            //编码+发送
            let cmd = HexHandler(4+49)
            cmd.put(size: 4, uint32: CmdCode.CMD_HEAD)
            cmd.put(size: 1, uint32: CmdCode.START_COPY)
            let boot = fwFile.fwbootInfo!.serialize()
            cmd.put(size: boot.count, data: boot)
            cmd.put(size: 4, uint32: address)
            cmd.put(size: 4, uint32: UInt32(fwFile.frData!.count))
            try sendCmd(data: cmd.buffer)
        }
        Thread.sleep(forTimeInterval: 1)
    }

    public func memoryOverlap(_ srcStart:UInt32, _ srcSize:UInt32, _ dstStart:UInt32, _ dstSize:UInt32) -> Bool{
        let dstEnd:UInt32 = dstStart + dstSize
        let srcEnd:UInt32 = srcStart + srcSize
        return srcEnd > dstStart && srcStart < dstEnd
    }
    
    //fast dfu流程
    public func updateFwRes(dfuMode:UInt32, dfuData:Data, address:UInt32, extFlash:Bool, listener:DfuListener? = nil) throws{
        let fastDfuDatabase:FastDfuDatabase = FastDfuDatabase()
        fastDfuDatabase.fwFile = FirmwareAndResource(data: dfuData)
        fastDfuDatabase.address = address
        fastDfuDatabase.dfuMode = dfuMode
        fastDfuDatabase.isExFlash = extFlash
        fastDfuDatabase.fastDfuVersion = 0
        fastDfuDatabase.bufferSize = 0

        if (0 == dfuMode || 1 == dfuMode){ // 0 or 1 means Firmware, 2 means Resource
            if (!(fastDfuDatabase.fwFile?.isFirmware ?? false)){
                throw ErrorMsg.error(msg: "Can't find image infomation data.")
            }

            if (dfuMode == 1){ // 1 means copy mode
                if ((fastDfuDatabase.fwFile?.fwbootInfo?.hasOverlap(dstStart: address, dstSize: UInt32(dfuData.count))) == true){
                    throw ErrorMsg.error(msg: "updateFwRes error with address overlapped")
                }
            }
        }

        DispatchQueue.main.async {
            listener?.dfuProgress(msg: "Loading device info...", progress: 0);
        }

        fastDfuDatabase.fastDfuVersion = try getFastDfuVersion()
        try selectAimFlash(isExFlash: fastDfuDatabase.isExFlash)
        fastDfuDatabase.bufferSize = try getBufferSize(fastDfuVersion: fastDfuDatabase.fastDfuVersion)
        DispatchQueue.main.async {
            listener?.dfuProgress(msg: "Erasing flash...", progress: 0);
        }
        try eraseFlash(dfuMode: fastDfuDatabase.dfuMode, fwFile: fastDfuDatabase.fwFile!, address: fastDfuDatabase.address)
        DispatchQueue.main.async {
            listener?.dfuProgress(msg: "Downloading...", progress: 0);
        }
        try downloadData(fastDfuVersion: fastDfuDatabase.fastDfuVersion, fwFile: fastDfuDatabase.fwFile!, bufferSize: fastDfuDatabase.bufferSize,listener: { progress in
            if (Thread.current.isCancelled){
                DispatchQueue.main.async {
                    listener?.dfuCancelled(progress: progress)
                }
                Thread.exit()
            }else {
                DispatchQueue.main.async {
                    listener?.dfuProgress(msg: "Downloading...", progress: progress);
                }
            }
        })
        
        // compat GR5515 SDK V1.6.12. BALPRO-3092.
        Thread.sleep(forTimeInterval: 0.2)

        try checkChecksum(fwFile: fastDfuDatabase.fwFile!)
        try postprogressing(dfuMode: fastDfuDatabase.dfuMode, fwFile: fastDfuDatabase.fwFile!, address: fastDfuDatabase.address)
        DispatchQueue.main.async {
            listener?.dfuProgress(msg: "DFU Completed", progress: 100);
        }
        DispatchQueue.main.async {
            listener?.dfuComplete();
        }
    }
    
    //tools
    public class FastDfuDatabase{
        ///外部数据（来自用户）
        public var fwFile:FirmwareAndResource? = nil
        public var address:UInt32 = 0
        public var dfuMode:UInt32 = 0
        public var isExFlash:Bool = false
        
        //内部数据（来自固件）
        public var fastDfuVersion:UInt32 = 0
        public var bufferSize:UInt32 = 0
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
            else if data.count == 40{
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

        public static func memoryOverlap(_ srcStart:UInt32, _ srcSize:UInt32, _ dstStart:UInt32, _ dstSize:UInt32) -> Bool{
            let dstEnd:UInt32 = dstStart + dstSize
            let srcEnd:UInt32 = srcStart + srcSize
            return srcEnd > dstStart && srcStart < dstEnd
        }
        
        public func hasOverlap(dstStart: UInt32, dstSize: UInt32) ->Bool{
            return GR5xxxFastDfu.Imginfo.memoryOverlap(loadAddr, appSize, dstStart, dstSize);
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
    public class CmdCode{
        static var CMD_HEAD:UInt32 = 0x474f4f44
        
        static var ERASE_FLASH:UInt32 = 0x01
        static var FLUSH_FLASH:UInt32 = 0x02
        static var CHECK_CHECKSUM:UInt32 = 0x03
        static var WRITE_BOOT:UInt32 = 0x04
        static var SELECT_AIM_FLASH:UInt32 = 0x05
        static var FLOW_CTRL_PAUSE:UInt32 = 0x06
        static var FLOW_CTRL_RESUME:UInt32 = 0x07
        static var START_COPY:UInt32 = 0x08
        static var GET_BUFFER_SIZE:UInt32 = 0x09
        static var NEXT_BUFFER:UInt32 = 0x0A
        static var GET_VERSION:UInt32 = 0x0B
    }
}
