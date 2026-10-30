import SwiftUI

extension Binding where Value == Bool {
	/// True while the optional has a value; setting false clears it. For `isPresented:` driven by optional state.
	init<T>(isPresent source: Binding<T?>) {
		self.init(get: { source.wrappedValue != nil }, set: { if !$0 { source.wrappedValue = nil } })
	}
}
