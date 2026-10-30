import Foundation

struct IPAddress: Hashable {
	enum Family: Hashable {
		case v4
		case v6

		var label: String {
			switch self {
			case .v4: return "IPv4"
			case .v6: return "IPv6"
			}
		}
	}

	let value: String
	let family: Family

	/// Converts a `sockaddr` blob from `NetService.addresses` into a numeric address.
	init?(socketAddress data: Data) {
		guard data.count >= MemoryLayout<sockaddr>.size else { return nil }
		let parsed: (String, Family)? = data.withUnsafeBytes { raw in
			guard let base = raw.baseAddress else { return nil }
			let address = base.assumingMemoryBound(to: sockaddr.self)
			let family: Family
			switch Int32(address.pointee.sa_family) {
			case AF_INET: family = .v4
			case AF_INET6: family = .v6
			default: return nil
			}
			var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
			guard getnameinfo(address, socklen_t(data.count), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
			return (String(cString: host), family)
		}
		guard let (value, family) = parsed else { return nil }
		self.value = value
		self.family = family
	}

	init(value: String, family: Family) {
		self.value = value
		self.family = family
	}
}
