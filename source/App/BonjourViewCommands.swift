import SwiftUI

struct BonjourViewCommands: Commands {
	let browser: BonjourBrowser
	@Environment(\.openWindow) private var openWindow
	@Environment(\.openURL) private var openURL
	@FocusedValue(\.serviceActions) private var actions
	@FocusedValue(\.inspectorPresented) private var inspectorPresented

	private static let websiteURL = URL(string: "https://github.com/hov172/BonjourView")!

	private var selection: [ServiceInstance] { actions?.selection ?? [] }

	var body: some Commands {
		CommandGroup(replacing: .undoRedo) {}

		CommandGroup(after: .importExport) {
			ForEach(ExportFormat.allCases) { format in
				Button("Export as \(format.title)…") { actions?.export(format) }
					.keyboardShortcut("e", modifiers: format == .json ? [.command] : [.command, .shift])
					.disabled(actions?.canExport != true)
			}
		}

		CommandGroup(after: .toolbar) {
			Button("Refresh") { browser.restart() }
				.keyboardShortcut("r")
			Button(inspectorPresented?.wrappedValue == true ? "Hide Inspector" : "Show Inspector") {
				inspectorPresented?.wrappedValue.toggle()
			}
			.keyboardShortcut("i", modifiers: [.command, .option])
			.disabled(inspectorPresented == nil)
			Divider()
		}

		CommandMenu("Service") {
			Button("Open") { selection.single?.url.map { openURL($0) } }
				.keyboardShortcut(.return)
				.disabled(actions?.canOpen != true)
			Button("Resolve Again") { selection.resolveAgain() }
				.keyboardShortcut("r", modifiers: [.command, .shift])
				.disabled(selection.isEmpty)
			Divider()
			Button("Copy Host") { selection.copyHosts() }
				.keyboardShortcut("c", modifiers: [.command, .option])
				.disabled(selection.isEmpty)
			Button("Copy Address") { selection.copyAddresses() }
				.disabled(selection.isEmpty)
			Button("Copy as JSON") { selection.copyJSON() }
				.keyboardShortcut("c", modifiers: [.command, .shift])
				.disabled(selection.isEmpty)
		}

		CommandGroup(replacing: .help) {
			Link("BonjourView Website", destination: Self.websiteURL)
			Button("License") { openWindow(id: WindowID.license) }
		}
	}
}
