import Foundation
import Testing
@testable import Bonjeff

struct ServiceExportTests {
	private func instance(name: String = "Office Printer") -> ServiceInstance {
		ServiceInstance(netService: NetService(domain: "local.", type: "_ipp._tcp.", name: name))
	}

	@Test func csvFieldQuotesOnlyWhenNeeded() {
		#expect(ServiceExport.csvField("plain") == "plain")
		#expect(ServiceExport.csvField("a,b") == "\"a,b\"")
		#expect(ServiceExport.csvField("say \"hi\"") == "\"say \"\"hi\"\"\"")
		#expect(ServiceExport.csvField("line\nbreak") == "\"line\nbreak\"")
	}

	@Test func csvHasHeaderAndOneRowPerRecord() {
		let csv = ServiceExport.csv([ServiceRecord(instance(name: "A, Inc")), ServiceRecord(instance(name: "B"))])
		let lines = csv.split(separator: "\n")

		#expect(lines.count == 3)
		#expect(lines[0] == "Name,Type,Domain,Host,Port,Addresses,TXT")
		#expect(lines[1].hasPrefix("\"A, Inc\",_ipp._tcp.,local.,"))
	}

	@Test func jsonRoundTripsThroughCodable() throws {
		let records = [ServiceRecord(instance())]

		let data = try ServiceExport.json(records)
		let decoded = try JSONDecoder().decode([ServiceRecord].self, from: data)

		#expect(decoded == records)
		#expect(decoded[0].host == nil)
		#expect(decoded[0].port == nil)
	}

	@Test func tsvLineHasFiveColumns() {
		let line = ServiceExport.tsvLine(instance())

		#expect(line.split(separator: "\t", omittingEmptySubsequences: false).count == 5)
		#expect(line.hasPrefix("Office Printer\t"))
	}

	@Test func unresolvedInstanceHasNoURL() {
		#expect(instance().url == nil)
		#expect(instance().displayHost == "")
		#expect(instance().state == .idle)
	}
}
