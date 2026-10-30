import Foundation
import Observation

/// Root of the discovery tree: domains → service types → instances.
/// Each domain and type owns the browser session that feeds it. This object also owns the
/// resolve policy: which instances resolve, and when monitoring stops.
@Observable
final class BonjourBrowser {
	private(set) var domains: [ServiceDomain] = []
	private(set) var isBrowsing = false
	private(set) var lastError: String?

	@ObservationIgnored private let settings: AppSettings
	@ObservationIgnored private var domainSession: NetServiceBrowserSession?
	@ObservationIgnored private var focusedTypeID: String?
	/// Type to reselect after a restart, since the list clears its selection when rows vanish.
	@ObservationIgnored private var pendingReselectID: String?

	init(settings: AppSettings = .shared) {
		self.settings = settings
	}

	var typeCount: Int { domains.reduce(0) { $0 + $1.types.count } }
	var instanceCount: Int { domains.reduce(0) { $0 + $1.types.reduce(0) { $0 + $1.instances.count } } }
	var hasInstances: Bool { domains.contains { $0.types.contains { !$0.instances.isEmpty } } }
	var allInstances: [ServiceInstance] { domains.flatMap { $0.types.flatMap(\.instances) } }

	func type(withID id: String?) -> ServiceType? {
		guard let id else { return nil }
		return domains.lazy.flatMap(\.types).first { $0.id == id }
	}

	func start() {
		guard !isBrowsing else { return }
		isBrowsing = true
		lastError = nil
		let session = NetServiceBrowserSession(query: .domains, includesPeerToPeer: settings.includePeerToPeer)
		session.onDomainFound = { [weak self] in self?.addDomain($0) }
		session.onDomainRemoved = { [weak self] in self?.removeDomain($0) }
		session.onError = { [weak self] in self?.lastError = $0 }
		domainSession = session
		session.start()
	}

	/// Drops everything and browses again, picking up changed settings.
	func restart() {
		pendingReselectID = focusedTypeID
		domainSession?.stop()
		domainSession = nil
		domains.forEach { $0.stop() }
		domains = []
		isBrowsing = false
		start()
	}

	/// The selected type resolves all its instances; the previously selected one stops monitoring
	/// unless everything resolves automatically. Call again when the focused type gains instances.
	func focus(on typeID: String?) {
		if focusedTypeID != typeID, !settings.resolveAutomatically {
			type(withID: focusedTypeID)?.instances.forEach { $0.stopMonitoring() }
		}
		focusedTypeID = typeID
		type(withID: typeID)?.instances.forEach { $0.resolve() }
	}

	/// After a restart, returns the previously selected type's ID once that type exists again.
	func takeReselectID() -> String? {
		guard let id = pendingReselectID, type(withID: id) != nil else { return nil }
		pendingReselectID = nil
		return id
	}

	/// Resolve everything that exists; used when the automatic-resolve setting turns on.
	func resolveAll() {
		allInstances.forEach { $0.resolve() }
	}

	private func addDomain(_ name: String) {
		let id = ServiceCatalog.normalize(name)
		guard !domains.contains(where: { $0.id == id }) else { return }
		let domain = ServiceDomain(name: name)
		domains.append(domain)
		domains.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

		let session = NetServiceBrowserSession(query: .serviceTypes(domain: name), includesPeerToPeer: settings.includePeerToPeer)
		session.onServiceFound = { [weak self, weak domain] service, _ in
			guard let self, let domain, let type = ServiceCatalog.serviceType(fromMetaQueryResult: service) else { return }
			self.addType(type, to: domain)
		}
		session.onServiceRemoved = { [weak domain] service in
			guard let type = ServiceCatalog.serviceType(fromMetaQueryResult: service) else { return }
			domain?.remove(type: type)
		}
		session.onError = { [weak self] in self?.lastError = $0 }
		domain.session = session
		session.start()
	}

	private func removeDomain(_ name: String) {
		let id = ServiceCatalog.normalize(name)
		guard let index = domains.firstIndex(where: { $0.id == id }) else { return }
		domains.remove(at: index).stop()
	}

	private func addType(_ type: String, to domain: ServiceDomain) {
		guard let serviceType = domain.add(type: type) else { return }
		// Unknown types resolve eagerly so a TXT-record hint (e.g. QuickDrop) can name them in the sidebar.
		let resolvesOnDiscovery = !serviceType.kind.isKnown
		let session = NetServiceBrowserSession(query: .instances(type: type, domain: domain.name), includesPeerToPeer: settings.includePeerToPeer)
		session.onServiceFound = { [weak self, weak serviceType] service, moreComing in
			guard let self, let serviceType, let instance = serviceType.add(service, moreComing: moreComing) else { return }
			if self.settings.resolveAutomatically || resolvesOnDiscovery || serviceType.id == self.focusedTypeID {
				instance.resolve()
			}
		}
		session.onServiceRemoved = { [weak serviceType] service in
			serviceType?.remove(service)
		}
		session.onError = { [weak self] in self?.lastError = $0 }
		serviceType.session = session
		session.start()
	}
}
