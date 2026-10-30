import SwiftUI

struct InstanceTableView: View {
	let type: ServiceType
	@Binding var selection: Set<String>
	let searchText: String
	@State private var sortOrder = [KeyPathComparator(\ServiceInstance.name)]
	@SceneStorage("instanceTableColumns") private var columnCustomization: TableColumnCustomization<ServiceInstance>
	@Environment(\.openURL) private var openURL

	var body: some View {
		// Filter and sort once per render; the table, menus and copy all share `rows`.
		let rows = type.instances(matching: searchText).sorted(using: sortOrder)

		if type.instances.isEmpty {
			ContentUnavailableView {
				Label("No Services", systemImage: type.kind.symbol)
			} description: {
				Text("Nothing is advertising \(type.kind.name) in \(type.domain) right now.")
			}
		} else if rows.isEmpty {
			ContentUnavailableView.search(text: searchText)
		} else {
			table(rows)
		}
	}

	private func table(_ rows: [ServiceInstance]) -> some View {
		let selectedRows = rows.filter { selection.contains($0.id) }
		return Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
			TableColumn("Name", value: \.name) { instance in
				HStack(spacing: 6) {
					VStack(alignment: .leading, spacing: 1) {
						Text(instance.name)
						// Generated names say nothing; show the host so the row is identifiable.
						if instance.hasOpaqueName, !instance.displayHost.isEmpty {
							Text(instance.displayHost)
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
					ResolveStateIndicator(state: instance.state)
				}
			}
			.width(min: 160, ideal: 220)
			.customizationID("name")
			.disabledCustomizationBehavior(.visibility)

			TableColumn("Host", value: \.displayHost) { instance in
				Text(instance.displayHost)
					.foregroundStyle(.secondary)
			}
			.width(min: 110, ideal: 150)
			.customizationID("host")
			.defaultVisibility(.hidden)

			TableColumn("Port", value: \.portSortKey) { instance in
				Text(instance.portText)
					.monospacedDigit()
			}
			.width(min: 48, ideal: 56, max: 80)
			.customizationID("port")

			TableColumn("IPv4", value: \.ipv4Text) { instance in
				Text(instance.ipv4Text)
					.monospacedDigit()
			}
			.width(min: 105, ideal: 120)
			.customizationID("ipv4")

			TableColumn("IPv6", value: \.ipv6Text) { instance in
				Text(instance.ipv6Text)
					.monospacedDigit()
					.foregroundStyle(.secondary)
			}
			.width(min: 120, ideal: 240)
			.customizationID("ipv6")
			.defaultVisibility(.hidden)
		}
		.contextMenu(forSelectionType: String.self) { ids in
			InstanceContextMenu(instances: rows.filter { ids.contains($0.id) })
		} primaryAction: { ids in
			rows.first { ids.contains($0.id) }?.url.map { openURL($0) }
		}
		.copyable(selectedRows.isEmpty ? [] : [selectedRows.map(ServiceExport.tsvLine).joined(separator: "\n")])
	}
}

struct ResolveStateIndicator: View {
	let state: ServiceInstance.ResolveState

	var body: some View {
		switch state {
		case .resolving:
			ProgressView()
				.controlSize(.mini)
				.frame(width: 14)
		case .failed(let message):
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.orange)
				.help(message)
				.frame(width: 14)
		case .idle, .resolved:
			EmptyView()
		}
	}
}

struct InstanceContextMenu: View {
	let instances: [ServiceInstance]

	var body: some View {
		if let url = instances.single?.url {
			Link("Open \(url.absoluteString)", destination: url)
			Divider()
		}
		Button("Copy Name") { Pasteboard.copyLines(instances.map(\.name)) }
		Button("Copy Host") { instances.copyHosts() }
		Button("Copy Address") { instances.copyAddresses() }
		Button("Copy as JSON") { instances.copyJSON() }
		Divider()
		Button("Resolve Again") { instances.resolveAgain() }
	}
}

