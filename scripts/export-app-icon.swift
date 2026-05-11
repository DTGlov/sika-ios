#!/usr/bin/env swift

// Sika app icon exporter — one-off chore generator.
//
// Replicates SikaMark.swift's Canvas drawing using CoreGraphics so the
// script runs as a standalone command-line tool (no SwiftUI / UIKit /
// iOS simulator session needed). Output is a 1024x1024 PNG with the
// gold cowrie on a deep-navy full-bleed background — Apple's mask
// adds the rounded-square crop at install time.
//
// Composition pinned to the SikaMark source:
//   - Designed at 48pt unit; export uses a 600pt cowrie centered in a
//     1024pt canvas (~60% occupancy, ~21% margin on each side).
//   - Body:  ellipse at (cx-14s, cy-20s) sized (28s, 40s), fill gold #D4A017
//   - Spine: vertical stroke (24s, 6s)→(24s, 42s), navy #0E1A2E, width 2.5s, round
//   - Ribs:  4 V-pairs opening downward from (24s, yStart) to
//            (22s, yEnd) and (26s, yEnd) for yPairs [(12,16), (18,22),
//            (24,28), (30,34)]; navy stroke, width 1.5s, round
//
// Usage:
//   swift scripts/export-app-icon.swift [output-path]
//
// Default output path:
//   ./Sika/Assets.xcassets/AppIcon.appiconset/sika-app-icon-1024.png
//
// To regenerate the icon (e.g. after a SikaMark tweak), update the
// constants below to match the SikaMark source and re-run.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Helpers

func hexColor(_ hex: UInt32) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return CGColor(red: r, green: g, blue: b, alpha: 1.0)
}

// MARK: - Composition constants (pinned to SikaMark.swift)

let canvasSize: CGFloat = 1024
let cowrieSize: CGFloat = 600
let cowrieOffset = (canvasSize - cowrieSize) / 2.0   // 212pt margin

let bodyColor       = hexColor(0xD4A017)   // sika gold
let strokeColor     = hexColor(0x0E1A2E)   // sika navy
let backgroundColor = hexColor(0x0E1A2E)   // sika navy (full bleed)

// MARK: - Context

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil,
        width: Int(canvasSize),
        height: Int(canvasSize),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
    fputs("error: failed to create CGContext\n", stderr)
    exit(1)
}

// Background — full-bleed navy; Apple's mask handles the rounded-square crop.
context.setFillColor(backgroundColor)
context.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

// Flip context so we can draw with Y-down coordinates that match
// SikaMark's Canvas convention (where ribs fan downward from a
// narrow top point to a wider bottom).
context.translateBy(x: 0, y: canvasSize)
context.scaleBy(x: 1, y: -1)

// Re-origin to the cowrie's top-left within the canvas, then use the
// same 48pt design coordinates as SikaMark.
context.translateBy(x: cowrieOffset, y: cowrieOffset)
let s: CGFloat = cowrieSize / 48.0   // 12.5

// MARK: - Body (gold ellipse)

let cx: CGFloat = 24 * s
let cy: CGFloat = 24 * s
let bodyRect = CGRect(
    x: cx - 14 * s,
    y: cy - 20 * s,
    width: 28 * s,
    height: 40 * s
)
context.setFillColor(bodyColor)
context.fillEllipse(in: bodyRect)

// MARK: - Spine (navy stroke, width 2.5s, round caps)

context.setStrokeColor(strokeColor)
context.setLineCap(.round)
context.setLineWidth(2.5 * s)
context.move(to: CGPoint(x: 24 * s, y: 6 * s))
context.addLine(to: CGPoint(x: 24 * s, y: 42 * s))
context.strokePath()

// MARK: - Ribs (4 V-pairs, navy stroke, width 1.5s, round caps)

context.setLineWidth(1.5 * s)
let ribY: [(start: CGFloat, end: CGFloat)] = [
    (12, 16), (18, 22), (24, 28), (30, 34)
]
for (yStart, yEnd) in ribY {
    // Left half — narrows from (24, yStart) to (22, yEnd)
    context.move(to: CGPoint(x: 24 * s, y: yStart * s))
    context.addLine(to: CGPoint(x: 22 * s, y: yEnd * s))
    // Right half — narrows from (24, yStart) to (26, yEnd)
    context.move(to: CGPoint(x: 24 * s, y: yStart * s))
    context.addLine(to: CGPoint(x: 26 * s, y: yEnd * s))
}
context.strokePath()

// MARK: - Encode PNG

guard let cgImage = context.makeImage() else {
    fputs("error: failed to make CGImage\n", stderr)
    exit(1)
}

let defaultPath = FileManager.default.currentDirectoryPath
    + "/Sika/Assets.xcassets/AppIcon.appiconset/sika-app-icon-1024.png"
let outputPath: String = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : defaultPath
let outputURL = URL(fileURLWithPath: outputPath)

// Ensure the parent directory exists before writing.
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fputs("error: failed to create CGImageDestination at \(outputPath)\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("error: failed to finalize PNG\n", stderr)
    exit(1)
}

print("✅ Wrote \(outputPath) — \(Int(canvasSize))×\(Int(canvasSize)) PNG")
