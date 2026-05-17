import Foundation

struct AppVersion {
    static var currentMarketingVersion: String {
        if let value = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           !value.isEmpty {
            return value
        }
        return AppBuildInfo.marketingVersion
    }

    static var currentBuildVersion: String {
        if let value = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
           !value.isEmpty {
            return value
        }
        return AppBuildInfo.buildVersion
    }

    /// Integer build number for runtime compatibility checks.
    static var build: Int {
        Int(currentBuildVersion) ?? 0
    }

    static var fullVersionString: String {
        "\(currentMarketingVersion) (\(currentBuildVersion))"
    }
}
