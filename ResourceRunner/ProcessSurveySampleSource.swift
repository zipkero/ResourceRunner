//
//  ProcessSurveySampleSource.swift
//  ResourceRunner
//
//  Created by zipkero on 8/15/26.
//

import Foundation

/// 프로세스 Collector를 소유하고 한 번의 조사 결과를 반환하는 `ScheduledSampleSource`.
/// Collector가 정체성별 실행 경로 캐시를 상태로 가진 값 타입이므로 actor로 두고
/// `MonitoringScheduler`가 `await`로 호출합니다.
///
/// 조사 자체의 실패는 던지지 않고 샘플 값으로 전달합니다.
/// 한 조사에서 값을 얻지 못한 프로세스는 이미 `ProcessSurveyReport.unreadableCount`로 구분되므로,
/// 여기서 실패로 담는 것은 열거 자체가 실패해 이번 tick의 결과가 아예 없는 경우뿐입니다.
/// 던지면 `MonitoringScheduler`가 그 tick을 건너뛰어 실패가 저장소와 표시 계층에 도달하지 못합니다.
actor ProcessSurveySampleSource<Collector: ProcessSurveyCollecting>: ScheduledSampleSource {
    private var collector: Collector

    init(collector: Collector) {
        self.collector = collector
    }

    func sample() -> ProcessSurveySample {
        do {
            return ProcessSurveySample(result: .success(try collector.survey()))
        } catch {
            return ProcessSurveySample(result: .failure(error))
        }
    }
}
