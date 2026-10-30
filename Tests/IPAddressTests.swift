import Foundation
import Testing
@testable import Bonjeff

struct IPAddressTests {
	@Test func formatsIPv4() {
		var address = sockaddr_in()
		address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
		address.sin_family = sa_family_t(AF_INET)
		address.sin_port = UInt16(631).bigEndian
		address.sin_addr.s_addr = inet_addr("192.168.1.10")
		let data = withUnsafeBytes(of: &address) { Data($0) }

		let result = IPAddress(socketAddress: data)

		#expect(result == IPAddress(value: "192.168.1.10", family: .v4))
	}

	@Test func formatsIPv6Loopback() {
		var address = sockaddr_in6()
		address.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
		address.sin6_family = sa_family_t(AF_INET6)
		address.sin6_addr = in6addr_loopback
		let data = withUnsafeBytes(of: &address) { Data($0) }

		let result = IPAddress(socketAddress: data)

		#expect(result == IPAddress(value: "::1", family: .v6))
	}

	@Test func rejectsUnknownFamilyAndShortData() {
		var address = sockaddr_in()
		address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
		address.sin_family = sa_family_t(AF_UNIX)
		let unixData = withUnsafeBytes(of: &address) { Data($0) }

		#expect(IPAddress(socketAddress: unixData) == nil)
		#expect(IPAddress(socketAddress: Data([0x01, 0x02])) == nil)
	}
}
