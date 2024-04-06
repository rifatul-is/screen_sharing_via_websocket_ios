//
//  SampleHandler.swift
//  Broadcast Extension
//
//  Created by Alex-Dan Bumbu on 04.06.2021.
//

import ReplayKit
import OSLog

let broadcastLogger = OSLog(subsystem: "example.wireguard", category: "Broadcast")
private enum Constants {
    // the App Group ID value that the app and the broadcast extension targets are setup with. It differs for each app.
    static let appGroupIdentifier = "group.FRNJ87T7Z9.example.wireguard"
}

class SampleHandler: RPBroadcastSampleHandler {
    
    private var webSocketClient : WebSocketClient = WebSocketClient(url: URL(string: "ws://0.tcp.in.ngrok.io:18094/ws")!)
    private var clientConnection: SocketConnection?
    private var uploader: SampleUploader?
    var lastFrameProcessTime: Date?
    
    private var frameCount: Int = 0
    
    var socketFilePath: String {
      let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier)
        return sharedContainer?.appendingPathComponent("rtc_SSFD").path ?? ""
    }
    
    func convertToBasr64(sampleBuffer: CMSampleBuffer, targetWidth: CGFloat) -> String? {
        guard let cvImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let context = CIContext()
        let ciImage = CIImage(cvImageBuffer: cvImageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        // Resize the image
        let scaledImage = resizeImage(image: UIImage(cgImage: cgImage), targetWidth: targetWidth)
        
        // Convert the resized UIImage to JPEG data
        guard let imageData = scaledImage.jpegData(compressionQuality: 0.6) else {
            return nil
        }
        
        // Return the base64 encoded JPEG data
        return imageData.base64EncodedString()
    }

    // Resize the image to a specified width while maintaining aspect ratio
    func resizeImage(image: UIImage, targetWidth: CGFloat) -> UIImage {
        
        let targetSize = CGSize(width: targetWidth, height: image.size.height * (targetWidth / image.size.width))

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image // Return original image if resize fails
    }
    
    private func checkForStopSignal() {
        let userDefaults = UserDefaults(suiteName: "example.wireguard.broadcast")
        if userDefaults?.bool(forKey: "ShouldStopBroadcast") == true {
            print("n\nn\nuser is force stoping broadcast\n\n\n\n\n")
            userDefaults?.set(false, forKey: "ShouldStopBroadcast") // Reset the flag
            let error = NSError(domain: "com.example.broadcast", code: 0, userInfo: [NSLocalizedDescriptionKey: "Broadcast stopped by the user."])
            self.finishBroadcastWithError(error)
        }
    }
    
    override init() {
      super.init()
        webSocketClient.connect()
//        if let connection = SocketConnection(filePath: socketFilePath) {
//          clientConnection = connection
//          setupConnection()
//          
//          uploader = SampleUploader(connection: connection)
//        }
//        os_log(.debug, log: broadcastLogger, "%{public}s", socketFilePath)
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
        frameCount = 0
        print("Boradcast started")
        DarwinNotificationCenter.shared.postNotification(.broadcastStarted)
        openConnection()
        startReplayKit()
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast.
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
        closeReplayKit()
        //webSocketClient.disconnect()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            //self.checkForStopSignal()
            //uploader?.send(sample: sampleBuffer)
            if let lastProcessTime = lastFrameProcessTime, Date().timeIntervalSince(lastProcessTime) < 5 {
                // Less than 5 seconds have passed since the last processed frame
                return
            }
            
            if let base64String = convertToBasr64(sampleBuffer: sampleBuffer, targetWidth: 512){
                //print("This is base base 64 _______________  \(base64String)\n\n\n\n\n\n\n\n\n\n\n\n\n")
                // Use the base64String as needed
                webSocketClient.sendMessage(base64String)
            }
            
            print(lastFrameProcessTime as Any)
            
            lastFrameProcessTime = Date()
            
        default:
            break
        }
    }
}

private extension SampleHandler {
  
    func setupConnection() {
        clientConnection?.didClose = { [weak self] error in
            os_log(.debug, log: broadcastLogger, "client connection did close \(String(describing: error))")
          
            if let error = error {
                self?.finishBroadcastWithError(error)
            } else {
                // the displayed failure message is more user friendly when using NSError instead of Error
                let JMScreenSharingStopped = 10001
                let customError = NSError(domain: RPRecordingErrorDomain, code: JMScreenSharingStopped, userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped"])
                self?.finishBroadcastWithError(customError)
            }
        }
    }
    
    
    func openConnection() {
        let queue = DispatchQueue(label: "broadcast.connectTimer")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard self?.clientConnection?.open() == true else {
                return
            }
            
            timer.cancel()
        }
        
        timer.resume()
    }
    
    func startReplayKit() {
        let group=UserDefaults(suiteName: Constants.appGroupIdentifier)
        group!.set(false, forKey: "closeReplayKitFromNative")
        group!.set(false, forKey: "closeReplayKitFromFlutter")
        group!.set(true, forKey: "hasSampleBroadcast")
    }
    
    func closeReplayKit() {
        let group = UserDefaults(suiteName: Constants.appGroupIdentifier)
        group!.set(true, forKey:"closeReplayKitFromNative")
        group!.set(false, forKey: "hasSampleBroadcast")
    }
}
