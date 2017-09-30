//
//  AHFMAudioPlayerVC.swift
//  Pods
//
//  Created by Andy Tong on 7/16/17.
//
//

import UIKit
import StringExtension
import AHAudioPlayer
import AHBannerView
import AHProgressSlider
import UIImageExtension
import SDWebImage

@objc public protocol AHFMAudioPlayerManagerDelegate: class {
    
    func audioPlayerVCListBarTapped(_ vc: AHFMAudioPlayerVC, trackId: Int, albumnId: Int)
    func audioPlayerVCAlbumnCoverTapped(_ vc: AHFMAudioPlayerVC, atIndex index:Int, trackId: Int, albumnId: Int)
    
    /// When the data is ready, call reload()
    func audioPlayerVCFetchInitialTrack(_ vc: AHFMAudioPlayerVC)
    func audioPlayerVCFetchTrack(_ vc: AHFMAudioPlayerVC, trackId: Int)
    func audioPlayerVCFetchNextTrack(_ vc: AHFMAudioPlayerVC, trackId: Int, albumnId: Int)
    func audioPlayerVCFetchPreviousTrack(_ vc: AHFMAudioPlayerVC, trackId: Int, albumnId: Int)
}

// The minimum seconds that lastPlayedTime has to reach to make audioPlayVC to play for it.
private let minimumLastPlayedSections: Double = 10.0

public struct AHFMAudioPlayerVCPlayerItem {
    public var albumnId: Int
    public var trackId: Int
    public var audioURL: String
    public var fullCover: String?
    public var thumbCover: String?
    
    public var albumnTitle: String?
    public var trackTitle: String?
    public var duration: TimeInterval?
    
    public var lastPlayedTime: TimeInterval?
    
    public init(dict: [String: Any]) {
        self.albumnId = dict["albumnId"] as! Int
        self.trackId = dict["trackId"] as! Int
        
        self.audioURL = dict["audioURL"] as! String
        
        self.fullCover = dict["fullCover"] as? String
        self.thumbCover = dict["thumbCover"] as? String
        
        self.albumnTitle = dict["albumnTitle"] as? String
        self.trackTitle = dict["trackTitle"] as? String
        self.duration = dict["duration"] as? TimeInterval
        self.lastPlayedTime = dict["lastPlayedTime"] as? TimeInterval
    }
}


public class AHFMAudioPlayerVC: UIViewController {
    @IBOutlet weak var shareBtn: UIButton!
    @IBOutlet weak var backBtn: UIButton!
    @IBOutlet weak var bgImg: UIImageView!
    @IBOutlet weak var nextBtn: UIButton!
    @IBOutlet weak var moreBtn: UIButton!
    @IBOutlet weak var listBar: UIButton!
    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var previousBtn: UIButton!
    @IBOutlet weak var progressSlider: AHProgressSlider!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var bannerView: AHBannerView!
    @IBOutlet weak var fastBackBtn: UIButton!
    
    @IBOutlet weak var fastForwardBtn: UIButton!
    @IBOutlet weak var rateBtn: UIButton!
    @IBOutlet weak var showTitleView: AHShowTitleView!
    
    public var manager: AHFMAudioPlayerManagerDelegate?
    
    public var playerItem: AHFMAudioPlayerVCPlayerItem?
    
    fileprivate var notificationHandlers = [NSObjectProtocol]()
    
    fileprivate var timer: Timer?

    // Should seek to play to lastPlayedTime or not
    fileprivate var playLastTimeMode = false
    
    /// Should the timer update slider or not
    fileprivate var shouldUpdateSlider = true
    
    /// Those two colors are for startTimeLabel and DuratinLabel
    fileprivate var labelNormalColor = UIColor.white
    fileprivate var labelSelectedColor = UIColor.red

    fileprivate var currentRateSpeed: AHAudioRateSpeed {
        return AHAudioPlayerManager.shared.rate
    }
    
    
    fileprivate var bannerBarStyle: AHBannerStyle?
    
    ///########## VC Class Related
    public init() { // programatic initializer
        let bundle = Bundle(for: type(of: self))
        super.init(nibName: "\(type(of: self))", bundle: bundle)
    }
    
