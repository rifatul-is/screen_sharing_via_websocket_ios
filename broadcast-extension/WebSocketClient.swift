//
//  WebSocketClient.swift
//  Screen Sharing IOS Demo
//
//  Created by Rifatul Islam Ramim on 4/4/24.
//

import Foundation

class WebSocketClient: NSObject, URLSessionWebSocketDelegate{
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private let url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        self.webSocketTask = session.webSocketTask(with: url)
    }
    
    func connect() {
        webSocketTask?.resume()
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    func sendMessage(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket sending error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("Error in receiving message: \(error)")
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received string: \(text)")
                case .data(let data):
                    print("Received data: \(data)")
                default:
                    break
                }
                
                self?.receiveMessage() // Listen for the next message
            }
        }
    }
    
    // MARK: URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket did open")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket did close with code: \(closeCode)")
    }
}
