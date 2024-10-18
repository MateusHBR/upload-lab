//
//  Logger.swift
//  Pods
//
//  Created by Mateus de Morais Ramalho on 10/10/24.
//

class UploaderDelegateLogger: UploaderDelegate {
    func uploadEnqueued(taskId: String) {
        print("Task enqueued: \(taskId)")
    }

    func uploadProgressed(taskId: String, inStatus: UploadTask.Status, progress: Int) {
        print("Task progress: \(taskId) - \(inStatus) - \(progress)")
    }

    func uploadCompleted(taskId: String, message: String?, statusCode: Int, headers: [String: Any]) {
        print("Task completed: \(taskId) - \(message) - \(statusCode)")
    }

    func uploadFailed(taskId: String, inStatus: UploadTask.Status, statusCode: Int, errorCode: String, errorMessage: String?, errorStackTrace: [String]) {
        print("Task failed: \(taskId) - \(inStatus) - \(statusCode) - \(errorCode) - \(errorMessage)")
    }
}
