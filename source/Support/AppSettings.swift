import Foundation
import Observation

/// User preferences, persisted in UserDefaults. One object, one key list.
@Observable
final class AppSettings {
	static let shared = AppSettings()

	var resolveAutomatically: Bool { didSet { defaults.set(resolveAutomatically, forKey: "ResolveAutomatically") } }
	var showRawTypeNames: Bool { didSet { defaults.set(showRawTypeNames, forKey: "ShowRawTypeNames") } }
	var includePeerToPeer: Bool { didSet { defaults.set(includePeerToPeer, forKey: "IncludePeerToPeer") } }
	var updateServiceNamesAutomatically: Bool { didSet { defaults.set(updateServiceNamesAutomatically, forKey: "UpdateServiceNamesAutomatically") } }

	@ObservationIgnored private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		resolveAutomatically = defaults.bool(forKey: "ResolveAutomatically")
		showRawTypeNames = defaults.bool(forKey: "ShowRawTypeNames")
		includePeerToPeer = defaults.object(forKey: "IncludePeerToPeer") as? Bool ?? true
		updateServiceNamesAutomatically = defaults.object(forKey: "UpdateServiceNamesAutomatically") as? Bool ?? true
	}
}
