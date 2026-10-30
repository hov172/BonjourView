import Foundation

/// Human-readable presentation for a DNS-SD service type.
struct ServiceKind: Hashable {
	let name: String
	let symbol: String
	/// URL scheme that can open an instance of this type, if any.
	let scheme: String?
	let isKnown: Bool
}

enum ServiceCatalog {
	/// `"_http._tcp."` or `"_HTTP._tcp"` → `"_http._tcp"`.
	static func normalize(_ type: String) -> String {
		type.lowercased().removingTrailingDots()
	}

	/// The single naming ladder: user rename > curated list > TXT-key hint > IANA registry > device-ID pattern > raw label.
	static func kind(
		forType type: String,
		txtKeys: [String] = [],
		customNames: CustomTypeNames = .shared,
		registry: IANARegistry = .shared
	) -> ServiceKind {
		let key = normalize(type)
		let curated = known[key]
		if let custom = customNames.name(forNormalizedType: key) {
			return ServiceKind(name: custom, symbol: curated?.symbol ?? "tag", scheme: curated?.scheme, isKnown: true)
		}
		if let curated {
			return curated
		}
		if let hint = kind(forTXTKeys: txtKeys) {
			return hint
		}
		let label = displayName(fromRawType: key)
		if let description = registry.description(forServiceName: label) {
			return ServiceKind(name: description, symbol: "network", scheme: nil, isKnown: true)
		}
		if isDeviceIdentifierType(key) {
			// Some apps (e.g. QuickDrop) advertise a type named after the device's MAC address.
			return ServiceKind(name: "Device-Specific", symbol: "qrcode", scheme: nil, isKnown: false)
		}
		return ServiceKind(name: displayName(fromRawType: type), symbol: "network", scheme: nil, isKnown: false)
	}

	private static func kind(forTXTKeys keys: [String]) -> ServiceKind? {
		for key in keys {
			let lowered = key.lowercased()
			if let match = txtKeyPrefixHints.first(where: { lowered.hasPrefix($0.prefix) }) {
				return match.kind
			}
		}
		return nil
	}

	private static let txtKeyPrefixHints: [(prefix: String, kind: ServiceKind)] = [
		("qd_", entry("QuickDrop", "doc.on.clipboard")),
	]

	/// `_fc9f5ed42c8a._tcp`: twelve hex digits, i.e. a MAC address used as a service type.
	static func isDeviceIdentifierType(_ normalizedType: String) -> Bool {
		let label = normalizedType.split(separator: ".").first.map(String.init) ?? ""
		guard label.hasPrefix("_"), label.count == 13 else { return false }
		return label.dropFirst().allSatisfy(\.isHexDigit)
	}

	/// `"_pdl-datastream._tcp"` → `"pdl-datastream"`.
	static func displayName(fromRawType type: String) -> String {
		let first = type.split(separator: ".").first.map(String.init) ?? type
		return first.hasPrefix("_") ? String(first.dropFirst()) : first
	}

	/// Builds a full service type from a `_services._dns-sd._udp` meta-query result.
	/// The result arrives as name `"_http"` and type `"_tcp.local."`; the domain part
	/// is not reliable, so only the transport label is used.
	static func serviceType(fromMetaQueryName name: String, type: String) -> String? {
		guard let dot = type.firstIndex(of: "."), dot > type.startIndex, name.hasPrefix("_") else {
			return nil
		}
		return "\(name).\(type[..<dot])."
	}

	static func serviceType(fromMetaQueryResult service: NetService) -> String? {
		serviceType(fromMetaQueryName: service.name, type: service.type)
	}

	private static func entry(_ name: String, _ symbol: String, _ scheme: String? = nil) -> ServiceKind {
		ServiceKind(name: name, symbol: symbol, scheme: scheme, isKnown: true)
	}

