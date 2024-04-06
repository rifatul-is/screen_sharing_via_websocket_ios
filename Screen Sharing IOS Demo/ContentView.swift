//
//  ContentView.swift
//  Screen Sharing IOS Demo
//
//  Created by Rifatul Islam Ramim on 19/3/24.
//

import SwiftUI
import ReplayKit

struct ContentView: View {
    @State var isCapturing = false
    @State private var isRecording = false
    

    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                self.broadcastPicker()
            }) {
                Text("Start Screen Sharing")
            }
            .disabled(isRecording)

            Button(action: {
                let userDefaults = UserDefaults(suiteName: "example.wireguard.broadcast-extension")
                userDefaults?.set(true, forKey: "ShouldStopBroadcast")
                isRecording.toggle()
            }) {
                Text("Stop Screen Sharing")
            }
            .disabled(!isRecording)
        }
    }
    
//    func initSocket() {
//        webSocketClient.connect()
//        isCapturing.toggle()
//    }
//    
//    func connectToSocket() {
//        // When you want to send a message
//        webSocketClient.sendMessage("Hello, WebSocket!")
//    }
//    
//    func disconnectSocket() {
//        webSocketClient.disconnect()
//        // Don't forget to disconnect when you're done
//    }
    
    

    func startCapture() {
        let recorder = RPScreenRecorder.shared()
        
        recorder.startCapture(handler: { (sampleBuffer, bufferType, error) in
            guard error == nil else {
                // Handle the error
                print("Error capturing screen: \(String(describing: error))")
                return
            }
            
            if bufferType == .video {
                // Process the video sampleBuffer
                if let base64String = self.convertToBase64(sampleBuffer: sampleBuffer) {
                    // Here you have your base64String of the captured frame
                    print("This is base base 64 _______________  \(base64String)")
                }
            }
        }) { (error) in
            if let error = error {
                // Handle the error
                print("Error starting capture: \(error.localizedDescription)")
            } else {
                isCapturing = true
            }
        }
    }
    
    func convertToBase64(sampleBuffer: CMSampleBuffer) -> String? {
        guard let cvImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let ciImage = CIImage(cvImageBuffer: cvImageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let imageData = uiImage.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        return imageData.base64EncodedString()
    }
    
    func stopCapture() {
        if isCapturing {
            RPScreenRecorder.shared().stopCapture { (error) in
                if let error = error {
                    print("Error stopping capture: \(error.localizedDescription)")
                } else {
                    isCapturing = false
                }
            }
        }
    }
    
    func startScreenSharing() {
        print("Start Screen sharing")
        
        //broadcastPicker()
        
        let recorder = RPScreenRecorder.shared()

//        recorder.startRecording { (error) in
//            if let error = error {
//                print("Failed to start recording: \(error.localizedDescription)")
//            } else {
//                isRecording = true
//                print("Recording started")
//            }
//        }
        
        
        recorder.startCapture(handler: { (sampleBuffer, bufferType, error) in
            guard error == nil else {
                // Handle error
                print("Error capturing screen: \(String(describing: error))")
                return
            }
            
            print("Started Recording")
            
            DispatchQueue.global(qos: .background).async {
                if let data = self.convertSampleBufferToData(sampleBuffer) {
                    // Process the data object (e.g., save it, send it over the network)
                    if bufferType == .video {
                        if let data = self.convertSampleBufferToData(sampleBuffer) {
                            // You now have a Data object containing the frame's bytes
                            // Perform your operations with `data`
                            print("this is the data \(data)")
                        }
                    }
                }
            }
            
        }) { (error) in
            // Handle startCapture error
            print("startCapture() failed: \(String(describing: error))")
        }
        
    }
    
    func processVideoFrames(url: URL) {
        let asset = AVAsset(url: url)
        guard let assetReader = try? AVAssetReader(asset: asset) else {
            print("Could not initialize asset reader")
            return
        }
        
        let videoTrack = asset.tracks(withMediaType: .video).first!
        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]
        let assetReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        
        assetReader.add(assetReaderOutput)
        assetReader.startReading()
        
        while assetReader.status == .reading {
            guard let sampleBuffer = assetReaderOutput.copyNextSampleBuffer() else { continue }
            if let image = sampleBufferToImage(sampleBuffer: sampleBuffer) {
                // Do something with the image (UIImage)
            }
        }
        
        if assetReader.status == .completed {
            // Finished reading and processing all frames
        }
    }

    func sampleBufferToImage(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    
    func convertSampleBufferToData(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        //print(width, " ", height, " ", bytesPerRow, " ", baseAddress ?? "Nothing Found")
        // Ensure you're using the correct bitmap info for your pixel buffer format.
        // For example, pixel buffers often use 32-bit BGRA format on iOS.
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue).rawValue
        print(bitmapInfo)
        
        guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            return nil
        }
        
        guard let cgImage = context.makeImage() else { return nil }
        
        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: 0.8)
    }
    
    
    
    func stopScreenSharing() {
        let recorder = RPScreenRecorder.shared()

        recorder.stopRecording { (previewViewController, error) in
            if let error = error {
                print("Failed to stop recording: \(error.localizedDescription)")
            } else {
                isRecording = false
                print("Recording stopped")
                // Optionally present the previewViewController to review the recording
            }
        }
    }
    
    func broadcastPicker () {
        if #available(iOS 12.0, *) {
            print("iOS 12+ is available")
            isRecording.toggle()
            DispatchQueue.main.async {
                print("Creating Picker")
                let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
                picker.showsMicrophoneButton = true
                picker.preferredExtension = "example.wireguard.broadcast-extension" // Directly using the provided bundle identifier
                
                for view in picker.subviews {
                    (view as? UIButton)?.sendActions(for: .allTouchEvents)
                }
            }
        }
    }
}

//#Preview {
//    ContentView()
//}
