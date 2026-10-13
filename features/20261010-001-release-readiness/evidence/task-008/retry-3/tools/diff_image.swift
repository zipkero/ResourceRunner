// task-008 retry-3 판독 보조: 기준 프레임 대비 회색조 절대 차이를 GAIN배로 키운 JPEG를 쓴다(crop X Y W H).
// 사용: diff_image OUT.jpg BASE.jpg FRAME.jpg GAIN X Y W H
import CoreGraphics
import Foundation
import ImageIO
func gray(_ path: String) -> ([UInt8], Int, Int) {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h)
    px.withUnsafeMutableBytes { b in
        let ctx = CGContext(data: b.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return (px, w, h)
}
let a = CommandLine.arguments
let (b, w, _) = gray(a[2]); let (f, _, _) = gray(a[3])
let gain = Int(a[4])!, x0 = Int(a[5])!, y0 = Int(a[6])!, cw = Int(a[7])!, ch = Int(a[8])!
var out = [UInt8](repeating: 0, count: cw * ch)
for y in 0..<ch { for x in 0..<cw {
    let i = (y0 + y) * w + x0 + x
    out[y * cw + x] = UInt8(min(255, abs(Int(f[i]) - Int(b[i])) * gain))
} }
let ctx = out.withUnsafeMutableBytes { CGContext(data: $0.baseAddress, width: cw, height: ch, bitsPerComponent: 8, bytesPerRow: cw,
    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!.makeImage()! }
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, "public.jpeg" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx, nil); CGImageDestinationFinalize(dest)
