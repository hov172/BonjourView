import SwiftUI

@main
struct BonjourViewApp: App {
	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
	@State private var browser = BonjourBrowser()

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environment(browser)
		}
		.defaultSize(width: 1120, height: 680)
		.commands {
			BonjourViewCommands(browser: browser)
		}

		Settings {
			SettingsView()
		}

		Window("License", id: WindowID.license) {
			LicenseView()
		}
		.defaultSize(width: 480, height: 520)
	}
}

enum WindowID {
	static let license = "license"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		true
	}
}
