import SwiftUI
import AVFoundation


struct CameraView: UIViewRepresentable {
    @ObservedObject var cameraFeedManager: CameraFeedManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraFeedManager.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        cameraFeedManager.startSession()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
            previewLayer.connection?.videoOrientation = getVideoOrientation()
        }
    }

    private func getVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .portrait
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
}

struct ContentView: View {
    @StateObject private var cameraFeedManager = CameraFeedManager()

    var body: some View {
        GeometryReader { geometry in
            VStack {
                CameraView(cameraFeedManager: cameraFeedManager)
                    .frame(height: geometry.size.height * 0.9 ) // Adjust the frame as needed
                    .onDisappear {
                        cameraFeedManager.stopSession()
                    }
                HStack{
                    
                        if let category = cameraFeedManager.detectedCategory {
                            VStack{
                    Text("Detected: \(category)")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                            }
                    }
                        
                    VStack(alignment: .trailing) {
                        
                                    ForEach(cameraFeedManager.topPredictions, id: \.self) { prediction in
                                        Text(prediction)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                    VStack(alignment: .trailing) {
                                    ForEach(cameraFeedManager.latestPredictions, id: \.self) { prediction in
                                        Text(prediction)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                }
                
                    
                
                
            }
        }
    }
}


