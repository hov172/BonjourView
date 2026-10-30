# Bonjeff: Review and Modernization Plan

Date: 2026-10-29. Codebase: ~1000 lines of Swift, AppKit, no storyboard, no tests.

## Part 1: Review

### What is good and should be kept

- The discovery layer is correct and well thought out. The meta-query on
  `_services._dns-sd._udp.` to enumerate types, lazy resolve only on expand,
  case-insensitive de-duplication, the `CFNetServiceCreateDictionaryWithTXTData`
  workaround for the `NSNull` crash, and the `NSDictionary` note about Unicode
  equality are all signs of someone who hit the real bugs. Keep this logic.
- Sandboxed, hardened runtime, no third-party dependencies, programmatic UI.
- Expansion state persisted per node with a migration path.

### Why it looks and feels like a 2017 utility

| Area | Finding | File |
|---|---|---|
| Table | Cell-based `NSOutlineView` (`dataCell`, `objectValueFor`). Deprecated since 10.10. Blocks the sidebar style, SF Symbol icons, badges, hover, and row animations. | BrowserWindowController.swift:316-331, 399 |
| Table | Forces the pre-Big Sur look: `rowHeight = 17`, `intercellSpacing = 3x2`, `style` set to plain via KVC string. | BrowserWindowController.swift:308-312 |
| Window | Single 300x200 window, no toolbar, no search, no detail pane, no status bar. All information is crammed into one indented tree with `" - 22"` count suffixes typed into the string. | BrowserWindowController.swift:264, 410 |
| Window | No empty state, no "searching" indicator, no error surface. `didNotSearch` and `didNotResolve` go to `NSLog` only. | BrowserDelegate.swift:614, ServiceDelegate.swift:910 |
| Updates | Every add calls `reloadItem(parent, reloadChildren:true)`, so rows jump and selection is lost. Should be `insertItems(at:)` / `removeItems(at:)` with animation. | BrowserWindowController.swift:336 |
| Updates | Domain removal posts `object:nil`, which reloads the whole tree. | RootBrowserDelegate.swift:650 |
| Model | Leaf rows are `(String, String)` tuples boxed into `Any`. They have no identity, so the outline view cannot track them across reloads and selection is unstable. | ServiceDelegate.swift:809-811 |
| Model | View attributes (fonts, bold key labels) are built inside the data source. No separation between model and presentation. | BrowserWindowController.swift:257-262, 419-428 |
| Bug | Closure-based observers are added, but `removeObserver(self, ...)` does not remove closure observers. Harmless today only because the app quits on last window close. | BrowserWindowController.swift:333-361, 367 |
| API | `NetService` / `NetServiceBrowser` deprecated (macOS 10.15). Still functional; replacement is `NWBrowser` or `dnssd`. | all *Delegate.swift |
| API | `String.index(of:)` deprecated, `#if swift(>=4.1)` branches, `SWIFT_VERSION = 4.2`. | DomainBrowserDelegate.swift:682, ServiceDelegate.swift:874 |
| License | Long license shown in an `NSTextField` label with no scroll view. | LicenseWindowController.swift:974 |
| Menus | Edit menu carries Undo/Redo/Paste/Spelling/Find items that do nothing in this app, so most of the menu is permanently disabled. | MainMenu.swift:133-206 |
| Polish | No Settings window, no localization files (strings are wrapped but never extracted), no accessibility labels, no help, no tests, no CI. | project |
| Icon | Verify `AppIcon.appiconset` is a macOS 11 style rounded-square icon with all 10 sizes. | nonsource/Assets.xcassets |

### What "high end" means for this app

Compare to Discovery (DNS-SD browser), Network Radar, or Apple's own Console.
The pattern is always the same: a sidebar for categories, a list in the
middle, an inspector on the right, a toolbar with search, live counts as
badges, and a status line. Users never read a protocol string like
`_pdl-datastream._tcp.` without a human name next to it.

## Part 2: Plan

Recommendation: keep the discovery layer, replace the UI with SwiftUI.
Reason: `NavigationSplitView`, `.searchable`, `Table`, `.toolbar`,
`.inspector`, `Settings` scene and `.badge` give the entire high-end shell
natively with less code than fixing the cell-based AppKit table. The model
classes stay in Swift and become `@Observable`. Deployment target 14.0 is
already set in the project and is enough.

Fallback if you prefer to stay AppKit: `NSSplitViewController` with a
source-list-style view-based `NSOutlineView` on the left and a view-based
`NSTableView` on the right. Same phases apply.

### Phase 0: Foundation (half a day)

1. `SWIFT_VERSION = 5.0`, deployment target 14.0 everywhere, delete the
   `#if swift(>=4.1)` branches and `index(of:)`.
2. Replace tuple leaf rows with a tiny `ServiceAttribute` class
   (`key`, `value`, `kind: host | port | address | txt`). Gives identity and
   lets the UI pick icons and actions per kind.
3. Store observer tokens and remove them; or, once the model is
   `@Observable`, delete the three notifications entirely.
4. Unit tests for the three pure functions that exist today: type parsing
   from the meta-query, sockaddr to string, TXT record parsing including the
   non key=value case. Add a GitHub Actions `xcodebuild test` workflow.

### Phase 1: Model (half a day)

