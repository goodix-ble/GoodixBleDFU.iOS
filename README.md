# DFU SDK for Goodix GR5xxx

本文档对应的工程演示了如何使用DFU SDK升级GR5xxx系列BLE芯片的固件程序。提供EasyDFU和FastDFU类，用于通过DFU和FastDFU协议进行固件升级。

## 1. EasyDFU2类

这个类用于进行DFU升级，对应可以参考芯片的ble_dfu_boot工程。


### 1.1 配置项

- ``setFastMode`` 设置快速升级模式。（仅对appbootloader DFU方案有效）
- ``setReconnectScanFilter`` 设置重连扫描过滤器。（固件端采用appbootloader DFU方案时，通过startDfu接口升级中途需要跳转至boot固件，该过滤器用于筛选目标boot固件）
- ``setListener`` 通过这个代理监听DFU的升级进度和结果。


### 1.2 进度回调

DFU库在主线程调用以下回调。

```swift
public protocol DfuListener {
    /**
     开始升级时调用该接口。
    */
    func dfuStart();
        /**
     更新升级过程的进度时调用该接口。
     - parameters
       - msg: 升级阶段信息。
       - progress: 升级进度（0-100）。
    */
    func dfuProgress(msg:String, progress:Int);
        /**
     升级成功时调用该接口。
    */
    func dfuComplete();
        /**
     升级过程遇到错误时调用该接口，并终止升级过程。
    */
    func dfuStopWithError(errorMsg:String);
}
```


### 1.3 功能函数
#### 1.3.1 startDfu()

这个函数将固件下载到芯片中。但是不能与当前的固件重叠。不建议使用。

```swift
public func startDfu(central:CBCentralManager?, target: CBPeripheral, dfuData:Data)
```

参数说明：
* central : 用于执行连接的中心对象。
* target : 需要被升级的目标设备。这个设备必须是由central获得的设备。它们2个要有关联关系。
* dfuData : 固件的数据。


### 1.3.2 startDfuInCopyMode

这个函数将固件下载到芯片中。可以用于升级当前正在运行的固件。推荐使用。

```swift
    startDfuInCopyMode(central:CBCentralManager?, target: CBPeripheral, dfuData:Data, copyAddr:UInt32)
```

参数说明：
* central : 用于执行连接的中心对象。
* target : 需要被升级的目标设备。这个设备必须是由central获得的设备。它们2个要有关联关系。
* dfuData : 固件的数据。
* copyAddr : 拷贝地址。新固件数据会被临时存放到芯片的这个地址上，等待无线数据传输完成后，再由芯片拷贝到固件的最终存储位置上。


### 1.3.3 startUpdateResource

这个函数将资源数据发送到硬件设备中。可以存储到芯片的内部Flash上，也可以存储到芯片的外部Flash上。如果需要存储到外部Flash上，需要芯片端提前初始化好外部Flash。

```swift
public func startUpdateResource(central:CBCentralManager?, target: CBPeripheral, dfuData:Data, extFlash:Bool, startAddr:UInt32)
```

参数说明：
* central : 用于执行连接的中心对象。
* target : 需要被升级的目标设备。这个设备必须是由central获得的设备。它们2个要有关联关系。
* dfuData : 资源数据。
* startAddr : 存放地址。该地址不能与单前运行固件占用的区域重叠。


## 2. FastDFU类

这个类用于进行FastDFU升级，对应可以参考芯片的ble_dfu_fast工程。


### 2.1 配置项

- ``setListener`` 通过这个代理监听DFU的升级进度和结果。


### 2.2 进度回调

DFU库在主线程调用以下回调。

```swift
public protocol DfuListener {
    /**
     开始升级时调用该接口。
    */
    func dfuStart();
        /**
     更新升级过程的进度时调用该接口。
     - parameters
       - msg: 升级阶段信息。
       - progress: 升级进度（0-100）。
    */
    func dfuProgress(msg:String, progress:Int);
        /**
     升级成功时调用该接口。
    */
    func dfuComplete();
        /**
     升级过程遇到错误时调用该接口，并终止升级过程。
    */
    func dfuStopWithError(errorMsg:String);
}
```


### 2.3 功能函数
#### 2.3.1 startDfu()

这个函数将固件下载到芯片中。但是不能与当前的固件重叠。不建议使用。

```swift
public func startDfu(central:CBCentralManager?, target: CBPeripheral, dfuData:Data)
```

参数说明：
* central : 用于执行连接的中心对象。
* target : 需要被升级的目标设备。这个设备必须是由central获得的设备。它们2个要有关联关系。
* dfuData : 固件的数据。


### 2.3.2 startDfuInCopyMode

这个函数将固件下载到芯片中。可以用于升级当前正在运行的固件。推荐使用。

```swift
public func startDfuInCopyMode(central:CBCentralManager?, target: CBPeripheral, dfuData: Data, copyAddr: UInt32)
```

参数说明：
* central : 用于执行连接的中心对象。
* target : 需要被升级的目标设备。这个设备必须是由central获得的设备。它们2个要有关联关系。
* dfuData : 固件的数据。
* copyAddr : 拷贝地址。新固件数据会被临时存放到芯片的这个地址上，等待无线数据传输完成后，再由芯片拷贝到固件的最终存储位置上。


### 2.3.3 startUpdateResource

这个函数将资源数据发送到硬件设备中。可以存储到芯片的内部Flash上，也可以存储到芯片的外部Flash上。如果需要存储到外部Flash上，需要芯片端提前初始化好外部Flash。

```swift
public func startResourceUpdate(central:CBCentralManager?, target: CBPeripheral, dfuData:Data, extFlash:Bool, startAddr:UInt32)
```

参数说明：
* central : 用于执行连接的中心对象。
* target : 需要被升级的目标设备。这个设备必须是由central获得的设备。它们2个要有关联关系。
* dfuData : 资源数据。
* startAddr : 存放地址。该地址不能与单前运行固件占用的区域重叠。
