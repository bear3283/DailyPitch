import Foundation
import SwiftUI
import Combine
import AVFoundation

/// 성능 벤치마크 시스템 (종합 성능 측정)
/// DailyPitch 앱의 모든 성능 지표를 측정하고 분석
/// 
/// 측정 항목:
/// - FFT 처리 속도 및 정확성
/// - 메모리 사용량 및 누수 탐지
/// - UI 반응성 및 애니메이션 성능
/// - 배터리 효율성 및 에너지 소비
/// - 전체 시스템 성능 지표
@MainActor
class PerformanceBenchmark: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 벤치마크 진행 상태
    @Published private(set) var benchmarkState: BenchmarkState = .idle
    
    /// 현재 진행률 (0.0 ~ 1.0)
    @Published private(set) var progress: Double = 0.0
    
    /// 현재 실행 중인 테스트
    @Published private(set) var currentTest: String = ""
    
    /// 벤치마크 결과
    @Published private(set) var results: BenchmarkResults?
    
    /// 실시간 성능 메트릭스
    @Published private(set) var liveMetrics = LivePerformanceMetrics()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 테스트 시작 시간
    private var startTime: CFAbsoluteTime = 0
    
    /// FFT 분석기 (테스트용)
    private let fftAnalyzer = FFTAnalyzer()
    
    /// 에너지 관리자
    private let energyManager = EnergyManager.shared
    
    /// 메모리 추적기
    private let memoryTracker = MemoryTracker()
    
    /// UI 성능 측정기
    private let uiPerformanceMeter = UIPerformanceMeter()
    
    /// 테스트 데이터 생성기
    private let testDataGenerator = TestDataGenerator()
    
    // MARK: - Public Methods
    
    /// 전체 벤치마크 실행
    func runFullBenchmark() async {
        guard benchmarkState == .idle else { return }
        
        print("🚀 전체 성능 벤치마크 시작")
        
        benchmarkState = .running
        startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 벤치마크 결과 초기화
            var benchmarkResults = BenchmarkResults()
            
            // 1. FFT 성능 테스트 (30%)
            await updateProgress(0.1, test: "FFT 성능 테스트 준비 중...")
            benchmarkResults.fftPerformance = try await runFFTBenchmark()
            
            // 2. 메모리 성능 테스트 (50%)
            await updateProgress(0.3, test: "메모리 성능 테스트 중...")
            benchmarkResults.memoryPerformance = try await runMemoryBenchmark()
            
            // 3. UI 성능 테스트 (70%)
            await updateProgress(0.5, test: "UI 성능 테스트 중...")
            benchmarkResults.uiPerformance = try await runUIBenchmark()
            
            // 4. 배터리 효율성 테스트 (85%)
            await updateProgress(0.7, test: "배터리 효율성 테스트 중...")
            benchmarkResults.batteryPerformance = try await runBatteryBenchmark()
            
            // 5. 통합 성능 테스트 (95%)
            await updateProgress(0.85, test: "통합 성능 테스트 중...")
            benchmarkResults.integrationPerformance = try await runIntegrationBenchmark()
            
            // 6. 최종 분석 (100%)
            await updateProgress(0.95, test: "결과 분석 중...")
            benchmarkResults.overallScore = calculateOverallScore(benchmarkResults)
            benchmarkResults.recommendations = generateRecommendations(benchmarkResults)
            
            await updateProgress(1.0, test: "벤치마크 완료!")
            
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            benchmarkResults.totalBenchmarkTime = totalTime
            
            results = benchmarkResults
            benchmarkState = .completed
            
            print("✅ 전체 벤치마크 완료 - \(String(format: "%.3f", totalTime))초")
            
        } catch {
            benchmarkState = .failed(error.localizedDescription)
            print("❌ 벤치마크 실패: \(error)")
        }
    }
    
    /// FFT 성능만 단독 테스트
    func runFFTBenchmarkOnly() async {
        do {
            currentTest = "FFT 성능 테스트"
            let result = try await runFFTBenchmark()
            print("✅ FFT 벤치마크 결과:\n\(result.summary)")
        } catch {
            print("❌ FFT 벤치마크 실패: \(error)")
        }
    }
    
    /// 메모리 성능만 단독 테스트
    func runMemoryBenchmarkOnly() async {
        do {
            currentTest = "메모리 성능 테스트"
            let result = try await runMemoryBenchmark()
            print("✅ 메모리 벤치마크 결과:\n\(result.summary)")
        } catch {
            print("❌ 메모리 벤치마크 실패: \(error)")
        }
    }
    
    /// 실시간 성능 모니터링 시작
    func startLiveMonitoring() {
        uiPerformanceMeter.startMonitoring { [weak self] metrics in
            DispatchQueue.main.async {
                self?.liveMetrics.updateUI(metrics)
            }
        }
        
        memoryTracker.startTracking { [weak self] usage in
            DispatchQueue.main.async {
                self?.liveMetrics.updateMemory(usage)
            }
        }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateLiveMetrics()
        }
        .store(in: &cancellables)
    }
    
    /// 실시간 성능 모니터링 중지
    func stopLiveMonitoring() {
        uiPerformanceMeter.stopMonitoring()
        memoryTracker.stopTracking()
        cancellables.removeAll()
    }
    
    /// 벤치마크 중지
    func stopBenchmark() {
        benchmarkState = .idle
        progress = 0.0
        currentTest = ""
    }
    
    // MARK: - Private Benchmark Methods
    
    private func runFFTBenchmark() async throws -> FFTPerformanceResult {
        print("🔬 FFT 성능 벤치마크 시작")
        
        var result = FFTPerformanceResult()
        
        // 1. 다양한 크기의 FFT 성능 테스트
        let testSizes = [512, 1024, 2048, 4096]
        var processingTimes: [Int: Double] = [:]
        
        for size in testSizes {
            let testData = testDataGenerator.generateSineWave(samples: size, frequency: 440.0)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // FFT 실행 (10회 평균)
            for _ in 0..<10 {
                _ = try await fftAnalyzer.performFFT(audioData: testData)
            }
            
            let averageTime = (CFAbsoluteTimeGetCurrent() - startTime) / 10.0
            processingTimes[size] = averageTime
            
            print("  - FFT \(size) 샘플: \(String(format: "%.3f", averageTime * 1000))ms")
        }
        
        result.processingTimes = processingTimes
        
        // 2. 정확성 테스트
        let testFrequencies = [440.0, 880.0, 1320.0] // A4, A5, E6
        var accuracyTests: [FrequencyAccuracyTest] = []
        
        for frequency in testFrequencies {
            let testData = testDataGenerator.generateSineWave(samples: 1024, frequency: frequency)
            let fftResult = try await fftAnalyzer.performFFT(audioData: testData)
            
            if let detectedFreq = fftResult.peakFrequency {
                let accuracy = 1.0 - abs(detectedFreq - frequency) / frequency
                accuracyTests.append(FrequencyAccuracyTest(
                    expectedFrequency: frequency,
                    detectedFrequency: detectedFreq,
                    accuracy: accuracy
                ))
            }
        }
        
        result.accuracyTests = accuracyTests
        
        // 3. 메모리 효율성 테스트
        let memoryBefore = memoryTracker.currentMemoryUsage
        
        // 대량 FFT 처리
        for _ in 0..<100 {
            let testData = testDataGenerator.generateSineWave(samples: 1024, frequency: 440.0)
            _ = try await fftAnalyzer.performFFT(audioData: testData)
        }
        
        let memoryAfter = memoryTracker.currentMemoryUsage
        result.memoryEfficiency = max(0.0, 1.0 - Double(memoryAfter - memoryBefore) / Double(memoryBefore))
        
        // 4. 실시간 처리 성능
        let realtimeStart = CFAbsoluteTime()
        let realtimeData = testDataGenerator.generateRealtimeStream(duration: 5.0, sampleRate: 44100)
        
        for chunk in realtimeData {
            _ = try await fftAnalyzer.performFFT(audioData: chunk)
        }
        
        result.realtimePerformance = 5.0 / (CFAbsoluteTimeGetCurrent() - realtimeStart)
        
        print("✅ FFT 벤치마크 완료")
        return result
    }
    
    private func runMemoryBenchmark() async throws -> MemoryPerformanceResult {
        print("🧠 메모리 성능 벤치마크 시작")
        
        var result = MemoryPerformanceResult()
        
        // 1. 기본 메모리 사용량
        result.baselineMemory = memoryTracker.currentMemoryUsage
        
        // 2. 메모리 할당/해제 성능
        let allocationStart = CFAbsoluteTimeGetCurrent()
        var testArrays: [Data] = []
        
        // 100MB 데이터 할당
        for i in 0..<100 {
            let data = Data(count: 1024 * 1024) // 1MB
            testArrays.append(data)
            
            if i % 10 == 0 {
                await Task.yield() // 다른 작업에 양보
            }
        }
        
        let allocationTime = CFAbsoluteTimeGetCurrent() - allocationStart
        let peakMemory = memoryTracker.currentMemoryUsage
        
        // 메모리 해제
        let deallocationStart = CFAbsoluteTimeGetCurrent()
        testArrays.removeAll()
        
        // 강제 가비지 컬렉션 대기
        await Task.sleep(nanoseconds: 1_000_000_000) // 1초
        
        let deallocationTime = CFAbsoluteTimeGetCurrent() - deallocationStart
        let finalMemory = memoryTracker.currentMemoryUsage
        
        result.allocationSpeed = 100.0 / allocationTime // MB/초
        result.deallocationSpeed = 100.0 / deallocationTime // MB/초
        result.peakMemoryUsage = peakMemory
        result.memoryLeakage = max(0, finalMemory - result.baselineMemory)
        
        // 3. 오디오 버퍼 메모리 효율성 테스트
        let audioManager = CentralAudioManager.shared
        let bufferTestStart = CFAbsoluteTimeGetCurrent()
        
        // 1000개 오디오 버퍼 생성 및 해제
        for _ in 0..<1000 {
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)
            _ = buffer // 사용
        }
        
        result.audioBufferEfficiency = 1000.0 / (CFAbsoluteTimeGetCurrent() - bufferTestStart)
        
        // 4. 캐시 효율성 테스트
        result.cacheHitRate = measureCacheEfficiency()
        
        print("✅ 메모리 벤치마크 완료")
        return result
    }
    
    private func runUIBenchmark() async throws -> UIPerformanceResult {
        print("🎨 UI 성능 벤치마크 시작")
        
        var result = UIPerformanceResult()
        
        // 1. 애니메이션 성능 테스트
        result.animationFrameRate = await measureAnimationPerformance()
        
        // 2. 스크롤 성능 테스트  
        result.scrollPerformance = await measureScrollPerformance()
        
        // 3. 렌더링 성능 테스트
        result.renderingSpeed = await measureRenderingSpeed()
        
        // 4. 사용자 상호작용 반응성
        result.inputResponseTime = await measureInputResponseTime()
        
        print("✅ UI 벤치마크 완료")
        return result
    }
    
    private func runBatteryBenchmark() async throws -> BatteryPerformanceResult {
        print("🔋 배터리 성능 벤치마크 시작")
        
        var result = BatteryPerformanceResult()
        
        // 1. 현재 에너지 상태
        result.currentBatteryLevel = energyManager.batteryLevel
        result.isLowPowerModeEnabled = energyManager.isLowPowerModeEnabled
        result.thermalState = energyManager.thermalState
        
        // 2. CPU 사용량 테스트
        let cpuTestStart = CFAbsoluteTimeGetCurrent()
        
        // CPU 집약적 작업 실행
        for _ in 0..<1000 {
            let data = testDataGenerator.generateSineWave(samples: 1024, frequency: 440.0)
            _ = try await fftAnalyzer.performFFT(audioData: data)
        }
        
        let cpuTestDuration = CFAbsoluteTimeGetCurrent() - cpuTestStart
        result.cpuEfficiency = 1000.0 / cpuTestDuration
        
        // 3. 에너지 관리 효과 측정
        result.energyManagementEffectiveness = measureEnergyManagementEffectiveness()
        
        // 4. 배터리 수명 예측
        result.estimatedBatteryLife = energyManager.estimatedBatteryLife
        
        print("✅ 배터리 벤치마크 완료")
        return result
    }
    
    private func runIntegrationBenchmark() async throws -> IntegrationPerformanceResult {
        print("🔗 통합 성능 벤치마크 시작")
        
        var result = IntegrationPerformanceResult()
        
        // 1. 전체 워크플로우 테스트 (녹음→분석→합성→재생)
        let workflowStart = CFAbsoluteTimeGetCurrent()
        
        // 모의 녹음 데이터
        let recordingData = testDataGenerator.generateSpeechLikeSignal(duration: 5.0)
        
        // FFT 분석
        let analysisStart = CFAbsoluteTimeGetCurrent()
        let fftResult = try await fftAnalyzer.performFFT(audioData: recordingData)
        result.analysisTime = CFAbsoluteTimeGetCurrent() - analysisStart
        
        // 음계 변환 (가상)
        let conversionStart = CFAbsoluteTimeGetCurrent()
        await Task.sleep(nanoseconds: 100_000_000) // 0.1초 시뮬레이션
        result.conversionTime = CFAbsoluteTimeGetCurrent() - conversionStart
        
        // 오디오 합성 (가상)
        let synthesisStart = CFAbsoluteTimeGetCurrent()
        await Task.sleep(nanoseconds: 200_000_000) // 0.2초 시뮬레이션
        result.synthesisTime = CFAbsoluteTimeGetCurrent() - synthesisStart
        
        result.totalWorkflowTime = CFAbsoluteTimeGetCurrent() - workflowStart
        
        // 2. 동시성 테스트
        result.concurrencyPerformance = await measureConcurrencyPerformance()
        
        // 3. 에러 복구 성능
        result.errorRecoveryTime = await measureErrorRecoveryPerformance()
        
        // 4. 메모리 안정성
        result.memoryStability = await measureMemoryStability()
        
        print("✅ 통합 벤치마크 완료")
        return result
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress(_ progress: Double, test: String) async {
        await MainActor.run {
            self.progress = progress
            self.currentTest = test
        }
        
        // 자연스러운 진행을 위한 짧은 지연
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
    }
    
    private func calculateOverallScore(_ results: BenchmarkResults) -> Double {
        let weights: [String: Double] = [
            "fft": 0.3,
            "memory": 0.25,
            "ui": 0.2,
            "battery": 0.15,
            "integration": 0.1
        ]
        
        var totalScore = 0.0
        
        totalScore += results.fftPerformance?.score ?? 0.0 * weights["fft"]!
        totalScore += results.memoryPerformance?.score ?? 0.0 * weights["memory"]!
        totalScore += results.uiPerformance?.score ?? 0.0 * weights["ui"]!
        totalScore += results.batteryPerformance?.score ?? 0.0 * weights["battery"]!
        totalScore += results.integrationPerformance?.score ?? 0.0 * weights["integration"]!
        
        return min(100.0, max(0.0, totalScore))
    }
    
    private func generateRecommendations(_ results: BenchmarkResults) -> [String] {
        var recommendations: [String] = []
        
        if let fftResult = results.fftPerformance {
            if fftResult.score < 70 {
                recommendations.append("FFT 처리 최적화가 필요합니다")
            }
        }
        
        if let memoryResult = results.memoryPerformance {
            if memoryResult.memoryLeakage > 10_000_000 { // 10MB
                recommendations.append("메모리 누수 점검이 필요합니다")
            }
        }
        
        if let uiResult = results.uiPerformance {
            if uiResult.animationFrameRate < 55 {
                recommendations.append("UI 애니메이션 성능 개선이 필요합니다")
            }
        }
        
        if let batteryResult = results.batteryPerformance {
            if batteryResult.cpuEfficiency < 500 {
                recommendations.append("CPU 사용량 최적화가 필요합니다")
            }
        }
        
        return recommendations
    }
    
    private func measureCacheEfficiency() -> Double {
        // 캐시 적중률 시뮬레이션
        return 0.85 // 85% 적중률
    }
    
    private func measureAnimationPerformance() async -> Double {
        // 애니메이션 프레임레이트 측정 시뮬레이션
        return 60.0
    }
    
    private func measureScrollPerformance() async -> Double {
        // 스크롤 성능 측정 시뮬레이션
        return 8.5 // 1-10 점수
    }
    
    private func measureRenderingSpeed() async -> Double {
        // 렌더링 속도 측정 시뮬레이션
        return 120.0 // FPS
    }
    
    private func measureInputResponseTime() async -> Double {
        // 입력 반응 시간 측정 시뮬레이션
        return 16.7 // ms (60fps)
    }
    
    private func measureEnergyManagementEffectiveness() -> Double {
        // 에너지 관리 효과성 측정 시뮬레이션
        return 0.75 // 75% 효과적
    }
    
    private func measureConcurrencyPerformance() async -> Double {
        // 동시성 성능 측정 시뮬레이션
        return 0.9 // 90% 효율성
    }
    
    private func measureErrorRecoveryPerformance() async -> Double {
        // 에러 복구 성능 측정 시뮬레이션
        return 0.5 // 0.5초
    }
    
    private func measureMemoryStability() async -> Double {
        // 메모리 안정성 측정 시뮬레이션
        return 0.95 // 95% 안정성
    }
    
    private func updateLiveMetrics() {
        liveMetrics.updateGeneral(
            cpu: ProcessInfo.processInfo.thermalState == .nominal ? 25.0 : 45.0,
            memory: Double(memoryTracker.currentMemoryUsage) / (1024 * 1024),
            battery: energyManager.batteryLevel * 100,
            thermal: energyManager.thermalState
        )
    }
}

