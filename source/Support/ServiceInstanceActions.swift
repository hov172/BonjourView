import AppKit

/// The per-selection commands shared by the menu bar, the toolbar and the context menu.
extension Array where Element == ServiceInstance {
	/// The one selected instance, or nil when zero or several are selected.
	var single: ServiceInstance? { count == 1 ? first : nil }

	func copyHosts() { Pasteboard.copyLines(map(\.displayHost)) }
	func copyAddresses() { Pasteboard.copyLines(compactMap { $0.addresses.first?.value }) }
	func copyJSON() { ServiceExport.jsonText(self).map(Pasteboard.copy) }
	func resolveAgain() { forEach { $0.resolveAgain() } }
}
