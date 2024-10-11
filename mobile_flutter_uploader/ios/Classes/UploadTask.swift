//
//  UploadTask.swift
//  Pods
//
//  Created by Mateus de Morais Ramalho on 10/10/24.
//
import Foundation

enum UploadTaskStatus: Int {
    case undefined = 0, enqueue, running, completed, failed, canceled, paused
}

struct UploadTask {
    let taskId: String
    let status: UploadTaskStatus
    let progress: Int
    let tag: String?
    let allowCellular: Bool

    init(taskId: String, status: UploadTaskStatus, progress: Int, tag: String? = nil, allowCellular: Bool = true) {
        self.taskId = taskId
        self.status = status
        self.progress = progress
        self.tag = tag
        self.allowCellular = allowCellular
    }
}

extension URLSessionTask.State {
    func statusText() -> String {
        switch self {
        case .running:
            return "running"
        case .canceling:
            return "canceling"
        case .completed:
            return "completed"
        case .suspended:
            return "suspended"
        default:
            return "unknown"
        }
    }
}
