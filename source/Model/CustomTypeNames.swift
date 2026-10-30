import Foundation
import Observation

/// User-chosen display names for service types, keyed by normalized type (`_nrd._tcp`).
/// Stored in UserDefaults; overrides every other naming source.
@Observable
final class CustomTypeNames {
	static let shared = CustomTypeNames()
	private static let defaultsKey = "CustomTypeNames"

	private(set) var names: [String: String]

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		names = defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
	}

	@ObservationIgnored private let defaults: UserDefaults

	func name(forType type: String) -> String? {
		name(forNormalizedType: ServiceCatalog.normalize(type))
	}

	func name(forNormalizedType key: String) -> String? {
		names[key]
	}

	/// Empty or whitespace-only names remove the override.
	func setName(_ name: String, forType type: String) {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		let key = ServiceCatalog.normalize(type)
		if trimmed.isEmpty {
			names.removeValue(forKey: key)
		} else {
			names[key] = trimmed
		}
		defaults.set(names, forKey: Self.defaultsKey)
	}

	func removeName(forType type: String) {
		setName("", forType: type)
	}
}
