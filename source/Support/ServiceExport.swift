import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
	case json
	case csv

	var id: String { rawValue }
	var title: String { rawValue.uppercased() }

	var contentType: UTType {
		switch self {
		case .json: return .json
		case .csv: return .commaSeparatedText
		}
	}
}

/// Flat, Codable snapshot of a service for export and copy.
struct ServiceRecord: Codable, Equatable {
	let name: String
	let type: String
	let domain: String
	let host: String?
	let port: Int?
	let addresses: [String]
	let txt: [String: String]

	init(_ instance: ServiceInstance) {
		name = instance.name
		type = instance.type
		domain = instance.domain
		host = instance.displayHost.isEmpty ? nil : instance.displayHost
		port = instance.port
		addresses = instance.addresses.map(\.value)
		txt = Dictionary(instance.txtRecords.map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
	}
}

enum ServiceExport {
	static let csvHeader = ["Name", "Type", "Domain", "Host", "Port", "Addresses", "TXT"]

	static func data(for instances: [ServiceInstance], format: ExportFormat) throws -> Data {
		let records = instances.map(ServiceRecord.init)
		switch format {
		case .json: return try json(records)
		case .csv: return Data(csv(records).utf8)
		}
	}

	static func json(_ records: [ServiceRecord]) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return try encoder.encode(records)
	}

	/// Pretty JSON for the pasteboard; nil only if encoding fails, which Codable structs of strings do not.
	static func jsonText(_ instances: [ServiceInstance]) -> String? {
		(try? json(instances.map(ServiceRecord.init))).flatMap { String(data: $0, encoding: .utf8) }
	}

	static func csv(_ records: [ServiceRecord]) -> String {
		let rows = records.map { record in
			[
				record.name,
				record.type,
				record.domain,
				record.host ?? "",
				record.port.map(String.init) ?? "",
				record.addresses.joined(separator: " "),
				record.txt.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "),
			].map(csvField).joined(separator: ",")
		}
		return ([csvHeader.joined(separator: ",")] + rows).joined(separator: "\n") + "\n"
	}

	/// RFC 4180 quoting: wrap when the field contains a comma, quote or newline; double embedded quotes.
	static func csvField(_ field: String) -> String {
		guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
		return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
	}

	/// Tab-separated line used by Copy in the table.
	static func tsvLine(_ instance: ServiceInstance) -> String {
		[instance.name, instance.displayHost, instance.portText, instance.ipv4Text, instance.ipv6Text]
			.joined(separator: "\t")
	}
}

/// Already-encoded export bytes plus their format, for `fileExporter`.
struct ExportDocument: FileDocument {
	static let readableContentTypes = ExportFormat.allCases.map(\.contentType)

	let data: Data
	let format: ExportFormat

	init(data: Data, format: ExportFormat) {
		self.data = data
		self.format = format
	}

	init(configuration: ReadConfiguration) throws {
		data = configuration.file.regularFileContents ?? Data()
		format = .json
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		FileWrapper(regularFileWithContents: data)
	}
}
