import Darwin

let expectedParentPID = CommandLine.arguments.dropFirst().first.flatMap(pid_t.init) ?? -1
let maximumPollCount = 300
let nanosecondsPerSecond = UInt64(NSEC_PER_SEC)

func monotonicNanoseconds() -> UInt64 {
    var time = timespec()
    clock_gettime(CLOCK_MONOTONIC_RAW, &time)
    return UInt64(time.tv_sec) * nanosecondsPerSecond + UInt64(time.tv_nsec)
}

for _ in 0..<maximumPollCount {
    guard getppid() == expectedParentPID else { exit(EXIT_SUCCESS) }

    // CPU 상세 상위 목록에 잡힐 최소 활동만 만들고 나머지 주기는 잠들어 한 코어를 계속 점유하지 않습니다.
    let workDeadline = monotonicNanoseconds() + 5_000_000
    while monotonicNanoseconds() < workDeadline {}
    usleep(95_000)
}
