import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

@MainActor
struct ResourceRateGraphRenderingTests {
    private let now = ContinuousClock().now
    private let width: CGFloat = 248

    private func history() -> [RateHistoryPoint] {
        [
            (-560, 300.0, 800.0, UInt64(1)),
            (-555, 1_800.0, 400.0, UInt64(1)),
            (-550, 400.0, 1_400.0, UInt64(1)),
            (-130, 600.0, 1_000.0, UInt64(2)),
            (-125, 1_500.0, 200.0, UInt64(2)),
            (-120, 100.0, 1_700.0, UInt64(2))
        ].map { offset, received, sent, segment in
            RateHistoryPoint(timestamp: now.advanced(by: .seconds(offset)),
                rate: RatePair(receivedBytesPerSecond: received, sentBytesPerSecond: sent)!,
                collectionEpoch: 0, rateSegment: segment)
        }
    }

    private func extendedHistory() -> [RateHistoryPoint] {
        let left = (0...40).map { index -> RateHistoryPoint in
            let peak = index == 20 ? 4_000.0 : 250 + Double(index % 8) * 140
            return RateHistoryPoint(timestamp: now.advanced(by: .seconds(-590 + index * 5)),
                rate: RatePair(receivedBytesPerSecond: peak, sentBytesPerSecond: 500)!,
                collectionEpoch: 0, rateSegment: 1)
        }
        let right = (0...40).map { index -> RateHistoryPoint in
            let write = index == 30 ? 3_000.0 : 500 + Double(index % 10) * 80
            return RateHistoryPoint(timestamp: now.advanced(by: .seconds(-210 + index * 5)),
                rate: RatePair(receivedBytesPerSecond: index < 15 ? 0 : 700,
                    sentBytesPerSecond: write)!,
                collectionEpoch: 0, rateSegment: 2)
        }
        return left + right
    }

