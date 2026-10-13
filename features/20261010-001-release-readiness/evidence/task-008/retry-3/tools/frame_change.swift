// task-008 retry-3 판독 보조: 기준 프레임 대비 회색조 차이 > THR 인 픽셀을 툴팁 사각형 안/밖으로 나눠 세고 밖의 경계 상자를 낸다.
// 사용: frame_change FRAMES_DIR BASELINE.jpg THR TX TY TW TH FRAME1.jpg FRAME2.jpg ...
// (TX,TY,TW,TH)는 상태 항목 툴팁 사각형(위쪽 기준 1x 좌표). y<24(메뉴바 줄)은 제외한다.
import CoreGraphics
import Foundation
import ImageIO

func gray(_ url: URL) -> ([UInt8], Int, Int) {
    let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
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
let dir = URL(fileURLWithPath: a[1])
let (base, w, h) = gray(dir.appendingPathComponent(a[2]))
let thr = Int(a[3])!, tx = Int(a[4])!, ty = Int(a[5])!, tw = Int(a[6])!, th = Int(a[7])!
for name in a.dropFirst(8) {
    let (p, _, _) = gray(dir.appendingPathComponent(name))
    var inTip = 0, out = 0, minX = w, minY = h, maxX = -1, maxY = -1
    for y in 24..<h { for x in 0..<w {
        let i = y * w + x
        if abs(Int(p[i]) - Int(base[i])) > thr {
            if x >= tx && x < tx + tw && y >= ty && y < ty + th { inTip += 1 } else {
                out += 1; minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
    } }
    let bbox = out > 0 ? "[\(minX),\(minY),\(maxX),\(maxY)]" : "null"
    print("{\"image\":\"\(name)\",\"tooltipChanged\":\(inTip),\"outsideChanged\":\(out),\"outsideBBox\":\(bbox)}")
}
