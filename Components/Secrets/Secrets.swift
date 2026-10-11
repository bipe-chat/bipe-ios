// Proseio: telemetry and bug-report endpoints are nil, which disables Sentry, PostHog,
// Element Call analytics and rageshake. No data goes to Element or US services.
nonisolated enum Secrets {
    static let sentryDSN: String? = nil
    static let sentryRustDSN: String? = nil
    static let postHogHost: String? = nil
    static let postHogAPIKey: String? = nil
    static let rageshakeURL: String? = nil
    static let mapLibreAPIKey: String? = "your_key"

}