    required public init?(coder aDecoder: NSCoder) { // storyboard initializer
        /*
         if override this method like:
         let bundle = Bundle(for: AHFMPlayerView.self)
         super.init(nibName: "AHFMPlayerView", bundle: bundle)
         then the navigation bar is not shown.
         not a good override
         */
        super.init(coder: aDecoder)
        let bundle = Bundle(for: type(of: self))
        let xibView = bundle.loadNibNamed("\(type(of: self))", owner: self, options: nil)!.first as! UIView
        self.view = xibView
    }
    
    
    deinit {
        for handler in notificationHandlers{
            NotificationCenter.default.removeObserver(handler)
        }
    }
    
}

//MARK:- Public API
extension AHFMAudioPlayerVC {
    /// Should be called when data is ready
    public func reload(_ data: [String: Any]?) {
        guard let data = data else {
            return
        }
        self.playerItem = AHFMAudioPlayerVCPlayerItem(dict: data)
        setupModel()
        setupAudioPlayer()
    }
}


//MARK:- VC Life Cycle
extension AHFMAudioPlayerVC {
    override open func viewDidLoad() {
        super.viewDidLoad()
        // This is to prevent the bgImg getting laggy during push animation.
        self.view.clipsToBounds = true
        
        setup()
        setupUI()
        
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        manager?.audioPlayerVCFetchInitialTrack(self)
        fireTimer()
    }
    
    /// This is the point where the currentEpisode/currentShow gets ready and can be played.
    fileprivate func setupAudioPlayer() {
        guard let playerItem = self.playerItem else {
            return
        }
        let trackId = playerItem.trackId
        
        if AHAudioPlayerManager.shared.state == .playing {
            if let playingTrackId = AHAudioPlayerManager.shared.playingTrackId,trackId == playingTrackId{
                // player is playing the same track, ignore
                self.playBtn.isSelected = true
                return
            }
        }else{
            self.playBtn.isSelected = false
        }
        
        // here, the player is either, playing different track or pausing for save track in playerItem.
        
        if AHAudioPlayerManager.shared.state == .paused,
            let playingTrackId = AHAudioPlayerManager.shared.playingTrackId,
            trackId == playingTrackId{
            
            self.shouldUpdateSlider = false
            self.playBtn.isSelected = false
            return
        }
        
        
        // 1. pausing different track. 
        // 2. playing different track.
        // We ignore the one playing in the player, and play our current track.
        
        if let lastPlayedTime = playerItem.lastPlayedTime, let duration = playerItem.duration {
            // the track has cached progress, lastPlayedTime.
            
            self.shouldUpdateSlider = false
            self.playBtn.isSelected = true
            
            let percent = lastPlayedTime / duration
            
            guard percent > 1.0 else {
                print("ERROR trackId:\(trackId): lastPlayedTime is bigger than duration")
                return
            }
            
            self.playLastTimeMode = true
            self.progressSlider.value = Float(percent)
            
        }else{
            // no lastPlayedTime, play from beginning
        }
        
        
        playBtnTapped(playBtn)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
    }
    
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    
}


//MARK:- Event Handling
extension AHFMAudioPlayerVC {
    @IBAction func speedBtnTapped(_ sender: UIButton) {
        AHAudioPlayerManager.shared.changeToNextRate()
        let speedStr = "\(AHAudioPlayerManager.shared.rate.rawValue)x"
        rateBtn.setTitle(speedStr, for: .normal)
    }
    
