import Foundation

extension String {
	/// `"printer.local."` → `"printer.local"`. DNS names and IANA descriptions both end with stray dots.
	func removingTrailingDots() -> String {
		var text = self
		while text.hasSuffix(".") { text.removeLast() }
		return text
	}
}
