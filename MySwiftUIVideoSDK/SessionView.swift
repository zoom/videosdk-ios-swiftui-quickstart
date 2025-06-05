//
//  SessionView.swift
//  MySwiftUIVideoSDKApp
//
//
//

import SwiftUI
import ZoomVideoSDK

struct SessionView: View {
    @StateObject private var viewModel = ViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            if viewModel.inSession {
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .center) {
                        RemoteVideoView(viewModel: viewModel)
                        if !viewModel.remoteVideoOn {
                            PlaceholderView(name: viewModel.remoteUserName ?? "")
                        }
                    }
                    ZStack(alignment: .center) {
                        LocalVideoView(viewModel: viewModel)
                        if !viewModel.videoOn {
                            PlaceholderView(name: viewModel.userName)
                        }
                    }
                    .frame(width: 120, height: 180)
                    .padding([.top, .trailing], 20)
                }
            } else {
                Text("Loading session...")
                    .task() {
                        viewModel.joinSession()
                    }.alert("Error", isPresented: $viewModel.joinSessionFailed, actions: {}, message: {
                        Text("Join session failed")
                    })
            }
        }
        .toolbar {
            if viewModel.inSession {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(action: {
                        viewModel.toggleVideo()
                    }, label: {
                        if viewModel.videoOn {
                            Label("Stop Video", systemImage: "video.slash")
                                .labelStyle(VerticalLabelStyle())
                        } else {
                            Label("Start Video", systemImage: "video")
                                .labelStyle(VerticalLabelStyle())
                        }
                    })
                    .buttonStyle(.borderless)
                    Spacer()
                    Button(action: {
                        viewModel.toggleAudio()
                    }, label: {
                        if viewModel.audioOn {
                            Label("Mute", systemImage: "mic.slash")
                                .labelStyle(VerticalLabelStyle())
                        } else {
                            Label("Sound On", systemImage: "mic")
                                .labelStyle(VerticalLabelStyle())
                        }
                    })
                    .buttonStyle(.borderless)
                    Spacer()
                    Button(action: {
                        viewModel.leaveSession()
                        dismiss()
                    }, label: {
                        Label("End Session", systemImage: "phone.down")
                            .labelStyle(VerticalLabelStyle())
                    })
                    .buttonStyle(.borderless)
                }
            }
        }
        .labelStyle(VerticalLabelStyle())
        .toolbarRole(.editor)
        .navigationBarBackButtonHidden(true)
    }
}

struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon.font(.headline)
            configuration.title.font(.footnote)
        }
    }
}

struct PlaceholderView: View {
    @State var name: String
    
    var body: some View {
        VStack(alignment: .center) {
            Image(systemName: "person.fill")
                .foregroundStyle(.white)
            Text(name)
                .foregroundStyle(.white)
        }
    }
}

struct LocalVideoView: UIViewRepresentable {
    @State fileprivate var viewModel: SessionView.ViewModel

    func makeUIView(context: Context) -> UIView {
        let videoView = UIView()
        viewModel.attachLocalVideo(to: videoView)
        return videoView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}

struct RemoteVideoView: UIViewRepresentable {
    @State fileprivate var viewModel: SessionView.ViewModel

    func makeUIView(context: Context) -> UIView {
        let videoView = UIView()
        viewModel.attachRemoteVideo(to: videoView)
        return videoView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}

extension SessionView {
    class ViewModel: NSObject, ObservableObject, ZoomVideoSDKDelegate {
        @MainActor weak var localView: UIView?
        @MainActor weak var remoteView: UIView?
        
        @Published var joinSessionFailed: Bool = false
        @Published var inSession: Bool = false
        @Published var leftSession: Bool = false
        // local user
        @Published var videoOn: Bool = false
        @Published var audioOn: Bool = false
        // remote user
        @Published var remoteUserName: String?
        @Published var remoteVideoOn: Bool = false
        
        // MARK: Session Information
        // TODO: Ensure that you do not hard code JWT or any other confidential credentials in your production app.
        // details: https://developers.zoom.us/docs/video-sdk/ios/sessions/#create-and-join-a-session
        // (2)
        let token = ""            // JWT
        let sessionName = ""      // NOTE: Must match "tpc" field in JWT
        let userName = ""
        let sessionPassword = ""  // optional
        
        @MainActor func attachLocalVideo(to view: UIView) {
            self.localView = view
        }
        
        @MainActor func attachRemoteVideo(to view: UIView) {
            self.remoteView = view
        }
        
        func joinSession() {
            ZoomVideoSDK.shareInstance()?.delegate = self

            // TODO: Ensure that you do not hard code JWT or any other confidential credentials in your production app.
            let sessionContext = ZoomVideoSDKSessionContext()
            sessionContext.token = token
            sessionContext.sessionName = sessionName
            sessionContext.userName = userName
            // sessionContext.sessionPassword = sessionPassword
            
            // Join Session
            if (ZoomVideoSDK.shareInstance()?.joinSession(sessionContext)) != nil {
                // Session joined successfully.
                print("Session joined")
                inSession = true
            } else {
                print("Join session failed")
                joinSessionFailed = true
            }
        }
        
