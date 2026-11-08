// Draws HookLink's icon (a hook on a chain link over a deep green tile) as a 1024x1024 PNG.
// Usage: swift scripts/make_icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Tile: rounded square, deep green to teal
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.addPath(tilePath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [NSColor(red: 0.05, green: 0.36, blue: 0.27, alpha: 1).cgColor,
                               NSColor(red: 0.03, green: 0.18, blue: 0.22, alpha: 1).cgColor] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.resetClip()

let gold = NSColor(red: 0.98, green: 0.80, blue: 0.33, alpha: 1).cgColor
ctx.setStrokeColor(gold); ctx.setLineCap(.round); ctx.setLineJoin(.round)

// Chain link: a rounded oval, tilted
ctx.saveGState()
ctx.translateBy(x: 400, y: 600); ctx.rotate(by: .pi / 4)
ctx.setLineWidth(58)
ctx.addPath(CGPath(roundedRect: CGRect(x: -150, y: -78, width: 300, height: 156), cornerWidth: 78, cornerHeight: 78, transform: nil))
ctx.strokePath()
ctx.restoreGState()

// Hook: a shaft from the link down-right, ending in a curved barb
ctx.setLineWidth(62)
ctx.move(to: CGPoint(x: 505, y: 495))
ctx.addLine(to: CGPoint(x: 640, y: 360))
ctx.addArc(center: CGPoint(x: 580, y: 300), radius: 85, startAngle: .pi / 4, endAngle: .pi * 1.15, clockwise: true)
ctx.strokePath()
// Barb tip
ctx.setFillColor(gold)
ctx.move(to: CGPoint(x: 470, y: 330)); ctx.addLine(to: CGPoint(x: 440, y: 230)); ctx.addLine(to: CGPoint(x: 530, y: 275)); ctx.closePath(); ctx.fillPath()

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
