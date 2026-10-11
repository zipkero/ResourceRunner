// task-008 완전 표시 판독 보조: 고정 ROI JPEG에서 팝오버 내용의 크기·대비·최종 프레임과의 일치도를 낸다.
// 사용: content_match FRAMES_DIR BASELINE.jpg REFERENCE.jpg X Y W H
// - mask: 회색조 |frame − baseline| > 24 인 픽셀(고정 영역 안). bbox는 mask의 경계 상자.
// - scale: frame bbox 폭 / reference bbox 폭. hscale: 높이 비.
// - ncc: frame bbox를 reference bbox 크기로 bilinear 재표본한 뒤 reference bbox와의 zero-mean 정규 상관.
// - contrast: 재표본 crop 표준편차 / reference crop 표준편차(불투명도 대리값).
import CoreGraphics
import Foundation
import ImageIO

struct Gray { var p: [UInt8]; var w: Int; var h: Int
    subscript(x: Int, y: Int) -> Double { Double(p[y * w + x]) } }

func load(_ url: URL) -> Gray? {
    guard let s = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(s, 0, nil) else { return nil }
    var px = [UInt8](repeating: 0, count: img.width * img.height)
    let ok = px.withUnsafeMutableBytes { b -> Bool in
        guard let c = CGContext(data: b.baseAddress, width: img.width, height: img.height, bitsPerComponent: 8,
            bytesPerRow: img.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return false }
        c.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height)); return true }
    return ok ? Gray(p: px, w: img.width, h: img.height) : nil
}

let a = CommandLine.arguments
guard a.count == 8, let rx = Int(a[4]), let ry = Int(a[5]), let rw = Int(a[6]), let rh = Int(a[7]) else {
    fputs("usage: content_match DIR BASE REF X Y W H\n", stderr); exit(2) }
let dir = URL(fileURLWithPath: a[1], isDirectory: true)
guard let base = load(dir.appendingPathComponent(a[2])), let ref = load(dir.appendingPathComponent(a[3])) else { exit(3) }

func bbox(_ g: Gray) -> (x0: Int, y0: Int, x1: Int, y1: Int, n: Int)? {
    var x0 = Int.max, y0 = Int.max, x1 = -1, y1 = -1, n = 0
    // 행·열별 변화 픽셀 수가 2 이상인 곳만 경계로 쓴다(JPEG 단일 픽셀 잡음 제외).
    var colCount = [Int](repeating: 0, count: g.w), rowCount = [Int](repeating: 0, count: g.h)
    for y in ry..<(ry + rh) { for x in rx..<(rx + rw) where abs(g[x, y] - base[x, y]) > 24 {
        colCount[x] += 1; rowCount[y] += 1; n += 1 } }
    for x in rx..<(rx + rw) where colCount[x] >= 2 { x0 = min(x0, x); x1 = max(x1, x) }
    for y in ry..<(ry + rh) where rowCount[y] >= 2 { y0 = min(y0, y); y1 = max(y1, y) }
    return x1 < 0 || y1 < 0 ? nil : (x0, y0, x1, y1, n)
}
guard let rb = bbox(ref) else { fputs("reference has no popover\n", stderr); exit(4) }
let RW = rb.x1 - rb.x0 + 1, RH = rb.y1 - rb.y0 + 1
var refCrop = [Double](); refCrop.reserveCapacity(RW * RH)
for y in rb.y0...rb.y1 { for x in rb.x0...rb.x1 { refCrop.append(ref[x, y]) } }
func stats(_ v: [Double]) -> (m: Double, s: Double) {
    let m = v.reduce(0, +) / Double(v.count)
    return (m, (v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(v.count)).squareRoot()) }
let rs = stats(refCrop)

let names = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".jpg") }.sorted()
for name in names {
    guard let g = load(dir.appendingPathComponent(name)), g.w == base.w else { continue }
    var row: [String: Any] = ["image": name]
    if let b = bbox(g) {
        let bw = Double(b.x1 - b.x0 + 1), bh = Double(b.y1 - b.y0 + 1)
        var crop = [Double](); crop.reserveCapacity(RW * RH)
        for j in 0..<RH { for i in 0..<RW {
            let fx = Double(b.x0) + (Double(i) + 0.5) * bw / Double(RW) - 0.5
            let fy = Double(b.y0) + (Double(j) + 0.5) * bh / Double(RH) - 0.5
            let x0 = max(0, min(g.w - 1, Int(fx.rounded(.down)))), y0 = max(0, min(g.h - 1, Int(fy.rounded(.down))))
            let x1 = min(g.w - 1, x0 + 1), y1 = min(g.h - 1, y0 + 1)
            let tx = max(0, min(1, fx - Double(x0))), ty = max(0, min(1, fy - Double(y0)))
            let v = g[x0, y0] * (1 - tx) * (1 - ty) + g[x1, y0] * tx * (1 - ty) + g[x0, y1] * (1 - tx) * ty + g[x1, y1] * tx * ty
            crop.append(v) } }
        let cs = stats(crop)
        var cov = 0.0
        for k in 0..<crop.count { cov += (crop[k] - cs.m) * (refCrop[k] - rs.m) }
        cov /= Double(crop.count)
        row["bbox"] = [b.x0, b.y0, b.x1, b.y1]
        row["changed"] = b.n
        row["scale"] = bw / Double(RW)
        row["hscale"] = bh / Double(RH)
        row["ncc"] = cs.s > 0 && rs.s > 0 ? cov / (cs.s * rs.s) : 0
        row["contrast"] = rs.s > 0 ? cs.s / rs.s : 0
    }
    let d = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
    print(String(decoding: d, as: UTF8.self))
}
