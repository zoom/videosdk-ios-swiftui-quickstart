import SwiftUI
import ZoomVideoSDK

extension SessionView {
    class ViewModel: NSObject, ObservableObject, ZoomVideoSDKDelegate {
        // Local user
        @MainActor weak var localView: UIView?
        @Published var joinSessionFailed: Bool = false
        @Published var inSession: Bool = false
        @Published var leftSession: Bool = false
        @Published var videoOn: Bool = false
        @Published var audioOn: Bool = false
        
        // Remote users
        @Published var remoteUsers: [ZoomVideoSDKUser] = []
        
        // MARK: Session Information
        // TODO: Ensure that you do not hard code JWT or any other confidential credentials in your production app.
        // Details: https://developers.zoom.us/docs/video-sdk/ios/sessions/#create-and-join-a-session
        let token = <#JWT#>
        let sessionName = <#Session Name#> // Also known as tpc in JWT
        let userName = <#Username#> // Display name
        //let sessionPassword = <#Password if any#>
        
        @MainActor func attachLocalVideo(to view: UIView) {
            self.localView = view
        }
        
        @MainActor func updateLocalVideo(to view: UIView) {
            guard let myUserVideoCanvas = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()?.getVideoCanvas(), let myVideoIsOn = myUserVideoCanvas.videoStatus()?.on else { return }
            if myVideoIsOn {
                myUserVideoCanvas.subscribe(with: localView, aspectMode: .panAndScan, andResolution: ._Auto)
            } else {
                myUserVideoCanvas.unSubscribe(with: localView)
            }
        }
        
        @MainActor func attachRemoteUserVideo(index: Int, to view: UIView) {
            guard let index = remoteUsers.indices.first(where: { $0 == index }) else { return }
            if let currentUserVideoCanvas = self.remoteUsers[index].getVideoCanvas(), let videoStatus = currentUserVideoCanvas.videoStatus() {
                if videoStatus.on {
                    currentUserVideoCanvas.subscribe(with: view, aspectMode: .panAndScan, andResolution: ._Auto)
                } else {
                    currentUserVideoCanvas.unSubscribe(with: view)
                }
            }
        }
        
        @MainActor func updateRemoteVideo(to view: UIView, index: Int) {
            guard let index = remoteUsers.indices.first(where: { $0 == index }) else { return }
            guard let index = remoteUsers.indices.first(where: { $0 == index }) else { return }
            if let currentUserVideoCanvas = self.remoteUsers[index].getVideoCanvas(), let videoStatus = currentUserVideoCanvas.videoStatus() {
                if videoStatus.on {
                    currentUserVideoCanvas.subscribe(with: view, aspectMode: .panAndScan, andResolution: ._Auto)
                } else {
                    currentUserVideoCanvas.unSubscribe(with: view)
                }
            }
        }
        
        func joinSession() {
            ZoomVideoSDK.shareInstance()?.delegate = self
            
            let sessionContext = ZoomVideoSDKSessionContext()
            sessionContext.token = token
            sessionContext.sessionName = sessionName
            sessionContext.userName = userName
            let videoOption = ZoomVideoSDKVideoOptions()
            videoOption.localVideoOn = true
            sessionContext.videoOption = videoOption
            //sessionContext.sessionPassword = sessionPassword // Uncomment if your session requires password
            
            // Join Session
            if let session = ZoomVideoSDK.shareInstance()?.joinSession(sessionContext) {
                
            } else {
                print("Join session failed")
                joinSessionFailed = true
            }
        }
        
        func onError(_ ErrorType: ZoomVideoSDKError, detail details: Int) {
            print("Error: \(ErrorType.rawValue) (\(details))")
            if !inSession {
                joinSessionFailed = true
                leftSession = true
            }
        }
        
        func onSessionJoin() {
            // Session joined successfully.
            print("Session joined")
            inSession = true
        }
    
