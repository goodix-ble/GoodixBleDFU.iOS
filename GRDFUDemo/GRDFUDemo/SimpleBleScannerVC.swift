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

private class ScanResult {
    var name:String? = nil;
    var peripheral:CBPeripheral? = nil;
    var rssi:Int = 0;
    var rssiSum:Int = 0;
    var rssiCnt:Int = 0;
    var rssiAvg:Int = 0;
}

public protocol SimpleBleScannerProtocol {
    func onSelectedPeripheral(_ sender:SimpleBleScannerVC, _ peripheral:CBPeripheral, _ name:String);
}

public class SimpleBleScannerVC: UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, UITextFieldDelegate {
    public var showFilterViews : Bool = false //设为true时，扫描界面将支持按名称或RRSI过滤
    public var bleMgr:CBCentralManager? = nil;
    public var miniRssi = -90;     //扫描支持的最的RSSI值
    public var nameFilter:String? = nil; //扫描指定的设备名称
    public var delegate:SimpleBleScannerProtocol? = nil;

    @IBOutlet weak var rssiFilterLabel: UILabel!
    @IBOutlet weak var resultTableView: UITableView!
    @IBOutlet weak var scanBtn: UIButton!
    @IBOutlet weak var nameInputTF: UITextField!
    @IBOutlet weak var rssiValueLabel: UILabel!
    @IBOutlet weak var nameFilterLabel: UILabel!
    @IBOutlet weak var rssiValueSlider: UISlider!

    let ITEM_IDENTIFIER = "ble_device";

    private var backupBleMgrDelegate:CBCentralManagerDelegate? = nil;
    private var resultMap:[UUID:ScanResult] = [:];
    private var resultList:[ScanResult] = [];
    private var scanDeviceNotInOnState : Bool = false; //第1次扫描时，可能蓝牙还未ON，所以扫不到设备。
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        rssiValueSlider.minimumValue = -127;
        rssiValueSlider.maximumValue = 0;
        rssiValueSlider.value = Float(miniRssi);
        rssiValueLabel.text = "\(miniRssi)dbm";
        if nameFilter != nil {
            nameInputTF.text = nameFilter;
        }

        if (!showFilterViews){
            rssiValueSlider.isHidden = true
            rssiValueLabel.isHidden = true
            nameInputTF.isHidden = true
            nameFilterLabel.isHidden = true
            rssiFilterLabel.isHidden = true
            if let listView = resultTableView{
                let bottom:NSLayoutConstraint = NSLayoutConstraint(item: listView, attribute: NSLayoutConstraint.Attribute.bottom, relatedBy:NSLayoutConstraint.Relation.equal, toItem:scanBtn, attribute:NSLayoutConstraint.Attribute.top, multiplier:1.0, constant: -20)
                resultTableView.superview!.addConstraint(bottom)
            }
        }

