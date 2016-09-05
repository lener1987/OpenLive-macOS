//
//  LiveRoomViewController.swift
//  OpenLive
//
//  Created by GongYuhua on 2/20/16.
//  Copyright © 2016 Agora. All rights reserved.
//

import Cocoa

protocol LiveRoomVCDelegate: NSObjectProtocol {
    func liveRoomVCNeedClose(liveVC: LiveRoomViewController)
}

class LiveRoomViewController: NSViewController {
    
    //MARK: IBOutlet
    @IBOutlet weak var roomNameLabel: NSTextField!
    @IBOutlet weak var remoteContainerView: NSView!
    @IBOutlet weak var muteAudioButton: NSButton!
    @IBOutlet weak var broadcastButton: NSButton!
    
    //MARK: public var
    var roomName: String!
    var clientRole = AgoraRtcClientRole.ClientRole_Audience {
        didSet {
            updateButtonsVisiablity()
        }
    }
    var videoProfile: AgoraRtcVideoProfile!
    var delegate: LiveRoomVCDelegate?
    
    //MARK: engine & session
    var rtcEngine: AgoraRtcEngineKit!
    private var isBroadcaster: Bool {
        return clientRole == .ClientRole_Broadcaster
    }
    private var isMuted = false {
        didSet {
            rtcEngine.muteLocalAudioStream(isMuted)
            muteAudioButton?.image = NSImage(named: isMuted ? "btn_mute_blue" : "btn_mute")
        }
    }
    private var videoSessions = [VideoSession]() {
        didSet {
            guard remoteContainerView != nil else {
                return
            }
            updateInterface()
        }
    }
    private var fullSession: VideoSession? {
        didSet {
            if fullSession != oldValue && remoteContainerView != nil {
                updateInterface()
            }
        }
    }
    private let viewLayouter = VideoViewLayouter()
    
    //MARK: - life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        roomNameLabel.stringValue = roomName
        updateButtonsVisiablity()
        
        loadAgoraKit()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.delegate = self
    }
    
    //MARK: - user action
    @IBAction func doMuteClicked(sender: NSButton) {
        isMuted = !isMuted
    }
    
    @IBAction func doBroadcastClicked(sender: NSButton) {
        if isBroadcaster {
            clientRole = .ClientRole_Audience
        } else {
            clientRole = .ClientRole_Broadcaster
        }
        
        rtcEngine.setClientRole(clientRole)
        updateInterface()
    }
    
    override func mouseUp(theEvent: NSEvent) {
        if theEvent.clickCount == 2 {
            if fullSession == nil {
                if let tappedSession = viewLayouter.reponseSessionOfEvent(theEvent, inSessions: videoSessions, inContainerView: remoteContainerView) {
                    fullSession = tappedSession
                }
            } else {
                fullSession = nil
            }
        }
    }
    
    @IBAction func doLeaveClicked(sender: NSButton) {
        leaveChannel()
    }
}

//MARK: - private
private extension LiveRoomViewController {
    func updateButtonsVisiablity() {
        broadcastButton?.image = NSImage(named: isBroadcaster ? "btn_join_cancel" : "btn_join")
        muteAudioButton?.hidden = !isBroadcaster
    }
    
    func leaveChannel() {
        rtcEngine.setupLocalVideo(nil)
        rtcEngine.leaveChannel(nil)
        if isBroadcaster {
            rtcEngine.stopPreview()
        }
        
        for session in videoSessions {
            session.hostingView.removeFromSuperview()
        }
        videoSessions.removeAll()
        
        delegate?.liveRoomVCNeedClose(self)
    }
    
    func alertEngineString(string: String) {
        alertString("Engine: \(string)")
    }
    
    func alertAppString(string: String) {
        alertString("App: \(string)")
    }
    
    func alertString(string: String) {
        guard !string.isEmpty else {
            return
        }
        
        let alert = NSAlert()
        alert.messageText = string
        alert.addButtonWithTitle("OK")
        alert.beginSheetModalForWindow(view.window!, completionHandler: nil)
    }
}

