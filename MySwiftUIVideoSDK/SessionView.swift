import SwiftUI
import ZoomVideoSDK

struct SessionView: View {
    @StateObject private var viewModel = ViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        if viewModel.inSession {
            NavigationStack {
                ScrollView {
                    VStack() {
                        VStack() {
                            if viewModel.videoOn {
                                LocalVideoView(viewModel: viewModel)
                            } else {
                                PlaceholderView(name: viewModel.userName)
                            }
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .padding()
                        ForEach(viewModel.remoteUsers.indices, id: \.self) { index in
                            VStack() {
                                if (viewModel.remoteUsers[index].getVideoCanvas()?.videoStatus()?.on ?? false) {
                                    RemoteVideoView(viewModel: viewModel, index: index)
                                } else {
                                    PlaceholderView(name: viewModel.remoteUsers[index].getName() ?? "")
                                }
                            }
                            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                }
            }
            .toolbar {
                if viewModel.inSession {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button(action: {
                            viewModel.toggleVideo()
                        }, label: {
                            Label {
                                Text(viewModel.videoOn ? "Stop Video" : "Start Video")
                            } icon: {
                                Image(systemName: viewModel.videoOn ? "video.slash" : "video")
                                    .frame(width: 24, height: 24)
                            }
                        })
                        .buttonStyle(.borderless)
                        Spacer()
                        Button(action: {
                            viewModel.toggleAudio()
                        }, label: {
                            Label {
                                Text(viewModel.audioOn ? "Mute" : "Sound On")
                            } icon: {
                                Image(systemName: viewModel.audioOn ? "mic.slash" : "mic")
                                    .frame(width: 24, height: 24)
                            }
                        })
                        .buttonStyle(.borderless)
                        Spacer()
                        Button(action: {
                            viewModel.leaveSession()
                            dismiss()
                        }, label: {
                            Label {
                                Text("End Session")
                            } icon: {
                                Image(systemName: "phone.down")
                                    .frame(width: 24, height: 24)
                            }
                        })
                        .buttonStyle(.borderless)
                    }
                }
            }
            .labelStyle(VerticalLabelStyle())
            .toolbarRole(.editor)
            .navigationBarBackButtonHidden(true)
        } else {
            NavigationStack {
                Text("Loading session...")
                    .task() {
                        viewModel.joinSession()
                    }.alert("Error", isPresented: $viewModel.joinSessionFailed, actions: {}, message: {
                        Text("Join session failed")
                    })
                    .font(.title)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

#Preview {
    SessionView()
}

public struct VerticalLabelStyle: LabelStyle {
    public func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon.font(.headline)
            configuration.title.font(.footnote)
        }
    }
}

public struct PlaceholderView: View {
    @State var name: String
    
    public var body: some View {
        VStack() {
            Image(systemName: "person.fill")
                .foregroundStyle(.white)
            Text(name)
                .foregroundStyle(.white)
        }
        .frame(maxHeight: .infinity)
    }
}

public struct LocalVideoView: UIViewRepresentable {
    @State var viewModel: SessionView.ViewModel
    
    public func makeUIView(context: Context) -> UIView {
        let videoView = UIView()
        viewModel.attachLocalVideo(to: videoView)
        return videoView
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        viewModel.updateLocalVideo(to: uiView)
    }
}

public struct RemoteVideoView: UIViewRepresentable {
    @State var viewModel: SessionView.ViewModel
    @State var index: Int
    
    public func makeUIView(context: Context) -> UIView {
        let videoView = UIView()
        return videoView
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        viewModel.updateRemoteVideo(to: uiView, index: index)
    }
}
