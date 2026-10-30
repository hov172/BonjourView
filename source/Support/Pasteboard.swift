import AppKit

enum Pasteboard {
	static func copy(_ string: String) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(string, forType: .string)
	}

	/// Copies non-empty values, one per line. Does nothing when there is nothing to copy.
	static func copyLines(_ values: [String]) {
		let lines = values.filter { !$0.isEmpty }
		guard !lines.isEmpty else { return }
		copy(lines.joined(separator: "\n"))
	}
}
