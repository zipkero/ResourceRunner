import AppKit
import SwiftUI
import Testing
@testable import ResourceRunner

private let detailTestInstant = ContinuousClock().now
private let detailTestWidth: CGFloat = 400
private let detailContentWidth: CGFloat = detailTestWidth - 32
private let detailGroupKey = ApplicationKey(value: "/Applications/Probe.app")

private func detailProcess(_ index: Int) -> ApplicationProcessDetail {
    ApplicationProcessDetail(
        pid: 12_345 + pid_t(index),
        executableName: "Probe Helper \(index)",
        cpuUsagePercent: 12.3,
        residentBytes: 512 * 1024 * 1024,
        isTranslated: true
    )
}

private func detailGroup(childCount: Int = 2, suffix: String = "") -> ApplicationProcessGroup {
    ApplicationProcessGroup(
        key: ApplicationKey(value: detailGroupKey.value + suffix),
        displayName: "Probe",
        processes: (0..<childCount).map(detailProcess),
        sortValue: 12.3
    )
}

private func detailCPUPresentation(coreUsages: [Double] = [0, 25, 50, 75, 100, 10, 20, 30, 40, 60]) -> CPUCardPresentation {
    CPUCardPresentation.assemble(
        cpu: CPUSystemMetrics(
            overallUsage: 42,
            userRatio: 30,
            systemRatio: 12,
            idleRatio: 58,
            coreUsages: coreUsages,
            loadAverage: LoadAverage(oneMinute: 1.5, fiveMinutes: 1.25, fifteenMinutes: 1)
        ),
        history: [],
        topApplications: [],
        processGroups: [detailGroup()],
        currentTimestamp: detailTestInstant
    )
}

private func detailMemoryPresentation() -> MemoryCardPresentation {
    let gibibyte: UInt64 = 1024 * 1024 * 1024
    return MemoryCardPresentation.assemble(
        memory: MemorySystemMetrics(
            totalPhysicalBytes: 16 * gibibyte,
            usedBytes: 8 * gibibyte,
            appBytes: 4 * gibibyte,
            wiredBytes: 2 * gibibyte,
            compressedBytes: 2 * gibibyte,
            cachedBytes: gibibyte,
            swapUsedBytes: 0,
            pressureLevel: .normal
        ),
        history: [],
        topApplications: [],
        processGroups: [detailGroup()],
        currentTimestamp: detailTestInstant
    )
}

@MainActor
private func detailMeasuredSize(_ view: some View, width: CGFloat = .greatestFiniteMagnitude) -> CGSize {
    NSHostingController(rootView: view).sizeThatFits(
        in: CGSize(width: width, height: .greatestFiniteMagnitude)
    )
}

@MainActor
private func detailBitmap(_ view: some View, width: CGFloat? = nil) -> NSBitmapImageRep? {
    let content = width.map { AnyView(view.frame(width: $0, alignment: .leading)) } ?? AnyView(view)
    let renderer = ImageRenderer(content: content)
    renderer.scale = 1
    guard let data = renderer.nsImage?.tiffRepresentation else { return nil }
    return NSBitmapImageRep(data: data)
}

/// `ImageRenderer`가 실체화하지 않는 `ScrollView`의 보이는 영역까지 포함해 AppKit hosting view 전체를 캡처합니다.
/// task-007은 이 경로로 production의 `ScrollView`와 고정 `.frame`을 함께 관찰합니다.
@MainActor
private func detailPopupBitmap(_ view: some View) -> NSBitmapImageRep? {
    let controller = NSHostingController(rootView: view)
    let bounds = CGRect(
        origin: .zero,
        size: CGSize(width: DashboardView.detailPopupWidth, height: DashboardView.detailPopupHeight)
    )
    controller.view.frame = bounds
    controller.view.layoutSubtreeIfNeeded()
    guard let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
    controller.view.cacheDisplay(in: bounds, to: bitmap)
    return bitmap
}

private func differentPixelCount(_ lhs: NSBitmapImageRep, _ rhs: NSBitmapImageRep) -> Int {
    guard lhs.pixelsWide == rhs.pixelsWide, lhs.pixelsHigh == rhs.pixelsHigh else { return .max }
    var count = 0
    for y in 0..<lhs.pixelsHigh {
        for x in 0..<lhs.pixelsWide where lhs.colorAt(x: x, y: y) != rhs.colorAt(x: x, y: y) {
            count += 1
        }
    }
    return count
}

