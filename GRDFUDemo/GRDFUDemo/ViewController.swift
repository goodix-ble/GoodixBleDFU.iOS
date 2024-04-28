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

import UIKit
import CoreBluetooth
import GRDFUSDK2
import libcomx


class ViewController: UIViewController, SimpleBleScannerProtocol, UIDocumentBrowserViewControllerDelegate, DfuListener, ComxLogRowProtocal{
    
    //MARK: members definition
    @IBOutlet weak var mDeviewName: UILabel!
    @IBOutlet weak var mScanButton: UIButton!
    @IBOutlet weak var mScrollView: UIScrollView!
    @IBOutlet weak var mFileNameLabel: UILabel!
    @IBOutlet weak var mBrowseButton: UIButton!
    @IBOutlet weak var mProgressLabel: UILabel!
    @IBOutlet weak var mAddressEditView: UITextField!
    @IBOutlet weak var mProgressView: UIProgressView!
    @IBOutlet weak var mErrorLabel: UILabel!
    @IBOutlet weak var mLogTextView: UITextView!
    @IBOutlet weak var mExtFlashCheckButton: UIButton!
    @IBOutlet weak var mEasyDfuFastModeButton: UIButton!
    @IBOutlet weak var mEasyDfuButton1: UIButton!
    @IBOutlet weak var mEasyDfuButton2: UIButton!
    @IBOutlet weak var mEasyDfuButton3: UIButton!
    @IBOutlet weak var mEasyDfuButton4: UIButton!
    @IBOutlet weak var mFastDfuButton1: UIButton!
    @IBOutlet weak var mFastDfuButton2: UIButton!
    @IBOutlet weak var mFastDfuButton3: UIButton!
    @IBOutlet weak var mCancelButton: UIButton!
    
    private let mBleManager = CBCentralManager();
    private var mSelectedDevice:CBPeripheral? = nil;
    private var mSelectedFileData:Data? = nil;
    private var mDfuStatusDialog : MBProgressHUD?
    private var mLogBuffer : String = String()
    private var mEasyDfu2 : EasyDfu2? = nil
    private var mFastDfu : FastDfu? = nil
    
