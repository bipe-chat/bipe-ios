// Bipe: no Sentry or PostHog (bipe#55). The rageshake endpoint is nil, which disables bug reports.
nonisolated enum Secrets {
    static let rageshakeURL: String? = nil
    static let mapLibreAPIKey: String? = "your_key"

}