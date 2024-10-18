//
//  UploaderService.swift
//  Pods
//
//  Created by Mateus de Morais Ramalho on 11/10/24.
//
class UploaderService {
    static let shared = UploaderService()
    
    let uploader: URLSessionUploader
    let fileManager: FileManager
    private let chunkSize = 4 * 1024 * 1024 // 4 MB
    
    // MARK: Public API
    func createUploadTask(uploadURL url: URL, filePath path: String) -> UploadTask {
        guard let filePathURL = URL(string: path),
            fileManager.fileExists(atPath: path) else {
            // Throws file does not exists
            print("File does not exists")
            return UploadTask(id: "", file: .init(path: URL(string: "")!, size: 0))
        }
        guard let fileHandle = try? FileHandle(forReadingFrom: filePathURL) else {
            print("Unable to open file")
            return UploadTask(id: "", file: .init(path: URL(string: "")!, size: 0))
        }
        let originalFileSize = fileHandle.seekToEndOfFile()
        try? fileHandle.close()
        
        let taskId = UUID().uuidString
        let file = UploadTask.FileMetadata(path: filePathURL, size: originalFileSize)
        var task = UploadTask(id: taskId, progress:  0, allowCellular: true, file: file)
        
        //TODO: create remote session and set id
        let session = UploadTask.Session(uploadURL: url, contentType: "png")
        task.session = session
        
        let chunks = splitFileIntoChunks(URL(fileURLWithPath: path), task: task)
        guard !chunks.isEmpty else {
            print("Empty file")
            //TODO: Throw exception
            return task
        }
        task.chunksQueue = chunks
        
        startUpload(url: url, task: task)
        return task
    }
    
    // MARK: Private API
    private init() {
        uploader = URLSessionUploader.shared
        fileManager = FileManager.default
    }
    
    private func splitFileIntoChunks(_ fileURL: URL, task: UploadTask) -> [UploadTask.Chunk] {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            print("Erro ao abrir o arquivo")
            return []
        }
        defer { fileHandle.closeFile() }
        
        var chunks: [UploadTask.Chunk] = []
        let fileSize = try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64 ?? 0
        var offset: UInt64 = 0
        
        let uploadTaskDir = fileManager.temporaryDirectory.appendingPathComponent(task.id)
        try? fileManager.removeItem(at: uploadTaskDir)
        try! fileManager.createDirectory(at: uploadTaskDir, withIntermediateDirectories: false) //TODO: Handle error
        
        while offset < (fileSize ?? 0) {
            let chunkSize = min(UInt64(self.chunkSize), (fileSize ?? 0) - offset)
            fileHandle.seek(toFileOffset: offset)
            let data = fileHandle.readData(ofLength: Int(chunkSize))
            
            let chunkTaskId = UUID().uuidString
            let chunkURL = uploadTaskDir.appendingPathComponent(chunkTaskId).appendingPathExtension("tmp")
            
            try! data.write(to: chunkURL, options: [.atomic]) //TODO: handle write failed
            
            let chunkFile = UploadTask.FileMetadata(path: chunkURL, size: chunkSize)
            let chunk = UploadTask.Chunk(taskId: chunkTaskId, uploadTaskId: task.id, file: chunkFile)
            chunks.append(chunk)
            
            offset += UInt64(data.count)
        }

        return chunks
    }

    func startUpload(url: URL, task: UploadTask) {
        guard task.chunksQueue.count > 0,
              let firstChunk = task.chunksQueue.first else {
            print("No chunk created") //TODO: throw
            return
        }
        guard let session = task.session else {
            print("No session created") //TODO: throw exception
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("bytes \(0)-\(firstChunk.file.size - 1)/\(task.file.size)", forHTTPHeaderField: "Content-Range")
        request.setValue(session.contentType, forHTTPHeaderField: "Content-Type")
        print("REQUEST: \(request) - HEADERS: \(request.allHTTPHeaderFields!)")
        
        let _ = uploader.enqueueUploadTask(request, task: task)
    }
}

// MARK: - UploaderDelegate
extension UploaderService: UploaderDelegate {
    func uploadEnqueued(taskId: String) {
        
    }
    
    func uploadProgressed(taskId: String, inStatus: UploadTask.Status, progress: Int) {
        
    }
    
    func uploadCompleted(taskId: String, message: String?, statusCode: Int, headers: [String : Any]) {
        //
    }
    
    func uploadFailed(taskId: String, inStatus: UploadTask.Status, statusCode: Int, errorCode: String, errorMessage: String?, errorStackTrace: [String]) {
        
    }
    
    
}
