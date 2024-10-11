//
//  Uploader.swift
//  mobile_flutter_uploader
//
//  Created by Mateus de Morais Ramalho on 07/09/24.
//

import Foundation

struct Keys {
    static let backgroundSessionIdentifier = "com.mobile_flutter_uploader.upload.background"
    static let wifiBackgroundSessionIdentifier = "com.mobileflutter_uploader.upload.background.wifi"
}

class Uploader: NSObject {
    static let shared = Uploader()

    var session: URLSession?
    var wifiSession: URLSession?
    let queue = OperationQueue()

    // Accessing uploadedData & runningTaskById will require exclusive access
    private let semaphore = DispatchSemaphore(value: 1)

    // Reference for uploaded data.
    var uploadedData = [String: Data]()

    // Reference for currently running tasks.
    var runningTaskById = [String: UploadTask]()

    private var delegates: [UploaderDelegate] = []

    /// See the discussion on
    /// [application:handleEventsForBackgroundURLSession:completionHandler:](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622941-application?language=objc)
    public var backgroundTransferCompletionHander: (() -> Void)?

    // MARK: Public API

    func addDelegate(_ delegate: UploaderDelegate) {
        delegates.append(delegate)
    }

    func enqueueUploadTask(_ request: URLRequest, path: String, wifiOnly: Bool) -> URLSessionUploadTask? {
        guard let session = self.session,
              let wifiSession = self.wifiSession else {
            return nil
        }

        let activeSession = wifiOnly ? wifiSession : session
        let uploadTask = activeSession.uploadTask(
                with: request,
                fromFile: URL(fileURLWithPath: path)
        )

        // Create a random UUID as task description (& ID).
        uploadTask.taskDescription = UUID().uuidString

        let taskId = identifierForTask(uploadTask)

        delegates.uploadEnqueued(taskId: taskId)

        uploadTask.resume()

        semaphore.wait()
        self.runningTaskById[taskId] = UploadTask(taskId: taskId, status: .enqueue, progress: 0)
        semaphore.signal()

        return uploadTask
    }

    ///
    /// The description on URLSessionTask.taskIdentifier explains how the task is only unique within a session.
    public func identifierForTask(_ task: URLSessionUploadTask) -> String {
        return  "\(self.session?.configuration.identifier ?? "com.mobile_flutter_uploader").\(task.taskDescription!)"
    }

    /// Cancel a task by ID.
    func cancelWithTaskId(_ taskId: String) {
        guard let session = session else { return }

        session.getTasksWithCompletionHandler { (_, uploadTasks, _) in
            for uploadTask in uploadTasks {
                if self.identifierForTask(uploadTask) == taskId && uploadTask.state == .running {
                    self.delegates.uploadProgressed(taskId: taskId, inStatus: .canceled, progress: -1)

                    uploadTask.cancel()
                    return
                }
            }
        }
    }

    /// Cancel all running tasks
    func cancelAllTasks() {
        session?.getTasksWithCompletionHandler { (_, uploadTasks, _) in
            for uploadTask in uploadTasks {
                let state = uploadTask.state
                let taskId = self.identifierForTask(uploadTask)
                if state == .running {
                    self.delegates.uploadProgressed(taskId: taskId, inStatus: .canceled, progress: -1)

                    uploadTask.cancel()
                }
            }
        }
    }

    // MARK: Private API

    private override init() {
        super.init()
        
        delegates.append(UploaderDelegateLogger())

        let bundle = Bundle.main
        
        self.queue.name = "com.mobile_flutter_uploader.queue"
        let maxUploadOperation = bundle.maximumConcurrentUploadOperation
        self.queue.maxConcurrentOperationCount = maxUploadOperation
        print("MAXIMUM_CONCURRENT_UPLOAD_OPERATION = \(maxUploadOperation)")
        
        let maxConcurrentTasks = bundle.maximumConcurrentTask
        print("MAXIMUM_CONCURRENT_TASKS = \(maxConcurrentTasks)")
        
        let timeoutIntervalForRequest = bundle.timeoutIntervalForRequest
        print("TIMEOUT_INTERVAL_FOR_REQUEST = \(timeoutIntervalForRequest) seconds")
        
        // configure session for wifi only uploads
        let wifiConfiguration = URLSessionConfiguration.background(withIdentifier: Keys.wifiBackgroundSessionIdentifier)
        wifiConfiguration.httpMaximumConnectionsPerHost = maxConcurrentTasks
        wifiConfiguration.timeoutIntervalForRequest = timeoutIntervalForRequest
        wifiConfiguration.allowsCellularAccess = false
        self.wifiSession = URLSession(configuration: wifiConfiguration, delegate: self, delegateQueue: queue)

        // configure regular session
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: Keys.backgroundSessionIdentifier)
        sessionConfiguration.httpMaximumConnectionsPerHost = maxConcurrentTasks
        sessionConfiguration.timeoutIntervalForRequest = timeoutIntervalForRequest
        self.session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: queue)
    }
           
    private func isRequestSuccessful(_ statusCode: Int) -> Bool {
        return statusCode >= 200 && statusCode <= 399
    }
}

// MARK: - URLSessionDelegate
extension Uploader: URLSessionDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("URLSessionDidBecomeInvalidWithError:")
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("URLSessionDidFinishEvents:")

        session.getTasksWithCompletionHandler { (_, uploadTasks, _) in
            self.semaphore.wait()
            defer { self.semaphore.signal() }

            if uploadTasks.isEmpty {
                print("All upload tasks have been completed")

                self.backgroundTransferCompletionHander?()
                self.backgroundTransferCompletionHander = nil
            }
        }
    }
}

