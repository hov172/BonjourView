import SwiftUI

struct SidebarView: View {
	@Environment(BonjourBrowser.self) private var browser
	@Binding var selection: String?
	let searchText: String
	@State private var renamingType: ServiceType?
	@State private var renameText = ""
	private let settings = AppSettings.shared
	private let customNames = CustomTypeNames.shared

	var body: some View {
		List(selection: $selection) {
			ForEach(browser.domains) { domain in
				Section(domain.displayName) {
					ForEach(filteredTypes(in: domain)) { type in
						ServiceTypeRow(type: type, showsRawName: settings.showRawTypeNames)
							.tag(type.id)
							.contextMenu {
								Button("Rename…") { beginRenaming(type) }
								if customNames.name(forType: type.type) != nil {
									Button("Use Default Name") { customNames.removeName(forType: type.type) }
								}
								Divider()
								Button("Copy Protocol Name") { Pasteboard.copy(type.type) }
								Link("Search the Web for “\(type.type)”", destination: Self.webSearchURL(for: type.type))
							}
					}
				}
			}
		}
		.listStyle(.sidebar)
		.navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 400)
		.overlay {
			if browser.domains.isEmpty {
				emptyState
			}
		}
		.alert("Rename Service Type", isPresented: Binding(isPresent: $renamingType), presenting: renamingType) { type in
			TextField("Name", text: $renameText)
			Button("Save") { customNames.setName(renameText, forType: type.type) }
			Button("Cancel", role: .cancel) {}
		} message: { type in
			Text("Shown instead of the default name for \(type.type). Leave empty to restore the default.")
		}
	}

	private func beginRenaming(_ type: ServiceType) {
		renameText = customNames.name(forType: type.type) ?? type.kind.name
		renamingType = type
	}

	private static func webSearchURL(for type: String) -> URL {
		var components = URLComponents(string: "https://duckduckgo.com/")!
		components.queryItems = [URLQueryItem(name: "q", value: "\"\(type)\" bonjour service")]
		return components.url!
	}

	private func filteredTypes(in domain: ServiceDomain) -> [ServiceType] {
		guard !searchText.isEmpty else { return domain.types }
		return domain.types.filter { $0.matches(searchText) }
	}

	@ViewBuilder
	private var emptyState: some View {
		if let error = browser.lastError {
			ContentUnavailableView {
				Label("Browsing Failed", systemImage: "exclamationmark.triangle")
			} description: {
				Text(error)
				Text("Check that BonjourView is allowed to find devices on the local network in System Settings › Privacy & Security › Local Network.")
			} actions: {
				Button("Try Again") { browser.restart() }
			}
		} else {
			ContentUnavailableView {
				Label("Searching for Services", systemImage: "antenna.radiowaves.left.and.right")
			} description: {
				ProgressView()
					.controlSize(.small)
					.padding(.top, 4)
			}
		}
	}
}

struct ServiceTypeRow: View {
	let type: ServiceType
	let showsRawName: Bool

	var body: some View {
		let kind = type.kind
		Label {
			VStack(alignment: .leading, spacing: 1) {
				Text(kind.name)
					.lineLimit(2)
				if showsRawName || !kind.isKnown {
					Text(type.type)
						.font(.caption)
						.foregroundStyle(.secondary)
						.monospaced()
						.lineLimit(1)
						.truncationMode(.middle)
				}
			}
		} icon: {
			Image(systemName: kind.symbol)
		}
		.badge(type.instances.count)
		.accessibilityLabel("\(kind.name), \(type.instances.count) services")
	}
}
