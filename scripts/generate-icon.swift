// Generates the BonjourView app icon in the macOS 11+ rounded-square style.
// Usage: swift scripts/generate-icon.swift nonsource/Assets.xcassets/AppIcon.appiconset
import AppKit

let canvas: CGFloat = 1024
// Apple's icon grid: the rounded square occupies 824pt of a 1024pt canvas.
let square = NSRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius = square.width * 0.2237

let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
	let path = NSBezierPath(roundedRect: square, xRadius: cornerRadius, yRadius: cornerRadius)

	NSGraphicsContext.saveGraphicsState()
	let shadow = NSShadow()
	shadow.shadowBlurRadius = 28
	shadow.shadowOffset = NSSize(width: 0, height: -14)
	shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
	shadow.set()
	NSColor.black.setFill()
	path.fill()
	NSGraphicsContext.restoreGraphicsState()

	let gradient = NSGradient(colors: [
		NSColor(srgbRed: 1.00, green: 0.62, blue: 0.24, alpha: 1),
		NSColor(srgbRed: 0.93, green: 0.40, blue: 0.10, alpha: 1),
		NSColor(srgbRed: 0.80, green: 0.27, blue: 0.06, alpha: 1),
	])!
	gradient.draw(in: path, angle: -90)

	// Subtle top sheen.
	NSGraphicsContext.saveGraphicsState()
	path.addClip()
	let sheen = NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
	sheen.draw(in: NSRect(x: square.minX, y: square.midY, width: square.width, height: square.height / 2), angle: -90)
	NSGraphicsContext.restoreGraphicsState()

	// Binoculars glyph, white with a soft shadow.
	let configuration = NSImage.SymbolConfiguration(pointSize: 440, weight: .medium)
	guard let symbol = NSImage(systemSymbolName: "binoculars.fill", accessibilityDescription: nil)?
		.withSymbolConfiguration(configuration) else {
		fatalError("binoculars.fill symbol unavailable")
	}
	let tinted = NSImage(size: symbol.size, flipped: false) { rect in
		symbol.draw(in: rect)
		NSColor.white.set()
		rect.fill(using: .sourceAtop)
		return true
	}
	let glyphRect = NSRect(
		x: square.midX - symbol.size.width / 2,
		y: square.midY - symbol.size.height / 2 + 10,
		width: symbol.size.width,
		height: symbol.size.height
	)
	NSGraphicsContext.saveGraphicsState()
	let glyphShadow = NSShadow()
	glyphShadow.shadowBlurRadius = 18
	glyphShadow.shadowOffset = NSSize(width: 0, height: -8)
	glyphShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
	glyphShadow.set()
	tinted.draw(in: glyphRect)
	NSGraphicsContext.restoreGraphicsState()
	return true
}

guard CommandLine.arguments.count == 2 else {
	fatalError("usage: generate-icon.swift <AppIcon.appiconset directory>")
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
	fatalError("could not render icon")
}
let master = outputDirectory.appendingPathComponent("icon_1024.png")
try png.write(to: master)

// Resize for every slot in the icon set.
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
	let pixels = points * scale
	let output = outputDirectory.appendingPathComponent("icon\(points)x\(points)@\(scale)x.png")
	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
	process.arguments = ["-z", "\(pixels)", "\(pixels)", master.path, "--out", output.path]
	process.standardOutput = FileHandle.nullDevice
	try process.run()
	process.waitUntilExit()
	guard process.terminationStatus == 0 else { fatalError("sips failed for \(output.lastPathComponent)") }
}
try FileManager.default.removeItem(at: master)
print("Wrote icon set to \(outputDirectory.path)")
