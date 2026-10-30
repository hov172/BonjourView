import SwiftUI

struct ContentView: View {
	@Environment(BonjourBrowser.self) private var browser
	@Environment(\.openURL) private var openURL
	@SceneStorage("selectedTypeID") private var selectedTypeID: String?
	@SceneStorage("inspectorPresented") private var inspectorPresented = true
	@State private var selectedInstanceIDs = Set<String>()
	@State private var searchText = ""
	@State private var pendingExport: ExportDocument?
	@State private var exportError: String?
	private let settings = AppSettings.shared
	private let registry = IANARegistry.shared

	var body: some View {
		// Derive selection once per render; every child reads from this.
		let selectedType = browser.type(withID: selectedTypeID)
		let selection = selectedType?.instances(withIDs: selectedInstanceIDs) ?? []
		let actions = ServiceActions(selection: selection, canExport: browser.hasInstances, export: export)

		NavigationSplitView {
			SidebarView(selection: $selectedTypeID, searchText: searchText)
		} detail: {
			detail(for: selectedType)
				.toolbar { toolbar(actions) }
		}
		.inspector(isPresented: $inspectorPresented) {
			InspectorView(instance: selection.single, selectionCount: selection.count)
				.inspectorColumnWidth(min: 250, ideal: 280, max: 480)
		}
		.searchable(text: $searchText, placement: .toolbar, prompt: "Filter services")
		.navigationTitle("BonjourView")
		.navigationSubtitle(selectedType?.kind.name ?? "")
		.frame(minWidth: 720, minHeight: 420)
		.focusedSceneValue(\.serviceActions, actions)
		.focusedSceneValue(\.inspectorPresented, $inspectorPresented)
		.fileExporter(
			isPresented: Binding(isPresent: $pendingExport),
			document: pendingExport,
			contentType: pendingExport?.format.contentType ?? .json,
			defaultFilename: "Bonjour Services"
		) { result in
			if case .failure(let error) = result {
				exportError = error.localizedDescription
			}
		}
		.alert("Export Failed", isPresented: Binding(isPresent: $exportError)) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(exportError ?? "")
		}
		.task {
			registry.loadIfNeeded()
			browser.start()
			browser.focus(on: selectedTypeID)
			if settings.updateServiceNamesAutomatically {
				await registry.updateIfStale()
			}
		}
		.onChange(of: settings.includePeerToPeer) { browser.restart() }
		.onChange(of: settings.resolveAutomatically) { _, isOn in if isOn { browser.resolveAll() } }
		.onChange(of: selectedTypeID) {
			selectedInstanceIDs = []
			browser.focus(on: selectedTypeID)
		}
		.onChange(of: selectedType?.instances.count) { browser.focus(on: selectedTypeID) }
		.onChange(of: browser.typeCount) {
			if selectedTypeID == nil, let id = browser.takeReselectID() {
				selectedTypeID = id
			}
		}
	}

	@ViewBuilder
	private func detail(for selectedType: ServiceType?) -> some View {
		Group {
			if let selectedType {
				InstanceTableView(type: selectedType, selection: $selectedInstanceIDs, searchText: searchText)
			} else {
				ContentUnavailableView {
					Label("No Service Type Selected", systemImage: "sidebar.left")
				} description: {
					Text("Choose a service type in the sidebar to see the devices advertising it.")
				}
			}
		}
		.safeAreaInset(edge: .bottom, spacing: 0) {
			StatusBarView()
		}
	}

	@ToolbarContentBuilder
	private func toolbar(_ actions: ServiceActions) -> some ToolbarContent {
		ToolbarItemGroup(placement: .primaryAction) {
			Button { actions.selection.single?.url.map { openURL($0) } } label: {
				Label("Open", systemImage: "arrow.up.forward.app")
			}
			.disabled(!actions.canOpen)
			.help("Open the selected service in its default app")

			Menu {
				ForEach(ExportFormat.allCases) { format in
					Button("Export as \(format.title)…") { export(format) }
				}
			} label: {
				Label("Export", systemImage: "square.and.arrow.up")
			}
			.disabled(!actions.canExport)
			.help("Export all discovered services")

			Button { browser.restart() } label: {
				Label("Refresh", systemImage: "arrow.clockwise")
			}
			.help("Start browsing again from scratch")

			Button { inspectorPresented.toggle() } label: {
				Label("Inspector", systemImage: "sidebar.trailing")
			}
			.help("Show or hide the inspector")
		}
	}

	private func export(_ format: ExportFormat) {
		do {
			pendingExport = ExportDocument(data: try ServiceExport.data(for: browser.allInstances, format: format), format: format)
		} catch {
			exportError = error.localizedDescription
		}
	}
}