    @IBAction func backBtnTapped(_ sender: UIButton) {
        if self.navigationController == nil {
            self.dismiss(animated: true, completion: nil)
        }else{
            self.navigationController?.popViewController(animated: true)
        }
    }
    @IBAction func shareBtnTapped(_ sender: UIButton) {
        
    }
    @IBAction func moreBtnTapped(_ sender: UIButton) {
        
    }
    @IBAction func listBarTapped(_ sender: UIButton) {
        guard let playerItem = self.playerItem else {
            return
        }
        manager?.audioPlayerVCListBarTapped(self, trackId: playerItem.trackId, albumnId: playerItem.albumnId)
    }
    @IBAction func fastBackTapped(_ sender: Any) {
        AHAudioPlayerManager.shared.seekBackward()
    }
    @IBAction func fastForwardTapped(_ sender: UIButton) {
        AHAudioPlayerManager.shared.seekForward()
    }
    @IBAction func playBtnTapped(_ sender: UIButton) {
        guard let playerItem = self.playerItem else {
            return
        }
        let trackId = playerItem.trackId
        
        if let playingTrackId = AHAudioPlayerManager.shared.playingTrackId,
            trackId == playingTrackId {
                
                if AHAudioPlayerManager.shared.state == .playing {
                    sender.isSelected = false
                    pause()
                }else{
                    sender.isSelected = true
                    resume()
                }
            
        }else{
            // not the same track, play this current one anyway, at the chosen progress from the slider though.
            AHAudioPlayerManager.shared.stop()
            play()
        }
        
        
    }
    @IBAction func previousBtnTapped(_ sender: UIButton) {
        guard let playerItem = self.playerItem else {
            return
        }
        self.playBtn.isSelected = true
        AHAudioPlayerManager.shared.stop()
        self.manager?.audioPlayerVCFetchPreviousTrack(self, trackId: playerItem.trackId, albumnId: playerItem.albumnId)
    }
    @IBAction func nextBtnTapped(_ sender: UIButton) {
        guard let playerItem = self.playerItem else {
            return
        }
        
        self.playBtn.isSelected = true
        AHAudioPlayerManager.shared.stop()
        self.manager?.audioPlayerVCFetchNextTrack(self, trackId: playerItem.trackId, albumnId: playerItem.albumnId)
    }
    
    // should prevent the timer updating the slider
    @IBAction func sliderTouchDown(_ sender: UISlider) {
        shouldUpdateSlider = false
        startTimeLabel.textColor = labelSelectedColor
        // prevent progress slider mismatched while seeking
        pause()
    }
    
    @IBAction func sliderDragInside(_ sender: UISlider) {
        let duration = AHAudioPlayerManager.shared.duration
        guard duration > 0.0 else {
            return
        }
        guard sender.value >= 0.0 && sender.value <= 1.0 else {
            return
        }
        let seconds = Double(duration) * Double(sender.value)
        startTimeLabel.text = String.secondToTime(seconds)
    }
    @IBAction func progressDidChange(_ sender: UISlider) {
        shouldUpdateSlider = true
        startTimeLabel.textColor = labelNormalColor
        guard sender.value >= 0.0 && sender.value <= 1.0 else {
            return
        }
        guard let playerItem = self.playerItem else {
            return
        }
        let trackId = playerItem.trackId

        if self.playLastTimeMode {
            self.playLastTimeMode = false
        }
        
        if let playingTrackId = AHAudioPlayerManager.shared.playingTrackId {
            if trackId == playingTrackId {
                // player is playing the same track, seek and resume directly
                // seek first
                AHAudioPlayerManager.shared.seekToPercent(Double(sender.value))
                
                // it's already paused in sliderTouchDown(_:) above, for preventing slider jump to begining point.
                // resume here
                resume()
            }else{
                // not the same track, play this current one anyway, at the chosen progress from the slider though.
                AHAudioPlayerManager.shared.stop()
                play()
            }
        }
        
        
    }
}

//MARK:- Player Control
extension AHFMAudioPlayerVC {
    
    /// play from beginning if there's no lastPlayedTime
    func play() {
        guard let playerItem = self.playerItem else {
            return
        }
        guard let url = URL(string: playerItem.audioURL) else {
            print("playerItem url is nil")
            return
        }
        
        rateBtn.setTitle("\(AHAudioRateSpeed.one.rawValue)x", for: .normal)
        
        stop()
        var toTime: TimeInterval? = nil
        if let lastPlayedTime = playerItem.lastPlayedTime,
            let duration = playerItem.duration,
        lastPlayedTime > 0.0, duration > 0.0{
            toTime = lastPlayedTime
            
            self.playLastTimeMode = false

        }
        
        
        AHAudioPlayerManager.shared.play(trackId: playerItem.trackId, trackURL: url, toTime: toTime)
    }
    func pause() {
        AHAudioPlayerManager.shared.pause()
    }
    
