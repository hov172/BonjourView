import Foundation
import Observation

/// A browsable DNS-SD domain, normally just `local.`.
@Observable
final class ServiceDomain: Identifiable {
	let name: String
	let id: String
	private(set) var types: [ServiceType] = []

	/// The meta-query session that enumerates this domain's service types.
	@ObservationIgnored var session: NetServiceBrowserSession?

	init(name: String) {
		self.name = name
		id = ServiceCatalog.normalize(name)
	}

	var displayName: String {
		id == "local" ? String(localized: "Local Network") : name
	}

	func type(named type: String) -> ServiceType? {
		let id = ServiceType.id(type: type, domain: name)
		return types.first { $0.id == id }
	}

	@discardableResult
	func add(type: String) -> ServiceType? {
		guard self.type(named: type) == nil else { return nil }
		let serviceType = ServiceType(type: type, domain: name)
		let newName = serviceType.kind.name
		let index = types.firstIndex { $0.kind.name.localizedStandardCompare(newName) == .orderedDescending } ?? types.endIndex
		types.insert(serviceType, at: index)
		return serviceType
	}

	func remove(type: String) {
		guard let match = self.type(named: type), let index = types.firstIndex(where: { $0 === match }) else { return }
		types.remove(at: index).stop()
	}

	func stop() {
		session?.stop()
		session = nil
		types.forEach { $0.stop() }
		types = []
	}
}
