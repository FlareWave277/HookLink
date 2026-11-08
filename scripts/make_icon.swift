// Draws HookLink's icon (a chain link holding a hook, gold on a deep green tile) as a 1024x1024 PNG.
// Usage: swift scripts/make_icon.swift <out.png>
import AppKit

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Tile: rounded square, deep green to teal
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [NSColor(red: 0.06, green: 0.38, blue: 0.28, alpha: 1).cgColor,
                               NSColor(red: 0.03, green: 0.17, blue: 0.21, alpha: 1).cgColor] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

let gold = NSColor(red: 0.98, green: 0.80, blue: 0.33, alpha: 1).cgColor
ctx.setStrokeColor(gold); ctx.setFillColor(gold)
ctx.setLineCap(.round); ctx.setLineJoin(.round)
let w: CGFloat = 60

// Chain link: an upright rounded oval near the top
ctx.setLineWidth(w)
ctx.addPath(CGPath(roundedRect: CGRect(x: 432, y: 600, width: 160, height: 250), cornerWidth: 80, cornerHeight: 80, transform: nil))
ctx.strokePath()

// Hook: a ring through the link's bottom, a straight shaft down, then a J curve up to a barbed point
ctx.setLineWidth(w)
ctx.move(to: CGPoint(x: 512, y: 600))          // from the link's bottom edge: they hold together
ctx.addLine(to: CGPoint(x: 512, y: 390))        // shaft
let c = CGPoint(x: 427, y: 390), r: CGFloat = 85
ctx.addArc(center: c, radius: r, startAngle: 0, endAngle: .pi, clockwise: true)   // J curve, bottom half of a circle
ctx.addLine(to: CGPoint(x: 342, y: 430))        // up the inner side to the point
ctx.strokePath()

// Barb: a solid arrowhead at the point, pointing up
ctx.move(to: CGPoint(x: 342, y: 520))
ctx.addLine(to: CGPoint(x: 290, y: 420))
ctx.addLine(to: CGPoint(x: 394, y: 420))
ctx.closePath(); ctx.fillPath()

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
