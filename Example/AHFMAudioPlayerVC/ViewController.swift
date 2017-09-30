//
//  ViewController.swift
//  AHFMAudioPlayerVC
//
//  Created by Andy Tong on 8/1/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import AHServiceRouter
import AHFMAudioPlayerManager
import AHFMAudioPlayerVCManager
import AHFMAudioPlayerVCServices

class ViewController: UIViewController {
    var flag = false
    override func viewDidLoad() {
        super.viewDidLoad()
        AHFMAudioPlayerManager.activate()
        AHFMAudioPlayerVCManager.activate()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let info = [AHFMAudioPlayerVCServices.keyTrackId: 22700]
        AHServiceRouter.navigateVC(AHFMAudioPlayerVCServices.service, taskName: AHFMAudioPlayerVCServices.taskNavigation, userInfo: info, type: .push(navVC: self.navigationController!), completion: nil)
        
    }

}