        func onSessionJoin() {
            // Render the current user's video
            if let myUser = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf(),
               // Get local user's video canvas
               let myUserVideoCanvas = myUser.getVideoCanvas() {
                // Turning on video for first time
                if let myVideoIsOn = myUserVideoCanvas.videoStatus()?.on {
                    if myVideoIsOn == false {
                        // Ensure this is called on main thread
                        Task(priority: .background) {
                            await MainActor.run {
                            // Subscribe to video canvas, render to local user view
                                myUserVideoCanvas.subscribe(with: localView, aspectMode: .panAndScan, andResolution: ._Auto)
                                videoOn = true
                                audioOn = true
                            }
                        }
                    }
                }
            }
        }
        
        func onUserJoin(_ helper: ZoomVideoSDKUserHelper?, users: [ZoomVideoSDKUser]?) {
            // Get remote user
            if let userArray = users, let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() {
                for user in userArray {
                    if (user.getID() != myself.getID()) {
                        remoteUserName = user.getName()
                        if let remoteUserVideoCanvas = user.getVideoCanvas() {
                            // Subscribe to video canvas, render to remote user view
                            Task(priority: .background) {
                                await MainActor.run {
                                    remoteVideoOn = true
                                    remoteUserVideoCanvas.subscribe(with: remoteView, aspectMode: .panAndScan, andResolution: ._Auto)
                                }
                            }
                        }
                        return
                    }
                }
            }
        }
        
        func onUserVideoStatusChanged(_ helper: ZoomVideoSDKVideoHelper?, user: [ZoomVideoSDKUser]?) {
            // Get remote user
            if let userArray = user, let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() {
                for user in userArray {
                    if (user.getID() != myself.getID()) {
                        // Get remote user canvas
                        if let remoteUserVideoCanvas = user.getVideoCanvas() {
                            // Check remote user's video status
                            if let remoteUserVideoIsOn = remoteUserVideoCanvas.videoStatus()?.on,
                               remoteUserVideoIsOn == true {
                                Task(priority: .background) {
                                    await MainActor.run {
                                        // Update UI
                                        remoteVideoOn = true
                                    }
                                }
                            } else {
                                Task(priority: .background) {
                                    await MainActor.run {
                                        // Update UI
                                        remoteVideoOn = false
                                    }
                                }
                            }
                        }
                    }
                    return
                }
            }
        }

        func onUserLeave(_ helper: ZoomVideoSDKUserHelper?, users: [ZoomVideoSDKUser]?) {
            // Get remote user
            if let userArray = users, let myself = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf() {
                for user in userArray {
                    if (user.getID() != myself.getID()) {
                        // Unsubscribe to remote user's video
                        if let remoteUserVideoCanvas = user.getVideoCanvas() {
                            Task(priority: .background) {
                                await MainActor.run {
                                    remoteUserVideoCanvas.unSubscribe(with: self.remoteView)
                                }
                            }
                        }
                        return
                    }
                }
            }
        }
        
        func onSessionLeave() {
            let myUser = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()
            // Unsubscribe local user's video canvas.
            if let usersVideoCanvas = myUser?.getVideoCanvas() {
                // Unsubscribe user's video canvas to stop rendering their video stream.
                Task(priority: .background) {
                    await MainActor.run {
                        usersVideoCanvas.unSubscribe(with: localView)
                    }
                }
            }
            
            // Get remote user
            if let remoteUsers = ZoomVideoSDK.shareInstance()?.getSession()?.getRemoteUsers() {
                for user in remoteUsers {
                    // Unsubscribe remote user's video canvas.
                    if let remoteUserVideoCanvas = user.getVideoCanvas() {
                        Task(priority: .background) {
                            await MainActor.run {
                                remoteUserVideoCanvas.unSubscribe(with: self.remoteView)
                            }
                        }
                    }
                }
            }
            leftSession = true
        }

        
        //()
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
                            // Update UI
                            videoOn = false
                        }
                    }
                } else {
                    Task(priority: .background) {
                        await MainActor.run {
                            let error = videoHelper.startVideo()
                            print("Start error: \(error.rawValue)")
                            // Update UI
                            videoOn = true
                        }
                    }
                }
            }
        }
        
        //()
        func toggleAudio() {
            let myUser = ZoomVideoSDK.shareInstance()?.getSession()?.getMySelf()
            // Get the user's audio status
            if let audioStatus = myUser?.audioStatus(),
               // Get ZoomVideoSDKAudioHelper to control audio
               let audioHelper = ZoomVideoSDK.shareInstance()?.getAudioHelper() {
                // Check if the user's audio type is none
                if audioStatus.audioType == .none {
                    Task(priority: .background) {
                        await MainActor.run {
                            audioHelper.startAudio()
                            audioOn = true
                        }
                    }
                } else {
                    // Toggle audio based on mute status
                    if audioStatus.isMuted {
                        Task(priority: .background) {
                            await MainActor.run {
                                let error = audioHelper.unmuteAudio(myUser)
                                print("Unmute error: \(error.rawValue)")
                                // Update UI
                                audioOn = true
                            }
                        }
                    } else {
                        Task(priority: .background) {
                            await MainActor.run {
                                let error = audioHelper.muteAudio(myUser)
                                print("Mute error: \(error.rawValue)")
                                // Update UI
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

#Preview {
    SessionView()
}
