import Foundation
import Testing
@testable import BonjourView

struct TXTRecordTests {
	/// Encodes strings in the DNS-SD wire format: one length byte followed by the bytes.
	private func record(_ items: [[UInt8]]) -> Data {
		items.reduce(into: Data()) { data, item in
			data.append(UInt8(item.count))
			data.append(contentsOf: item)
		}
	}

	private func record(_ strings: [String]) -> Data {
		record(strings.map { Array($0.utf8) })
	}

	@Test func parsesKeyValuePairsSortedByKey() {
		let entries = TXTRecord.parse(record(["version=2", "path=/admin"]))

		#expect(entries.map(\.key) == ["path", "version"])
		#expect(entries.map(\.value) == ["/admin", "2"])
		#expect(entries.allSatisfy { !$0.isBinary })
	}

	@Test func keyWithoutValueIsPresentWithEmptyValue() {
		let entries = TXTRecord.parse(record(["enabled", "name="]))

		#expect(entries == [TXTEntry(key: "enabled", value: "", isBinary: false),
		                    TXTEntry(key: "name", value: "", isBinary: false)])
	}

	@Test func firstOccurrenceWinsCaseInsensitively() {
		let entries = TXTRecord.parse(record(["Key=first", "key=second", "KEY=third"]))

		#expect(entries == [TXTEntry(key: "Key", value: "first", isBinary: false)])
	}

	@Test func nonUTF8ValueIsHex() {
		let entries = TXTRecord.parse(record([Array("blob=".utf8) + [0xFF, 0x00, 0xAB]]))

		#expect(entries == [TXTEntry(key: "blob", value: "ff 00 ab", isBinary: true)])
	}

	@Test func controlCharactersAreTreatedAsBinaryEvenWhenValidUTF8() {
		let entries = TXTRecord.parse(record([Array("nrAD=".utf8) + [0x01, 0x00, 0x01, 0x01]]))

		#expect(entries == [TXTEntry(key: "nrAD", value: "01 00 01 01", isBinary: true)])
		#expect(entries[0].displayValue == "01 00 01 01")
	}

	@Test func longBinaryValueIsSummarizedForDisplay() {
		let bytes = [UInt8](repeating: 0xAB, count: 40)
		let entry = TXTRecord.parse(record([Array("blob=".utf8) + bytes]))[0]

		#expect(entry.displayValue.hasPrefix("40 bytes · ab ab ab ab ab ab ab ab …"))
		#expect(entry.value.split(separator: " ").count == 40)
	}

	@Test func rawBinaryItemWithoutKeyIsKeptAsHex() {
		let entries = TXTRecord.parse(record([[0x01, 0x02, 0xFE]]))

		#expect(entries == [TXTEntry(key: "", value: "01 02 fe", isBinary: true)])
	}

	@Test func emptyAndZeroLengthItemsProduceNothing() {
		#expect(TXTRecord.parse(Data()).isEmpty)
		#expect(TXTRecord.parse(Data([0x00, 0x00])).isEmpty)
	}

	@Test func truncatedLengthPrefixDoesNotCrash() {
		// Claims 20 bytes but only 3 follow.
		let data = Data([20] + Array("a=b".utf8))

		#expect(TXTRecord.parse(data) == [TXTEntry(key: "a", value: "b", isBinary: false)])
	}

	@Test func zeroLengthKeyIsIgnored() {
		let entries = TXTRecord.parse(record(["=value", "ok=1"]))

		#expect(entries == [TXTEntry(key: "ok", value: "1", isBinary: false)])
	}
}
