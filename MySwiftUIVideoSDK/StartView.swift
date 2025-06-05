//
//  StartView.swift
//  MySwiftUIVideoSDKApp
//
//

import SwiftUI
import ZoomVideoSDK

struct StartView: View {
    @State private var viewModel = ViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                NavigationLink("Start Session", destination: SessionView())
            }
            .padding()
        }
        .onAppear {
            viewModel.setupSDK()
        }
    }
    
}

extension StartView {
    @Observable @MainActor
    class ViewModel {
        // MARK: VSDK setup
        func setupSDK() {
            // (1)
            let initParams = ZoomVideoSDKInitParams()
            initParams.domain = "zoom.us"
            let sdkInitReturnStatus = ZoomVideoSDK.shareInstance()?.initialize(initParams)
            
            switch sdkInitReturnStatus {
            case .Errors_Success:
                print ("SDK initialization succeeded")
            default:
                if let error = sdkInitReturnStatus {
                    print("SDK initialization failed: \(error)")
                    return
                }
            }
        }
    }
}

#Preview {
    StartView()
}
