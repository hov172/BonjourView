import Foundation
import Observation
import TabularData

/// Service-name descriptions from IANA's Service Name and Transport Protocol Port Number Registry.
/// A snapshot ships in the bundle; a fresh copy of the same public file can be fetched periodically.
/// Nothing about the user's network is ever sent; only the static CSV is downloaded.
@Observable
final class IANARegistry {
	static let shared = IANARegistry()

	static let registryURL = URL(string: "https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.csv")!
	static let resourceName = "service-names-port-numbers"
	static let updateInterval: TimeInterval = 7 * 24 * 60 * 60
	/// A real registry has thousands of rows; anything smaller is a bad download.
	static let minimumEntryCount = 1000
	private static let lastUpdatedKey = "IANARegistryLastUpdated"

	private(set) var descriptions: [String: String]
	private(set) var isUpdating = false
	private(set) var lastError: String?
	private(set) var lastUpdated: Date? = UserDefaults.standard.object(forKey: IANARegistry.lastUpdatedKey) as? Date

	@ObservationIgnored private var loadTask: Task<Void, Never>?

	init(descriptions: [String: String] = [:]) {
		self.descriptions = descriptions
		if !descriptions.isEmpty { loadTask = Task {} }
	}

	var entryCount: Int { descriptions.count }

	/// `"airplay"` → `"Protocol for streaming of audio/video content"`. Triggers the initial load on first use.
	func description(forServiceName name: String) -> String? {
		loadIfNeeded()
		return descriptions[name.lowercased()]
	}

	/// Parses the cached download, or the bundled snapshot, off the main thread. Safe to call repeatedly.
	func loadIfNeeded() {
		guard loadTask == nil else { return }
		loadTask = Task { [weak self] in
			let table = await Task.detached(priority: .utility) { Self.loadFromDisk() }.value
			self?.descriptions = table
		}
	}

	/// Downloads a new copy when the last one is older than `updateInterval`.
	func updateIfStale() async {
		if let lastUpdated, Date().timeIntervalSince(lastUpdated) < Self.updateInterval { return }
		await update()
	}

	func update() async {
		guard !isUpdating else { return }
		isUpdating = true
		lastError = nil
		defer { isUpdating = false }
		do {
			let (data, response) = try await URLSession.shared.data(from: Self.registryURL)
			guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
				throw URLError(.badServerResponse)
			}
			guard let csv = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
			guard let parsed = await Task.detached(priority: .utility, operation: { Self.validParse(csv: csv) }).value else {
				throw URLError(.cannotParseResponse)
			}
			if let cacheURL = Self.cacheURL {
				try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
				try data.write(to: cacheURL, options: .atomic)
			}
			descriptions = parsed
			lastUpdated = Date()
			UserDefaults.standard.set(lastUpdated, forKey: Self.lastUpdatedKey)
		} catch {
			lastError = error.localizedDescription
		}
	}

	/// Valid cache wins; otherwise the bundled snapshot; otherwise empty.
	private static func loadFromDisk() -> [String: String] {
		if let cacheURL, let csv = try? String(contentsOf: cacheURL, encoding: .utf8), let parsed = validParse(csv: csv) {
			return parsed
		}
		if let url = Bundle.main.url(forResource: resourceName, withExtension: "csv"),
		   let csv = try? String(contentsOf: url, encoding: .utf8) {
			return parse(csv: csv)
		}
		return [:]
	}

	/// `parse` plus the size sanity check shared by the disk and download paths.
	static func validParse(csv: String) -> [String: String]? {
		let parsed = parse(csv: csv)
		return parsed.count >= minimumEntryCount ? parsed : nil
	}

	private static let nameColumn = "Service Name"
	private static let descriptionColumn = "Description"

	/// Service Name → Description, first occurrence wins, placeholder rows skipped.
	static func parse(csv: String) -> [String: String] {
		let columns = [nameColumn, descriptionColumn]
		guard let frame = try? DataFrame(
			csvData: Data(csv.utf8),
			columns: columns,
			types: Dictionary(uniqueKeysWithValues: columns.map { ($0, CSVType.string) }),
			options: CSVReadingOptions(hasHeaderRow: true)
		) else { return [:] }
		var table: [String: String] = [:]
		for row in frame.rows {
			guard let rawName = row[nameColumn] as? String, let rawDescription = row[descriptionColumn] as? String else { continue }
			let name = rawName.trimmingCharacters(in: .whitespaces).lowercased()
			let description = rawDescription
				.replacingOccurrences(of: "\n", with: " ")
				.trimmingCharacters(in: .whitespacesAndNewlines)
				.removingTrailingDots()
			guard !name.isEmpty, !description.isEmpty, table[name] == nil, !isPlaceholder(description) else { continue }
			table[name] = description
		}
		return table
	}

	private static func isPlaceholder(_ description: String) -> Bool {
		let lowered = description.lowercased()
		return lowered == "unassigned" || lowered == "reserved" || lowered.hasPrefix("de-registered") || lowered.hasPrefix("deprecated")
	}

	private static var cacheURL: URL? {
		FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
			.appendingPathComponent("IANA", isDirectory: true)
			.appendingPathComponent("\(resourceName).csv")
	}
}
