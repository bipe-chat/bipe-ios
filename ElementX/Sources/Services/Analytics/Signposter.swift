//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

/// Performance instrumentation points. Bipe: no Sentry (bipe#55), so the calls record nothing.
class Signposter {
    
    enum TransactionName: Hashable {
        case cachedRoomList
        case upToDateRoomList
        case notificationToMessage
        case openRoom
        case sendMessage(uuid: String)
        
        var id: String {
            switch self {
            case .cachedRoomList:
                "Cached room list"
            case .upToDateRoomList:
                "Up-to-date room list"
            case .notificationToMessage:
                "Notification to message"
            case .openRoom:
                "Open a room"
            case .sendMessage:
                "Send a message"
            }
        }
    }
    
    enum SpanName: String {
        case timelineLoad = "Timeline load"
    }
    
    struct Span {
        func finish() { }
    }
    
    enum TagName: String {
        case homeserver
    }
    
    // MARK: - Transactions
    
    func startTransaction(_ transactionName: TransactionName, operation: String = "ux", tags: [TagName: String] = [:]) { }
    
    func finishTransaction(_ transactionName: TransactionName) { }
    
    func resetTransactions() { }
    
    // MARK: - Spans
    
    func addSpan(_ spanName: SpanName, toTransaction transactionName: TransactionName) -> Span? {
        nil
    }
    
    // MARK: - Tags
    
    func addGlobalTag(_ tagName: TagName, value: String) { }
}
