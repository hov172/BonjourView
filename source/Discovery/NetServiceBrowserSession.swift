import Foundation

/// One `NetServiceBrowser` and the query it runs. Results are forwarded through closures.
/// Callbacks arrive on the main run loop.
final class NetServiceBrowserSession: NSObject, NetServiceBrowserDelegate {
	enum Query {
		case domains
		case serviceTypes(domain: String)
		case instances(type: String, domain: String)
	}

	static let metaQueryType = "_services._dns-sd._udp."

	private let query: Query
	private let browser = NetServiceBrowser()

	var onDomainFound: ((String) -> Void)?
	var onDomainRemoved: ((String) -> Void)?
	/// `moreComing` is true while the responder still has queued results; callers batch until it is false.
	var onServiceFound: ((NetService, _ moreComing: Bool) -> Void)?
	var onServiceRemoved: ((NetService) -> Void)?
	var onError: ((String) -> Void)?

	init(query: Query, includesPeerToPeer: Bool) {
		self.query = query
		super.init()
		browser.includesPeerToPeer = includesPeerToPeer
		browser.delegate = self
	}

	func start() {
		switch query {
		case .domains:
			browser.searchForBrowsableDomains()
		case .serviceTypes(let domain):
			// PTR query for "_services._dns-sd._udp.<domain>" lists every advertised type.
			// See https://developer.apple.com/library/archive/qa/qa1337/
			browser.searchForServices(ofType: Self.metaQueryType, inDomain: domain)
		case .instances(let type, let domain):
			browser.searchForServices(ofType: type, inDomain: domain)
		}
	}

	func stop() {
		browser.delegate = nil
		browser.stop()
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
		onDomainFound?(domainString)
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
		onDomainRemoved?(domainString)
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
		onServiceFound?(service, moreComing)
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
		onServiceRemoved?(service)
	}

	func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
		onError?(NetServiceErrorText.message(for: errorDict))
	}
}
