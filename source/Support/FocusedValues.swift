import SwiftUI

/// What the main window exposes to the menu bar via the focus system.
struct ServiceActions {
	let selection: [ServiceInstance]
	let canExport: Bool
	let export: (ExportFormat) -> Void

	var hasSelection: Bool { !selection.isEmpty }
	var canOpen: Bool { selection.single?.url != nil }
}

private struct ServiceActionsKey: FocusedValueKey {
	typealias Value = ServiceActions
}

private struct InspectorPresentedKey: FocusedValueKey {
	typealias Value = Binding<Bool>
}

extension FocusedValues {
	var serviceActions: ServiceActions? {
		get { self[ServiceActionsKey.self] }
		set { self[ServiceActionsKey.self] = newValue }
	}

	var inspectorPresented: Binding<Bool>? {
		get { self[InspectorPresentedKey.self] }
		set { self[InspectorPresentedKey.self] = newValue }
	}
}
