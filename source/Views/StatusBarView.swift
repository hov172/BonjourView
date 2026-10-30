import SwiftUI

struct StatusBarView: View {
	@Environment(BonjourBrowser.self) private var browser

	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(browser.isBrowsing ? Color.green : Color.secondary)
				.frame(width: 7, height: 7)
				.accessibilityHidden(true)
			Text(browser.isBrowsing ? "Browsing" : "Stopped")
			Text("·").foregroundStyle(.tertiary)
			Text("^[\(browser.typeCount) type](inflect: true) · ^[\(browser.instanceCount) service](inflect: true)")
				.monospacedDigit()
			Spacer()
			if let error = browser.lastError {
				ErrorLabel(message: error)
					.lineLimit(1)
			}
		}
		.font(.callout)
		.foregroundStyle(.secondary)
		.padding(.horizontal, 12)
		.padding(.vertical, 6)
		.background(.bar)
		.overlay(alignment: .top) { Divider() }
	}
}
