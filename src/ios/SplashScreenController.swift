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
//        let imagePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0].appending("/ad_image.png")
//        if let image = UIImage(contentsOfFile: imagePath) {
//            adImageView?.image = image
//        }
        adImageView?.image = UIImage(named: "AppIcon")  // for test
    }
}
