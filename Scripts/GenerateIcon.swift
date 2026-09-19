import AppKit
import Foundation
let target = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
let size = NSSize(width: 1024, height: 1024)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(red: 1, green: 203/255, blue: 10/255, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let ink = NSColor(red: 35/255, green: 35/255, blue: 35/255, alpha: 1)
ink.setFill()
let bag = NSBezierPath(roundedRect: NSRect(x: 245, y: 225, width: 534, height: 490), xRadius: 70, yRadius: 70)
bag.fill()
let handle = NSBezierPath(); handle.move(to: NSPoint(x: 390, y: 670))
handle.curve(to: NSPoint(x: 634, y: 670), controlPoint1: NSPoint(x: 370, y: 922), controlPoint2: NSPoint(x: 654, y: 922))
handle.lineWidth = 50; handle.lineCapStyle = .round; ink.setStroke(); handle.stroke()
NSColor.white.setStroke()
let check = NSBezierPath(); check.move(to: NSPoint(x: 387, y: 454)); check.line(to: NSPoint(x: 479, y: 369)); check.line(to: NSPoint(x: 637, y: 545)); check.lineWidth = 46; check.lineCapStyle = .round; check.lineJoinStyle = .round; check.stroke()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: target.appendingPathComponent("AppIcon.png"))
let json = """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
"""
try json.write(to: target.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
