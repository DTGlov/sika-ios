#!/usr/bin/env swift

// Sika launch-screen cowrie exporter.
//
// Sibling of export-app-icon.swift; same SikaMark primitives, but:
//  - TRANSPARENT background (the launch screen's `UIColorName` in
//    Info.plist provides the navy fill behind the image)
//  - Cowrie fills 100% of the bitmap (no inner padding — the cowrie
//    image IS the cowrie at the desired display size)
//  - Emits three sizes for @1x / @2x / @3x at 280pt display size
//
// Usage:
//   swift scripts/export-launch-cowrie.swift
//
// Output:
//   Sika/Assets.xcassets/LaunchCowrie.imageset/LaunchCowrie.png       (280×280, @1x)
//   Sika/Assets.xcassets/LaunchCowrie.imageset/LaunchCowrie@2x.png    (560×560, @2x)
//   Sika/Assets.xcassets/LaunchCowrie.imageset/LaunchCowrie@3x.png    (840×840, @3x)
//
// Re-run this script to regenerate after any SikaMark geometry tweak.

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

let bodyColor   = hexColor(0xD4A017)   // sika gold
let strokeColor = hexColor(0x0E1A2E)   // sika navy

/// Render the cowrie centered in a square bitmap with transparent background.
/// `pixelSize` is the bitmap width/height (e.g. 280 for @1x, 560 for @2x).
func renderCowrie(pixelSize: Int) -> CGImage? {
    let size = CGFloat(pixelSize)
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        return nil
    }

    // No background fill — the launch screen's UIColorName supplies it.

    // Y-down convention so ribs open downward matching SikaMark's Canvas.
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: 1, y: -1)

    // SikaMark designs at 48pt; we want the cowrie to fill the bitmap.
    let s: CGFloat = size / 48.0
    let cx: CGFloat = 24 * s
    let cy: CGFloat = 24 * s

    // Body (gold ellipse)
    let bodyRect = CGRect(
        x: cx - 14 * s,
        y: cy - 20 * s,
        width: 28 * s,
        height: 40 * s
    )
    context.setFillColor(bodyColor)
    context.fillEllipse(in: bodyRect)

    // Spine (navy stroke, width 2.5s, round caps)
    context.setStrokeColor(strokeColor)
    context.setLineCap(.round)
    context.setLineWidth(2.5 * s)
    context.move(to: CGPoint(x: 24 * s, y: 6 * s))
    context.addLine(to: CGPoint(x: 24 * s, y: 42 * s))
    context.strokePath()

    // Ribs (4 V-pairs, navy stroke, width 1.5s, round caps)
    context.setLineWidth(1.5 * s)
    let ribY: [(start: CGFloat, end: CGFloat)] = [
        (12, 16), (18, 22), (24, 28), (30, 34)
    ]
    for (yStart, yEnd) in ribY {
        context.move(to: CGPoint(x: 24 * s, y: yStart * s))
        context.addLine(to: CGPoint(x: 22 * s, y: yEnd * s))
        context.move(to: CGPoint(x: 24 * s, y: yStart * s))
        context.addLine(to: CGPoint(x: 26 * s, y: yEnd * s))
    }
    context.strokePath()

    return context.makeImage()
}

func writePNG(_ image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

// MARK: - Emit @1x / @2x / @3x

let cwd = FileManager.default.currentDirectoryPath
let imageSetDir = "\(cwd)/Sika/Assets.xcassets/LaunchCowrie.imageset"

let variants: [(size: Int, filename: String)] = [
    (280, "LaunchCowrie.png"),       // @1x
    (560, "LaunchCowrie@2x.png"),    // @2x
    (840, "LaunchCowrie@3x.png"),    // @3x
]

for (size, filename) in variants {
    guard let image = renderCowrie(pixelSize: size) else {
        fputs("error: render failed for \(filename) (\(size)px)\n", stderr)
        exit(1)
    }
    let path = "\(imageSetDir)/\(filename)"
    guard writePNG(image, to: path) else {
        fputs("error: write failed for \(path)\n", stderr)
        exit(1)
    }
    print("✅ Wrote \(filename) — \(size)×\(size)")
}
