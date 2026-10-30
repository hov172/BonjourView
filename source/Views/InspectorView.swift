import SwiftUI

struct InspectorView: View {
	let instance: ServiceInstance?
	let selectionCount: Int

	var body: some View {
		if let instance {
			InstanceDetailView(instance: instance)
		} else {
			ContentUnavailableView {
				Label(selectionCount > 1 ? "\(selectionCount) Services Selected" : "No Selection", systemImage: "info.circle")
			} description: {
				Text("Select a single service to see its details.")
			}
		}
	}
}

struct InstanceDetailView: View {
	let instance: ServiceInstance

	var body: some View {
		Form {
			Section("Service") {
				LabeledContent("Name", value: instance.name)
				ForEach(InstanceNameDecoder.decode(instance.name)) { field in
					LabeledContent(field.label) {
						Text(field.value)
							.font(.callout.monospaced())
							.foregroundStyle(.secondary)
							.textSelection(.enabled)
					}
				}
				LabeledContent("Type", value: instance.kind.name)
				CopyableRow(label: "Protocol", value: instance.type, isMonospaced: true)
				LabeledContent("Domain", value: instance.domain)
			}

			Section("Network") {
				networkContent
			}

			Section("TXT Record") {
				if instance.txtRecords.isEmpty {
					Text(instance.state == .resolved ? "No TXT record" : "Not resolved yet")
						.foregroundStyle(.secondary)
				} else {
					ForEach(instance.txtRecords) { entry in
						CopyableRow(label: entry.key.isEmpty ? "(binary)" : entry.key, value: entry.value, displayValue: entry.displayValue, isMonospaced: entry.isBinary)
					}
				}
			}
		}
		.formStyle(.grouped)
		.hardTopScrollEdge()
	}

	@ViewBuilder
	private var networkContent: some View {
		switch instance.state {
		case .idle:
			Button("Resolve") { instance.resolve() }
		case .resolving:
			HStack {
				ProgressView().controlSize(.small)
				Text("Resolving…").foregroundStyle(.secondary)
			}
		case .failed(let message):
			ErrorLabel(message: message)
			Button("Try Again") { instance.resolveAgain() }
		case .resolved:
			CopyableRow(label: "Host", value: instance.displayHost)
			CopyableRow(label: "Port", value: instance.portText, isMonospaced: true)
			ForEach(instance.addresses, id: \.self) { address in
				CopyableRow(label: address.family.label, value: address.value, isMonospaced: true)
			}
			if let url = instance.url {
				Link(destination: url) {
					Label("Open \(url.absoluteString)", systemImage: "arrow.up.forward.app")
				}
			}
		}
	}
}

struct CopyableRow: View {
	let label: String
	/// What the copy button copies.
	let value: String
	/// What is shown; defaults to `value`.
	var displayValue: String?
	var isMonospaced = false
	@State private var didCopy = false

	var body: some View {
		LabeledContent(label) {
			HStack(spacing: 6) {
				Text(displayValue ?? value)
					.font(isMonospaced ? .body.monospaced() : .body)
					.textSelection(.enabled)
					.multilineTextAlignment(.trailing)
					.lineLimit(3)
					.truncationMode(.middle)
					.help(value)
				Button {
					Pasteboard.copy(value)
					didCopy = true
					Task {
						try? await Task.sleep(for: .seconds(1.2))
						didCopy = false
					}
				} label: {
					Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
						.contentTransition(.symbolEffect(.replace))
				}
				.buttonStyle(.borderless)
				.disabled(value.isEmpty)
				.help("Copy \(label)")
				.accessibilityLabel("Copy \(label)")
			}
		}
	}
}

private extension View {
	/// Keeps the inspector content crisp under the toolbar instead of blurring it (macOS 26+).
	@ViewBuilder
	func hardTopScrollEdge() -> some View {
		if #available(macOS 26.0, *) {
			scrollEdgeEffectStyle(.hard, for: .top)
		} else {
			self
		}
	}
}