    func stop() {
        AHAudioPlayerManager.shared.stop()
    }
    
    func resume() {
        AHAudioPlayerManager.shared.resume()
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // The purpose of overriding this method is to present touches passed through to parent viewControllers when presenting.
        // Do nothing.
    }
}

//MARK:- Helper Methods
extension AHFMAudioPlayerVC {
    func fireTimer() {
        if let timer = timer {
            timer.invalidate()
        }
        
        timer = Timer(timeInterval: 0.1, target: self, selector: #selector(updatePlayer), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .commonModes)
    }
    func updatePlayer() {
        guard let thisTrackId = self.playerItem?.trackId else {
            return
        }
        
        guard let thatTrackId = AHAudioPlayerManager.shared.playingTrackId else {
            return
        }
        
        guard thisTrackId == thatTrackId else {
            return
        }
        
        progressSlider.loadedProgress = CGFloat(AHAudioPlayerManager.shared.loadedProgress)
        if shouldUpdateSlider {
            progressSlider.value = Float(AHAudioPlayerManager.shared.progress)
            startTimeLabel.text = AHAudioPlayerManager.shared.currentTimePretty
            totalTimeLabel.text = AHAudioPlayerManager.shared.durationPretty
        }
        let speedStr = AHAudioPlayerManager.shared.rate.rawValue > 0 ? "\(AHAudioPlayerManager.shared.rate.rawValue)x" : "1.0x"
        rateBtn.setTitle(speedStr, for: .normal)
    }
    
}

//MARK:- Setups
extension AHFMAudioPlayerVC {
    func setup(){
        // add notifications for audioPlayer
        let changeStateHandler = NotificationCenter.default.addObserver(forName: AHAudioPlayerDidChangeState, object: nil, queue: nil) { (_) in
            
            if AHAudioPlayerManager.shared.state == .playing {
                if self.shouldUpdateSlider == false {
                    self.shouldUpdateSlider = true
                }
                self.playBtn.isSelected = true
            }else if AHAudioPlayerManager.shared.state == .paused {
                if self.playLastTimeMode {
                    return
                }
                self.playBtn.isSelected = false
            }
        }
        notificationHandlers.append(changeStateHandler)
        
        
        let switchPlayHanlder = NotificationCenter.default.addObserver(forName: AHAudioPlayerDidSwitchPlay, object: nil, queue: nil) { (_) in
            guard let playerItem = self.playerItem else {return}
            guard let trackId = AHAudioPlayerManager.shared.playingTrackId else {
                return
            }
            guard playerItem.trackId != trackId else{
                return
            }
            // audioPlayer now is playing next episode which could be from the same show or not
            self.manager?.audioPlayerVCFetchTrack(self, trackId: trackId)
        }
        notificationHandlers.append(switchPlayHanlder)
    }
    
