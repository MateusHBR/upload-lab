//
//  UploadTask.swift
//  Pods
//
//  Created by Mateus de Morais Ramalho on 10/10/24.
//
import Foundation

struct UploadTask {
    let id: String
    let tag: String?
    var progress: Int64
    let allowCellular: Bool
    let status: Status
    let file: FileMetadata
    var session: Session?
    var chunksQueue: [Chunk]

    init(id: String, tag: String? = nil, progress: Int64 = 0,
         allowCellular: Bool = true, status: Status = .undefined, file: FileMetadata,
         session: Session? = nil, chunksQueue: [Chunk] = []) {
        self.id = id
        self.status = status
        self.progress = progress
        self.tag = tag
        self.allowCellular = allowCellular
        self.file = file
        self.chunksQueue = chunksQueue
        self.session = session
    }
}

// MARK: - Status
extension UploadTask {
    enum Status: Int {
        case undefined = 0, enqueue, running, completed, failed, canceled, paused
    }
}

// MARK: - Session
extension UploadTask {
    struct Session {
        let uploadURL: URL
        let contentType: String
        
        init(uploadURL: URL, contentType: String) {
            self.uploadURL = uploadURL
            self.contentType = contentType
        }
    }
}

// MARK: - Chunk
extension UploadTask {
    struct Chunk {
        let taskId: String
        let uploadTaskId: String
        let status: Status
        var progress: Int
        let file: FileMetadata
        
        init(taskId: String, uploadTaskId: String, status: Status = .undefined,
             progress: Int = 0, file: FileMetadata) {
            self.uploadTaskId = uploadTaskId
            self.taskId = taskId
            self.status = status
            self.progress = progress
            self.file = file
        }
    }
}

extension UploadTask {
    struct FileMetadata {
        let path: URL
        let size: UInt64
        
        init(path: URL, size: UInt64) {
            self.path = path
            self.size = size
        }
    }
}

