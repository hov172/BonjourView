import Foundation
import Testing
@testable import BonjourView

struct ServiceCatalogTests {
	@Test func normalizesCaseAndTrailingDots() {
		#expect(ServiceCatalog.normalize("_HTTP._tcp.") == "_http._tcp")
		#expect(ServiceCatalog.normalize("_http._tcp") == "_http._tcp")
	}

	@Test func knownTypeHasNameSymbolAndScheme() {
		let kind = ServiceCatalog.kind(forType: "_http._tcp.")

		#expect(kind.isKnown)
		#expect(kind.name == "Web Server (HTTP)")
		#expect(kind.symbol == "globe")
		#expect(kind.scheme == "http")
	}

	@Test func unknownTypeFallsBackToStrippedName() {
		let kind = ServiceCatalog.kind(forType: "_someVendorThing._tcp.")

		#expect(!kind.isKnown)
		#expect(kind.name == "someVendorThing")
		#expect(kind.symbol == "network")
		#expect(kind.scheme == nil)
	}

	@Test func lookupIsCaseInsensitiveForMixedCaseAppleTypes() {
		#expect(ServiceCatalog.kind(forType: "_appSvcPrePair._tcp.").isKnown)
		#expect(ServiceCatalog.kind(forType: "_applicationServicePairing._tcp.").name == "Companion App Pairing")
	}

	@Test func macAddressTypeIsLabelledDeviceSpecific() {
		let kind = ServiceCatalog.kind(forType: "_FC9F5ED42C8A._tcp.")

		#expect(!kind.isKnown)
		#expect(kind.name == "Device-Specific")
		#expect(ServiceCatalog.isDeviceIdentifierType("_fc9f5ed42c8a._tcp"))
		#expect(!ServiceCatalog.isDeviceIdentifierType("_http._tcp"))
		#expect(!ServiceCatalog.isDeviceIdentifierType("_22022._tcp"))
	}

	@Test func txtKeyPrefixIdentifiesQuickDropOnlyForUnknownTypes() {
		let registry = IANARegistry(descriptions: [:])

		#expect(ServiceCatalog.kind(forType: "_FC9F5ED42C8A._tcp.", txtKeys: ["n", "qd_caps", "qd_kid"], registry: registry).name == "QuickDrop")
		#expect(ServiceCatalog.kind(forType: "_FC9F5ED42C8A._tcp.", txtKeys: ["path", "version"], registry: registry).name == "Device-Specific")
		#expect(ServiceCatalog.kind(forType: "_http._tcp.", txtKeys: ["qd_caps"], registry: registry).name == "Web Server (HTTP)")
	}

	@Test func customNameOverridesEverythingAndEmptyRestores() throws {
		let suite = try #require(UserDefaults(suiteName: "BonjourViewTests.CustomTypeNames"))
		suite.removePersistentDomain(forName: "BonjourViewTests.CustomTypeNames")
		let names = CustomTypeNames(defaults: suite)
		let registry = IANARegistry(descriptions: [:])

		names.setName("  Apple TV Pairing ", forType: "_nrd._tcp.")
		names.setName("My Web", forType: "_HTTP._tcp")

		#expect(ServiceCatalog.kind(forType: "_nrd._tcp.", customNames: names, registry: registry).name == "Apple TV Pairing")
		#expect(ServiceCatalog.kind(forType: "_nrd._tcp.", customNames: names, registry: registry).isKnown)
		#expect(ServiceCatalog.kind(forType: "_http._tcp.", customNames: names, registry: registry).name == "My Web")
		#expect(ServiceCatalog.kind(forType: "_http._tcp.", customNames: names, registry: registry).scheme == "http")

		names.setName("   ", forType: "_nrd._tcp.")
		#expect(ServiceCatalog.kind(forType: "_nrd._tcp.", customNames: names, registry: registry).name == "nrd")
		#expect(CustomTypeNames(defaults: suite).name(forType: "_http._tcp.") == "My Web")
	}

	@Test func buildsTypeFromMetaQueryResult() {
		#expect(ServiceCatalog.serviceType(fromMetaQueryName: "_http", type: "_tcp.local.") == "_http._tcp.")
		#expect(ServiceCatalog.serviceType(fromMetaQueryName: "_airplay", type: "_tcp.members.btmm.icloud.com.") == "_airplay._tcp.")
	}

	@Test func rejectsMalformedMetaQueryResult() {
		#expect(ServiceCatalog.serviceType(fromMetaQueryName: "_http", type: ".local.") == nil)
		#expect(ServiceCatalog.serviceType(fromMetaQueryName: "_http", type: "nodots") == nil)
		#expect(ServiceCatalog.serviceType(fromMetaQueryName: "http", type: "_tcp.local.") == nil)
	}
}
