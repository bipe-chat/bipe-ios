// Bipe: no Sentry or PostHog (bipe#55). Problem reports go to the Bipe API on the server in Brazil (bipe#367).
nonisolated enum Secrets {
    static let rageshakeURL: String? = "https://api.bipe.net.br/v1/bug-reports/submit"
    static let mapLibreAPIKey: String? = "your_key"

}