        /* auto scanning 2 times for getting devices completely */
        onClickScanBtn(scanBtn) //start scanning 1st time
        scanBtn.isHidden = true
        Timer.scheduledTimer(withTimeInterval: TimeInterval(1), repeats: false, block:{(timer: Timer) -> Void in
            self.onClickScanBtn(self.scanBtn) //stop scaning for the 1st time
            self.scanBtn.isHidden = false
            self.onClickScanBtn(self.scanBtn)//start scaning for the 2nd time
        })
    }

    public override func viewDidAppear(_ animated: Bool) {
        if bleMgr == nil {
            bleMgr = CBCentralManager(delegate: self, queue: nil);
        } else {
            backupBleMgrDelegate = bleMgr!.delegate;
            bleMgr!.delegate = self;
        }
        
        scanBtn.isEnabled = bleMgr!.state == .poweredOn;
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        if let ble = self.bleMgr {
            if ble.isScanning {
                ble.stopScan();
                scanBtn.setTitle("SCAN", for: .normal);
                enableUI(true);
            }
            
            if let bak = backupBleMgrDelegate {
                ble.delegate = bak;
                backupBleMgrDelegate = nil;
            }
        }
    }

    public class func make(_ delegate:SimpleBleScannerProtocol?, _ reusedCentralManager:CBCentralManager?) -> SimpleBleScannerVC {
        let sb = UIStoryboard(name: "SimpleBleScanner", bundle: nil);
        let vc = sb.instantiateViewController(withIdentifier: "SimpleBleScanner") as! SimpleBleScannerVC;
        vc.delegate = delegate;
        vc.bleMgr = reusedCentralManager;
        return vc;
    }
    
    public class func show(_ from:UIViewController) -> SimpleBleScannerVC {
        let vc = make(nil, nil);
        from.present(vc, animated: true);
        return vc;
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        scanBtn.isEnabled = (central.state == .poweredOn);
        if (self.scanDeviceNotInOnState && (self.bleMgr?.isScanning ?? false) && (central.state == .poweredOn)){
            self.scanDeviceNotInOnState = false;
            self.bleMgr?.stopScan();
            self.bleMgr?.scanForPeripherals(withServices: nil);
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let devId = peripheral.identifier;
        let rssi = Int(truncating: RSSI);

        // 需要及时取出广播中的名称，peripheral.name中的名字是固定的
        var name = advertisementData[CBAdvertisementDataLocalNameKey] as! String?;
        if name == nil {
            name = peripheral.name;
        }
        if name == nil {
            name = "NULL";
        }

        var foundResult = resultMap[devId];

        // 不存在时才判断是否能加入到列表
        if foundResult == nil {
            if rssi < miniRssi {
                return;
            }

            if let nameFilter = self.nameFilter {
                if name == nil || !(name!.contains(nameFilter)) {
                    return;
                }
            }
            
            foundResult = ScanResult();
            foundResult!.name = name;
            foundResult!.peripheral = peripheral
            resultMap[devId] = foundResult!;
            resultList.append(foundResult!)
        }

        let scanResult = foundResult!;
        scanResult.rssi = rssi;
        scanResult.rssiCnt += 1;
        scanResult.rssiSum += rssi;
        scanResult.rssiAvg = scanResult.rssiSum / scanResult.rssiCnt;
        // resort
        resultList.sort { o1, o2 in
            return o1.rssi > o2.rssi;
        }
        // update
        resultTableView.reloadData();
        
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultList.count;
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: ITEM_IDENTIFIER);
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: ITEM_IDENTIFIER);
        }
        let item = resultList[indexPath.row];
        cell!.textLabel!.text = item.name ?? "NULL";
        cell!.detailTextLabel!.text = "\(item.rssi) dbm  \(item.peripheral!.identifier.uuidString)";
        return cell!;
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectItem = resultList[indexPath.row];
        dismiss(animated: true);
        delegate?.onSelectedPeripheral(self, selectItem.peripheral!, selectItem.name!);
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(false);
        return true;
    }

    @IBAction func onRssiSliderChanged(_ sender: UISlider) {
        miniRssi = Int(rssiValueSlider.value);
        rssiValueLabel.text = "\(miniRssi)dbm";
    }

    @IBAction func onClickScanBtn(_ sender: UIButton) {
        if let ble = self.bleMgr {
            if ble.isScanning {
                ble.stopScan();
                sender.setTitle("SCAN", for: .normal);
                enableUI(true);
            } else {
                resultMap.removeAll(keepingCapacity: true);
                resultList.removeAll(keepingCapacity: true);
                if let nameInput = nameInputTF.text {
                    if nameInput.isEmpty {
                        nameFilter = nil;
                    } else {
                        nameFilter = nameInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines);
                    }
                } else {
                    nameFilter = nil;
                }
                miniRssi = Int(rssiValueSlider.value);

                ble.scanForPeripherals(withServices: nil);
                self.scanDeviceNotInOnState = (self.bleMgr?.state == CBManagerState.unknown);

                sender.setTitle("STOP", for: .normal);
                enableUI(false);
                resultTableView.reloadData();
            }
        }
    }
    
    func enableUI(_ enable:Bool) {
        rssiValueSlider.isEnabled = enable;
        nameInputTF.isEnabled = false;
    }
}
