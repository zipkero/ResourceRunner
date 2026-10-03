import AppKit
import SwiftUI

// 실제 수집과 분리된 배치 샘플입니다. 수치는 시각 비교용 고정값입니다.
struct PreviewPalette {
    let dark: Bool
    func color(_ light: UInt32, _ darkValue: UInt32) -> Color {
        let value = dark ? darkValue : light
        return Color(red: Double((value >> 16) & 255) / 255,
                     green: Double((value >> 8) & 255) / 255,
                     blue: Double(value & 255) / 255)
    }
    var background: Color { color(0xececec, 0x1e1e1e) }
    var card: Color { color(0xffffff, 0x2e2e2e) }
    var plot: Color { color(0xf5f5f5, 0x262626) }
    var primary: Color { color(0x202020, 0xf0f0f0) }
    var secondary: Color { color(0x696969, 0xb3b3b3) }
    var blue: Color { color(0x256cbb, 0x6399ed) }
    var blueLight: Color { color(0x003a6c, 0xcbdaff) }
    var orange: Color { color(0x83441d, 0xc07345) }
    var orangeLight: Color { color(0xba6e41, 0xecae8c) }
}

struct MiniGraph: View {
    let palette: PreviewPalette
    var disk = false
    private func points(width: CGFloat, height: CGFloat, offset: Double) -> [CGPoint] {
        (0...68).map { index in
            let x = Double(index) / 68
            let base = disk ? 0.15 : 0.24
            let pulse = exp(-pow((x - 0.66) / 0.07, 2)) * (disk ? 0.58 : 0.34)
            let wave = sin(x * 39 + offset) * 0.05 + sin(x * 87 + offset) * 0.025
            return CGPoint(x: x * width, y: height * (1 - base - pulse - wave - offset * 0.025))
        }
    }
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.plot))
            var grid = Path()
            grid.move(to: CGPoint(x: 0, y: size.height / 2))
            grid.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(grid, with: .color(.black.opacity(palette.dark ? 0.18 : 0.038)), lineWidth: 1)
            for series in 0...1 {
                let values = points(width: size.width, height: size.height, offset: Double(series) * 2)
                var line = Path()
                line.addLines(values)
                let color = disk ? (series == 0 ? palette.orange : palette.orangeLight)
                                 : (series == 0 ? palette.blue : palette.blueLight)
                if !disk {
                    var area = line
                    area.addLine(to: CGPoint(x: size.width, y: size.height))
                    area.addLine(to: CGPoint(x: 0, y: size.height))
                    area.closeSubpath()
                    context.fill(area, with: .color(color.opacity(series == 0 ? 0.34 : 0.16)))
                }
                context.stroke(line, with: .color(color),
                    style: StrokeStyle(lineWidth: disk ? 1 : 0.9, dash: series == 0 ? [3, 2] : []))
            }
        }
        .clipped()
    }
}

struct CompactPreview: View {
    let p: PreviewPalette
    let appNames = ["Xcode", "Safari", "ResourceRunner", "Terminal", "Finder"]
    let cpuValues = ["18.6%", "9.4%", "1.8%", "0.8%", "0.4%"]
    let memoryValues = ["4.2 GB", "2.6 GB", "182.0 MB", "94.1 MB", "72.4 MB"]

