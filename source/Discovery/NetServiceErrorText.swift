import Foundation

enum NetServiceErrorText {
	static func message(for errorDict: [String: NSNumber]) -> String {
		guard let raw = errorDict[NetService.errorCode]?.intValue else {
			return String(localized: "Unknown error")
		}
		switch NetService.ErrorCode(rawValue: raw) {
		case .timeoutError: return String(localized: "Timed out")
		case .notFoundError: return String(localized: "Not found")
		case .collisionError: return String(localized: "Name collision")
		case .activityInProgress: return String(localized: "Already in progress")
		case .badArgumentError: return String(localized: "Invalid service")
		case .cancelledError: return String(localized: "Cancelled")
		case .invalidError: return String(localized: "Invalid configuration")
		case .missingRequiredConfigurationError: return String(localized: "Missing configuration")
		default: return String(localized: "Error \(raw)")
		}
	}
}
