//
//  MainViewController.swift
//  OpenLive
//
//  Created by GongYuhua on 2/20/16.
//  Copyright © 2016 Agora. All rights reserved.
//

import Cocoa

class MainViewController: NSViewController {
    
    @IBOutlet weak var roomInputTextField: NSTextField!
    
    var videoProfile = AgoraRtcVideoProfile._VideoProfile_360P
    private var agoraKit: AgoraRtcEngineKit!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.whiteColor().CGColor
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        roomInputTextField.becomeFirstResponder()
    }
    
    override func prepareForSegue(segue: NSStoryboardSegue, sender: AnyObject?) {
        guard let segueId = segue.identifier where !segueId.isEmpty else {
            return
        }
        
        if segueId == "mainToSettings" {
            let settingsVC = segue.destinationController as! SettingsViewController
            settingsVC.videoProfile = videoProfile
            settingsVC.delegate = self
        } else if segueId == "mainToLive" {
            let liveVC = segue.destinationController as! LiveRoomViewController
            liveVC.roomName = roomInputTextField.stringValue
            liveVC.videoProfile = videoProfile
            if let value = sender as? NSNumber, let role = AgoraRtcClientRole(rawValue: value.integerValue) {
                liveVC.clientRole = role
            }
            liveVC.delegate = self
        }
    }
    
    //MARK: - user actions
    @IBAction func doJoinAsAudienceClicked(sender: NSButton) {
        guard let roomName = roomInputTextField?.stringValue where !roomName.isEmpty else {
            return
        }
        joinWithRole(.ClientRole_Audience)
    }
    
    @IBAction func doJoinAsBroadcasterClicked(sender: NSButton) {
        guard let roomName = roomInputTextField?.stringValue where !roomName.isEmpty else {
            return
        }
        joinWithRole(.ClientRole_Broadcaster)
    }
    
    @IBAction func doSettingsClicked(sender: NSButton) {
        performSegueWithIdentifier("mainToSettings", sender: nil)
    }
}

private extension MainViewController {
    func joinWithRole(role: AgoraRtcClientRole) {
        performSegueWithIdentifier("mainToLive", sender: NSNumber(integer: role.rawValue))
    }
}

extension MainViewController: SettingsVCDelegate {
    func settingsVC(settingsVC: SettingsViewController, closeWithProfile profile: AgoraRtcVideoProfile) {
        videoProfile = profile
        settingsVC.view.window?.contentViewController = self
    }
}

extension MainViewController: LiveRoomVCDelegate {
    func liveRoomVCNeedClose(liveVC: LiveRoomViewController) {
        guard let window = liveVC.view.window else {
            return
        }
        
        if window.styleMask & NSFullScreenWindowMask == NSFullScreenWindowMask {
            window.toggleFullScreen(nil)
        }
        
        window.styleMask |= NSFullSizeContentViewWindowMask | NSMiniaturizableWindowMask
        window.delegate = nil
        window.collectionBehavior = .Default

        window.contentViewController = self
    }
}
