//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AnalyticsEvents
@testable import ElementX
import Testing

@MainActor
final class AnalyticsTests {
    private let appSettings: AppSettings
    private let analytics: AnalyticsServiceProtocol
    private let analyticsClient: AnalyticsClientMock
    
    init() {
        appSettings = AppSettings.volatile()
        
        analyticsClient = AnalyticsClientMock()
        analyticsClient.isRunning = false
        analytics = AnalyticsService(client: analyticsClient, appSettings: appSettings)
    }
    
    @Test
    func analyticsPromptNewUser() {
        // Given a fresh install of the app (without analytics having been set).
        // When the user is prompted for analytics.
        let showPrompt = analytics.shouldShowAnalyticsPrompt
        
        // Then the prompt should not be shown. Bipe has no analytics configuration (bipe#55).
        #expect(!showPrompt, "Bipe never shows the analytics prompt.")
    }
    
    @Test
    func analyticsPromptUserDeclined() {
        // Given an existing install of the app where the user previously declined analytics
        appSettings.analyticsConsentState = .optedOut
        
        // When the user is prompted for analytics
        let showPrompt = analytics.shouldShowAnalyticsPrompt
        
        // Then no prompt should be shown.
        #expect(!showPrompt, "A prompt should not be shown any more.")
    }
    
    @Test
    func analyticsPromptUserAccepted() {
        // Given an existing install of the app where the user previously accepted analytics
        appSettings.analyticsConsentState = .optedIn
        
        // When the user is prompted for analytics
        let showPrompt = analytics.shouldShowAnalyticsPrompt
        
        // Then no prompt should be shown.
        #expect(!showPrompt, "A prompt should not be shown any more.")
    }
    
    @Test
    func analyticsPromptNotDisplayed() {
        // Given a fresh install of the app Analytics should be disabled
        #expect(appSettings.analyticsConsentState == .unknown)
        #expect(!analytics.isEnabled)
        #expect(!analyticsClient.startAnalyticsConfigurationCalled)
    }
    
    @Test
    func analyticsOptOut() {
        // Given a fresh install of the app (without analytics having been set).
        // When analytics is opt-out
        analytics.optOut()
        // Then analytics should be disabled
        #expect(appSettings.analyticsConsentState == .optedOut)
        #expect(!analytics.isEnabled)
        #expect(!analyticsClient.isRunning)
        // Analytics client should have been stopped
        #expect(analyticsClient.stopCalled)
    }
    
    @Test
    func analyticsOptIn() {
        // Given a fresh install of the app (without analytics having been set).
        // When analytics is opt-in
        analytics.optIn()
        // The analytics should be enabled
        #expect(appSettings.analyticsConsentState == .optedIn)
        #expect(analytics.isEnabled)
        // Bipe: the analytics client never starts without a configuration (bipe#55).
        #expect(!analyticsClient.startAnalyticsConfigurationCalled)
    }
    
    @Test
    func analyticsStartIfNotEnabled() {
        // Given an existing install of the app where the user previously declined the tracking
        appSettings.analyticsConsentState = .optedOut
        // Analytics should not start
        #expect(!analytics.isEnabled)
        analytics.startIfEnabled()
        #expect(!analyticsClient.startAnalyticsConfigurationCalled)
    }
    
    @Test
    func analyticsStartIfEnabled() {
        // Given an existing install of the app where the user previously accepted the tracking
        appSettings.analyticsConsentState = .optedIn
        // Analytics should start
        #expect(analytics.isEnabled)
        analytics.startIfEnabled()
        // Bipe: the analytics client never starts without a configuration (bipe#55).
        #expect(!analyticsClient.startAnalyticsConfigurationCalled)
    }
    
    @Test
    func resetConsentState() {
        // Given an existing install of the app where the user previously accpeted the tracking
        appSettings.analyticsConsentState = .optedIn
        #expect(!analytics.shouldShowAnalyticsPrompt)
        
        // When forgetting analytics consents
        analytics.resetConsentState()
        
        // Then the consent state is unknown again. Bipe still shows no prompt (bipe#55).
        #expect(appSettings.analyticsConsentState == .unknown)
        #expect(!analytics.shouldShowAnalyticsPrompt)
    }
}
