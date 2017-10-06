//
//  ViewController.swift
//  AHFMAudioPlayerVC
//
//  Created by Andy Tong on 8/1/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import AHServiceRouter

import AHFMAudioPlayerVCServices
import AHFMBottomPlayerServices

import AHFMAudioPlayerManager
import AHFMAudioPlayerVCManager
import AHFMHistoryVCManager
import AHFMBottomPlayerManager
import AHFMEpisodeListVCManager

class ViewController: UIViewController {
    var flag = false
    override func viewDidLoad() {
        super.viewDidLoad()
        AHFMAudioPlayerManager.activate()
        AHFMAudioPlayerVCManager.activate()
        AHFMBottomPlayerManager.activate()
        AHFMHistoryVCManager.activate()
        AHFMEpisodeListVCManager.activate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let dict: [String: Any] = [AHFMBottomPlayerServices.keyShowPlayer: true, AHFMBottomPlayerServices.keyParentVC: self]
        AHServiceRouter.doTask(AHFMBottomPlayerServices.service, taskName: AHFMBottomPlayerServices.taskDisplayPlayer, userInfo: dict, completion: nil)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let info = [AHFMAudioPlayerVCServices.keyTrackId: 22700]
        AHServiceRouter.navigateVC(AHFMAudioPlayerVCServices.service, taskName: AHFMAudioPlayerVCServices.taskNavigation, userInfo: info, type: .push(navVC: self.navigationController!), completion: nil)
        
    }

}
