//
//  XYNetToolLogAdapter.swift
//  XYDevTool
//

import Foundation

/// App 层适配器：将基础网络工具产生的事件转为本地运行日志。
final class XYNetToolLogAdapter: XYNetToolEventSink {
    static let shared = XYNetToolLogAdapter()

    private init() {}

    func receive(_ event: XYNetToolEvent) {
        AppLogger.shared.track(
            category: .network,
            name: event.name,
            level: event.level == .error ? .error : .info,
            result: mapResult(event.result),
            metadata: event.metadata
        )
    }

    private func mapResult(_ result: XYNetToolEventResult?) -> AppLogResult? {
        switch result {
        case .success: return .success
        case .failure: return .failure
        case nil: return nil
        }
    }
}