        func onUserJoin(_ helper: ZoomVideoSDKUserHelper?, users: [ZoomVideoSDKUser]?) {
            // Get remote user
            if let userArray = users, let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() {
                for user in userArray {
                    if (user.getID() != myself.getID()) {
                        remoteUsers.append(user)
                    }
                }
            }
        }
        
        func onUserLeave(_ helper: ZoomVideoSDKUserHelper?, users: [ZoomVideoSDKUser]?) {
            // Get remote user
            if let userArray = users, let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() {
                for user in userArray {
                    if (user.getID() != myself.getID()) {
                        remoteUsers.removeAll { remoteUser in
                            remoteUser.getID() == user.getID()
                        }
                    }
                }
            }
        }
        
        func onUserVideoStatusChanged(_ helper: ZoomVideoSDKVideoHelper?, user: [ZoomVideoSDKUser]?) {
            
            if let userArray = user, let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() {
                for user in userArray {
                    if (user.getID() == myself.getID()) {
                        if let myUserVideoCanvas = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()?.getVideoCanvas(), let myVideoIsOn = myUserVideoCanvas.videoStatus()?.on {
                            if myVideoIsOn {
                                Task(priority: .background) {
                                    await MainActor.run {
                                        self.videoOn = true
                                    }
                                }
                            } else {
                                Task(priority: .background) {
                                    await MainActor.run {
                                        videoOn = false
                                    }
                                }
                            }
                        }
                    }
                    
                    // Get remote user
                    if (user.getID() != myself.getID()), let remoteUserIndex = remoteUsers.firstIndex(where: { currentUser in
                        currentUser.getID() == user.getID()
                    }) {
                        remoteUsers[remoteUserIndex] = user
                    }
                }
            }
        }
        
        func onSessionLeave() {
            leftSession = true
        }
        
        // Local user - toggle video on/off
        func toggleVideo() {
            if let usersVideoCanvas = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()?.getVideoCanvas(),
               // Get ZoomVideoSDKVideoHelper to control video
               let videoHelper = ZoomVideoSDK.shareInstance()?.getVideoHelper() {
                if let myVideoIsOn = usersVideoCanvas.videoStatus()?.on,
                   myVideoIsOn == true {
                    Task(priority: .background) {
                        await MainActor.run {
                            let error = videoHelper.stopVideo()
                            print("Stop error: \(error.rawValue)")
                        }
                    }
                } else {
                    Task(priority: .background) {
                        await MainActor.run {
                            let error = videoHelper.startVideo()
                            print("Start error: \(error.rawValue)")
                        }
                    }
                }
            }
        }
        
        // Local user - toggle audio mic unmute/mute
        func toggleAudio() {
            let myUser = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()
            // Get the user's audio status
            if let audioStatus = myUser?.audioStatus(),
               // Get ZoomVideoSDKAudioHelper to control audio
               let audioHelper = ZoomVideoSDK.shareInstance()?.getAudioHelper() {
                // Check if the user's audio type is none - Not connected yet
                if audioStatus.audioType == .none {
                    Task(priority: .background) {
                        await MainActor.run {
                            audioHelper.startAudio()
                            audioOn = true
                        }
                    }
                } else {
                    // Audio is connected - Toggle audio based on mute status
                    if audioStatus.isMuted {
                        Task(priority: .background) {
                            await MainActor.run {
                                let error = audioHelper.unmuteAudio(myUser)
                                print("Unmute error: \(error.rawValue)")
                                audioOn = true
                            }
                        }
                    } else {
                        Task(priority: .background) {
                            await MainActor.run {
                                let error = audioHelper.muteAudio(myUser)
                                print("Mute error: \(error.rawValue)")
                                audioOn = false
                            }
                        }
                    }
                }
            }
        }
        
        func leaveSession() {
            ZoomVideoSDK.shareInstance()?.leaveSession(true)
        }
        
    }
}