    @objc func aboutButtonClicked(){
        let alertController = UIAlertController(title: "About", message:
            "Version: V2.0.1\n\nCopyright (C) 2023, Shenzhen Goodix Technology Co., Ltd. All Rights Reserved.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default){(action)in
            alertController.dismiss(animated: true)
        }
        alertController.addAction(okAction)

        self.present(alertController, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        mLogTextView.text = ""
        mProgressView.setProgress(0, animated: false)
        colorNavigationBar()
    }

    func showStatusTextToast(text: String){
        mDfuStatusDialog = MBProgressHUD.showAdded(to: self.view, animated: true)
        mDfuStatusDialog?.label.text = text
        mDfuStatusDialog?.mode = MBProgressHUDMode.text
        mDfuStatusDialog?.animationType = MBProgressHUDAnimation.zoom
        mDfuStatusDialog?.removeFromSuperViewOnHide = true
        mDfuStatusDialog?.hide(animated: true, afterDelay: 2.5)
        mDfuStatusDialog?.offset = CGPoint(x: 0, y: MBProgressMaxOffset)
    }

    func disableAllViews(disable:Bool, butExceptCanncelButton:Bool){
        mScanButton.isEnabled = !disable
        mScanButton.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mBrowseButton.isEnabled = !disable
        mBrowseButton.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mAddressEditView.isEnabled = !disable

        mExtFlashCheckButton.setImage(UIImage(named:"icon_checked"), for: UIControl.State.selected)
        mExtFlashCheckButton.setImage(UIImage(named:"icon_uncheck"), for: UIControl.State.normal)
        if (mExtFlashCheckButton.isSelected){
            if (disable){
                mExtFlashCheckButton.setImage(UIImage(named:"icon_check_disable"), for: UIControl.State.normal)
                mExtFlashCheckButton.setImage(UIImage(named:"icon_check_disable"), for: UIControl.State.disabled)
            }else {
                mExtFlashCheckButton.setImage(UIImage(named:"icon_checked"), for: UIControl.State.selected)
            }
        }else {
            if (disable){
                mExtFlashCheckButton.setImage(UIImage(named:"icon_uncheck"), for: UIControl.State.normal)
                mExtFlashCheckButton.setImage(UIImage(named:"icon_uncheck"), for: UIControl.State.disabled)
            }else {
                mExtFlashCheckButton.setImage(UIImage(named:"icon_uncheck"), for: UIControl.State.normal)
            }
        }
        mExtFlashCheckButton.isEnabled = !disable
        mExtFlashCheckButton.alpha = disable ? 0.6 : 1.0
        
        mEasyDfuFastModeButton.setImage(UIImage(named:"icon_checked"), for: UIControl.State.selected)
        mEasyDfuFastModeButton.setImage(UIImage(named:"icon_uncheck"), for: UIControl.State.normal)
        if (mEasyDfuFastModeButton.isSelected){
            if (disable){
                mEasyDfuFastModeButton.setImage(UIImage(named:"icon_check_disable"), for: UIControl.State.normal)
                mEasyDfuFastModeButton.setImage(UIImage(named:"icon_check_disable"), for: UIControl.State.disabled)
            }else {
                mEasyDfuFastModeButton.setImage(UIImage(named:"icon_checked"), for: UIControl.State.selected)
            }
        }else {
            if (disable){
                mEasyDfuFastModeButton.setImage(UIImage(named:"icon_uncheck"), for: UIControl.State.normal)
                mEasyDfuFastModeButton.setImage(UIImage(named:"icon_uncheck"), for: UIControl.State.disabled)
            }else {
                mEasyDfuFastModeButton.setImage(UIImage(named:"icon_uncheck"), for: UIControl.State.normal)
            }
        }
        mEasyDfuFastModeButton.isEnabled = !disable
        mEasyDfuFastModeButton.alpha = disable ? 0.6 : 1.0
        
        mEasyDfuButton1.isEnabled = !disable
        mEasyDfuButton1.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mEasyDfuButton2.isEnabled = !disable
        mEasyDfuButton2.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mEasyDfuButton3.isEnabled = !disable
        mEasyDfuButton3.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mEasyDfuButton4.isEnabled = !disable
        mEasyDfuButton4.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mFastDfuButton1.isEnabled = !disable
        mFastDfuButton1.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mFastDfuButton2.isEnabled = !disable
        mFastDfuButton2.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mFastDfuButton3.isEnabled = !disable
        mFastDfuButton3.backgroundColor = disable ? UIColor.lightGray : UIColor.systemBlue
        
        mCancelButton.isEnabled = butExceptCanncelButton ? disable : !disable
        mCancelButton.backgroundColor = mCancelButton.isEnabled ? UIColor.systemBlue : UIColor.lightGray
    }
    
    //MARK: DfuListener implementation
    
    func dfuStart() {
        mProgressLabel.text = "Start Downloading..."
        mProgressView.progress = 0.0
        disableAllViews(disable: true, butExceptCanncelButton: true)

        mScrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
    }

    func dfuProgress(msg: String, progress: Int) {
        mProgressLabel.text = msg + " \(progress) % "
        mProgressView.progress = Float(progress) / 100
    }
    
    func dfuComplete() {
        mProgressLabel.text = "DFU Completed"
        mProgressView.progress = 1.0
        disableAllViews(disable: false, butExceptCanncelButton: true)
        showLogInfo()
    }
    
    func dfuStopWithError(errorMsg: String) {
        mProgressLabel.text = "Error:\(errorMsg)"
        disableAllViews(disable: false, butExceptCanncelButton: true)
        showLogInfo()
    }
    func dfuCancelled(progress:Int){
        mProgressLabel.text = "DFU Cancelled"
        disableAllViews(disable: false, butExceptCanncelButton: true)
        showLogInfo()
    }

    func showLogInfo(maxSize : Int = 2048, clearBufferAfterShowing:Bool = true){
        if (!mLogBuffer.isEmpty){
            mLogTextView.text = String(mLogBuffer.suffix(maxSize));
            if (clearBufferAfterShowing){
                mLogBuffer.removeAll()
            }
        }
    }

    //MARK: Handle DFU

    @IBAction func selectDeviceButtonClicked(_ sender: UIButton) {
        let scanDeviceVc = SimpleBleScannerVC.make(nil, nil)
        scanDeviceVc.bleMgr = mBleManager
        scanDeviceVc.delegate = self
        self.present(scanDeviceVc, animated: true)
    }

    @IBAction func selectFileButtonClicked(_ sender: UIButton) {
        let selectFileVc = UIDocumentBrowserViewController();
        selectFileVc.delegate = self;
        selectFileVc.allowsDocumentCreation = false;
        selectFileVc.allowsPickingMultipleItems = false;
        present(selectFileVc, animated: true);
    }
    
    @IBAction func checkExtFlashButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
    }
    @IBAction func checkEasyDfuFastModeButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
    }
    
    @IBAction func addressEditViewDidEndOnExit(_ sender: UITextField) {
        mAddressEditView.resignFirstResponder()
    }
    
    @IBAction func easyButtonClicked(_ sender: UIButton) {
        mLogTextView.text = ""
        
        guard mSelectedDevice != nil else {
            showStatusTextToast(text: "select valid ble device")
            return
        }
        
        guard mSelectedFileData != nil else {
            print("select a firmware/resource file.")
            showStatusTextToast(text: "select valid firmware file")
            return
        }

        mEasyDfu2 = EasyDfu2()
        mFastDfu = nil
        guard let easyDfu2 = mEasyDfu2 else {
            return
        }

        easyDfu2.setListener(listener: self)
        easyDfu2.setFastMode(isFastMode: self.mEasyDfuFastModeButton.isSelected)
        easyDfu2.setLogListener(listener: self)

        if 1001 == sender.tag{ //startDfu
            easyDfu2.startDfu(central: mBleManager, target: mSelectedDevice!, dfuData: mSelectedFileData!)
        }else if 1002 == sender.tag{ //startDfuInCopyMode
            if let copyAddr = self.mAddressEditView.text{
                if let address = UInt32(copyAddr, radix:16){
                    easyDfu2.startDfuInCopyMode(central: mBleManager, target: mSelectedDevice!, dfuData: mSelectedFileData!, copyAddr: address)
                    print("start copy dfu...")
                }else{
                    showStatusTextToast(text:"input valid copy address")
                }
            }
        }else if 1003 == sender.tag{ //startUpdateResource
            if let address_str = self.mAddressEditView.text{
                if let address = UInt32(address_str, radix:16){
                    let isTargetExternFlash = mExtFlashCheckButton.isSelected
                    easyDfu2.startResourceUpdate(central: mBleManager, target: mSelectedDevice!, dfuData: mSelectedFileData!, extFlash: isTargetExternFlash, startAddr: address)
                    print("start resource update...")
                }else{
                    showStatusTextToast(text:"input valid write address")
                }
            }
        }else if 1004 == sender.tag{ //startDfuWithDfuBoot
            //因为重连之后才会调用onDFUStart，这里提前禁止界面操作，体验会更好
            disableAllViews(disable: true, butExceptCanncelButton: true)
            
            //警告：因IOS不能取得蓝牙地址，所以重连时是依据DFU BOOT模式时的设备名，这里是不可靠的。
            easyDfu2.setReconnectScanFilter { peripheral, advertisementData, rssi in
                if peripheral.name == "Goodix_DFU"{
                    return true
                }else{
                    return false
                }
            }
            easyDfu2.startDfuWithDfuBoot(central: mBleManager, target: mSelectedDevice!, dfuData: mSelectedFileData!)
        }
    }
    
    @IBAction func fastDfuButtonClicked(_ sender: UIButton) {
        mLogTextView.text = ""
        
        guard mSelectedDevice != nil else {
            showStatusTextToast(text:"select valid ble device")
            return
        }
        
        guard mSelectedFileData != nil else {
            showStatusTextToast(text:"select valid firmware file")
            return
        }
        
        mFastDfu = FastDfu()
        mEasyDfu2 = nil
        guard let fastDfu = mFastDfu else {
            return
        }

        fastDfu.setListener(listener: self)
        fastDfu.setLogListener(listener: self)
        
        if 2001 == sender.tag{ //startDfu
            fastDfu.startDfu(central: mBleManager, target: mSelectedDevice!, dfuData: mSelectedFileData!)
        }else if 2002 == sender.tag{ //startDfuInCopyMode
            if let copyAddr = self.mAddressEditView.text{
                if let address = UInt32(copyAddr, radix:16){
                    fastDfu.startDfuInCopyMode(central: mBleManager, target: mSelectedDevice!, dfuData: mSelectedFileData!, copyAddr: address)
                }else{
                    showStatusTextToast(text:"input valid copy address")
                }
            }
        }else if 2003 == sender.tag{ //startUpdateResource
            if let copyAddr = self.mAddressEditView.text{
                if let address = UInt32(copyAddr, radix:16){
                    let isTargetExternFlash = mExtFlashCheckButton.isSelected
                    fastDfu.startResourceUpdate(central: mBleManager, target: mSelectedDevice!, dfuData: mSelectedFileData!, extFlash: isTargetExternFlash, startAddr: address)
                }else{
                    showStatusTextToast(text:"input valid write address")
                }
            }
        }
    }
    
    @IBAction func cancelButtonClicked(_ sender: Any) {
        if let easyDfu2 = mEasyDfu2 {
            easyDfu2.cancel()
        }
        if let fastDfu = mFastDfu {
            fastDfu.cancel()
        }
    }
    
    func colorNavigationBar() -> Void {
        self.navigationController?.navigationBar.barTintColor = UIColor.systemBlue
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        if #available(iOS 15.0, *) {
                    let appearnce = UINavigationBarAppearance()
                    appearnce.configureWithOpaqueBackground()
                    appearnce.backgroundColor = UIColor.systemBlue
            appearnce.titleTextAttributes = [NSAttributedString.Key.foregroundColor:UIColor.white]
            self.navigationController?.navigationBar.standardAppearance = appearnce
            self.navigationController?.navigationBar.scrollEdgeAppearance = appearnce
        }

        let rightBarButtonItem = UIBarButtonItem(title: "About", style: .plain, target: self, action: #selector(aboutButtonClicked))
        self.navigationItem.rightBarButtonItem = rightBarButtonItem;
    }
    
    func onSelectedPeripheral(_ sender: SimpleBleScannerVC, _ peripheral: CBPeripheral, _ name: String) {
        mSelectedDevice = peripheral
        mDeviewName.text = name
    }
    
    func documentBrowser(_ controller: UIDocumentBrowserViewController, didPickDocumentsAt documentURLs: [URL]) {
        if !documentURLs.isEmpty {
            let fileUrl = documentURLs[0];
            if fileUrl.startAccessingSecurityScopedResource() {
                let file = NSFileCoordinator();
                file.coordinate(readingItemAt: fileUrl, error: NSErrorPointer(nil)) { URL in
                    mSelectedFileData = try! Data(contentsOf: URL);
                    mFileNameLabel.text = fileUrl.lastPathComponent
                }
                fileUrl.stopAccessingSecurityScopedResource();
            }
        }
        controller.dismiss(animated: true);
    }
 
    //MARK : ComxLogRowProtocal
    func logRaw(timestamp: TimeInterval, _ level: ComxLogLevel, _ tag: String, _ msg: String, _ logStr: String?) {
        if let logText = logStr{
            mLogBuffer.append(logText + "\n")
        }
    }
}

