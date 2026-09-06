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
    let y = (0.2126729 * red + 0.7151522 * green + 0.0721750 * blue) / 1.0
    return PaletteLabColor(lightness: 116 * xyzComponent(y) - 16)
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
    private let appearances: [(name: NSAppearance.Name, backgroundHex: UInt32)] = [
        (.aqua, 0xececec),
        (.darkAqua, 0x2e2e2e),
    ]

    @Test func allSixteenColorsMeetContrastAndKeepTheSameStepMeaning() throws {
        for appearance in appearances {
            let background = NSColor(rgbHexForTest: appearance.backgroundHex)

            for ramp in [DashboardColorPalette.cpu, DashboardColorPalette.memory] {
                let colors = try DashboardColorPalette.RampStep.allCases.map {
                    try resolvedSRGB(ramp($0), appearanceName: appearance.name)
                }
                let contrasts = colors.map { contrastRatio($0, background) }
                let lightnesses = colors.map { labColor($0).lightness }

                #expect(contrasts.allSatisfy { $0 >= 3 })
                #expect(zip(contrasts, contrasts.dropFirst()).allSatisfy { $0.0 > $0.1 })
                #expect(colors.dropFirst().allSatisfy { hueDistance(colors[0], $0) < 0.04 })
                if appearance.name == .aqua {
                    #expect(zip(lightnesses, lightnesses.dropFirst()).allSatisfy { $0.0 < $0.1 })
                } else {
                    #expect(zip(lightnesses, lightnesses.dropFirst()).allSatisfy { $0.0 > $0.1 })
                }
            }
        }
    }

    @Test func cpuAndMemoryKeepDistinctResourceHues() throws {
        for appearance in appearances {
            let cpu = try resolvedSRGB(DashboardColorPalette.cpu(.step2), appearanceName: appearance.name)
            let memory = try resolvedSRGB(DashboardColorPalette.memory(.step2), appearanceName: appearance.name)

            #expect(hueDistance(cpu, memory) > 0.1)
        }
    }

    @Test func memoryCategoriesUseAllFourStepsInOrder() throws {
        for appearance in appearances {
            let categories = MemoryCompositionCategory.allCases
            let categoryColors = try categories.map {
                try resolvedSRGB(DashboardColorPalette.memoryComposition($0), appearanceName: appearance.name)
            }
            let rampColors = try DashboardColorPalette.RampStep.allCases.map {
                try resolvedSRGB(DashboardColorPalette.memory($0), appearanceName: appearance.name)
            }

            #expect(categories == [.app, .wired, .compressed, .cached])
            #expect(categoryColors == rampColors)
            let lightnesses = categoryColors.map { labColor($0).lightness }
            #expect(Set(lightnesses.map { ($0 * 10).rounded() }).count == 4)
        }
    }

    @Test func cpuBandsAndCoreEntryUseTheCPUResourceRamp() throws {
        for appearance in appearances {
            let user = try resolvedSRGB(DashboardColorPalette.cpuUser, appearanceName: appearance.name)
            let system = try resolvedSRGB(DashboardColorPalette.cpuSystem, appearanceName: appearance.name)
            let step3 = try resolvedSRGB(DashboardColorPalette.cpu(.step3), appearanceName: appearance.name)
            let step1 = try resolvedSRGB(DashboardColorPalette.cpu(.step1), appearanceName: appearance.name)

            #expect(user == step3)
            #expect(system == step1)
            for step in DashboardColorPalette.RampStep.allCases {
                let core = try resolvedSRGB(DashboardColorPalette.cpuCoreFill(step), appearanceName: appearance.name)
                let cpu = try resolvedSRGB(DashboardColorPalette.cpu(step), appearanceName: appearance.name)
                #expect(core == cpu)
            }
        }
    }

    @Test func cpuBandCompositeLightnessDifferenceImprovesInBothAppearances() throws {
        for appearance in appearances {
            let background = NSColor(rgbHexForTest: appearance.backgroundHex)
            let user = try resolvedSRGB(DashboardColorPalette.cpuUser, appearanceName: appearance.name)
            let system = try resolvedSRGB(DashboardColorPalette.cpuSystem, appearanceName: appearance.name)
            let userComposite = composited(user, opacity: HistoryGraphView.fillOpacity(for: .lower), over: background)
            let systemComposite = composited(system, opacity: HistoryGraphView.fillOpacity(for: .upper), over: background)
            let difference = abs(labColor(userComposite).lightness - labColor(systemComposite).lightness)

            #expect(difference > 10.5, "\(appearance.name.rawValue) 합성 후 ΔL*가 \(difference)입니다")
        }
        #expect(
            abs(
                HistoryGraphView.fillOpacity(for: .lower)
                    - HistoryGraphView.fillOpacity(for: .upper)
                    - 0.45
            ) < 0.000_001
        )
    }
}

private extension NSColor {
    convenience init(rgbHexForTest hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