    private func render(_ kind: ResourceRateGraphSlotView.Kind, placeholder: Bool,
                        appearance name: NSAppearance.Name) throws -> NSBitmapImageRep {
        let appearance = try #require(NSAppearance(named: name))
        let view = ResourceRateGraphSlotView(kind: kind,
            history: placeholder ? [] : history(),
            firstHistoryPointAt: placeholder ? nil : now.advanced(by: .seconds(-560)),
            fixedNow: now)
            .frame(width: width, height: HistoryGraphLayout.slotHeight)
            .background(DashboardColorPalette.cardSurface)
            .environment(\.colorScheme, name == .darkAqua ? .dark : .light)
        var rendered: NSBitmapImageRep?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            rendered = renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        }
        let bitmap = try #require(rendered)
        let mode = name == .darkAqua ? "dark" : "light"
        let resource = kind == .network ? "network" : "disk"
        let state = placeholder ? "placeholder" : "normal"
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        Attachment.record(png, named: "\(resource)-\(state)-\(mode).png")
        return try #require(NSBitmapImageRep(data: png))
    }

    private func renderHeader(_ kind: ResourceRateGraphSlotView.Kind, placeholder: Bool,
                              appearance name: NSAppearance.Name) throws {
        let graph = ResourceRateGraph.make(history: placeholder ? [] : history(),
            firstHistoryPointAt: placeholder ? nil : now.advanced(by: .seconds(-560)),
            currentTimestamp: now)
        let view = ResourceRateGraphHeaderView(kind: kind, rangeLabel: graph.rangeLabel)
            .frame(width: width, height: 14)
            .background(DashboardColorPalette.cardSurface)
            .environment(\.colorScheme, name == .darkAqua ? .dark : .light)
        let appearance = try #require(NSAppearance(named: name))
        var rendered: NSBitmapImageRep?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            rendered = renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        }
        let bitmap = try #require(rendered)
        #expect(bitmap.pixelsWide == Int(width))
        #expect(bitmap.pixelsHigh == 14)
        let mode = name == .darkAqua ? "dark" : "light"
        let resource = kind == .network ? "network" : "disk"
        let state = placeholder ? "placeholder" : "normal"
        Attachment.record(try #require(bitmap.representation(using: .png, properties: [:])),
            named: "\(resource)-header-\(state)-\(mode).png")
    }

    private func renderExtended(_ kind: ResourceRateGraphSlotView.Kind,
                                appearance name: NSAppearance.Name) throws -> NSBitmapImageRep {
        let appearance = try #require(NSAppearance(named: name))
        let view = ResourceRateGraphSlotView(kind: kind, history: extendedHistory(),
            firstHistoryPointAt: now.advanced(by: .seconds(-590)), fixedNow: now)
            .frame(width: width, height: HistoryGraphLayout.slotHeight)
            .background(DashboardColorPalette.cardSurface)
            .environment(\.colorScheme, name == .darkAqua ? .dark : .light)
        var rendered: NSBitmapImageRep?
        appearance.performAsCurrentDrawingAppearance {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            rendered = renderer.nsImage?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        }
        let bitmap = try #require(rendered)
        let mode = name == .darkAqua ? "dark" : "light"
        let resource = kind == .network ? "network" : "disk"
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        Attachment.record(png, named: "\(resource)-extended-\(mode).png")
        return try #require(NSBitmapImageRep(data: png))
    }

    private func color(_ bitmap: NSBitmapImageRep, x: Int, y: Int) throws -> NSColor {
        try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
    }

    private func resolved(_ color: Color, appearance name: NSAppearance.Name) throws -> NSColor {
        let appearance = try #require(NSAppearance(named: name))
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB)
        }
        return try #require(resolved)
    }

    private func distance(_ a: NSColor, _ b: NSColor) -> CGFloat {
        abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent)
            + abs(a.blueComponent - b.blueComponent)
    }

    @Test func lightAndDarkNormalAndPlaceholderShareFrameSurfaceAndRealGap() throws {
        for appearance: NSAppearance.Name in [.aqua, .darkAqua] {
            let surface = try resolved(DashboardColorPalette.graphPlotSurface, appearance: appearance)
            let card = try resolved(DashboardColorPalette.cardSurface, appearance: appearance)
            #expect(distance(surface, card) > 0.05)
            for kind: ResourceRateGraphSlotView.Kind in [.network, .disk] {
                let normal = try render(kind, placeholder: false, appearance: appearance)
                let empty = try render(kind, placeholder: true, appearance: appearance)
                try renderHeader(kind, placeholder: false, appearance: appearance)
                try renderHeader(kind, placeholder: true, appearance: appearance)
                #expect(normal.pixelsWide == Int(width))
                #expect(empty.pixelsWide == Int(width))
                #expect(normal.pixelsHigh == Int(HistoryGraphLayout.slotHeight))
                #expect(empty.pixelsHigh == normal.pixelsHigh)
                // 두 연속 구간 사이에는 그려진 선·음영이 없이 동일한 판 면이 남습니다.
                let bare = try color(normal, x: 125, y: 75)
                let placeholderBare = try color(empty, x: 125, y: 75)
                #expect(distance(bare, placeholderBare) < 0.03)
                let outside = try color(empty, x: 125, y: 116)
                #expect(distance(outside, placeholderBare) > 0.04)
                // 판 경계에 윤곽선·세로 눈금을 추가하지 않습니다.
                #expect(distance(try color(empty, x: 0, y: 75), placeholderBare) < 0.03)
                #expect(distance(try color(empty, x: 247, y: 75), placeholderBare) < 0.03)
                let gridline = try color(empty, x: 125, y: 50)
                #expect(distance(gridline, placeholderBare) > 0.005)
            }
        }
    }

    @Test func renderStylesAndPaletteRolesMatchTheLegendAndGraph() throws {
        #expect(ResourceRateGraphSlotView.Series.received.style.dash == [4, 3])
        #expect(ResourceRateGraphSlotView.Series.sent.style.dash.isEmpty)
        #expect(ResourceRateGraphSlotView.Series.received.style.lineWidth ==
            ResourceRateGraphSlotView.Series.sent.style.lineWidth)
        for appearance: NSAppearance.Name in [.aqua, .darkAqua] {
            #expect(distance(try resolved(DashboardColorPalette.networkReceived, appearance: appearance),
                try resolved(DashboardColorPalette.cpu(.step3), appearance: appearance)) < 0.001)
            #expect(distance(try resolved(DashboardColorPalette.networkSent, appearance: appearance),
                try resolved(DashboardColorPalette.cpu(.step1), appearance: appearance)) < 0.001)
            #expect(distance(try resolved(DashboardColorPalette.diskRead, appearance: appearance),
                try resolved(DashboardColorPalette.memoryComposition(.compressed), appearance: appearance)) < 0.001)
            #expect(distance(try resolved(DashboardColorPalette.diskWritten, appearance: appearance),
                try resolved(DashboardColorPalette.memoryComposition(.cached), appearance: appearance)) < 0.001)
        }
        #expect(HistoryGraphLayout.plotHeight == 100)
        #expect(HistoryGraphLayout.slotHeight == 118)
        #expect(HistoryGraphGridline.lineWidth == 1)
    }

    @Test func wideConnectedRunsExposeDashSolidZeroAndBothPeaksWithoutPaintingGap() throws {
        let graph = ResourceRateGraph.make(history: extendedHistory(),
            firstHistoryPointAt: now.advanced(by: .seconds(-590)), currentTimestamp: now)
        #expect(graph.visibleSegments.map(\.count) == [41, 41])
        #expect(graph.upperBound == 5_000)
        for appearance: NSAppearance.Name in [.aqua, .darkAqua] {
            for kind: ResourceRateGraphSlotView.Kind in [.network, .disk] {
                let bitmap = try renderExtended(kind, appearance: appearance)
                #expect(bitmap.pixelsWide == Int(width))
                #expect(bitmap.pixelsHigh == Int(HistoryGraphLayout.slotHeight))
                let bare = try color(bitmap, x: 125, y: 75)
                #expect(distance(try color(bitmap, x: 120, y: 75), bare) < 0.03)
                #expect(distance(try color(bitmap, x: 130, y: 75), bare) < 0.03)
                // 왼쪽 실선과 오른쪽 0선의 실제 픽셀이 판 면과 다릅니다.
                #expect(distance(try color(bitmap, x: 45, y: 90), bare) > 0.02)
                let zeroInk = try (165..<195).filter {
                    distance(try color(bitmap, x: $0, y: 99), bare) > 0.02
                }.count
                #expect(zeroInk > 0)
            }
        }
    }
}
