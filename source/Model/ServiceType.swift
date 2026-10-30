import Foundation
import Observation

/// All instances of one service type in one domain, e.g. `_ipp._tcp.` in `local.`.
@Observable
final class ServiceType: Identifiable {
	let type: String
	let domain: String
	let id: String
	private(set) var instances: [ServiceInstance] = []

	/// The browser session that discovers this type's instances. Owned here so its lifetime matches the type.
	@ObservationIgnored var session: NetServiceBrowserSession?
	@ObservationIgnored private var pending: [ServiceInstance] = []
	@ObservationIgnored private var flushTask: Task<Void, Never>?
	/// Safety net: the responder sometimes ends a burst with `moreComing == true`.
	private static let flushDelay: Duration = .milliseconds(200)

	init(type: String, domain: String) {
		self.type = type
		self.domain = domain
		id = Self.id(type: type, domain: domain)
	}

	static func id(type: String, domain: String) -> String {
		ServiceCatalog.normalize(type) + "." + ServiceCatalog.normalize(domain)
	}

	/// Falls back to a TXT-record hint from any resolved instance when the type itself is unknown.
	var kind: ServiceKind {
		ServiceCatalog.kind(forType: type, txtKeys: instances.flatMap { $0.txtRecords.map(\.key) })
	}

	func instances(withIDs ids: Set<String>) -> [ServiceInstance] {
		instances.filter { ids.contains($0.id) }
	}

	/// Queues the instance; the list is published once per discovery burst (when `moreComing` is false).
	@discardableResult
	func add(_ netService: NetService, moreComing: Bool = false) -> ServiceInstance? {
		let id = ServiceInstance.id(name: netService.name, type: netService.type, domain: netService.domain)
		guard !instances.contains(where: { $0.id == id }), !pending.contains(where: { $0.id == id }) else { return nil }
		let instance = ServiceInstance(netService: netService)
		pending.append(instance)
		if moreComing {
			scheduleFlush()
		} else {
			flush()
		}
		return instance
	}

	func remove(_ netService: NetService) {
		let id = ServiceInstance.id(name: netService.name, type: netService.type, domain: netService.domain)
		pending.removeAll { $0.id == id }
		guard let index = instances.firstIndex(where: { $0.id == id }) else { return }
		instances.remove(at: index).stopMonitoring()
	}

	private func scheduleFlush() {
		flushTask?.cancel()
		flushTask = Task { @MainActor [weak self] in
			try? await Task.sleep(for: Self.flushDelay)
			guard !Task.isCancelled else { return }
			self?.flush()
		}
	}

	private func flush() {
		flushTask?.cancel()
		flushTask = nil
		guard !pending.isEmpty else { return }
		instances = (instances + pending).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
		pending = []
	}

	func stop() {
		session?.stop()
		session = nil
		flushTask?.cancel()
		pending = []
		instances.forEach { $0.stopMonitoring() }
		instances = []
	}
}