private extension LiveRoomViewController {
    func updateInterface() {
        var displaySessions = videoSessions
        if !isBroadcaster && !displaySessions.isEmpty {
            displaySessions.removeFirst()
        }
        viewLayouter.layoutSessions(displaySessions, fullSession: fullSession, inContainer: remoteContainerView)
        setStreamTypeForSessions(displaySessions, fullSession: fullSession)
    }
    
    func setStreamTypeForSessions(sessions: [VideoSession], fullSession: VideoSession?) {
        if let fullSession = fullSession {
            for session in sessions {
                rtcEngine.setRemoteVideoStream(UInt(session.uid), type: (session == fullSession ? .VideoStream_High : .VideoStream_Low))
            }
        } else {
            for session in sessions {
                rtcEngine.setRemoteVideoStream(UInt(session.uid), type: .VideoStream_High)
            }
        }
    }
    
    func addLocalSession() {
        let localSession = VideoSession.localSession()
        videoSessions.append(localSession)
        rtcEngine.setupLocalVideo(localSession.canvas)
    }
    
    func fetchSessionOfUid(uid: Int64) -> VideoSession? {
        for session in videoSessions {
            if session.uid == uid {
                return session
            }
        }
        
        return nil
    }
    
    func videoSessionOfUid(uid: Int64) -> VideoSession {
        if let fetchedSession = fetchSessionOfUid(uid) {
            return fetchedSession
        } else {
            let newSession = VideoSession(uid: uid)
            videoSessions.append(newSession)
            return newSession
        }
    }
}

//MARK: - Agora SDK
private extension LiveRoomViewController {
    func loadAgoraKit() {
        rtcEngine = AgoraRtcEngineKit.sharedEngineWithAppId(KeyCenter.AppId, delegate: self)
        rtcEngine.setChannelProfile(.ChannelProfile_LiveBroadcasting)
        rtcEngine.enableVideo()
        rtcEngine.enableDualStreamMode(true)
        rtcEngine.setVideoProfile(videoProfile)
        rtcEngine.setClientRole(clientRole)
        
        if isBroadcaster {
            rtcEngine.startPreview()
        }
        
        addLocalSession()
        
        let code = rtcEngine.joinChannelByKey(nil, channelName: roomName, info: nil, uid: 0, joinSuccess: nil)
        if code != 0 {
            dispatch_async(dispatch_get_main_queue(), {
                self.alertEngineString("\(NSLocalizedString("Join channel failed: ", comment: ""))\(code)")
            })
        }
    }
}

extension LiveRoomViewController: AgoraRtcEngineDelegate {
    func rtcEngine(engine: AgoraRtcEngineKit!, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        let userSession = videoSessionOfUid(Int64(uid))
        rtcEngine.setupRemoteVideo(userSession.canvas)
    }
    
    func rtcEngine(engine: AgoraRtcEngineKit!, firstLocalVideoFrameWithSize size: CGSize, elapsed: Int) {
        if let _ = videoSessions.first {
            updateInterface()
        }
    }
    
    func rtcEngine(engine: AgoraRtcEngineKit!, didOfflineOfUid uid: UInt, reason: AgoraRtcUserOfflineReason) {
        var indexToDelete: Int?
        for (index, session) in videoSessions.enumerate() {
            if session.uid == Int64(uid) {
                indexToDelete = index
            }
        }
        
        if let indexToDelete = indexToDelete {
            let deletedSession = videoSessions.removeAtIndex(indexToDelete)
            deletedSession.hostingView.removeFromSuperview()
            
            if deletedSession == fullSession {
                fullSession = nil
            }
        }
    }
}

//MARK: - window
extension LiveRoomViewController: NSWindowDelegate {
    func windowShouldClose(sender: AnyObject) -> Bool {
        leaveChannel()
        return false
    }
}
