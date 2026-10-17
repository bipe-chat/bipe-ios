//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Testing

struct AppSettingsTests {
    @Test
    func defaultAccountProvider() {
        let appSettings = AppSettings.volatile()
        #expect(appSettings.defaultAccountProvider == appSettings.accountProviders[0])
        
        // Bipe: other account providers are not allowed by default, so a previous server is ignored.
        appSettings.previousServers = ["example.com"]
        #expect(appSettings.defaultAccountProvider == appSettings.accountProviders[0])
        
        appSettings.override(allowOtherAccountProviders: true)
        #expect(appSettings.defaultAccountProvider == .generic("example.com"))
    }
}

// MARK: - Helpers

private extension AppSettings {
    func override(allowOtherAccountProviders: Bool) {
        override(accountProviders: accountProviders,
                 allowOtherAccountProviders: allowOtherAccountProviders,
                 hideBrandChrome: hideBrandChrome,
                 pushGatewayBaseURL: pushGatewayBaseURL,
                 oAuthRedirectURL: oAuthRedirectURL,
                 oAuthClientURIPath: oAuthClientURIPath,
                 websiteURL: websiteURL,
                 logoURL: logoURL,
                 copyrightURL: copyrightURL,
                 acceptableUseURL: acceptableUseURL,
                 privacyURL: privacyURL,
                 encryptionURL: encryptionURL,
                 deviceVerificationURL: deviceVerificationURL,
                 chatBackupDetailsURL: chatBackupDetailsURL,
                 identityPinningViolationDetailsURL: identityPinningViolationDetailsURL,
                 historySharingDetailsURL: historySharingDetailsURL,
                 elementWebHosts: elementWebHosts,
                 accountProvisioningHost: accountProvisioningHost,
                 bugReportApplicationID: bugReportApplicationID,
                 analyticsTermsURL: analyticsTermsURL,
                 mapTilerConfiguration: mapTilerConfiguration.publisher.value)
    }
}
