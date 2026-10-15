//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import AnalyticsEvents

/// Bipe has no analytics (bipe#55). This client never starts and drops every event.
class DisabledAnalyticsClient: AnalyticsClientProtocol {
    let isRunning = false
    
    func start(analyticsConfiguration: AnalyticsConfiguration) { }
    
    func reset() { }
    
    func stop() { }
    
    func capture(_ event: AnalyticsEventProtocol) { }
    
    func screen(_ event: AnalyticsScreenProtocol) { }
    
    func updateUserProperties(_ event: AnalyticsEvent.UserProperties) { }
}
