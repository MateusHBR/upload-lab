//
//  URLSessionTask.State+Extensions.swift
//  Pods
//
//  Created by Mateus de Morais Ramalho on 11/10/24.
//
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
