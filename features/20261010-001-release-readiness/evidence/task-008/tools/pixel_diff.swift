// 프레임 probe JPEG를 회색조로 읽어 고정 영역의 기준(클릭 전)·참조(완전 표시 뒤) 대비 변화량을 낸다.
// 사용: pixel_diff FRAMES_DIR BASELINE.jpg REFERENCE.jpg X Y W H
import CoreGraphics
import Foundation
import ImageIO

func gray(_ url: URL) -> (pixels: [UInt8], width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height)
    let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return ok ? (pixels, width, height) : nil
}

let args = CommandLine.arguments
guard args.count == 8, let x = Int(args[4]), let y = Int(args[5]), let w = Int(args[6]), let h = Int(args[7]) else {
    fputs("usage: pixel_diff FRAMES_DIR BASELINE REFERENCE X Y W H\n", stderr); exit(2)
}
let dir = URL(fileURLWithPath: args[1], isDirectory: true)
guard let base = gray(dir.appendingPathComponent(args[2])),
      let ref = gray(dir.appendingPathComponent(args[3])) else { fputs("baseline/reference unreadable\n", stderr); exit(3) }
// CGContext 회색조 버퍼는 위쪽 행부터 저장되므로 y는 이미지 위쪽 기준이다.
func stats(_ a: [UInt8], _ b: [UInt8], width: Int) -> (mean: Double, frac: Double) {
    var sum = 0, changed = 0, n = 0
    for row in y..<(y + h) {
        for col in x..<(x + w) {
            let d = abs(Int(a[row * width + col]) - Int(b[row * width + col]))
            sum += d; n += 1
            if d > 24 { changed += 1 }
        }
    }
    return (Double(sum) / Double(n), Double(changed) / Double(n))
}
let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    .filter { $0.hasSuffix(".jpg") }.sorted()
for name in names {
    guard let image = gray(dir.appendingPathComponent(name)), image.width == base.width else { continue }
    let vb = stats(image.pixels, base.pixels, width: image.width)
    let vr = stats(image.pixels, ref.pixels, width: image.width)
    let row: [String: Any] = ["image": name, "baseMean": vb.mean, "baseFrac": vb.frac,
                              "refMean": vr.mean, "refFrac": vr.frac]
    let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}