private enum ReferenceCellOmission {
    case none
    case track
    case fill
    case valueText
    case coreNumber
}

private struct ReferenceCoreCell: View {
    let omission: ReferenceCellOmission
    let usage: Double

    var body: some View {
        VStack(spacing: CPUCoreUsageCellView.rowSpacing) {
            ZStack(alignment: .bottom) {
                if omission != .track {
                    Rectangle().fill(DashboardColorPalette.cpuCoreTrack)
                }
                if omission != .fill {
                    Rectangle()
                        .fill(DashboardColorPalette.cpuCoreFill)
                        .frame(height: CPUCoreGridLayout.barHeight * CGFloat(usage) / 100)
                }
            }
            .frame(height: CPUCoreGridLayout.barHeight)
            .clipShape(RoundedRectangle(cornerRadius: CPUCoreUsageCellView.cornerRadius))

            if omission != .valueText {
                Text(CPUCoreUsageFormatting.valueText(usage)).font(.caption2)
            }
            if omission != .coreNumber {
                Text(CPUCoreUsageFormatting.coreNumberText(coreIndex: 0))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private enum ReferenceRowOmission {
    case none
    case nameIndent
    case valueIndent
    case boundarySpacings
}

private struct ReferenceApplicationRow: View {
    let group: ApplicationProcessGroup
    let expanded: Bool
    let omission: ReferenceRowOmission

    var body: some View {
        DisclosureGroup(isExpanded: .constant(expanded)) {
            VStack(
                alignment: .leading,
                spacing: omission == .boundarySpacings ? 0 : ApplicationProcessRowLayout.betweenChildren
            ) {
                ForEach(group.processes, id: \.pid) { process in
                    VStack(
                        alignment: .leading,
                        spacing: omission == .boundarySpacings ? 0 : ApplicationProcessRowLayout.withinChildRow
                    ) {
                        Text("\(process.executableName) (PID \(process.pid))")
                            .padding(.leading, omission == .nameIndent ? 0 : ApplicationProcessRowLayout.childIndent)
                        Text(ApplicationProcessValueFormatting.cpuProcessValueText(process))
                            .padding(.leading, omission == .valueIndent ? 0 : ApplicationProcessRowLayout.childValueIndent)
                    }
                    .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, omission == .boundarySpacings ? 0 : ApplicationProcessRowLayout.parentToFirstChild)
            .padding(.bottom, omission == .boundarySpacings ? 0 : ApplicationProcessRowLayout.afterLastChild)
        } label: {
            HStack(spacing: ApplicationProcessRowLayout.labelIconSpacing) {
                ApplicationRowIconView(
                    content: ApplicationRowIconLayout.content(for: group.key, from: StubApplicationIconProvider()),
                    pointSize: ApplicationRowIconLayout.detailPointSize
                )
                Text(group.displayName)
                Spacer()
                Text(ApplicationProcessValueFormatting.cpuGroupValueText(group.sortValue))
            }
        }
        .font(.caption)
    }
}

@MainActor
private func productionApplicationRow(expanded: Bool) -> some View {
    ApplicationProcessGroupRow(
        group: detailGroup(),
        groupValueText: ApplicationProcessValueFormatting.cpuGroupValueText,
        valueText: ApplicationProcessValueFormatting.cpuProcessValueText,
        iconProvider: StubApplicationIconProvider(),
        isExpanded: .constant(expanded)
    )
}

@MainActor
private func elementSensitivityFailure(_ element: DetailPopoverNewDisplayElement) -> String? {
    switch element {
    case .coreGridHeading:
        let presentation = detailCPUPresentation()
        let detail = CPUDetailView(presentation: presentation, iconProvider: StubApplicationIconProvider())
        let full = detailMeasuredSize(detail, width: detailContentWidth).height
        let without = detailMeasuredSize(CPUDetailWithoutGridHeading(presentation: presentation), width: detailContentWidth).height
        return without < full ? nil : "CPU 상세 전체에서 격자 머리글을 뺀 기준 높이가 \(full)에서 \(without)으로 줄지 않습니다"

    case .coreBarTrack, .coreBarFill, .coreValueText, .coreNumber:
        let omission: ReferenceCellOmission = switch element {
        case .coreBarTrack: .track
        case .coreBarFill: .fill
        case .coreValueText: .valueText
        case .coreNumber: .coreNumber
        default: .none
        }
        guard
            let production = detailBitmap(CPUCoreUsageCellView(coreIndex: 0, usage: 50), width: detailContentWidth),
            let full = detailBitmap(ReferenceCoreCell(omission: .none, usage: 50), width: detailContentWidth),
            let without = detailBitmap(ReferenceCoreCell(omission: omission, usage: 50), width: detailContentWidth)
        else { return "코어 칸 비트맵을 만들지 못했습니다" }
        guard differentPixelCount(production, full) == 0 else {
            return "production 코어 칸이 전체 기준 조립과 다릅니다"
        }
        return differentPixelCount(full, without) > 0 ? nil : "요소 하나를 뺀 코어 칸 기준이 전체와 갈리지 않습니다"

    case .lastRowEmptySlot:
        guard
            let full = detailBitmap(CPUCoreUsageGridView(usages: Array(repeating: 50, count: 9)), width: detailContentWidth),
            let without = detailBitmap(GridWithoutEmptySlots(usages: Array(repeating: 50, count: 9)), width: detailContentWidth)
        else { return "마지막 행 격자 비트맵을 만들지 못했습니다" }
        return differentPixelCount(full, without) > 0 ? nil : "마지막 행 빈 칸 자리만 뺀 기준이 전체와 갈리지 않습니다"

    case .childNameIndent, .childValueIndent, .childBoundarySpacings:
        let omission: ReferenceRowOmission = switch element {
        case .childNameIndent: .nameIndent
        case .childValueIndent: .valueIndent
        case .childBoundarySpacings: .boundarySpacings
        default: .none
        }
        guard
            let production = detailBitmap(productionApplicationRow(expanded: true), width: detailContentWidth),
            let full = detailBitmap(ReferenceApplicationRow(group: detailGroup(), expanded: true, omission: .none), width: detailContentWidth),
            let without = detailBitmap(ReferenceApplicationRow(group: detailGroup(), expanded: true, omission: omission), width: detailContentWidth)
        else { return "하위 행 비트맵을 만들지 못했습니다" }
        guard differentPixelCount(production, full) == 0 else {
            return "production 하위 행이 전체 기준 조립과 다릅니다"
        }
        return differentPixelCount(full, without) > 0 ? nil : "요소 하나를 뺀 하위 행 기준이 전체와 갈리지 않습니다"
    }
}

private struct GridWithoutEmptySlots: View {
    let usages: [Double]

    var body: some View {
        let rows = CPUCoreGridLayout.rows(coreCount: usages.count)
        VStack(spacing: CPUCoreGridLayout.cellSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: CPUCoreGridLayout.cellSpacing) {
                    ForEach(row, id: \.self) { coreIndex in
                        CPUCoreUsageCellView(coreIndex: coreIndex, usage: usages[coreIndex])
                    }
                }
            }
        }
    }
}

private struct CPUValuelessReference: View {
    var body: some View {
        ScrollView {
            Text("아직 CPU 값이 수집되지 않았습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: DashboardView.detailPopupWidth, height: DashboardView.detailPopupHeight)
    }
}

/// 머리글 감도는 섹션 조각이 아니라 production `CPUDetailView.body` 전체와 비교합니다.
/// body가 `coreUsageSection` 자체를 조립하지 않으면 production 높이가 이 기준보다 작아져 단언이 실패합니다.
private struct CPUDetailWithoutGridHeading: View {
    let presentation: CPUCardPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("User \(pct(presentation.userRatio)) · System \(pct(presentation.systemRatio)) · Idle \(pct(presentation.detail.idleRatio))")
                .font(.caption)

            CPUCoreUsageGridView(usages: presentation.detail.coreUsages)

            let load = presentation.detail.loadAverage
            Text("Load Average \(fmt(load.oneMinute)) / \(fmt(load.fiveMinutes)) / \(fmt(load.fifteenMinutes))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ApplicationProcessGroupListView(
                groups: presentation.detail.applications,
                sortDescription: presentation.detail.applicationsHeading,
                groupValueText: ApplicationProcessValueFormatting.cpuGroupValueText,
                iconProvider: StubApplicationIconProvider(),
                valueText: ApplicationProcessValueFormatting.cpuProcessValueText
            )
        }
    }

    private func pct(_ value: Double) -> String { "\(Int(value.rounded()))%" }
    private func fmt(_ value: Double) -> String { String(format: "%.2f", value) }
}

@Suite("상세 팝업 값 없음 상태")
@MainActor
struct DetailPopoverValuelessStateTests {
    @Test("CPU·Memory 상세 콘텐츠의 프레임은 네 상태 모두 400×480이다")
    func framesStayFixedAcrossAllStates() {
        let cpu = detailCPUPresentation()
        let cpuStates: [ResourceCardState<CPUCardPresentation>] = [
            .collecting,
            .normal(cpu, timestamp: detailTestInstant),
            .failure(lastKnown: nil),
            .stopped(lastKnown: nil)
        ]
        let memory = detailMemoryPresentation()
        let memoryStates: [ResourceCardState<MemoryCardPresentation>] = [
            .collecting,
            .normal(memory, timestamp: detailTestInstant),
            .failure(lastKnown: nil),
            .stopped(lastKnown: nil)
        ]

        let cpuSizes = cpuStates.map {
            detailMeasuredSize(CPUDetailPopoverContent(state: $0, iconProvider: StubApplicationIconProvider()))
        }
        let memorySizes = memoryStates.map {
            detailMeasuredSize(MemoryDetailPopoverContent(state: $0, iconProvider: StubApplicationIconProvider()))
        }

        #expect(cpuSizes.allSatisfy { $0 == CGSize(width: 400, height: 480) }, "CPU 상태별 프레임: \(cpuSizes)")
        #expect(memorySizes.allSatisfy { $0 == CGSize(width: 400, height: 480) }, "Memory 상태별 프레임: \(memorySizes)")
    }

    @Test("수집 중·실패·중지는 같은 안내 문구 하나만 그린다")
    func valuelessStatesRenderTheSameSingleMessage() throws {
        let states: [ResourceCardState<CPUCardPresentation>] = [
            .collecting,
            .failure(lastKnown: nil),
            .stopped(lastKnown: nil)
        ]
        let bitmaps = try states.map {
            let content = CPUDetailPopoverContent(state: $0, iconProvider: StubApplicationIconProvider())
            return try #require(detailPopupBitmap(content))
        }
        let reference = try #require(detailPopupBitmap(CPUValuelessReference()))

        for bitmap in bitmaps {
            #expect(differentPixelCount(bitmap, reference) == 0, "값 없음 콘텐츠가 안내 문구 하나의 기준 조립과 다릅니다")
        }
        #expect(differentPixelCount(bitmaps[0], bitmaps[1]) == 0)
        #expect(differentPixelCount(bitmaps[1], bitmaps[2]) == 0)

        let extraMessage = detailPopupBitmap(
            ZStack(alignment: .bottomLeading) {
                CPUValuelessReference()
                Text("추가")
            }
        )
        #expect(extraMessage != nil)
        #expect(differentPixelCount(reference, extraMessage!) > 0, "추가 요소가 생겨도 렌더 동일성 비교가 반응하지 않습니다")
    }

    @Test("production 전수 목록의 아홉 요소는 정상에만 있고 요소별 감도 점검을 통과한다")
    func everyNewElementExistsOnlyInNormalAndHasSensitivity() {
        let presentation = detailCPUPresentation()
        let states: [(String, ResourceCardState<CPUCardPresentation>, Bool)] = [
            ("수집 중", .collecting, false),
            ("정상", .normal(presentation, timestamp: detailTestInstant), true),
            ("실패", .failure(lastKnown: nil), false),
            ("중지", .stopped(lastKnown: nil), false)
        ]

        #expect(CPUDetailView.newDisplayElements == DetailPopoverNewDisplayElement.allCases)
        #expect(CPUDetailView.newDisplayElements.count == 9)

        for (stateName, state, expectsElements) in states {
            let content = CPUDetailPopoverContent(state: state, iconProvider: StubApplicationIconProvider())
            for element in CPUDetailView.newDisplayElements {
                #expect(
                    content.newDisplayElements.contains(element) == expectsElements,
                    "\(stateName) 상태의 \(element.rawValue) 포함 여부가 다릅니다"
                )
            }
        }

        for element in CPUDetailView.newDisplayElements {
            let failure = elementSensitivityFailure(element)
            #expect(failure == nil, "\(element.rawValue) 감도 자기점검 실패: \(failure ?? "")")
        }
    }

    @Test("빈 코어 입력은 행과 렌더 높이를 만들지 않는다")
    func emptyCoreInputCreatesNoRowsOrInventedZero() {
        #expect(CPUCoreGridLayout.rows(coreCount: 0).isEmpty)
        let size = detailMeasuredSize(CPUCoreUsageGridView(usages: []), width: detailContentWidth)
        #expect(size.height == 0, "빈 격자의 렌더 높이가 \(size.height)라 없는 코어 자리를 만들었습니다")
    }
}
