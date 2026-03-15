#!/usr/bin/env swift
import AppKit
import CoreGraphics

/// Generates the WorkspaceSwitcher app icon at all required sizes.
/// Design: Two overlapping rounded cards (representing workspace switching)
/// with a gradient background.

func generateIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024.0

    // Background: rounded rect with gradient
    let bgRadius = 228.0 * scale
    let bgPath = CGPath(roundedRect: bounds.insetBy(dx: 2 * scale, dy: 2 * scale),
                        cornerWidth: bgRadius, cornerHeight: bgRadius, transform: nil)
    context.addPath(bgPath)
    context.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.15, green: 0.15, blue: 0.22, alpha: 1.0),
        CGColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!
    context.drawLinearGradient(gradient,
                               start: CGPoint(x: size / 2, y: size),
                               end: CGPoint(x: size / 2, y: 0),
                               options: [])
    context.resetClip()

    // Card dimensions
    let cardWidth = 440.0 * scale
    let cardHeight = 320.0 * scale
    let cardRadius = 36.0 * scale
    let centerX = size / 2
    let centerY = size / 2

    // Back card (slightly rotated, offset)
    context.saveGState()
    context.translateBy(x: centerX - 20 * scale, y: centerY + 30 * scale)
    context.rotate(by: -0.12)
    let backCard = CGRect(x: -cardWidth / 2, y: -cardHeight / 2, width: cardWidth, height: cardHeight)
    let backPath = CGPath(roundedRect: backCard, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
    context.setFillColor(CGColor(red: 0.35, green: 0.35, blue: 0.45, alpha: 0.6))
    context.addPath(backPath)
    context.fillPath()
    context.restoreGState()

    // Front card
    context.saveGState()
    context.translateBy(x: centerX + 20 * scale, y: centerY - 20 * scale)
    context.rotate(by: 0.06)
    let frontCard = CGRect(x: -cardWidth / 2, y: -cardHeight / 2, width: cardWidth, height: cardHeight)
    let frontPath = CGPath(roundedRect: frontCard, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)

    // Front card gradient
    context.addPath(frontPath)
    context.clip()
    let cardGradientColors = [
        CGColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1.0),
        CGColor(red: 0.20, green: 0.40, blue: 0.85, alpha: 1.0),
    ] as CFArray
    let cardGradient = CGGradient(colorsSpace: colorSpace, colors: cardGradientColors, locations: [0.0, 1.0])!
    context.drawLinearGradient(cardGradient,
                               start: CGPoint(x: 0, y: cardHeight / 2),
                               end: CGPoint(x: 0, y: -cardHeight / 2),
                               options: [])
    context.resetClip()

    // Lines on front card (representing account rows)
    let lineY1 = 60.0 * scale
    let lineY2 = -20.0 * scale
    let lineY3 = -100.0 * scale
    let lineLeft = -cardWidth / 2 + 50 * scale
    let lineRight = cardWidth / 2 - 50 * scale
    let lineHeight = 18.0 * scale

    for lineY in [lineY1, lineY2, lineY3] {
        // Circle (account icon)
        let circleSize = 36.0 * scale
        let circleRect = CGRect(x: lineLeft, y: lineY - circleSize / 2,
                                width: circleSize, height: circleSize)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
        context.fillEllipse(in: circleRect)

        // Line (account name)
        let textRect = CGRect(x: lineLeft + circleSize + 16 * scale, y: lineY - lineHeight / 2,
                              width: (lineRight - lineLeft - circleSize - 16 * scale) * 0.7, height: lineHeight)
        let textPath = CGPath(roundedRect: textRect, cornerWidth: lineHeight / 2,
                              cornerHeight: lineHeight / 2, transform: nil)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.4))
        context.addPath(textPath)
        context.fillPath()
    }

    context.restoreGState()

    // Switch arrows (center-bottom area)
    let arrowSize = 80.0 * scale
    let arrowCenterX = centerX
    let arrowCenterY = centerY - size * 0.30

    context.saveGState()
    context.translateBy(x: arrowCenterX, y: arrowCenterY)

    // Arrow circle background
    let arrowBgSize = arrowSize * 2.2
    context.setFillColor(CGColor(red: 0.95, green: 0.60, blue: 0.10, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: -arrowBgSize / 2, y: -arrowBgSize / 2,
                                    width: arrowBgSize, height: arrowBgSize))

    // Draw switch symbol (two arrows)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1.0))
    context.setLineWidth(8.0 * scale)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // Right arrow
    let a = arrowSize * 0.35
    context.move(to: CGPoint(x: -a, y: a * 0.5))
    context.addLine(to: CGPoint(x: a, y: a * 0.5))
    context.move(to: CGPoint(x: a * 0.4, y: a))
    context.addLine(to: CGPoint(x: a, y: a * 0.5))
    context.addLine(to: CGPoint(x: a * 0.4, y: 0))
    context.strokePath()

    // Left arrow
    context.move(to: CGPoint(x: a, y: -a * 0.5))
    context.addLine(to: CGPoint(x: -a, y: -a * 0.5))
    context.move(to: CGPoint(x: -a * 0.4, y: 0))
    context.addLine(to: CGPoint(x: -a, y: -a * 0.5))
    context.addLine(to: CGPoint(x: -a * 0.4, y: -a))
    context.strokePath()

    context.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("ERROR: Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("  Created: \(path)")
    } catch {
        print("ERROR: \(error)")
    }
}

// Required sizes for macOS app icon
let sizes: [(label: String, size: Int, scale: Int)] = [
    ("16x16@1x", 16, 1),
    ("16x16@2x", 32, 2),
    ("32x32@1x", 32, 1),
    ("32x32@2x", 64, 2),
    ("128x128@1x", 128, 1),
    ("128x128@2x", 256, 2),
    ("256x256@1x", 256, 1),
    ("256x256@2x", 512, 2),
    ("512x512@1x", 512, 1),
    ("512x512@2x", 1024, 2),
]

let scriptDir = CommandLine.arguments[0].components(separatedBy: "/").dropLast().joined(separator: "/")
let projectDir = scriptDir.isEmpty ? ".." : scriptDir + "/.."
let assetDir = projectDir + "/WorkspaceSwitcher/Resources/Assets.xcassets/AppIcon.appiconset"

print("Generating app icons...")

// Generate the master 1024px icon
let masterIcon = generateIcon(size: 1024)

for entry in sizes {
    let filename = "icon_\(entry.size)x\(entry.size).png"
    let path = assetDir + "/" + filename

    if entry.size == 1024 {
        savePNG(masterIcon, to: path)
    } else {
        let resized = NSImage(size: NSSize(width: entry.size, height: entry.size))
        resized.lockFocus()
        masterIcon.draw(in: NSRect(x: 0, y: 0, width: entry.size, height: entry.size),
                        from: NSRect(x: 0, y: 0, width: 1024, height: 1024),
                        operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        savePNG(resized, to: path)
    }
}

// Update Contents.json
let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_64x64.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_1024x1024.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let contentsPath = assetDir + "/Contents.json"
try! contentsJSON.write(toFile: contentsPath, atomically: true, encoding: .utf8)
print("  Updated: Contents.json")
print("Done!")