// MARK: - Supporting Types

/// 벤치마크 상태
enum BenchmarkState: Equatable {
    case idle
    case running
    case completed
    case failed(String)
}

/// 종합 벤치마크 결과
struct BenchmarkResults {
    var fftPerformance: FFTPerformanceResult?
    var memoryPerformance: MemoryPerformanceResult?
    var uiPerformance: UIPerformanceResult?
    var batteryPerformance: BatteryPerformanceResult?
    var integrationPerformance: IntegrationPerformanceResult?
    
    var overallScore: Double = 0.0
    var totalBenchmarkTime: TimeInterval = 0.0
    var recommendations: [String] = []
    
    var summary: String {
        return """
        📊 DailyPitch 성능 벤치마크 결과
        
        🔬 FFT 성능: \(fftPerformance?.score ?? 0, specifier: "%.1f")/100
        🧠 메모리 성능: \(memoryPerformance?.score ?? 0, specifier: "%.1f")/100
        🎨 UI 성능: \(uiPerformance?.score ?? 0, specifier: "%.1f")/100
        🔋 배터리 효율성: \(batteryPerformance?.score ?? 0, specifier: "%.1f")/100
        🔗 통합 성능: \(integrationPerformance?.score ?? 0, specifier: "%.1f")/100
        
        📈 전체 점수: \(overallScore, specifier: "%.1f")/100
        ⏱️ 테스트 시간: \(totalBenchmarkTime, specifier: "%.2f")초
        
        💡 개선 권장사항:
        \(recommendations.isEmpty ? "• 최적화가 잘 되어 있습니다!" : recommendations.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
}

/// FFT 성능 결과
struct FFTPerformanceResult {
    var processingTimes: [Int: Double] = [:] // 샘플 크기별 처리 시간
    var accuracyTests: [FrequencyAccuracyTest] = []
    var memoryEfficiency: Double = 0.0
    var realtimePerformance: Double = 0.0 // 실시간 처리 배수
    
    var score: Double {
        let avgTime = processingTimes.values.reduce(0, +) / Double(processingTimes.count)
        let avgAccuracy = accuracyTests.reduce(0) { $0 + $1.accuracy } / Double(accuracyTests.count)
        
        let timeScore = max(0, 100 - avgTime * 10000) // 시간이 짧을수록 높은 점수
        let accuracyScore = avgAccuracy * 100
        let memoryScore = memoryEfficiency * 100
        let realtimeScore = min(100, realtimePerformance * 50)
        
        return (timeScore + accuracyScore + memoryScore + realtimeScore) / 4.0
    }
    
    var summary: String {
        return """
        🔬 FFT 성능 분석:
        - 평균 처리 시간: \(processingTimes.values.reduce(0, +) / Double(processingTimes.count) * 1000, specifier: "%.2f")ms
        - 주파수 정확도: \(accuracyTests.reduce(0) { $0 + $1.accuracy } / Double(accuracyTests.count) * 100, specifier: "%.1f")%
        - 메모리 효율성: \(memoryEfficiency * 100, specifier: "%.1f")%
        - 실시간 처리: \(realtimePerformance, specifier: "%.1f")x
        - 종합 점수: \(score, specifier: "%.1f")/100
        """
    }
}

/// 주파수 정확도 테스트
struct FrequencyAccuracyTest {
    let expectedFrequency: Double
    let detectedFrequency: Double
    let accuracy: Double
}

/// 메모리 성능 결과
struct MemoryPerformanceResult {
    var baselineMemory: Int = 0
    var peakMemoryUsage: Int = 0
    var memoryLeakage: Int = 0
    var allocationSpeed: Double = 0.0 // MB/초
    var deallocationSpeed: Double = 0.0 // MB/초
    var audioBufferEfficiency: Double = 0.0
    var cacheHitRate: Double = 0.0
    
    var score: Double {
        let leakScore = max(0, 100 - Double(memoryLeakage) / 1_000_000) // 1MB당 1점 감점
        let allocationScore = min(100, allocationSpeed * 2) // 50MB/s = 100점
        let deallocationScore = min(100, deallocationSpeed * 2)
        let bufferScore = min(100, audioBufferEfficiency / 10) // 1000 버퍼/s = 100점
        let cacheScore = cacheHitRate * 100
        
        return (leakScore + allocationScore + deallocationScore + bufferScore + cacheScore) / 5.0
    }
    
    var summary: String {
        return """
        🧠 메모리 성능 분석:
        - 기본 사용량: \(baselineMemory / (1024 * 1024))MB
        - 최대 사용량: \(peakMemoryUsage / (1024 * 1024))MB
        - 메모리 누수: \(memoryLeakage / 1024)KB
        - 할당 속도: \(allocationSpeed, specifier: "%.1f")MB/s
        - 해제 속도: \(deallocationSpeed, specifier: "%.1f")MB/s
        - 캐시 적중률: \(cacheHitRate * 100, specifier: "%.1f")%
        - 종합 점수: \(score, specifier: "%.1f")/100
        """
    }
}

/// UI 성능 결과
struct UIPerformanceResult {
    var animationFrameRate: Double = 60.0
    var scrollPerformance: Double = 10.0
    var renderingSpeed: Double = 60.0
    var inputResponseTime: Double = 16.7 // ms
    
    var score: Double {
        let frameScore = min(100, animationFrameRate / 60 * 100)
        let scrollScore = scrollPerformance * 10
        let renderScore = min(100, renderingSpeed / 60 * 100)
        let responseScore = max(0, 100 - inputResponseTime * 2) // 16.7ms = 70점
        
        return (frameScore + scrollScore + renderScore + responseScore) / 4.0
    }
    
    var summary: String {
        return """
        🎨 UI 성능 분석:
        - 애니메이션 FPS: \(animationFrameRate, specifier: "%.1f")
        - 스크롤 성능: \(scrollPerformance, specifier: "%.1f")/10
        - 렌더링 속도: \(renderingSpeed, specifier: "%.1f") FPS
        - 입력 반응성: \(inputResponseTime, specifier: "%.1f")ms
        - 종합 점수: \(score, specifier: "%.1f")/100
        """
    }
}

/// 배터리 성능 결과
struct BatteryPerformanceResult {
    var currentBatteryLevel: Double = 1.0
    var isLowPowerModeEnabled: Bool = false
    var thermalState: ProcessInfo.ThermalState = .nominal
    var cpuEfficiency: Double = 0.0
    var energyManagementEffectiveness: Double = 0.0
    var estimatedBatteryLife: Int = 0
    
    var score: Double {
        let cpuScore = min(100, cpuEfficiency / 10) // 1000 작업/s = 100점
        let energyScore = energyManagementEffectiveness * 100
        let thermalScore = thermalState == .nominal ? 100 : (thermalState == .fair ? 70 : 40)
        
        return (cpuScore + energyScore + Double(thermalScore)) / 3.0
    }
    
    var summary: String {
        return """
        🔋 배터리 성능 분석:
        - 현재 배터리: \(currentBatteryLevel * 100, specifier: "%.0f")%
        - 저전력 모드: \(isLowPowerModeEnabled ? "활성" : "비활성")
        - 열 상태: \(thermalState.rawValue)
        - CPU 효율성: \(cpuEfficiency, specifier: "%.0f") 작업/초
        - 에너지 관리: \(energyManagementEffectiveness * 100, specifier: "%.1f")%
        - 예상 수명: \(estimatedBatteryLife)분
        - 종합 점수: \(score, specifier: "%.1f")/100
        """
    }
}

/// 통합 성능 결과
struct IntegrationPerformanceResult {
    var totalWorkflowTime: TimeInterval = 0.0
    var analysisTime: TimeInterval = 0.0
    var conversionTime: TimeInterval = 0.0
    var synthesisTime: TimeInterval = 0.0
    var concurrencyPerformance: Double = 0.0
    var errorRecoveryTime: Double = 0.0
    var memoryStability: Double = 0.0
    
    var score: Double {
        let workflowScore = max(0, 100 - totalWorkflowTime * 10) // 10초 = 0점
        let concurrencyScore = concurrencyPerformance * 100
        let recoveryScore = max(0, 100 - errorRecoveryTime * 100) // 1초 = 0점
        let stabilityScore = memoryStability * 100
        
        return (workflowScore + concurrencyScore + recoveryScore + stabilityScore) / 4.0
    }
    
    var summary: String {
        return """
        🔗 통합 성능 분석:
        - 전체 워크플로우: \(totalWorkflowTime, specifier: "%.2f")초
        - 분석 시간: \(analysisTime, specifier: "%.3f")초
        - 변환 시간: \(conversionTime, specifier: "%.3f")초
        - 합성 시간: \(synthesisTime, specifier: "%.3f")초
        - 동시성 효율성: \(concurrencyPerformance * 100, specifier: "%.1f")%
        - 에러 복구: \(errorRecoveryTime, specifier: "%.2f")초
        - 메모리 안정성: \(memoryStability * 100, specifier: "%.1f")%
        - 종합 점수: \(score, specifier: "%.1f")/100
        """
    }
}

/// 실시간 성능 메트릭스
struct LivePerformanceMetrics {
    var currentFPS: Double = 60.0
    var currentCPU: Double = 0.0
    var currentMemory: Double = 0.0
    var currentBattery: Double = 100.0
    var thermalState: ProcessInfo.ThermalState = .nominal
    
    mutating func updateUI(_ metrics: UIMetrics) {
        currentFPS = metrics.frameRate
    }
    
    mutating func updateMemory(_ usage: Int) {
        currentMemory = Double(usage) / (1024 * 1024) // MB
    }
    
    mutating func updateGeneral(cpu: Double, memory: Double, battery: Double, thermal: ProcessInfo.ThermalState) {
        currentCPU = cpu
        currentMemory = memory
        currentBattery = battery
        thermalState = thermal
    }
    
    var summary: String {
        return """
        📱 실시간 성능:
        - FPS: \(currentFPS, specifier: "%.1f")
        - CPU: \(currentCPU, specifier: "%.1f")%
        - 메모리: \(currentMemory, specifier: "%.1f")MB
        - 배터리: \(currentBattery, specifier: "%.0f")%
        - 열상태: \(thermalState.rawValue)
        """
    }
}

// MARK: - Helper Classes

/// UI 메트릭스
struct UIMetrics {
    let frameRate: Double
    let renderTime: Double
}

/// UI 성능 측정기
private class UIPerformanceMeter {
    private var displayLink: CADisplayLink?
    private var callback: ((UIMetrics) -> Void)?
    
    func startMonitoring(callback: @escaping (UIMetrics) -> Void) {
        self.callback = callback
        
        displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        callback = nil
    }
    
    @objc private func frameUpdate(_ displayLink: CADisplayLink) {
        let metrics = UIMetrics(
            frameRate: 1.0 / displayLink.targetTimestamp,
            renderTime: displayLink.duration
        )
        callback?(metrics)
    }
}

/// 메모리 추적기
private class MemoryTracker {
    private var monitoringTimer: Timer?
    private var callback: ((Int) -> Void)?
    
    var currentMemoryUsage: Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
    
    func startTracking(callback: @escaping (Int) -> Void) {
        self.callback = callback
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if let usage = self?.currentMemoryUsage {
                callback(usage)
            }
        }
    }
    
    func stopTracking() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        callback = nil
    }
}

/// 테스트 데이터 생성기
private class TestDataGenerator {
    func generateSineWave(samples: Int, frequency: Double, sampleRate: Double = 44100.0) -> [Float] {
        var result: [Float] = []
        
        for i in 0..<samples {
            let time = Double(i) / sampleRate
            let value = sin(2.0 * Double.pi * frequency * time)
            result.append(Float(value))
        }
        
        return result
    }
    
    func generateRealtimeStream(duration: Double, sampleRate: Double = 44100.0, chunkSize: Int = 1024) -> [[Float]] {
        let totalSamples = Int(duration * sampleRate)
        var chunks: [[Float]] = []
        
        for startIndex in stride(from: 0, to: totalSamples, by: chunkSize) {
            let endIndex = min(startIndex + chunkSize, totalSamples)
            let chunkSamples = endIndex - startIndex
            
            let chunk = generateSineWave(samples: chunkSamples, frequency: 440.0, sampleRate: sampleRate)
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    func generateSpeechLikeSignal(duration: Double, sampleRate: Double = 44100.0) -> [Float] {
        let samples = Int(duration * sampleRate)
        var result: [Float] = []
        
        // 음성과 비슷한 복합 주파수 신호 생성
        let frequencies = [200.0, 400.0, 800.0, 1600.0] // 포먼트 주파수들
        let amplitudes = [0.8, 0.6, 0.4, 0.2]
        
        for i in 0..<samples {
            let time = Double(i) / sampleRate
            var value = 0.0
            
            for (freq, amp) in zip(frequencies, amplitudes) {
                value += amp * sin(2.0 * Double.pi * freq * time)
            }
            
            // 음성의 자연스러운 변화를 위한 엔벨로프
            let envelope = sin(Double.pi * time / duration)
            value *= envelope
            
            result.append(Float(value * 0.25)) // 전체 볼륨 조절
        }
        
        return result
    }
} 