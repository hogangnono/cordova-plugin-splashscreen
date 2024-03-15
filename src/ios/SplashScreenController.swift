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
        super.viewDidLoad()
        
        // 광고 이미지 표시 여부 결정
        if shouldSplashScreenAd() {
            loadAndSplashScreenAdImage()
        } else {
            UserDefaults.standard.set(false, forKey: "isAdDisplayed")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        resizeAdImageView()
    }
         
    /**
     * 광고 이미지 표시 여부를 결정하는 함수
     * - UserDefaults에 저장된 광고 begin과 end을 비교하여 현재 시간이 광고 기간에 속하는지 확인
     */
    private func shouldSplashScreenAd() -> Bool {
        guard let beginString = UserDefaults.standard.object(forKey: "SplashBegin") as? String,
              let endString = UserDefaults.standard.object(forKey: "SplashEnd") as? String  else {return false}
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        guard let beginDate = dateFormatter.date(from: beginString),
              let endDate = dateFormatter.date(from: endString) else { return false }
        
        let now = Date() // 여기를 수정함
        return now >= beginDate && now <= endDate
    }
    
    /**
    * 광고 이미지를 불러와서 표시하는 함수
    * - Documents 경로에 파일을  불러와서 이미지를 표시
    */
    private func loadAndSplashScreenAdImage() {
        // Documents 폴더 경로 얻기
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imagePath = documentsPath.appendingPathComponent("splashAd.png").path // 파일 경로 조합
            
            // UIImage로 이미지 로드 시도
            if let image = UIImage(contentsOfFile: imagePath) {
                print("[SplashScreen] SplashScreenController - imagePath:\(imagePath)")
                self.adImageView.image = image

                let splashId = UserDefaults.standard.integer(forKey: "SplashId") // 숫자형으로 SplashId 가져오기
                if splashId != 0 { // SplashId가 0이 아니면, 즉, 유효한 경우에만 실행
                    UserDefaults.standard.set(true, forKey: "isAdDisplayed")
                    UserDefaults.standard.set(splashId, forKey: "displayedSplashId") // SplashId 저장
                } else {
                    print("[SplashScreen] SplashScreenController - SplashId not found or invalid")
                    UserDefaults.standard.set(false, forKey: "isAdDisplayed")
                }

            } else {
                // 파일이 존재하지 않거나 유효하지 않은 경우의 처리
                UserDefaults.standard.set(false, forKey: "isAdDisplayed")
                print("[SplashScreen] SplashScreenController - No ad image found or invalid path")
            }
        }
    }

    private func resizeAdImageView() {
        let isIPhone = (UIDevice.current.userInterfaceIdiom == .phone)
        let maxWidth = view.frame.size.width
        if (isIPhone && maxWidth < 360) {  // width 360 미만(iPhone SE) 대응
            let prevImageCenter = adImageView.center
            let WIDTH_320 = 320
            let HEIGHT_320 = 222
            let HEIGHT_360 = 250
            adImageView.frame = CGRect(x: 0, y: 0, width: WIDTH_320, height: HEIGHT_320)
            adImageView.center.x = prevImageCenter.x
            adImageView.center.y = prevImageCenter.y + CGFloat(((HEIGHT_360 - HEIGHT_320) / 2))
        }
    }
}
