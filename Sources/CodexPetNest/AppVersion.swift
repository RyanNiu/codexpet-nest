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

    static var fullVersionString: String {
        "\(currentMarketingVersion) (\(currentBuildVersion))"
    }
}