// MARK: - URLSessionTaskDelegate
extension Uploader: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        print("URLSessionTaskIsWaitingForConnectivity:")
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }

        if totalBytesExpectedToSend == NSURLSessionTransferSizeUnknown {
            print("Unknown transfer size")
        } else {
            guard let uploadTask = task as? URLSessionUploadTask else {
                print("URLSessionDidSendBodyData: an not uplaod task")
                return
            }

            let taskId = identifierForTask(uploadTask)
            let bytesExpectedToSend = Double(totalBytesExpectedToSend)
            let tBytesSent = Double(totalBytesSent)
            let progress = round(Double(tBytesSent / bytesExpectedToSend * 100))

            let runningTask = self.runningTaskById[taskId]
            print("URLSessionDidSendBodyData: \(taskId), byteSent: \(bytesSent), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSend: \(totalBytesExpectedToSend), progress:\(progress)")

            if runningTask != nil {
                let isRunning: (Int, Int, Int) -> Bool = { (current, previous, step) in
                    let prev = previous + step
                    return (current == 0 || current > prev || current >= 100) &&  current != previous
                }

                if isRunning(Int(progress), runningTask!.progress, MobileFlutterUploaderPlugin.stepUpdate) {
                    self.delegates.uploadProgressed(taskId: taskId, inStatus: .running, progress: Int(progress))
                    self.runningTaskById[taskId] = UploadTask(taskId: taskId, status: .running, progress: Int(progress), tag: runningTask?.tag)
                }
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        semaphore.wait()
        defer {
            semaphore.signal()
        }

        guard let uploadTask = task as? URLSessionUploadTask else {
            print("URLSessionDidCompleteWithError: not an upload task")
            return
        }
        
        let taskId = identifierForTask(uploadTask)

        if error != nil {
            print("URLSessionDidCompleteWithError: \(taskId) failed with \(error!.localizedDescription)")
            var uploadStatus: UploadTaskStatus = .failed
            switch error! {
            case URLError.cancelled:
                uploadStatus = .canceled
            default:
                uploadStatus = .failed
            }

            self.delegates.uploadFailed(taskId: taskId,
                                        inStatus: uploadStatus,
                                        statusCode: 500,
                                        errorCode: "upload_error",
                                        errorMessage: error?.localizedDescription ?? "",
                                        errorStackTrace: Thread.callStackSymbols)

            self.runningTaskById.removeValue(forKey: taskId)
            self.uploadedData.removeValue(forKey: taskId)
            return
        }

        var hasResponseError = false
        var response: HTTPURLResponse?
        var statusCode = 500

        if task.response is HTTPURLResponse {
            response = task.response as? HTTPURLResponse

            if response != nil {
                print("URLSessionDidCompleteWithError: \(taskId) with response: \(response!) and status: \(response!.statusCode)")
                statusCode = response!.statusCode
                hasResponseError = !isRequestSuccessful(response!.statusCode)
            }
        }

        print("URLSessionDidCompleteWithError: upload completed")

        let headers = response?.allHeaderFields
        var responseHeaders = [String: Any]()
        if headers != nil {
            headers!.forEach { (key, value) in
                if let key = key as? String {
                    responseHeaders[key] = value
                }
            }
        }

        let message: String?
        if let data = uploadedData[taskId] {
            message = String(data: data, encoding: String.Encoding.utf8)
        } else {
            message = nil
        }

        let statusText = uploadTask.state.statusText()
        if error == nil && !hasResponseError {
            print("URLSessionDidCompleteWithError: response: \(message ?? "null"), task: \(statusText)")
            self.delegates.uploadCompleted(taskId: taskId, message: message, statusCode: response?.statusCode ?? 200, headers: responseHeaders)
        } else if hasResponseError {
            print("URLSessionDidCompleteWithError: task: \(statusText) statusCode: \(response?.statusCode ?? -1), error:\(message ?? "null"), response:\(String(describing: response))")
            self.delegates.uploadFailed(taskId: taskId, inStatus: .failed, statusCode: statusCode, errorCode: "upload_error", errorMessage: message, errorStackTrace: Thread.callStackSymbols)
        } else {
            print("URLSessionDidCompleteWithError: task: \(statusText) statusCode: \(response?.statusCode ?? -1), error:\(error?.localizedDescription ?? "none")")
            delegates.uploadFailed(
                taskId: taskId,
                inStatus: .failed,
                statusCode: statusCode,
                errorCode: "upload_error",
                errorMessage: error?.localizedDescription ?? "",
                errorStackTrace: Thread.callStackSymbols
            )
        }

        self.uploadedData.removeValue(forKey: taskId)
        self.runningTaskById.removeValue(forKey: taskId)
    }
}

// MARK: - URLSessionDataDelegate
extension Uploader: URLSessionDataDelegate {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        semaphore.wait()
        defer { semaphore.signal() }

        print("URLSessionDidReceiveData:")

        guard let uploadTask = dataTask as? URLSessionUploadTask else {
            print("URLSessionDidReceiveData: not an uplaod task")
            return
        }

        if data.count > 0 {
            let taskId = identifierForTask(uploadTask)
            if var existing = uploadedData[taskId] {
                existing.append(data)
            } else {
                uploadedData[taskId] = Data(data)
            }
        }
    }
}
