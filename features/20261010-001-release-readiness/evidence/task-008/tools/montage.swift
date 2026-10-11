// 판독 확인용: 여러 ROI JPEG에서 같은 crop을 잘라 격자로 붙이고 각 칸 위에 라벨을 쓴다.
// 사용: montage OUT.jpg COLS X Y W H LABEL1=FILE1 LABEL2=FILE2 ...
import AppKit
let a = CommandLine.arguments
let cols = Int(a[2])!, x = CGFloat(Double(a[3])!), y = CGFloat(Double(a[4])!), w = CGFloat(Double(a[5])!), h = CGFloat(Double(a[6])!)
let items = a.dropFirst(7).map { s -> (String, String) in let p = s.split(separator: "=", maxSplits: 1); return (String(p[0]), String(p[1])) }
let rows = (items.count + cols - 1) / cols, lab: CGFloat = 16
let W = Int(w) * cols, H = Int(h + lab) * rows
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
for (i, (label, file)) in items.enumerated() {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: file) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
          let crop = img.cropping(to: CGRect(x: x, y: y, width: w, height: h)) else { continue }
    let c = CGFloat(i % cols), r = CGFloat(i / cols)
    let top = CGFloat(H) - r * (h + lab)
    ctx.draw(crop, in: CGRect(x: c * w, y: top - lab - h, width: w, height: h))
    (label as NSString).draw(at: CGPoint(x: c * w + 3, y: top - lab + 1),
        withAttributes: [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.red])
}
let out = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, "public.jpeg" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, out, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
CGImageDestinationFinalize(dest)
