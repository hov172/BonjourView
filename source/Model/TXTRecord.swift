import Foundation

struct TXTEntry: Identifiable, Hashable {
	let key: String
	let value: String
	/// True when the value could not be decoded as UTF-8 and is shown as hex.
	let isBinary: Bool

	var id: String { key.isEmpty ? "binary:\(value)" : key.lowercased() }

	/// Short form for display: text as-is, binary as a byte count plus the first bytes.
	var displayValue: String {
		guard isBinary else { return value }
		let groups = value.split(separator: " ")
		guard groups.count > Self.previewBytes else { return value }
		return "\(groups.count) bytes · " + groups.prefix(Self.previewBytes).joined(separator: " ") + " …"
	}

	private static let previewBytes = 8
}

/// Parses the DNS-SD TXT record wire format (RFC 6763 §6):
/// a sequence of length-prefixed strings, each `key`, `key=` or `key=value`.
/// Implemented directly instead of via `NetService.dictionary(fromTXTRecord:)`,
/// which inserts `NSNull` for values that are not `key=value` and crashes when bridged.
enum TXTRecord {
	static func parse(_ data: Data) -> [TXTEntry] {
		var entries: [TXTEntry] = []
		var seenKeys = Set<String>()
		var index = data.startIndex

		while index < data.endIndex {
			let length = Int(data[index])
			index += 1
			guard length > 0 else { continue }
			let end = min(index + length, data.endIndex)
			let item = data[index..<end]
			index = end

			guard let entry = Self.entry(from: item) else { continue }
			if !entry.key.isEmpty {
				// RFC 6763 §6.4: keys are case-insensitive and the first occurrence wins.
				guard seenKeys.insert(entry.key.lowercased()).inserted else { continue }
			}
			entries.append(entry)
		}

		return entries.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
	}

	private static func entry(from item: Data) -> TXTEntry? {
		// RFC 6763 §6.4: an item with a zero-length key ("=value") must be ignored.
		guard item.first != UInt8(ascii: "=") else { return nil }
		if let separator = item.firstIndex(of: UInt8(ascii: "=")), separator > item.startIndex,
		   let key = String(data: item[item.startIndex..<separator], encoding: .utf8), isValidKey(key) {
			let valueData = item[item.index(after: separator)...]
			if let value = String(data: valueData, encoding: .utf8), isPrintable(value) {
				return TXTEntry(key: key, value: value, isBinary: false)
			}
			return TXTEntry(key: key, value: hex(valueData), isBinary: true)
		}
		if let key = String(data: item, encoding: .utf8), isValidKey(key) {
			return TXTEntry(key: key, value: "", isBinary: false)
		}
		return TXTEntry(key: "", value: hex(item), isBinary: true)
	}

	/// RFC 6763 §6.4: printable ASCII excluding `=`.
	private static func isValidKey(_ key: String) -> Bool {
		!key.isEmpty && key.utf8.allSatisfy { $0 >= 0x20 && $0 < 0x7F && $0 != UInt8(ascii: "=") }
	}

	/// Control characters other than tab and newline mean the value is a binary blob, not text.
	private static func isPrintable(_ text: String) -> Bool {
		text.unicodeScalars.allSatisfy { $0 == "\t" || $0 == "\n" || $0 == "\r" || !($0.value < 0x20 || $0.value == 0x7F) }
	}

	private static func hex(_ data: Data) -> String {
		data.map { String(format: "%02x", $0) }.joined(separator: " ")
	}
}
