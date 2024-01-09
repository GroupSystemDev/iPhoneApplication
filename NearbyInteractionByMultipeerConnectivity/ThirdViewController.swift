//
//  ThirdViewController.swift
//  NearbyInteractionByMultipeerConnectivity
//
//  Created by 黒川龍之介 on 2024/01/08.
//

import UIKit
import os.log

class ThirdViewController: UIViewController {
    let logger = os.Logger(subsystem: "com.example.apple-samplecode.NINearbyAccessorySample", category: "AccessoryDemoViewController")
    @IBOutlet weak var LabelA:UILabel!
    @IBOutlet weak var LabelB:UILabel!
    @IBOutlet weak var LabelC:UILabel!
    @IBOutlet weak var LabelD:UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    @IBAction func update() {
        Task { @MainActor in
            try await fetchData()
        }
    }
    
    func fetchData() async throws {
        
        var urlComponents = URLComponents(string: "http://18.183.185.52:8080/vacancies")!
        let decoder = JSONDecoder()
        let request = URLRequest(url: urlComponents.url!)
        let (data, response) = try await URLSession.shared.data(for: request)
        print(String(data: data, encoding: .utf8))
        guard let decodeData = try? decoder.decode(ParkingDataChild.self, from: data) else {
            print("error")
            return
        }
        
        logger.info("\(data)")
        logger.info("###")
        print(decodeData)
        print(data)
//        logger.info(decodeData)
        
//        // APIエンドポイントのURLを指定します
//        let apiUrl = URL(string: "http://18.183.185.52:8080/vacancies")!
//        
//        // URLセッションを作成します
//        let session = URLSession.shared
//        
//        // リクエストを作成します
//        let request = URLRequest(url: apiUrl)
//        
//        let (data, _) = try await URLSession.shared.data(from: url)
//        
//        // リクエストを送信し、データを取得します
//        let task = session.dataTask(with: request) { (data, response, error) in
//            if let error = error {
//                print("エラー: \(error.localizedDescription)")
//                return
//            }
//            
//            if let data = data {
//                // レスポンスデータを文字列に変換して表示します
//                if let responseString = String(data: data, encoding: .utf8) {
//                    print("レスポンスデータ: \(responseString)")
//                }
//                let decoder = JSONDecoder()
//                let parkingData = try decoder.decode(ParkingData.self, from: data)
//            }
//        }
//        
//        // タスクを実行します
//        task.resume()
    }
}

struct ParkingDataChild: Decodable {
    let parking_area: String
    let status: String
    let created_at: String
    let update_at: String
}
struct ParkingData: Decodable {
    var parkingdatas: [ParkingData]
}
