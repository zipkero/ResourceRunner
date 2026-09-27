//
//  DashboardColorPaletteTests.swift
//  ResourceRunnerTests
//

import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

private struct PaletteLabColor {
    let lightness: Double
    /// CIELAB 채도. 가라앉은 톤과 떠오르는 톤을 밝기가 아니라 이 값으로 가릅니다.
    let chroma: Double
}

private func resolvedSRGB(_ color: Color, appearanceName: NSAppearance.Name) throws -> NSColor {
    let appearance = try #require(NSAppearance(named: appearanceName))
    var resolved: NSColor?
    appearance.performAsCurrentDrawingAppearance {
        resolved = NSColor(color).usingColorSpace(.sRGB)
    }
    return try #require(resolved)
}

private func linearized(_ component: CGFloat) -> Double {
    let value = Double(component)
    return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
}

private func relativeLuminance(_ color: NSColor) -> Double {
    0.2126 * linearized(color.redComponent)
        + 0.7152 * linearized(color.greenComponent)
        + 0.0722 * linearized(color.blueComponent)
}

private func contrastRatio(_ first: NSColor, _ second: NSColor) -> Double {
    let luminances = [relativeLuminance(first), relativeLuminance(second)].sorted()
    return (luminances[1] + 0.05) / (luminances[0] + 0.05)
}

private func hueDistance(_ first: NSColor, _ second: NSColor) -> CGFloat {
    let distance = abs(first.hueComponent - second.hueComponent)
    return min(distance, 1 - distance)
}

private func labColor(_ color: NSColor) -> PaletteLabColor {
    func xyzComponent(_ value: Double) -> Double {
        value > 216.0 / 24389.0 ? pow(value, 1.0 / 3.0) : (24389.0 / 27.0 * value + 16) / 116
    }

    let red = linearized(color.redComponent)
    let green = linearized(color.greenComponent)
    let blue = linearized(color.blueComponent)
    let x = (0.4124564 * red + 0.3575761 * green + 0.1804375 * blue) / 0.9504559
    let y = (0.2126729 * red + 0.7151522 * green + 0.0721750 * blue) / 1.0
    let z = (0.0193339 * red + 0.1191920 * green + 0.9503041 * blue) / 1.0890578
    let aStar = 500 * (xyzComponent(x) - xyzComponent(y))
    let bStar = 200 * (xyzComponent(y) - xyzComponent(z))
    return PaletteLabColor(
        lightness: 116 * xyzComponent(y) - 16,
        chroma: (aStar * aStar + bStar * bStar).squareRoot()
    )
}

private func composited(_ foreground: NSColor, opacity: Double, over background: NSColor) -> NSColor {
    NSColor(
        srgbRed: foreground.redComponent * opacity + background.redComponent * (1 - opacity),
        green: foreground.greenComponent * opacity + background.greenComponent * (1 - opacity),
        blue: foreground.blueComponent * opacity + background.blueComponent * (1 - opacity),
        alpha: 1
    )
}

@Suite("대시보드 리소스 색 램프")
@MainActor
struct DashboardColorPaletteTests {
    private let appearanceNames: [NSAppearance.Name] = [.aqua, .darkAqua]

    /// 대비를 재는 기준면은 근사값이 아니라 그 색이 실제로 놓이는 면(카드 면)입니다.
    /// production 팔레트에서 직접 풀어 쓰므로 면 값이 바뀌면 아래 대비 단언이 모두 그 자리에서 함께 움직입니다.
    private func cardSurface(_ appearanceName: NSAppearance.Name) throws -> NSColor {
        try resolvedSRGB(DashboardColorPalette.cardSurface, appearanceName: appearanceName)
    }

    /// 그래프 판 위 요소(두 밴드·기준선)가 실제로 놓이는 기준면입니다.
    /// 요약 줄 스와치는 카드 면 위에 남으므로 두 밴드 색은 카드 면과 판 면 두 기준면을 모두 지킵니다.
    private func plotSurface(_ appearanceName: NSAppearance.Name) throws -> NSColor {
        try resolvedSRGB(DashboardColorPalette.graphPlotSurface, appearanceName: appearanceName)
    }