    func setupUI() {
        
        // bannerBarStyle
        var bannerStyle = AHBannerStyle()
        bannerStyle.isInfinite = false
        bannerStyle.isPagingEnabled = true
        bannerStyle.showIndicator = false
        bannerStyle.showPageControl = true
        bannerStyle.isPageControlSeparated = true
        bannerStyle.bottomHeight = 20.0
        bannerStyle.pageControlSelectedColor = UIColor.white
        self.bannerBarStyle = bannerStyle
        
        bannerView.backgroundColor = UIColor.clear
        bannerView.delegate = self
        bannerView.alpha = 1.0
        
        
        // time labels
        startTimeLabel.textColor = labelNormalColor
        totalTimeLabel.textColor = labelNormalColor
        
        let thumbImg = UIImage(name: "player-thumb", user: self)
        progressSlider.value = 0.0
        progressSlider.setThumbImage(thumbImg, for: .normal)
        progressSlider.minimumTrackTintColor = UIColor.red
        progressSlider.isContinuous = false
        
        // bgImg
        bgImg.image = UIImage(name: "test-bg", user: self)
        
        // backBtn
        backBtn.setImage(UIImage(name: "back", user: self), for: .normal)
        
        // shareBtn
        shareBtn.setImage(UIImage(name: "share", user: self), for: .normal)
        
        // playBtn
        let playImg = UIImage(name: "play", user: self)
        let pauseImg = UIImage(name: "pause", user: self)
        playBtn.setImage(playImg, for: .normal)
        playBtn.setImage(pauseImg, for: .selected)
        
        // listBar
        let listBarImg = UIImage(name: "list-bar", user: self)
        listBar.setImage(listBarImg, for: .normal)
        
        // previousBtn
        let previousNormal = UIImage(name: "previous-normal", user: self)
        let previousDisable = UIImage(name: "previous-disable", user: self)
        previousBtn.setImage(previousNormal, for: .normal)
        previousBtn.setImage(previousDisable, for: .disabled)
        
        // nextBtn
        let nextNormal = UIImage(name: "next-normal", user: self)
        let nextDisable = UIImage(name: "next-disable", user: self)
        nextBtn.setImage(nextNormal, for: .normal)
        nextBtn.setImage(nextDisable, for: .disabled)
        
        // moreBtn
        let moreImg = UIImage(name: "more-dot", user: self)
        moreBtn.setImage(moreImg, for: .normal)
        
        
        // fastBack
        let fastbackImg = UIImage(name: "fast-backward", user: self)
        fastBackBtn.setImage(fastbackImg, for: .normal)
        
        // fastForward
        let fastForwardImg = UIImage(name: "fast-forward", user: self)
        fastForwardBtn.setImage(fastForwardImg, for: .normal)
        
        // showTitleView
        showTitleView.backgroundColor = UIColor.clear
        showTitleView.textColor = UIColor.white
    }
    
    fileprivate func setupModel() {
        guard let playerItem = self.playerItem else {
                return
        }
        
        showTitleView.title = playerItem.albumnTitle ?? ""
        showTitleView?.detail = playerItem.trackTitle ?? ""
        let url = URL(string: playerItem.fullCover ?? "")
        bgImg?.sd_setImage(with: url)
        setupBannerView()
    }
    
    func setupBannerView(){
        guard let barStyle = self.bannerBarStyle else {
            return
        }
        bannerView.setup(imageCount: 3, Style: barStyle) {[weak self] (imageView, index) in
            guard self != nil else {return}
            guard let playerItem = self?.playerItem else {return}
            
            if index == 1 {
                let image = UIImage(name: "shameless-ad", user: self!)
                imageView.image = image
                return
            }
            
            let urlStr = index == 0 ? playerItem.fullCover : playerItem.thumbCover
            let url = URL(string: urlStr ?? "")
            
            imageView.sd_setImage(with: url, completed: {[weak self] (image, _, _, _) in
                guard let strongSelf = self else {return}
                
                // check if this currently displaying banner imageView is for thisIndex
                let thisIndex = index
                guard thisIndex == self?.bannerView.index else {return}
                
                guard let image = image else {return}
                guard let bannerView = strongSelf.bannerView else {return}
                if image.size.height > bannerView.frame.height ||
                    image.size.width > bannerView.frame.width {
                    // if image is larger than the view, than scaleAspectFit
                    imageView.contentMode = .scaleAspectFit
                }else{
                    // if image is smaller than the view, than let it be
                    imageView.contentMode = .center
                }
                
                imageView.image = image
            })
            
        }
    }
}

extension AHFMAudioPlayerVC: AHBannerViewDelegate {
    public func bannerView(_ bannerView: AHBannerView, didTapped atIndex: Int){
        guard let playerItem = self.playerItem else {return}
        manager?.audioPlayerVCAlbumnCoverTapped(self, atIndex: atIndex, trackId: playerItem.trackId, albumnId: playerItem.albumnId)
    }
    public func bannerView(_ bannerView: AHBannerView, didSwitch toIndex: Int){
        
    }
}




















