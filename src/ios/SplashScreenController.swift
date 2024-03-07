//
//  SplashScreenController.swift
//  Hogangnono
//
//  Created by Rad Kim on 3/4/24.
//

import Foundation
import UIKit

class SplashScreenController : UIViewController{
    @IBOutlet weak var adImageView: UIImageView!

    override func viewDidLoad() {
        print("[RAD] SplashScreenController - viewDidLoad+++")
        super.viewDidLoad()
        
        // 광고 이미지 표시 여부 결정
         if shouldSplashScreenAd() {
             loadAndSplashScreenAdImage()
         }
     }
         
    /**
     * 광고 이미지 표시 여부를 결정하는 함수
     * - UserDefaults에 저장된 광고 begin과 end을 비교하여 현재 시간이 광고 기간에 속하는지 확인
     */
    private func shouldSplashScreenAd() -> Bool {
        guard let firstAdItemData = UserDefaults.standard.object(forKey: "SplashAdItem") as? [String: Any],
              let beginString = firstAdItemData["begin"] as? String,
              let endString = firstAdItemData["end"] as? String else {return false}
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        guard let beginDate = dateFormatter.date(from: beginString),
              let endDate = dateFormatter.date(from: endString) else { return false }
        
        let now = Date() // 여기를 수정함
        return now >= beginDate && now <= endDate
    }
    
    /**
    * 광고 이미지를 불러와서 표시하는 함수
    * - UserDefaults에 저장된 이미지 파일 경로를 불러와서 이미지를 표시
    */
    private func loadAndSplashScreenAdImage() {
        // UserDefaults에서 이미지 파일 경로 불러오기
        if let imagePath = UserDefaults.standard.string(forKey: "SplashScreenImageLocalPath"),
           let image = UIImage(contentsOfFile: imagePath) {
            print("[RAD] SplashScreenController - imagePath:\(imagePath)")
            self.adImageView.image = image
        } else {
            // 파일이 존재하지 않는 경우의 처리
            print("[RAD] SplashScreenController - No ad image found or invalid path")
        }
    }

}
