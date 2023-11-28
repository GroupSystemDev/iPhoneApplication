//
//  ViewController.swift
//  NearbyInteractionByMultipeerConnectivity
//
//  Created by AM2190 on 2021/11/17.
//

import UIKit
import MultipeerConnectivity
import NearbyInteraction
import CoreBluetooth

class ViewController: UIViewController {
    // MARK: - NearbyInteractionで使う変数
    var niSession: NISession?
    var myTokenData: Data?

    //  MARK: - Core Bluetoothで使う変数
    var peripheralManager: CBPeripheralManager!
    let tokenServiceUUID: CBUUID = CBUUID(string:"2AC0B600-7C0C-4C9D-AB71-072AE2037107")
    let appleWatchTokenCharacteristicUUID: CBUUID = CBUUID(string:"2AC0B601-7C0C-4C9D-AB71-072AE2037107")
    let iPhoneTokenCharacteristicUUID: CBUUID = CBUUID(string:"2AC0B602-7C0C-4C9D-AB71-072AE2037107")
    var tokenService: CBMutableService?
    var appleWatchTokenCharacteristic: CBMutableCharacteristic?
    var iPhoneTokenCharacteristic: CBMutableCharacteristic?
    
    // MARK: - CSVファイル
    var file: File!
    
    // MARK: - IBOutlet instances
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var directionXLabel: UILabel!
    @IBOutlet weak var directionYLabel: UILabel!
    @IBOutlet weak var directionZLabel: UILabel!
    
    // MARK: - UI lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if niSession != nil {
            return
        }
        setupNearbyInteraction()
        setupCoreBluetooth()
        file = File.shared
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        peripheralManager.stopAdvertising()
        super.viewWillDisappear(animated)
    }
    
    // MARK: - Nearby Interactionの設定
    func setupNearbyInteraction() {
        // Nearby Interactionがサポートされているか確認
        guard NISession.isSupported else {
            print("This device doesn't support Nearby Interaction.")
            return
        }
        // セッションの定義
        niSession = NISession()
        niSession?.delegate = self
        
        // トークンの作成
        guard let token = niSession?.discoveryToken else {
            return
        }
        myTokenData = try! NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }
    // MARK: - Core Bluetoothの設定
    func setupCoreBluetooth() {
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        appleWatchTokenCharacteristic = CBMutableCharacteristic(type: appleWatchTokenCharacteristicUUID,
                                                                properties: [.write], value: nil,
                                                                permissions: [.writeable])
        iPhoneTokenCharacteristic = CBMutableCharacteristic(type: iPhoneTokenCharacteristicUUID,
                                                            properties: [.read], value: myTokenData,
                                                            permissions: [.readable])
        // serviceの作成
        tokenService = CBMutableService(type: tokenServiceUUID, primary: true)
        // serviceにcharacteristicsを追加
        tokenService?.characteristics = [appleWatchTokenCharacteristic!, iPhoneTokenCharacteristic!]
    }
}

// MARK: - NISessionのデリゲートを設定
extension ViewController: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        var stringData = ""
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }
        
        if let distance = accessory.distance {
            distanceLabel.text = distance.description
            stringData += distance.description
        }else {
            distanceLabel.text = "-"
        }
        stringData += ","
        
        
        if let direction = accessory.direction {
            directionXLabel.text = direction.x.description
            directionYLabel.text = direction.y.description
            directionZLabel.text = direction.z.description
            
            stringData += direction.x.description + ","
            stringData += direction.y.description + ","
            stringData += direction.z.description
        }else {
            directionXLabel.text = "-"
            directionYLabel.text = "-"
            directionZLabel.text = "-"
        }
        
        stringData += "\n"
        file.addDataToFile(rowString: stringData)
    }
    
}

// MARK: - Core Bluetoothのペリフェラル用デリゲート
extension ViewController: CBPeripheralManagerDelegate, CBPeripheralDelegate {
    // BLEの状態による処理
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        switch peripheral.state {
            // BLE通信している場合
        case .poweredOn:
            print("CBManager state is powered on")
            // ペリフェラルマネージャーにサービストークンを追加
            peripheralManager.add(tokenService!)
            // アドバタイズを開始
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [tokenServiceUUID]])
            stateLabel.text = "CoreBluetooth is start advertising"
            print("Start Advertising")
            // BLE通信してない場合
        default:
            print("CBManager state is \(peripheral.state)")
            return
        }
    }
    // Readコマンドの要求が来る時に呼ばれるメソッド
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid.isEqual(iPhoneTokenCharacteristicUUID) {
            // characteristicの読み込み
            if let value = iPhoneTokenCharacteristic?.value {
                if request.offset > value.count {
                    peripheral.respond(to: request, withResult: CBATTError.invalidOffset)
                    print("Read fail: invalid offset")
                    return
                }
                request.value = value.subdata(in: Range(uncheckedBounds: (request.offset, value.count)))
                peripheral.respond(to: request, withResult: CBATTError.success)
            }
        }else {
            print("Read fail: wrong characteristic uuid:", request.characteristic.uuid)
        }
    }
    // Writeコマンドの要求が来た時に呼ばれるメソッド
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if request.characteristic.uuid.isEqual(appleWatchTokenCharacteristicUUID) {
                guard let value = request.value else {
                    print("characteristic's value is nil")
                    return
                }
                appleWatchTokenCharacteristic?.value = value
                peripheralManager.respond(to: request, withResult: CBATTError.success)
                
                guard let appleWatchToken = try! NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: value) else {
                    print("AppleWatch's DiscoverToken is nil")
                    return
                }
                // UWBのトークンを渡してる
                let config = NINearbyPeerConfiguration(peerToken: appleWatchToken)
                // UWBセッションの開始
                niSession?.run(config)
                file.createFile(connectedDeviceName: "AppleWatch")
                print("NearbyInteraction session is running")
                stateLabel.text = "NearbyInteraction Session is start running"
            }else {
                print("Read fail: wrong characteristic uuid:", request.characteristic.uuid)
            }
        }
    }
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Failed to advertise: \(error.localizedDescription)")
        } else {
            print("Advertising started")
        }
    }
}
