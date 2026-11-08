// Draws HookLink's icon (a tilted chain link with a hook hanging from it, gold on a deep green tile) as a 1024x1024 PNG.
// The mark is measured after stroking and centred on the tile. Usage: swift scripts/make_icon.swift <out.png>
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
                      colors: [NSColor(red: 0.05, green: 0.36, blue: 0.27, alpha: 1).cgColor,
                               NSColor(red: 0.03, green: 0.18, blue: 0.22, alpha: 1).cgColor] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

let s2 = CGFloat(2).squareRoot() / 2
func p(_ a: CGPoint, _ d: CGVector, _ k: CGFloat) -> CGPoint { CGPoint(x: a.x + d.dx * k, y: a.y + d.dy * k) }
let down = CGVector(dx: s2, dy: -s2)     // the hook's direction: down and to the right
let back = CGVector(dx: -s2, dy: s2)     // after the curve: up and to the left
let side = CGVector(dx: s2, dy: s2)      // across the hook

// Chain link: a rounded oval tilted 45°, long axis up-right
let linkC = CGPoint(x: 400, y: 600), linkHalfH: CGFloat = 78
var t = CGAffineTransform(translationX: linkC.x, y: linkC.y).rotated(by: .pi / 4)
let link = CGPath(roundedRect: CGRect(x: -150, y: -linkHalfH, width: 300, height: 2 * linkHalfH), cornerWidth: linkHalfH, cornerHeight: linkHalfH, transform: &t)

// Hook: from the link's lower-right side (no gap), a straight shaft, a half-turn curve, a short return, then the barb
let start = p(linkC, down, linkHalfH)
let shaftEnd = p(start, down, 230)
let r: CGFloat = 85
let center = p(shaftEnd, CGVector(dx: -s2, dy: -s2), r)       // the curve turns back toward the lower left
let hook = CGMutablePath()
hook.move(to: start); hook.addLine(to: shaftEnd)
hook.addArc(center: center, radius: r, startAngle: .pi / 4, endAngle: .pi * 1.25 - 2 * .pi, clockwise: true)
let curveEnd = p(center, CGVector(dx: -s2, dy: -s2), r)
let tip = p(curveEnd, back, 40)
hook.addLine(to: tip)

// Barb: an arrowhead on the tip, pointing the way the hook ends
let barb = CGMutablePath()
barb.move(to: p(tip, back, 95))
barb.addLine(to: p(tip, side, 58)); barb.addLine(to: p(tip, side, -58)); barb.closeSubpath()

// Centre the whole mark on the tile
let w: CGFloat = 60
let bounds = link.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 10).boundingBox
    .union(hook.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 10).boundingBox)
    .union(barb.boundingBox)
ctx.translateBy(x: 512 - bounds.midX, y: 512 - bounds.midY)

let gold = NSColor(red: 0.98, green: 0.80, blue: 0.33, alpha: 1).cgColor
ctx.setStrokeColor(gold); ctx.setFillColor(gold); ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.setLineWidth(w)
ctx.addPath(link); ctx.strokePath()
ctx.addPath(hook); ctx.strokePath()
ctx.addPath(barb); ctx.fillPath()

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
