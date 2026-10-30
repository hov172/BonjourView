import Foundation

/// Explains machine-generated instance names so the inspector can show what they encode.
/// Formats seen in the wild:
///   `_apple-mobdev2._tcp`  "ec:81:50:b7:8b:e6@fe80::ee81:50ff:feb7:8be6-supportsRP-26"
///   `_raop._tcp`           "7AD359201C0B@Living Room"
///   `_sleep-proxy._udp`    "70-35-60-63.1 Living Room"
///   `_trel._udp`           "ce4d5d96248bfd21" (Thread extended address)
///   `_nrd._tcp` and others  UUIDs
enum InstanceNameDecoder {
	struct Field: Identifiable, Equatable {
		let label: String
		let value: String
		var id: String { label + value }
	}

	static func decode(_ name: String) -> [Field] {
		if UUID(uuidString: name) != nil {
			return [Field(label: "Identifier", value: "Random UUID chosen by the advertising device")]
		}
		if let fields = decodeSleepProxy(name) { return fields }
		if let fields = decodeMACPrefixed(name) { return fields }
		if isHex(name, count: 16) {
			return [Field(label: "Thread Extended Address", value: "64-bit IEEE EUI-64 of the Thread interface")]
		}
		if isBase32Identifier(name) {
			return [Field(label: "Identifier", value: "Generated device ID")]
		}
		return []
	}

	/// Names that carry no human-readable device name at all; the host is the handle to show instead.
	static func isOpaque(_ name: String) -> Bool {
		if UUID(uuidString: name) != nil { return true }
		if isBase32Identifier(name) || isHex(name, count: 16) { return true }
		let head = name.split(separator: "@", maxSplits: 1).first.map(String.init) ?? name
		return isMAC(head)
	}

	// MARK: - Formats

	/// "<mac>@<ipv6>-<flags>" (Apple mobile device) or "<mac>@<device name>" (AirPlay audio / RAOP).
	private static func decodeMACPrefixed(_ name: String) -> [Field]? {
		guard let at = name.firstIndex(of: "@") else { return nil }
		let mac = String(name[..<at])
		guard isMAC(mac) else { return nil }
		let rest = String(name[name.index(after: at)...])

		var fields = [Field(label: "MAC Address", value: formattedMAC(mac))]
		if rest.hasPrefix("fe80:") {
			var parts = rest.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
			fields.append(Field(label: "Link-Local IPv6", value: parts.removeFirst()))
			for flag in parts where !flag.isEmpty {
				switch flag {
				case "supportsRP": fields.append(Field(label: "Capability", value: "Remote Pairing (wireless Xcode/Finder pairing)"))
				case _ where flag.allSatisfy(\.isNumber): fields.append(Field(label: "OS Version", value: "iOS \(flag)"))
				default: fields.append(Field(label: "Flag", value: flag))
				}
			}
		} else {
			fields.append(Field(label: "Device Name", value: rest))
		}
		return fields
	}

	/// Bonjour Sleep Proxy: "<type>-<portability>-<marginal power>-<total power>.<metric> <name>", lower is better.
	private static func decodeSleepProxy(_ name: String) -> [Field]? {
		guard let space = name.firstIndex(of: " ") else { return nil }
		let metrics = name[..<space]
		let deviceName = name[name.index(after: space)...].trimmingCharacters(in: .whitespaces)
		let halves = metrics.split(separator: ".", maxSplits: 1)
		guard halves.count == 2, let metric = Int(halves[1]) else { return nil }
		let scores = halves[0].split(separator: "-").compactMap { Int($0) }
		guard scores.count == 4 else { return nil }
		return [
			Field(label: "Proxy Score", value: "type \(scores[0]) · portability \(scores[1]) · marginal power \(scores[2]) · total power \(scores[3]) (lower is preferred)"),
			Field(label: "Metric", value: String(metric)),
			Field(label: "Device Name", value: deviceName),
		]
	}

	// MARK: - Shapes

	private static func isMAC(_ text: String) -> Bool {
		isHex(text.filter { $0 != ":" && $0 != "-" }, count: 12)
	}

	private static func isHex(_ text: String, count: Int) -> Bool {
		text.count == count && text.allSatisfy(\.isHexDigit) && text.contains(where: \.isNumber)
	}

	/// Long upper-case base32 blobs (A–Z, 2–7) such as "NEO2KVC6FGZIFXPLSBAVTAQT".
	private static func isBase32Identifier(_ text: String) -> Bool {
		text.count >= 20 && text.contains(where: \.isNumber)
			&& text.allSatisfy { ($0.isUppercase && $0.isLetter) || ("2"..."7").contains($0) }
	}

	private static func formattedMAC(_ mac: String) -> String {
		guard !mac.contains(":") else { return mac.lowercased() }
		let hex = Array(mac.lowercased())
		return stride(from: 0, to: hex.count, by: 2).map { String(hex[$0..<$0 + 2]) }.joined(separator: ":")
	}
}
