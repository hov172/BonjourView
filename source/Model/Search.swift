import Foundation

/// One definition of what the search field matches, shared by the sidebar and the table.
extension ServiceType {
	/// Matches the type's own labels: display name, protocol string and domain.
	func matchesOwnName(_ query: String) -> Bool {
		kind.name.localizedCaseInsensitiveContains(query)
			|| type.localizedCaseInsensitiveContains(query)
			|| domain.localizedCaseInsensitiveContains(query)
	}

	/// Type matches when its own labels match or any instance does.
	func matches(_ query: String) -> Bool {
		matchesOwnName(query) || instances.contains { $0.matches(query) }
	}

	/// Rows to show for a query: everything when the type itself matched, otherwise only matching instances.
	func instances(matching query: String) -> [ServiceInstance] {
		guard !query.isEmpty else { return instances }
		if matchesOwnName(query) { return instances }
		return instances.filter { $0.matches(query) }
	}
}

extension ServiceInstance {
	/// Everything the inspector can show for this instance: name, decoded name fields, host, port, addresses, TXT record.
	func matches(_ query: String) -> Bool {
		name.localizedCaseInsensitiveContains(query)
			|| displayHost.localizedCaseInsensitiveContains(query)
			|| portText == query
			|| addresses.contains { $0.value.localizedCaseInsensitiveContains(query) }
			|| txtRecords.contains { $0.key.localizedCaseInsensitiveContains(query) || $0.value.localizedCaseInsensitiveContains(query) }
			|| InstanceNameDecoder.decode(name).contains { $0.value.localizedCaseInsensitiveContains(query) || $0.label.localizedCaseInsensitiveContains(query) }
	}
}
