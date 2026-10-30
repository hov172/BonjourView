import Foundation
import Testing
@testable import BonjourView

struct InstanceNameDecoderTests {
	@Test func opaqueNamesAreDetected() {
		for name in ["98e1deb1-b763-45c1-a867-8f16a0dbc0c6", "FC9F5ED42C8A", "70:45:5A:8F:D2:4B",
		             "ec:81:50:b7:8b:e6@fe80::ee81:50ff:feb7:8be6-supportsRP-26", "7AD359201C0B@Living Room",
		             "ce4d5d96248bfd21", "NEO2KVC6FGZIFXPLSBAVTAQT"] {
			#expect(InstanceNameDecoder.isOpaque(name), "\(name)")
		}
		for name in ["Living Room", "Office Printer", "deadbeefcafe", "jay@home", "HovNas", "70-35-60-63.1 Living Room", "MYSERVER"] {
			#expect(!InstanceNameDecoder.isOpaque(name), "\(name)")
		}
	}

	@Test func decodesAppleMobileDeviceName() {
		let fields = InstanceNameDecoder.decode("ec:81:50:b7:8b:e6@fe80::ee81:50ff:feb7:8be6-supportsRP-26")

		#expect(fields.map(\.label) == ["MAC Address", "Link-Local IPv6", "Capability", "OS Version"])
		#expect(fields[0].value == "ec:81:50:b7:8b:e6")
		#expect(fields[1].value == "fe80::ee81:50ff:feb7:8be6")
		#expect(fields[3].value == "iOS 26")
	}

	@Test func decodesAirPlayAudioName() {
		let fields = InstanceNameDecoder.decode("7AD359201C0B@Living Room")

		#expect(fields == [.init(label: "MAC Address", value: "7a:d3:59:20:1c:0b"), .init(label: "Device Name", value: "Living Room")])
	}

	@Test func decodesSleepProxyName() {
		let fields = InstanceNameDecoder.decode("70-35-60-63.1 Living Room")

		#expect(fields.map(\.label) == ["Proxy Score", "Metric", "Device Name"])
		#expect(fields[0].value.hasPrefix("type 70 · portability 35 · marginal power 60 · total power 63"))
		#expect(fields[1].value == "1")
		#expect(fields[2].value == "Living Room")
	}

	@Test func decodesThreadAndGeneratedIdentifiers() {
		#expect(InstanceNameDecoder.decode("ce4d5d96248bfd21").first?.label == "Thread Extended Address")
		#expect(InstanceNameDecoder.decode("NEO2KVC6FGZIFXPLSBAVTAQT").first?.label == "Identifier")
		#expect(InstanceNameDecoder.decode("98e1deb1-b763-45c1-a867-8f16a0dbc0c6").count == 1)
		#expect(InstanceNameDecoder.decode("Living Room").isEmpty)
	}
}