    /// 기준선은 반투명 색이라, 테스트 안 리터럴이 아니라 appearance별로 푼 값의 알파를 그대로 아래 면(판 면 또는 채움 합성색)에 합성합니다.
    private func gridlineComposite(over surface: NSColor, appearanceName: NSAppearance.Name) throws -> NSColor {
        let gridline = try resolvedSRGB(DashboardColorPalette.graphPlotGridline, appearanceName: appearanceName)
        return composited(gridline, opacity: Double(gridline.alphaComponent), over: surface)
    }

    /// 두 밴드 채움을 판 면에 합성한 색입니다. 채움 색과 불투명도를 production에서 가져와 값이 바뀌면 함께 움직입니다.
    private func bandFillComposite(_ band: HistoryGraphView.BandRole, over surface: NSColor, appearanceName: NSAppearance.Name) throws -> NSColor {
        let color = band == .lower ? DashboardColorPalette.cpuUser : DashboardColorPalette.cpuSystem
        return composited(
            try resolvedSRGB(color, appearanceName: appearanceName),
            opacity: HistoryGraphView.fillOpacity(for: band),
            over: surface
        )
    }

    @Test func popoverBackgroundAndCardSurfaceLiftTheCardInBothAppearances() throws {
        for appearanceName in appearanceNames {
            let background = try resolvedSRGB(DashboardColorPalette.popoverBackground, appearanceName: appearanceName)
            let surface = try cardSurface(appearanceName)

            #expect(background != surface, "\(appearanceName.rawValue) 팝오버 바탕과 카드 면이 같은 색입니다")
            #expect(
                labColor(surface).lightness > labColor(background).lightness,
                "\(appearanceName.rawValue) 카드 면 L* \(labColor(surface).lightness)가 바탕 \(labColor(background).lightness)보다 밝지 않습니다"
            )
        }
    }

    @Test func allSixteenColorsMeetContrastAndKeepTheSameStepMeaning() throws {
        for appearanceName in appearanceNames {
            let background = try cardSurface(appearanceName)

            let colors = try DashboardColorPalette.RampStep.allCases.map {
                try resolvedSRGB(DashboardColorPalette.cpu($0), appearanceName: appearanceName)
            }
            let contrasts = colors.map { contrastRatio($0, background) }
            let lightnesses = colors.map { labColor($0).lightness }

            #expect(contrasts.allSatisfy { $0 >= 3 })
            #expect(zip(contrasts, contrasts.dropFirst()).allSatisfy { $0.0 > $0.1 })
            #expect(colors.dropFirst().allSatisfy { hueDistance(colors[0], $0) < 0.04 })
            if appearanceName == .aqua {
                #expect(zip(lightnesses, lightnesses.dropFirst()).allSatisfy { $0.0 < $0.1 })
            } else {
                #expect(zip(lightnesses, lightnesses.dropFirst()).allSatisfy { $0.0 > $0.1 })
            }
        }
    }

    @Test func memoryCategoriesSplitIntoTwoHuesWithTheDarkerCategoryFirst() throws {
        #expect(MemoryCompositionCategory.allCases == [.app, .wired, .compressed, .cached])
        for appearanceName in appearanceNames {
            let colors = try memoryCategoryColors(appearanceName: appearanceName)
            let lightnesses = colors.map { labColor($0).lightness }

            #expect(hueDistance(colors[0], colors[1]) < 0.04)
            #expect(hueDistance(colors[2], colors[3]) < 0.04)
            #expect(hueDistance(colors[0], colors[2]) > 0.1)
            #expect(lightnesses[0] < lightnesses[1])
            #expect(lightnesses[2] < lightnesses[3])
        }
    }

    @Test func memoryCategoryColorsMeetBackgroundContrastInBothAppearances() throws {
        for appearanceName in appearanceNames {
            let background = try cardSurface(appearanceName)
            let contrasts = try memoryCategoryColors(appearanceName: appearanceName)
                .map { contrastRatio($0, background) }

            #expect(contrasts.allSatisfy { $0 >= 3 }, "\(appearanceName.rawValue) 대비가 \(contrasts)입니다")
        }
    }

    @Test func adjacentMemoryCategoriesDifferInLightness() throws {
        for appearanceName in appearanceNames {
            let lightnesses = try memoryCategoryColors(appearanceName: appearanceName)
                .map { labColor($0).lightness }

            #expect(
                zip(lightnesses, lightnesses.dropFirst()).allSatisfy { abs($0.0 - $0.1) > 1 },
                "\(appearanceName.rawValue) L*가 \(lightnesses)입니다"
            )
        }
    }

    @Test func cpuBandsUseTheCPUResourceRamp() throws {
        for appearanceName in appearanceNames {
            let user = try resolvedSRGB(DashboardColorPalette.cpuUser, appearanceName: appearanceName)
            let system = try resolvedSRGB(DashboardColorPalette.cpuSystem, appearanceName: appearanceName)
            let step3 = try resolvedSRGB(DashboardColorPalette.cpu(.step3), appearanceName: appearanceName)
            let step1 = try resolvedSRGB(DashboardColorPalette.cpu(.step1), appearanceName: appearanceName)

            #expect(user == step3)
            #expect(system == step1)
        }
    }

    @Test func coreFillColorsMeetCardSurfaceContrastInBothAppearances() throws {
        for appearanceName in appearanceNames {
            let surface = try cardSurface(appearanceName)
            let contrasts = try coreFillColors(appearanceName: appearanceName)
                .map { contrastRatio($0, surface) }

            #expect(contrasts.allSatisfy { $0 >= 3 }, "\(appearanceName.rawValue) 대비가 \(contrasts)입니다")
        }
    }

    @Test func busyCoreFillSplitsFromTheOtherTwoInHue() throws {
        for appearanceName in appearanceNames {
            let colors = try coreFillColors(appearanceName: appearanceName)

            #expect(hueDistance(colors[0], colors[1]) < 0.04)
            #expect(hueDistance(colors[0], colors[2]) > 0.1)
            #expect(hueDistance(colors[1], colors[2]) > 0.1)
        }
    }

    @Test func quietAndElevatedCoreFillsAreLessSaturatedThanBusy() throws {
        for appearanceName in appearanceNames {
            let chromas = try coreFillColors(appearanceName: appearanceName)
                .map { labColor($0).chroma }

            #expect(
                chromas[0] < chromas[2] && chromas[1] < chromas[2],
                "\(appearanceName.rawValue) C*가 \(chromas)입니다"
            )
        }
    }

    /// 코어 채움 세 값을 `quiet` · `elevated` · `busy` 순으로 돌려줍니다.
    /// 단계 넷 중 `.step3`·`.step4`가 같은 값이므로 단계가 아니라 색 셋으로 셉니다.
    private func coreFillColors(appearanceName: NSAppearance.Name) throws -> [NSColor] {
        try [DashboardColorPalette.RampStep.step4, .step2, .step1].map {
            try resolvedSRGB(DashboardColorPalette.cpuCoreFill($0), appearanceName: appearanceName)
        }
    }

    @Test func graphPlotSurfaceSitsBetweenPopoverBackgroundAndCardSurfaceInBothAppearances() throws {
        for appearanceName in appearanceNames {
            let background = try resolvedSRGB(DashboardColorPalette.popoverBackground, appearanceName: appearanceName)
            let plot = try plotSurface(appearanceName)
            let card = try cardSurface(appearanceName)
            let backgroundLightness = labColor(background).lightness
            let plotLightness = labColor(plot).lightness
            let cardLightness = labColor(card).lightness

            #expect(plot != card, "\(appearanceName.rawValue) 판 면과 카드 면이 같은 색입니다")
            #expect(
                backgroundLightness < plotLightness && plotLightness < cardLightness,
                "\(appearanceName.rawValue) L*가 바탕 \(backgroundLightness) · 판 면 \(plotLightness) · 카드 \(cardLightness)입니다"
            )
            #expect(
                cardLightness - plotLightness < cardLightness - backgroundLightness,
                "\(appearanceName.rawValue) 판–카드 ΔL* \(cardLightness - plotLightness)가 바탕–카드 ΔL* \(cardLightness - backgroundLightness)보다 작지 않습니다"
            )
        }
    }

    @Test func graphPlotSurfaceIsAchromaticInBothAppearances() throws {
        for appearanceName in appearanceNames {
            let plot = try plotSurface(appearanceName)

            #expect(
                plot.redComponent == plot.greenComponent && plot.greenComponent == plot.blueComponent,
                "\(appearanceName.rawValue) 판 면 성분이 R \(plot.redComponent) · G \(plot.greenComponent) · B \(plot.blueComponent)입니다"
            )
        }
    }

    @Test func cpuBandColorsMeetGraphPlotSurfaceContrastInBothAppearances() throws {
        for appearanceName in appearanceNames {
            let plot = try plotSurface(appearanceName)
            let contrasts = try [DashboardColorPalette.cpuUser, DashboardColorPalette.cpuSystem].map {
                contrastRatio(try resolvedSRGB($0, appearanceName: appearanceName), plot)
            }

            #expect(contrasts.allSatisfy { $0 >= 3 }, "\(appearanceName.rawValue) 판 면 대비가 \(contrasts)입니다")
        }
    }

    /// 기준선은 판 면 위에서 판 면보다 한 단 어두운 눈금이라, 식별 한계는 넘지만 판 가장자리 단차보다 약합니다.
    @Test func graphPlotGridlineIsDarkerThanPlotSurfaceAndWeakerThanPlotEdge() throws {
        for appearanceName in appearanceNames {
            let card = try cardSurface(appearanceName)
            let plot = try plotSurface(appearanceName)
            let plotLightness = labColor(plot).lightness
            let onPlotLightness = labColor(try gridlineComposite(over: plot, appearanceName: appearanceName)).lightness
            let gridlineDifference = plotLightness - onPlotLightness
            let edgeDifference = labColor(card).lightness - plotLightness

            #expect(
                onPlotLightness < plotLightness,
                "\(appearanceName.rawValue) 판 면 위 기준선 L* \(onPlotLightness)가 판 면 \(plotLightness)보다 낮지 않습니다"
            )
            #expect(
                2.3 < gridlineDifference && gridlineDifference < edgeDifference,
                "\(appearanceName.rawValue) 판 면 위 기준선 ΔL* \(gridlineDifference)가 2.3과 판–카드 ΔL* \(edgeDifference) 사이가 아닙니다"
            )
        }
    }

    /// 부하가 50%를 넘어 채움이 기준선 자리를 덮어도, 채움 위에 그린 기준선이 판 면 위만큼 가깝게 보이고
    /// 채움 아래에 깔았을 때보다 잘 보이며, 그 자리 밴드 채움보다는 약합니다.
    @Test func graphPlotGridlineStaysVisibleInsideBothBandFillsAndWeakerThanTheFill() throws {
        for appearanceName in appearanceNames {
            let plot = try plotSurface(appearanceName)
            let plotLightness = labColor(plot).lightness
            let onPlotDifference = plotLightness
                - labColor(try gridlineComposite(over: plot, appearanceName: appearanceName)).lightness
            let gridlineBelowFills = try gridlineComposite(over: plot, appearanceName: appearanceName)

            for band in [HistoryGraphView.BandRole.lower, .upper] {
                let fill = try bandFillComposite(band, over: plot, appearanceName: appearanceName)
                let fillLightness = labColor(fill).lightness
                let overFillDifference = abs(
                    labColor(try gridlineComposite(over: fill, appearanceName: appearanceName)).lightness - fillLightness
                )
                let underFillDifference = abs(
                    labColor(try bandFillComposite(band, over: gridlineBelowFills, appearanceName: appearanceName)).lightness
                        - fillLightness
                )
                let fillDifference = abs(fillLightness - plotLightness)

                #expect(
                    overFillDifference >= onPlotDifference * 2 / 3,
                    "\(appearanceName.rawValue) \(band) 채움 위 기준선 ΔL* \(overFillDifference)가 판 면 위 \(onPlotDifference)의 3분의 2보다 작습니다"
                )
                #expect(
                    overFillDifference > underFillDifference,
                    "\(appearanceName.rawValue) \(band) 채움 위 기준선 ΔL* \(overFillDifference)가 채움 아래 \(underFillDifference)보다 크지 않습니다"
                )
                #expect(
                    overFillDifference < fillDifference,
                    "\(appearanceName.rawValue) \(band) 채움 위 기준선 ΔL* \(overFillDifference)가 채움의 판 면 대비 ΔL* \(fillDifference)보다 작지 않습니다"
                )
            }
        }
    }

    @Test func graphPlotGridlineIsAchromaticInBothAppearances() throws {
        for appearanceName in appearanceNames {
            let gridline = try resolvedSRGB(DashboardColorPalette.graphPlotGridline, appearanceName: appearanceName)

            #expect(
                gridline.redComponent == gridline.greenComponent && gridline.greenComponent == gridline.blueComponent,
                "\(appearanceName.rawValue) 기준선 성분이 R \(gridline.redComponent) · G \(gridline.greenComponent) · B \(gridline.blueComponent)입니다"
            )
        }
    }

    /// 판 면 위 요소의 세기가 `밴드 > 판 가장자리 > 기준선` 순서라, 판 면이 데이터보다 먼저 눈에 들어오지 않고
    /// 기준선은 판을 가르는 경계가 아니라 판 안의 눈금으로 남습니다.
    @Test func gridlineIsWeakerThanGraphPlotEdgeWhichIsWeakerThanUpperBandFill() throws {
        for appearanceName in appearanceNames {
            let card = try cardSurface(appearanceName)
            let plot = try plotSurface(appearanceName)
            let system = try resolvedSRGB(DashboardColorPalette.cpuSystem, appearanceName: appearanceName)
            let plotLightness = labColor(plot).lightness
            let edgeDifference = abs(labColor(card).lightness - plotLightness)
            let gridlineDifference = abs(
                labColor(try gridlineComposite(over: plot, appearanceName: appearanceName)).lightness - plotLightness
            )
            let upperFill = composited(system, opacity: HistoryGraphView.fillOpacity(for: .upper), over: plot)
            let upperFillDifference = abs(labColor(upperFill).lightness - plotLightness)

            #expect(
                gridlineDifference < edgeDifference,
                "\(appearanceName.rawValue) 판 면 위 기준선 ΔL* \(gridlineDifference)가 판 가장자리 ΔL* \(edgeDifference)보다 작지 않습니다"
            )
            #expect(
                edgeDifference < upperFillDifference,
                "\(appearanceName.rawValue) 판 가장자리 ΔL* \(edgeDifference)가 위 밴드 채움 ΔL* \(upperFillDifference)보다 작지 않습니다"
            )
        }
    }

    /// 두 밴드가 실제로 놓이는 면은 판 면이므로 합성 기준면도 판 면입니다.
    @Test func cpuBandCompositeLightnessDifferenceImprovesInBothAppearances() throws {
        for appearanceName in appearanceNames {
            let background = try plotSurface(appearanceName)
            let user = try resolvedSRGB(DashboardColorPalette.cpuUser, appearanceName: appearanceName)
            let system = try resolvedSRGB(DashboardColorPalette.cpuSystem, appearanceName: appearanceName)
            let userComposite = composited(user, opacity: HistoryGraphView.fillOpacity(for: .lower), over: background)
            let systemComposite = composited(system, opacity: HistoryGraphView.fillOpacity(for: .upper), over: background)
            let difference = abs(labColor(userComposite).lightness - labColor(systemComposite).lightness)

            #expect(difference > 10.5, "\(appearanceName.rawValue) 합성 후 ΔL*가 \(difference)입니다")
        }
        #expect(
            abs(
                HistoryGraphView.fillOpacity(for: .lower)
                    - HistoryGraphView.fillOpacity(for: .upper)
                    - 0.45
            ) < 0.000_001
        )
    }

    private func memoryCategoryColors(appearanceName: NSAppearance.Name) throws -> [NSColor] {
        try MemoryCompositionCategory.allCases.map {
            try resolvedSRGB(DashboardColorPalette.memoryComposition($0), appearanceName: appearanceName)
        }
    }
}
