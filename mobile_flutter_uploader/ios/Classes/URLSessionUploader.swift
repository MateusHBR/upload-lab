//
//  Uploader.swift
//  mobile_flutter_uploader
//
//  Created by Mateus de Morais Ramalho on 07/09/24.
//

import Foundation

class URLSessionUploader: NSObject {
    static let shared = URLSessionUploader()

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

    func enqueueUploadTask(_ request: URLRequest, task: UploadTask) -> URLSessionUploadTask? {
        guard let session = self.session,
              let wifiSession = self.wifiSession else {
            print("No session created")
            return nil
        }
        guard let firstChunk = task.chunksQueue.first else {
            print("Chunk not found")
            return nil
        }
        
        let activeSession = task.allowCellular ? session : wifiSession
        let uploadTask = activeSession.uploadTask(
                with: request,
                fromFile: firstChunk.file.path
        )
        uploadTask.taskDescription = firstChunk.taskId
        delegates.uploadEnqueued(taskId: firstChunk.taskId)
        uploadTask.resume()

        semaphore.wait()
        //TODO: Set task status to enqueued
        let enqueuedTask = UploadTask(id: task.id,
                                      tag: task.tag,
                                      progress: task.progress,
                                      allowCellular: task.allowCellular,
                                      status: .enqueue,
                                      file: task.file,
                                      session: task.session,
                                      chunksQueue: task.chunksQueue)
        self.runningTaskById[identifierForTask(uploadTask)] = enqueuedTask
        semaphore.signal()

        return uploadTask
    }
    
    private func uploadNextChunk(lastTask: URLSessionUploadTask) {
        print("NEXT CHUNK CALLED")
        self.semaphore.wait()
        defer { semaphore.signal() }
        
        guard let session = self.session,
              let wifiSession = self.wifiSession else {
            return
        }

        let lastTaskId = identifierForTask(lastTask)
        guard var task = self.runningTaskById[lastTaskId], !task.chunksQueue.isEmpty else {
            print("No more chunks \(self.runningTaskById[lastTaskId]?.id ?? "No task") --- \(self.runningTaskById[lastTaskId]?.chunksQueue.isEmpty ?? false)")
            self.runningTaskById.removeValue(forKey: lastTaskId)
            return
        }
        guard let taskSession = task.session else {
            print("No upload session exists")
            return
        }
        
        let activeSession = task.allowCellular ? session : wifiSession
        
        let previousChunk = task.chunksQueue.remove(at: 0)
        task.progress += Int64(previousChunk.file.size)
        
        guard let nextChunk = task.chunksQueue.first else { return }
        
        var request = URLRequest(url: taskSession.uploadURL)
        request.httpMethod = "PUT"
        request.setValue("bytes \(task.progress)-\(task.progress + Int64(nextChunk.file.size) - 1)/\(task.file.size)", forHTTPHeaderField: "Content-Range")
        request.setValue(taskSession.contentType, forHTTPHeaderField: "Content-Type")
        print("REQUEST: \(request) - HEADERS: \(request.allHTTPHeaderFields!)")
        
        let uploadTask = activeSession.uploadTask(
                with: request,
                fromFile: nextChunk.file.path
        )
        uploadTask.taskDescription = task.id

        delegates.uploadEnqueued(taskId: nextChunk.taskId)
        uploadTask.resume()
        self.runningTaskById.removeValue(forKey: lastTaskId)
        self.runningTaskById[identifierForTask(uploadTask)] = task
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

// MARK: - Keys
extension URLSessionUploader {
    struct Keys {
        static let backgroundSessionIdentifier = "com.mobile_flutter_uploader.upload.background"
        static let wifiBackgroundSessionIdentifier = "com.mobileflutter_uploader.upload.background.wifi"
    }
}

// MARK: - URLSessionDelegate
extension URLSessionUploader: URLSessionDelegate {
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
extension URLSessionUploader: URLSessionTaskDelegate {
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
        defer { semaphore.signal() }

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

            guard let runningTask else { return }

            let isRunning: (Int, Int, Int) -> Bool = { (current, previous, step) in
                let prev = previous + step
                return (current == 0 || current > prev || current >= 100) &&  current != previous
            }
            guard isRunning(
                Int(progress),
                runningTask.chunksQueue.first!.progress,
                MobileFlutterUploaderPlugin.stepUpdate) else { return }
            
            self.delegates.uploadProgressed(taskId: taskId, inStatus: .running, progress: Int(progress))
            let updatedTask = UploadTask(id: taskId,
                                                      tag: runningTask.tag,
                                                      progress: runningTask.progress,
                                                      allowCellular: runningTask.allowCellular,
                                                      status: .running,
                                                      file: runningTask.file,
                                                      session: runningTask.session,
                                                      chunksQueue: runningTask.chunksQueue)
            if var chunk = updatedTask.chunksQueue.first {
                chunk.progress = Int(progress)
            }
            self.runningTaskById[taskId] = updatedTask
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let uploadTask = task as? URLSessionUploadTask else {
            print("URLSessionDidCompleteWithError: not an upload task")
            return
        }
        
        let taskId = identifierForTask(uploadTask)

        if error != nil {
            print("URLSessionDidCompleteWithError: \(taskId) failed with \(error!.localizedDescription)")
            var uploadStatus: UploadTask.Status = .failed
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
            semaphore.wait()
            self.runningTaskById.removeValue(forKey: taskId)
            self.uploadedData.removeValue(forKey: taskId)
            semaphore.signal()
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
            print("URLSessionDidCompleteWithError: completed response: \(message ?? "null"), task: \(statusText)")
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
        
        semaphore.wait()
        self.uploadedData.removeValue(forKey: taskId)
        semaphore.signal()
        
        if response?.statusCode == 308 {
            uploadNextChunk(lastTask: uploadTask)
        } else {
            semaphore.wait()
            self.runningTaskById.removeValue(forKey: taskId)
            print(self.runningTaskById)
            semaphore.signal()
        }
    }
}

// MARK: - URLSessionDataDelegate
extension URLSessionUploader: URLSessionDataDelegate {
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
            print("URLSessionDidReceiveData: not an upload task")
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
