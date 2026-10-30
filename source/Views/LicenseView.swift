import SwiftUI

struct LicenseView: View {
	@State private var licenseText = ""

	var body: some View {
		ScrollView {
			Text(licenseText)
				.textSelection(.enabled)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(20)
		}
		.frame(minWidth: 400, minHeight: 300)
		.task {
			licenseText = Bundle.main.url(forResource: "LICENSE", withExtension: "txt")
				.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
				?? String(localized: "LICENSE.txt is missing from the application bundle.")
		}
	}
}
