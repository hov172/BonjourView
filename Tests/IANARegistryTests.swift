import Foundation
import Testing
@testable import BonjourView

struct IANARegistryTests {
	private let sample = """
	Service Name,Port Number,Transport Protocol,Description,Assignee
	http,80,tcp,World Wide Web HTTP,[IESG]
	http,80,udp,World Wide Web HTTP,[IESG]
	airplay,,tcp,"Protocol for streaming of audio/video content.",[Apple_Inc_2]
	meshcop,,udp,Thread Mesh Commissioning,[Thread_Group_Inc]
	,1234,tcp,No name,[x]
	unused,4,tcp,Unassigned,
	gone,5,tcp,De-registered 2010,
	"""

	@Test func parsesQuotedMultilineFields() {
		let csv = "Service Name,Port Number,Transport Protocol,Description\nfoo,1,tcp,\"Line one\nline two, with comma\"\n"

		#expect(IANARegistry.parse(csv: csv)["foo"] == "Line one line two, with comma")
	}

	@Test func parsesFirstOccurrenceAndSkipsPlaceholders() {
		let table = IANARegistry.parse(csv: sample)

		#expect(table["http"] == "World Wide Web HTTP")
		#expect(table["airplay"] == "Protocol for streaming of audio/video content")
		#expect(table["meshcop"] == "Thread Mesh Commissioning")
		#expect(table["unused"] == nil)
		#expect(table["gone"] == nil)
		#expect(table.count == 3)
	}

	@Test func catalogFallsBackToRegistryForUnknownTypes() {
		let registry = IANARegistry(descriptions: ["xyzzy-test": "Example Service From IANA"])

		let kind = ServiceCatalog.kind(forType: "_XYZZY-test._tcp.", registry: registry)

		#expect(kind.isKnown)
		#expect(kind.name == "Example Service From IANA")
		#expect(ServiceCatalog.kind(forType: "_http._tcp.", registry: registry).name == "Web Server (HTTP)")
	}

	@Test func validParseRejectsSmallTables() {
		#expect(IANARegistry.validParse(csv: sample) == nil)
		#expect(IANARegistry.parse(csv: sample).count == 3)
	}

	@Test func bundledSnapshotParsesToThousandsOfEntries() throws {
		let url = try #require(Bundle(for: BundleToken.self).url(forResource: IANARegistry.resourceName, withExtension: "csv")
			?? Bundle.main.url(forResource: IANARegistry.resourceName, withExtension: "csv"))
		let csv = try String(contentsOf: url, encoding: .utf8)

		let table = IANARegistry.parse(csv: csv)

		#expect(table.count >= IANARegistry.minimumEntryCount)
		#expect(table["airplay"]?.isEmpty == false)
	}

}

private final class BundleToken {}
