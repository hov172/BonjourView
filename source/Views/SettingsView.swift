import SwiftUI

struct SettingsView: View {
	@Bindable private var settings = AppSettings.shared
	private let registry = IANARegistry.shared

	var body: some View {
		Form {
			Section {
				Toggle("Resolve services automatically", isOn: $settings.resolveAutomatically)
				Text("Look up host, port and addresses for every service as soon as it appears. Off resolves only the selected type and uses less network traffic.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
			Section {
				Toggle("Show protocol names in the sidebar", isOn: $settings.showRawTypeNames)
				Toggle("Include peer-to-peer (AWDL) services", isOn: $settings.includePeerToPeer)
			}
			Section {
				Toggle("Update service names from IANA weekly", isOn: $settings.updateServiceNamesAutomatically)
				Text("Downloads the public IANA service-name registry so unfamiliar protocols get a description. Nothing about your network is sent.")
					.font(.callout)
					.foregroundStyle(.secondary)
				LabeledContent("Last updated") {
					Text(registry.lastUpdated.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never (using built-in copy)")
						.foregroundStyle(.secondary)
				}
				LabeledContent("Known service names") {
					Text(registry.entryCount, format: .number)
						.foregroundStyle(.secondary)
						.monospacedDigit()
				}
				HStack {
					Button("Update Now") {
						Task { await registry.update() }
					}
					.disabled(registry.isUpdating)
					if registry.isUpdating {
						ProgressView().controlSize(.small)
					}
					if let error = registry.lastError {
						ErrorLabel(message: error)
							.font(.callout)
					}
				}
			}
		}
		.formStyle(.grouped)
		.frame(width: 440)
		.fixedSize()
		.onAppear { registry.loadIfNeeded() }
	}
}
