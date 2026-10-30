import Foundation
import Observation

/// One advertised service, e.g. "Office Printer" of type `_ipp._tcp.`.
/// Resolution (host, port, addresses, TXT) is lazy and starts with `resolve()`.
@Observable
final class ServiceInstance: Identifiable {
	enum ResolveState: Equatable {
		case idle
		case resolving
		case resolved
		case failed(String)
	}

	let name: String
	let type: String
	let domain: String
	let id: String

	private(set) var hostName: String?
	private(set) var port: Int?
	private(set) var addresses: [IPAddress] = []
	private(set) var txtRecords: [TXTEntry] = []
	private(set) var state: ResolveState = .idle

	// Display strings are stored, not computed: they are table sort keys and change only on resolve.
	/// Host name without the trailing root dot, e.g. `printer.local`.
	private(set) var displayHost = ""
	private(set) var portText = ""
	private(set) var ipv4Text = ""
	private(set) var ipv6Text = ""

	@ObservationIgnored let netService: NetService
	@ObservationIgnored private var resolver: Resolver?

	private static let resolveTimeout: TimeInterval = 10

	init(netService: NetService) {
		self.netService = netService
		name = netService.name
		type = netService.type
		domain = netService.domain
		id = Self.id(name: netService.name, type: netService.type, domain: netService.domain)
	}

	static func id(name: String, type: String, domain: String) -> String {
		"\(name).\(type)\(domain)".lowercased()
	}

	var kind: ServiceKind { ServiceCatalog.kind(forType: type, txtKeys: txtRecords.map(\.key)) }

	/// True for machine-generated names where the host is the readable handle.
	var hasOpaqueName: Bool { InstanceNameDecoder.isOpaque(name) }
	var portSortKey: Int { port ?? -1 }
	var ipv4: [IPAddress] { addresses.filter { $0.family == .v4 } }

	/// URL that opens this service in the default handler, when the type has a scheme.
	var url: URL? {
		guard let scheme = kind.scheme, let port else { return nil }
		guard let host = displayHost.isEmpty ? ipv4.first?.value : displayHost else { return nil }
		var components = URLComponents()
		components.scheme = scheme
		components.host = host
		components.port = port
		return components.url
	}

	/// Starts resolving and monitoring TXT record changes. Idempotent.
	func resolve() {
		guard resolver == nil else { return }
		let resolver = Resolver(owner: self)
		self.resolver = resolver
		netService.delegate = resolver
		netService.startMonitoring()
		applyTXTRecord(netService.txtRecordData())
		if state != .resolved {
			state = .resolving
			netService.resolve(withTimeout: Self.resolveTimeout)
		}
	}

	/// Stops monitoring. Resolved data is kept so the table stays populated.
	func stopMonitoring() {
		guard resolver != nil else { return }
		netService.stop()
		netService.stopMonitoring()
		netService.delegate = nil
		resolver = nil
		if state == .resolving {
			state = .idle
		}
	}

	func resolveAgain() {
		stopMonitoring()
		state = .idle
		resolve()
	}

	fileprivate func didResolve() {
		hostName = netService.hostName
		port = netService.port > 0 ? netService.port : nil
		var seen = Set<IPAddress>()
		addresses = (netService.addresses ?? [])
			.compactMap(IPAddress.init(socketAddress:))
			.filter { seen.insert($0).inserted }
			.sorted { lhs, rhs in
				if lhs.family != rhs.family { return lhs.family == .v4 }
				return lhs.value < rhs.value
			}
		displayHost = hostName?.removingTrailingDots() ?? ""
		portText = port.map(String.init) ?? ""
		ipv4Text = addresses.filter { $0.family == .v4 }.map(\.value).joined(separator: ", ")
		ipv6Text = addresses.filter { $0.family == .v6 }.map(\.value).joined(separator: ", ")
		// The TXT record can change during resolution without a didUpdateTXTRecord callback.
		applyTXTRecord(netService.txtRecordData())
		state = .resolved
	}

	fileprivate func didFailToResolve(_ errorDict: [String: NSNumber]) {
		state = .failed(NetServiceErrorText.message(for: errorDict))
	}

	fileprivate func applyTXTRecord(_ data: Data?) {
		txtRecords = data.map(TXTRecord.parse) ?? []
	}
}

/// NetService callbacks arrive on the main run loop, which is where the model is read.
private final class Resolver: NSObject, NetServiceDelegate {
	unowned let owner: ServiceInstance

	init(owner: ServiceInstance) {
		self.owner = owner
	}

	func netServiceDidResolveAddress(_ sender: NetService) {
		owner.didResolve()
	}

	func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
		owner.didFailToResolve(errorDict)
	}

	func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
		owner.applyTXTRecord(data)
	}
}