1. `@Observable final class ServiceType { name, domain, instances: [ServiceInstance], humanName, symbol }`.
2. `@Observable final class ServiceInstance { name, host, port, addresses, txt: [ServiceAttribute], state: .idle | .resolving | .resolved | .failed(Error) }`.
3. `@Observable final class BonjourModel { domains: [Domain], isSearching, lastError }`.
   Wraps the existing `NetServiceBrowser` delegates, which mutate these arrays
   on the main thread. UI changes become diffs, not reloads.
4. A static table mapping about 60 common types to human names and SF Symbols
   (`_http._tcp` → "Web Server", `globe`; `_airplay._tcp` → "AirPlay", `airplayvideo`;
   `_ipp._tcp` → "Printer", `printer`; `_ssh._tcp` → "SSH", `terminal`;
   `_smb._tcp` → "File Sharing", `externaldrive.connected.to.line.below`;
   `_raop._tcp` → "AirPlay Audio", `hifispeaker`). Unknown types fall back to
   the raw string and `network`.

### Phase 2: Shell (one to two days)

Layout: `NavigationSplitView` with three columns.

1. Sidebar: domains as sections, service types as rows with icon, human
   name, raw type in secondary text, instance count as `.badge`. Preserves
   today's expand state through `@SceneStorage` / `UserDefaults`.
2. Content: `Table` of instances for the selected type. Columns: Name, Host,
   Port, IPv4, IPv6. Sortable, multi-select, `Copy` copies rows as TSV.
   Resolving starts when a type is selected, matching today's lazy behavior.
3. Inspector (`.inspector`): selected instance detail. Grouped form with
   Host, Port, Addresses (each with a copy button), then TXT record as a
   two-column table. Hex shown in monospaced font when the value is not UTF-8.
4. Toolbar: search field (`.searchable`, filters names, hosts and TXT
   values), Refresh, toggle inspector, "Open" button that is enabled when
   the type maps to a URL scheme (`http`, `https`, `ssh`, `vnc`, `smb`, `afp`,
   `ipp`, `rtsp`) and calls `NSWorkspace.open`.
5. Status bar at the bottom of the content column: "22 types · 412 services
   · Searching…" with a small `ProgressView` while browsers are active.
6. Empty states via `ContentUnavailableView`: no domains, no services for a
   type, no search matches, and a "Local network access denied" state when
   `didNotSearch` reports an error.
7. Context menus on every row: Copy Name, Copy Host, Copy Address, Copy as
   JSON, Open.
8. Window: default 1000x640, `minSize` 720x420, title "Bonjeff", subtitle
   with selected type. Full-size content view and unified toolbar come free.

### Phase 3: Menus and app plumbing (half a day)

1. Replace the hand-built menu with `CommandGroup`s in the SwiftUI `App`:
   remove Undo/Redo/Paste/Spelling/Find, add View (Show Inspector, Refresh),
   Service (Open, Copy Address), Help (Website, License).
2. `Settings` scene: "Resolve services automatically", "Show raw type
   names", "Include peer-to-peer (AWDL)".
3. License window becomes a scrolling `TextEditor` in a sheet, or just a
   link in the About panel credits.
4. Export menu item: write all discovered services as JSON or CSV with
   `fileExporter`.

### Phase 4: Discovery layer refresh (one day, optional, do last)

Move from `NetService` to `NWBrowser` for enumeration and TXT records, keep
`DNSServiceResolve` / `DNSServiceGetAddrInfo` from `dnssd` for host and
address resolution, since `NWBrowser` does not expose addresses directly.
Behavior is identical, but removes every deprecation warning and adds
Thread-based Bonjour and `includePeerToPeer` via `NWParameters`. Skip this
if the warnings are acceptable; `NetService` still works on macOS 15.

### Phase 5: Polish and release (one day)

1. App icon: regenerate as a single 1024px macOS 11 style icon, or an
   Icon Composer file for macOS 26, with a network glyph on a rounded square.
2. Accessibility: labels on icon-only buttons, VoiceOver-readable badges,
   full keyboard navigation between the three columns.
3. Dark mode and Increased Contrast pass with Xcode's Accessibility Inspector.
4. Localization: `Localizable.xcstrings` with the existing English, since every
   user string is already wrapped.
5. Help menu pointing at a short GitHub Pages or README anchor.
6. Notarized release workflow in GitHub Actions on tag push.

### Explicitly not doing

- Sparkle auto-update: the README distributes via GitHub Releases. Add only
  if you move off that.
- Favorites, history, or a database of past sightings. No evidence of need.
- Custom drawing or custom controls of any kind. Everything above is stock.

### Order and effort

| Phase | Effort | Visible result |
|---|---|---|
| 0 Foundation | 0.5 d | Warnings gone, tests exist |
| 1 Model | 0.5 d | None yet |
| 2 Shell | 1.5 d | The app looks like a modern Mac app |
| 3 Menus and plumbing | 0.5 d | Menus match the features, Settings, Export |
| 5 Polish and release | 1 d | Icon, accessibility, localization, CI release |
| 4 Discovery refresh | 1 d | Zero deprecations, optional |

About four working days to a shippable 3.0 without Phase 4.

## Status (2026-10-29)

Phases 0, 1, 2, 3 and 5 are implemented in this tree. Phase 4 (NWBrowser/dnssd) was deliberately deferred: `NetService` still works on current macOS and the discovery layer is isolated behind `NetServiceBrowserSession`, so it can be swapped later without touching the UI.
