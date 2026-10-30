import SwiftUI

/// The one way errors are shown inline: orange warning triangle plus message.
struct ErrorLabel: View {
	let message: String

	var body: some View {
		Label(message, systemImage: "exclamationmark.triangle.fill")
			.foregroundStyle(.orange)
			.lineLimit(2)
	}
}
