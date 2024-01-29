import AVFoundation
import CoreML
import Vision
import Combine
import UIKit
import Foundation

struct Prediction {
    let identifier: String
    let confidence: Float
}
class CameraFeedManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    let captureSession = AVCaptureSession() // Changed from 'private' to 'internal'
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var resNetModel: VNCoreMLModel?

    @Published var latestPrediction: String = "Detecting..."
    @Published var latestPredictions: [String] = []
    @Published var topPredictions: [String] = []
    @Published var detectedCategory: String?
    private var predictionsBuffer: [Prediction] = []
    private var updateTimer: Timer?

    let MacBookStrings: [String] = [
           "desktop computer",
           "laptop, laptop computer",
           "monitor",
           "screen, CRT screen",
           "notebook, notebook computer",
       ]

    let TVStrings: [String] = [
       "home theater, home theatre",
       "entertainment center",
       "television, television system",
       "loudspeaker, speaker, speaker unit, loudspeaker system, speaker system",
       "cinema, movie theater, movie theatre, movie house, picture palace",
    ]

    let AppleWatchStrings: [String] = [
       "buckle",
       "watch",
       "digital",
       "belt"
    ]
    
    let IPhoneStrings: [String] = [
        "iPod",
        "cleaver, meat cleaver, chopper",
        "remote control, remote",
        "cellular telephone, cellular phone, cellphone, cell, mobile phone",

    ]

    override init() {
        super.init()
        setupCameraFeed()
        setupCoreMLModel()
        startUpdateTimer()
    }

    private func setupCameraFeed() {
        captureSession.sessionPreset = .hd1920x1080 // Use an appropriate preset

        guard let captureDevice = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: Unable to initialize camera.")
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        if let connection = videoDataOutput.connection(with: .video) {
                   connection.videoOrientation = getCaptureVideoOrientation()
               }
           }
    private func getCaptureVideoOrientation() -> AVCaptureVideoOrientation {
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
    private func setupCoreMLModel() {
        do {
            
            resNetModel = try VNCoreMLModel(for: Resnet50().model)
        } catch {
            print("Error: Unable to load CoreML model - \(error)")
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let resNetModel = resNetModel else { return }

        let request = VNCoreMLRequest(model: resNetModel) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation] else { return }
            self?.addToBuffer(predictions: results.map { Prediction(identifier: $0.identifier, confidence: $0.confidence) })
            let topResults = results.prefix(3).map { observation in
                String(format: "%@: %.2f%%", observation.identifier, observation.confidence * 100)
            }
            DispatchQueue.main.async {
                self?.latestPredictions = topResults
            }
        }
  
        
        

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
    }
    private func addToBuffer(predictions: [Prediction]) {
        DispatchQueue.main.async {
            self.predictionsBuffer.append(contentsOf: predictions)
        }
    }

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTopPredictions()
        }
    }

    private func updateTopPredictions() {
        let summedPredictions = Dictionary(grouping: predictionsBuffer, by: { $0.identifier })
            .mapValues { $0.reduce(0) { $0 + $1.confidence } }

        let sortedPredictions = summedPredictions.sorted { $0.value > $1.value }
            .prefix(3)
            .map { String(format: "%@: %.2f%%", $0.key, $0.value * 100) }
        
        DispatchQueue.main.async {
            self.topPredictions = sortedPredictions
            self.detectedCategory = self.checkForMatches(in: self.topPredictions)
            self.predictionsBuffer.removeAll()
        }
    }
    private func checkForMatches(in predictions: [String]) -> String? {
           let allStrings = [("MacBook", MacBookStrings), ("TV", TVStrings), ("Apple Watch", AppleWatchStrings), ("IPhone", IPhoneStrings)]
           for (category, strings) in allStrings {
               if predictions.contains(where: { prediction in
                   strings.contains { string in
                       prediction.lowercased().contains(string.lowercased())
                   }
               }) {
                   return category
               }
           }
           return nil
       }
    func startSession() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }

        func stopSession() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
}
