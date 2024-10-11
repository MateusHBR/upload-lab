//
//  Bundle+Extensions.swift
//  Pods
//
//  Created by Mateus de Morais Ramalho on 10/10/24.
//

fileprivate struct BundleKeys {
    static let maximumConcurrentTask = "FUMaximumConnectionsPerHost"
    static let maximumConcurrentUploadOperation = "FUMaximumUploadOperation"
    static let timeoutIntervalForRequest = "FUTimeoutInSeconds"
}


extension Bundle {
    var maximumConcurrentTask: Int {
        return self.object(forInfoDictionaryKey: BundleKeys.maximumConcurrentTask) as? Int ?? 3
    }
    
    var maximumConcurrentUploadOperation: Int {
        return self.object(forInfoDictionaryKey: BundleKeys.maximumConcurrentUploadOperation) as? Int ?? 2
    }
    
    var timeoutIntervalForRequest: Double {
        if let timeoutSetting = Bundle.main.object(forInfoDictionaryKey: BundleKeys.timeoutIntervalForRequest) as? NSNumber {
            return timeoutSetting.doubleValue
        } else {
            return 3600.0
        }
    }
}
