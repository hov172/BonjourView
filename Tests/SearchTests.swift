import Foundation
import Testing
@testable import Bonjeff

struct SearchTests {
	private func type(with names: [String]) -> ServiceType {
		let type = ServiceType(type: "_raop._tcp.", domain: "local.")
		for name in names {
			type.add(NetService(domain: "local.", type: "_raop._tcp.", name: name))
		}
		return type
	}

	@Test func typeNameMatchShowsAllInstances() {
		let type = type(with: ["7AD359201C0B@Living Room", "9ACF4BB8AE0A@MacBook Pro"])

		#expect(type.matches("AirPlay Audio"))
		#expect(type.instances(matching: "airplay").count == 2)
		#expect(type.instances(matching: "_raop").count == 2)
	}

	@Test func instanceMatchFiltersRows() {
		let type = type(with: ["7AD359201C0B@Living Room", "9ACF4BB8AE0A@MacBook Pro"])

		#expect(type.instances(matching: "living").map(\.name) == ["7AD359201C0B@Living Room"])
		#expect(type.matches("macbook"))
		#expect(!type.matches("printer"))
	}

	@Test func decodedNameFieldsAreSearchable() {
		let type = type(with: ["7AD359201C0B@Living Room"])

		// The formatted MAC only exists in the decoded fields, not in the raw name.
		#expect(type.instances(matching: "7a:d3:59").count == 1)
		#expect(type.instances(matching: "MAC Address").count == 1)
	}

	@Test func emptyQueryReturnsEverything() {
		let type = type(with: ["A", "B"])

		#expect(type.instances(matching: "").count == 2)
	}
}