    func text(_ string: String, size: CGFloat = 10, strong: Bool = false,
              secondary: Bool = false) -> some View {
        Text(string).font(.system(size: size, weight: strong ? .semibold : .regular))
            .foregroundStyle(secondary ? p.secondary : p.primary)
            .lineLimit(1)
    }
    func heading(_ name: String, key: String) -> some View {
        HStack {
            text(name, size: 10 * 2 / 3, strong: true, secondary: true)
            Spacer()
            text(key, size: 10 * 2 / 3, secondary: true)
        }.frame(height: 8)
    }
    func card<Content: View>(_ height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content().padding(6).frame(width: 264, height: height, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 8).fill(p.card))
    }
    func icon(_ index: Int) -> some View {
        let symbols = ["hammer.fill", "safari.fill", "cat.fill", "terminal.fill", "folder.fill"]
        return Image(systemName: symbols[index])
            .font(.system(size: 8)).foregroundStyle(index == 0 ? p.blue : p.secondary)
            .frame(width: 10, height: 10)
    }
    func ranking(_ values: [String]) -> some View {
        VStack(spacing: 1) {
            HStack { text("TOP 5", size: 7, strong: true, secondary: true); Spacer() }
                .frame(height: 8)
                .padding(.bottom, 3)
            ForEach(0..<5) { index in
                HStack(spacing: 4) {
                    icon(index)
                    text(appNames[index], size: 9)
                    Spacer(minLength: 2)
                    text(values[index], size: 9).monospacedDigit()
                }.frame(height: 10)
            }
        }
    }
    var cpu: some View {
        card(211) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    heading("CPU", key: "⌘1")
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        text("34.2", size: 26 * 2 / 3, strong: true).monospacedDigit()
                        text("%", size: 10, secondary: true)
                        Spacer()
                    }.frame(height: 21)
                    HStack(spacing: 5) {
                        Circle().fill(p.blue).frame(width: 5, height: 5)
                        text("User 27%", size: 9, secondary: true)
                        Circle().fill(p.blueLight).frame(width: 5, height: 5)
                        text("System 7%", size: 9, secondary: true)
                    }.frame(height: 11)
                }
                VStack(spacing: 2) {
                    MiniGraph(palette: p).frame(height: 100 * 2 / 3)
                    HStack {
                        text("10분 전", size: 7, secondary: true)
                        Spacer()
                        text("지금", size: 7, secondary: true)
                    }.frame(height: 9)
                }
                ranking(cpuValues)
            }
        }
    }
    var memory: some View {
        card(143) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(spacing: 2) {
                    heading("Memory", key: "⌘2")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        text("22.4", size: 26 * 2 / 3, strong: true).monospacedDigit()
                        text("GB / 36 GB", size: 10)
                        Spacer(minLength: 4)
                        HStack(spacing: 0) {
                            Rectangle().fill(p.blue).frame(width: 24)
                            Rectangle().fill(p.blueLight).frame(width: 13)
                            Rectangle().fill(p.orange).frame(width: 11)
                            Rectangle().fill(p.orangeLight).frame(width: 18)
                        }.frame(height: 8).clipShape(RoundedRectangle(cornerRadius: 2))
                    }.frame(height: 21)
                }
                VStack(alignment: .leading, spacing: 2) {
                    text("● Pressure 정상 · Swap 1.2 GB (+24 MB)", size: 9, secondary: true)
                    text("App  Wired  Compressed  Cached", size: 8, secondary: true)
                }
                ranking(memoryValues)
            }
        }
    }
    func networkRate(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            text(label, size: 10, secondary: true)
            Spacer()
            text(value, size: 26 * 2 / 3, strong: true).monospacedDigit()
            text("KB/s", size: 9, secondary: true)
        }.frame(height: 22)
    }
    var network: some View {
        card(101) {
            VStack(alignment: .leading, spacing: 4) {
                heading("Network · 물리 합계", key: "⌘3")
                VStack(spacing: 2) {
                    networkRate("다운로드", value: "326.4")
                    networkRate("업로드", value: "28.6")
                }
                VStack(alignment: .leading, spacing: 2) {
                    text("Wi-Fi · 활성 1개", size: 9, secondary: true)
                }
            }
        }
    }
    var disk: some View {
        card(101) {
            VStack(alignment: .leading, spacing: 4) {
                heading("Disk · 물리 합계", key: "⌘4")
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 3) {
                            text("Read", size: 9, secondary: true)
                            text("127.8", size: 12, strong: true).monospacedDigit()
                            text("KB/s", size: 7, secondary: true)
                        }
                        HStack(spacing: 3) {
                            text("Write", size: 9, secondary: true)
                            text("523.7", size: 12, strong: true).monospacedDigit()
                            text("KB/s", size: 7, secondary: true)
                        }
                    }.frame(width: 112, alignment: .leading)
                    MiniGraph(palette: p, disk: true).frame(height: 42)
                }.frame(height: 45)
                VStack(alignment: .leading, spacing: 2) {
                    text("전체 926.4·가용 775.7 GB", size: 9, secondary: true)
                }
            }
        }
    }
    var body: some View {
        VStack(spacing: 6) { cpu; memory; network; disk }
            .padding(8).frame(width: 280, height: 590, alignment: .top)
            .background(p.background)
            .environment(\.colorScheme, p.dark ? .dark : .light)
    }
}

@main
struct Export {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        for dark in [true, false] {
            let renderer = ImageRenderer(content: CompactPreview(p: PreviewPalette(dark: dark)))
            renderer.scale = 3
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let data = bitmap.representation(using: .png, properties: [:]) else {
                fatalError("샘플 렌더 실패")
            }
            let name = dark ? "compact-dark.png" : "compact-light.png"
            try data.write(to: URL(fileURLWithPath: "/tmp/ResourceRunner-compact-preview-20261003/" + name))
            print("\(name): \(bitmap.pixelsWide)×\(bitmap.pixelsHigh), 논리 크기 280×590pt")
        }
    }
}