	private static let known: [String: ServiceKind] = [
		// Web and remote access
		"_http._tcp": entry("Web Server (HTTP)", "globe", "http"),
		"_https._tcp": entry("Web Server (HTTPS)", "lock.shield", "https"),
		"_ssh._tcp": entry("SSH", "terminal", "ssh"),
		"_sftp-ssh._tcp": entry("SFTP", "terminal", "sftp"),
		"_telnet._tcp": entry("Telnet", "terminal", "telnet"),
		"_rfb._tcp": entry("Screen Sharing (VNC)", "display", "vnc"),
		"_rdp._tcp": entry("Remote Desktop (RDP)", "display", "rdp"),
		"_net-assistant._udp": entry("Apple Remote Desktop", "display.2"),
		"_teamviewer._tcp": entry("TeamViewer", "display"),
		// File sharing
		"_smb._tcp": entry("File Sharing (SMB)", "externaldrive.connected.to.line.below", "smb"),
		"_afpovertcp._tcp": entry("File Sharing (AFP)", "externaldrive.connected.to.line.below", "afp"),
		"_nfs._tcp": entry("NFS", "externaldrive", "nfs"),
		"_ftp._tcp": entry("FTP", "externaldrive", "ftp"),
		"_webdav._tcp": entry("WebDAV", "externaldrive", "http"),
		"_adisk._tcp": entry("Time Machine Disk", "externaldrive.badge.timemachine"),
		"_syncthing._tcp": entry("Syncthing", "arrow.triangle.2.circlepath"),
		// Media
		"_airplay._tcp": entry("AirPlay", "airplayvideo"),
		"_raop._tcp": entry("AirPlay Audio", "hifispeaker"),
		"_daap._tcp": entry("Music Sharing (DAAP)", "music.note.list"),
		"_dacp._tcp": entry("Remote Control (DACP)", "music.note"),
		"_googlecast._tcp": entry("Google Cast", "tv"),
		"_spotify-connect._tcp": entry("Spotify Connect", "music.note"),
		"_sonos._tcp": entry("Sonos", "hifispeaker.2"),
		"_plexmediasvr._tcp": entry("Plex Media Server", "play.rectangle"),
		"_rtsp._tcp": entry("Streaming (RTSP)", "video", "rtsp"),
		"_amzn-wplay._tcp": entry("Amazon Fire TV", "tv"),
		"_androidtvremote2._tcp": entry("Android TV Remote", "tv"),
		"_appletv-v2._tcp": entry("Apple TV", "appletv"),
		"_mediaremotetv._tcp": entry("Apple TV Remote", "appletv"),
		"_touch-able._tcp": entry("Apple TV Remote (Legacy)", "appletv"),
		"_nvstream._tcp": entry("NVIDIA GameStream", "gamecontroller"),
		// Printing and scanning
		"_ipp._tcp": entry("Printer (IPP)", "printer", "ipp"),
		"_ipps._tcp": entry("Printer (IPPS)", "printer", "ipps"),
		"_printer._tcp": entry("Printer (LPD)", "printer"),
		"_pdl-datastream._tcp": entry("Printer (Raw)", "printer"),
		"_scanner._tcp": entry("Scanner", "scanner"),
		"_uscan._tcp": entry("Scanner (eSCL)", "scanner"),
		"_uscans._tcp": entry("Scanner (eSCL/TLS)", "scanner"),
		"_privet._tcp": entry("Cloud Print", "printer"),
		// Apple ecosystem (identified from the daemons that advertise them: rapportd, identityservicesd, mediaremoted)
		"_companion-link._tcp": entry("Companion Link", "link"),
		"_applicationservicepairing._tcp": entry("Companion App Pairing", "link"),
		"_appsvcprepair._tcp": entry("Companion Pre-Pairing", "link"),
		"_asquic._udp": entry("Identity Services (QUIC)", "message"),
		"_rdlink._tcp": entry("Remote Display Pairing", "appletv"),
		"_device-info._tcp": entry("Device Info", "info.circle"),
		"_workstation._tcp": entry("Workstation", "desktopcomputer"),
		"_apple-mobdev2._tcp": entry("iOS Device (Wi-Fi Sync)", "iphone"),
		"_remotepairing._tcp": entry("Remote Pairing", "link"),
		"_remoted._tcp": entry("Remote Development", "hammer"),
		"_sleep-proxy._udp": entry("Bonjour Sleep Proxy", "moon.zzz"),
		"_eppc._tcp": entry("Remote Apple Events", "applescript"),
		"_distcc._tcp": entry("Distributed Compiler", "hammer"),
		"_homekit._tcp": entry("HomeKit", "homekit"),
		"_hap._tcp": entry("HomeKit Accessory", "homekit"),
		"_services._dns-sd._udp": entry("Service Types", "list.bullet"),
		// Thread (OpenThread border router services)
		"_meshcop._udp": entry("Thread Border Router", "antenna.radiowaves.left.and.right"),
		"_meshcop-e._udp": entry("Thread Border Router (ext.)", "antenna.radiowaves.left.and.right"),
		"_trel._udp": entry("Thread Radio Link (TREL)", "antenna.radiowaves.left.and.right"),
		"_srpl-tls._tcp": entry("Thread SRP Replication", "arrow.triangle.2.circlepath"),
		"_dnssd-server._udp": entry("Thread DNS-SD Server", "antenna.radiowaves.left.and.right"),
		"_infra-analytics._udp": entry("Thread Analytics", "antenna.radiowaves.left.and.right"),
		// Smart home
		"_matter._tcp": entry("Matter", "homekit"),
		"_matterc._udp": entry("Matter Commissioning", "homekit"),
		"_hue._tcp": entry("Philips Hue", "lightbulb"),
		"_elg._tcp": entry("Elgato", "lightbulb"),
		"_home-assistant._tcp": entry("Home Assistant", "house"),
		"_esphomelib._tcp": entry("ESPHome", "cpu"),
		"_arduino._tcp": entry("Arduino OTA", "cpu"),
		"_octoprint._tcp": entry("OctoPrint", "cube"),
		"_mqtt._tcp": entry("MQTT", "antenna.radiowaves.left.and.right"),
		"_coap._udp": entry("CoAP", "antenna.radiowaves.left.and.right"),
		// Directory, mail, chat
		"_ldap._tcp": entry("LDAP Directory", "person.2"),
		"_kerberos._tcp": entry("Kerberos", "key"),
		"_od-master._tcp": entry("Open Directory", "person.2"),
		"_odproxy._tcp": entry("Open Directory Proxy", "person.2"),
		"_apple-sasl._tcp": entry("Password Server", "key"),
		"_smtp._tcp": entry("Mail (SMTP)", "envelope"),
		"_imap._tcp": entry("Mail (IMAP)", "envelope"),
		"_pop3._tcp": entry("Mail (POP3)", "envelope"),
		"_xmpp-client._tcp": entry("Jabber (XMPP)", "message"),
		"_presence._tcp": entry("Bonjour Chat", "message"),
		"_sip._udp": entry("SIP", "phone"),
		// Cameras and misc
		"_ptp._tcp": entry("Camera (PTP)", "camera"),
		"_ica-networking._tcp": entry("Camera (ICA)", "camera"),
		"_axis-video._tcp": entry("Axis Camera", "video"),
		"_snmp._udp": entry("SNMP", "chart.bar"),
		"_ntp._udp": entry("Time (NTP)", "clock"),
		"_dosvc._tcp": entry("Windows Delivery Opt.", "arrow.down.circle"),
	]
}
