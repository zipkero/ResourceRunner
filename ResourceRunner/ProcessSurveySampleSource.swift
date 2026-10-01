//
//  ProcessSurveySampleSource.swift
//  ResourceRunner
//
//  Created by zipkero on 8/15/26.
//

import Foundation

/// 프로세스 Collector를 소유하고 한 번의 조사 결과를 반환하는 `ScheduledSampleSource`.
/// Collector 조사를 순서대로 실행하도록 actor로 두고 `MonitoringScheduler`가 `await`로 호출합니다.
///
/// 조사 자체의 실패는 던지지 않고 샘플 값으로 전달합니다.
/// 한 조사에서 값을 얻지 못한 프로세스는 이미 `ProcessSurveyReport.unreadableCount`로 구분되므로,
/// 여기서 실패로 담는 것은 열거 자체가 실패해 이번 tick의 결과가 아예 없는 경우뿐입니다.
/// 던지면 `MonitoringScheduler`가 그 tick을 건너뛰어 실패가 저장소와 표시 계층에 도달하지 못합니다.
actor ProcessSurveySampleSource<Collector: ProcessSurveyCollecting>: ScheduledSampleSource {
    private var collector: Collector
    private let admission: CollectionAdmission?

    init(collector: Collector, admission: CollectionAdmission? = nil) {
        self.collector = collector
        self.admission = admission
    }

    func sample() -> ProcessSurveySample {
        do {
            return ProcessSurveySample(result: .success(try collector.survey()))
        } catch {
            return ProcessSurveySample(result: .failure(error))
        }
    }

    /// 프로세스 조사는 순간 조회이므로 구간 식별자를 계산에 사용하지 않습니다.
    /// context 경로에서는 조사 뒤 현재 실행권을 다시 확인합니다.
    func sample(collectionEpoch: Int) -> ProcessSurveySample? {
        sample()
    }

    func sample(context: CollectionRunContext) async -> ProcessSurveySample? {
        guard let admission else { return sample() }
        guard admission.isCurrent(context) else { return nil }
        let value = sample()
        return admission.admit(context, phase: .source, timestamp: ContinuousClock().now) { value }
    }
}
