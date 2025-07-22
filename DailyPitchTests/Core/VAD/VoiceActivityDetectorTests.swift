import XCTest
import AVFoundation
@testable import DailyPitch

/// VoiceActivityDetector 테스트 클래스
/// VAD의 핵심 기능들을 종합적으로 테스트
class VoiceActivityDetectorTests: XCTestCase {
    
    var vad: VoiceActivityDetector!
    let sampleRate: Double = 44100.0
    let frameSize: Int = 1024
    
    override func setUp() {
        super.setUp()
        
        // 테스트용 VAD 설정
        let testConfig = VoiceActivityDetector.VADConfiguration(
            energyThreshold: 0.01,
            zcrThreshold: 50.0,
            spectralFluxThreshold: 0.02,
            minSpeechDuration: 0.05,
            minSilenceDuration: 0.02,
            hangoverTime: 0.1,
            useAdaptiveThreshold: true,
            noiseEstimationTime: 0.2
        )
        
        vad = VoiceActivityDetector(
            configuration: testConfig,
            sampleRate: sampleRate,
            frameSize: frameSize
        )
    }
    
    override func tearDown() {
        vad = nil
        super.tearDown()
    }
    
    // MARK: - 기본 기능 테스트
    
    func testVADInitialization() {
        XCTAssertNotNil(vad, "VAD should initialize successfully")
    }
    
    func testVADReset() {
        vad.reset()
        // reset 후에도 정상 동작하는지 확인
        let silenceData = generateSilence(duration: 1.0)
        let results = vad.detectVoiceActivity(in: silenceData)
        XCTAssertFalse(results.isEmpty, "VAD should return results after reset")
    }
    
    // MARK: - 신호 생성 헬퍼
    
    func testSilenceDetection() {
        // 완전한 무음 신호 생성
        let silenceData = generateSilence(duration: 1.0)
        let results = vad.detectVoiceActivity(in: silenceData)
        
        XCTAssertFalse(results.isEmpty, "Should detect frames even in silence")
        
        // 대부분이 무음으로 분류되어야 함
        let speechFrames = results.filter { $0.isSpeech }
        let speechRatio = Double(speechFrames.count) / Double(results.count)
        
        XCTAssertLessThan(speechRatio, 0.2, "Silence should have low speech ratio (< 20%)")
    }
    
    func testToneDetection() {
        // 440Hz 순음 생성 (A4)
        let toneData = generateTone(frequency: 440.0, duration: 1.0, amplitude: 0.5)
        let results = vad.detectVoiceActivity(in: toneData)
        
        XCTAssertFalse(results.isEmpty, "Should detect frames in tone signal")
        
        // 대부분이 음성으로 분류되어야 함
        let speechFrames = results.filter { $0.isSpeech }
        let speechRatio = Double(speechFrames.count) / Double(results.count)
        
        XCTAssertGreaterThan(speechRatio, 0.7, "Clean tone should have high speech ratio (> 70%)")
    }
    
    func testNoiseDetection() {
        // 랜덤 노이즈 생성
        let noiseData = generateNoise(duration: 1.0, amplitude: 0.1)
        let results = vad.detectVoiceActivity(in: noiseData)
        
        XCTAssertFalse(results.isEmpty, "Should detect frames in noise signal")
        
        // 노이즈는 중간 정도의 음성 비율을 가져야 함
        let speechFrames = results.filter { $0.isSpeech }
        let speechRatio = Double(speechFrames.count) / Double(results.count)
        
        XCTAssertLessThan(speechRatio, 0.6, "Noise should have moderate speech ratio")
    }
    
    func testMixedSignalDetection() {
        // 음성 + 무음 + 음성 패턴
        let speech1 = generateTone(frequency: 200.0, duration: 0.5, amplitude: 0.3)
        let silence = generateSilence(duration: 0.2)
        let speech2 = generateTone(frequency: 400.0, duration: 0.5, amplitude: 0.3)
        
        let mixedData = speech1 + silence + speech2
        let results = vad.detectVoiceActivity(in: mixedData)
        
        let segments = vad.createSegments(from: results)
        let speechSegments = vad.speechSegments(from: segments)
        
        // 2개 이상의 음성 세그먼트가 검출되어야 함
        XCTAssertGreaterThanOrEqual(speechSegments.count, 2, "Should detect at least 2 speech segments")
    }
    
    // MARK: - 세그먼트 테스트
    
    func testSegmentCreation() {
        let toneData = generateTone(frequency: 300.0, duration: 0.5, amplitude: 0.4)
        let results = vad.detectVoiceActivity(in: toneData)
        let segments = vad.createSegments(from: results)
        
        XCTAssertFalse(segments.isEmpty, "Should create segments from VAD results")
        
        // 세그먼트 시간 순서 확인
        for i in 1..<segments.count {
            XCTAssertGreaterThanOrEqual(
                segments[i].startTime, 
                segments[i-1].endTime,
                "Segments should be in chronological order"
            )
        }
    }
    
    func testSpeechSegmentFiltering() {
        let mixedData = generateMixedSignal()
        let results = vad.detectVoiceActivity(in: mixedData)
        let allSegments = vad.createSegments(from: results)
        let speechSegments = vad.speechSegments(from: allSegments)
        
        // 음성 세그먼트는 전체 세그먼트보다 적거나 같아야 함
        XCTAssertLessThanOrEqual(speechSegments.count, allSegments.count)
        
        // 모든 음성 세그먼트는 isSpeech가 true여야 함
        for segment in speechSegments {
            XCTAssertTrue(segment.isSpeech, "Speech segments should have isSpeech = true")
            XCTAssertGreaterThan(segment.duration, 0, "Speech segments should have positive duration")
        }
    }
    
    // MARK: - 품질 및 성능 테스트
    
    func testVADResultQuality() {
        let toneData = generateTone(frequency: 440.0, duration: 1.0, amplitude: 0.5)
        let results = vad.detectVoiceActivity(in: toneData)
        
        for result in results {
            // 에너지 레벨은 0~1 범위여야 함
            XCTAssertGreaterThanOrEqual(result.energyLevel, 0.0)
            XCTAssertLessThanOrEqual(result.energyLevel, 1.0)
            
            // 신뢰도는 0~1 범위여야 함
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            
            // ZCR은 양수여야 함
            XCTAssertGreaterThanOrEqual(result.zeroCrossingRate, 0.0)
            
            // 스펙트럼 플럭스는 0 이상이어야 함
            XCTAssertGreaterThanOrEqual(result.spectralFlux, 0.0)
        }
    }
    
    func testVADPerformance() {
        let longAudioData = generateTone(frequency: 440.0, duration: 10.0, amplitude: 0.3)
        
        measure {
            let _ = vad.detectVoiceActivity(in: longAudioData)
        }
    }
    
    func testMinimumDurationConstraints() {
        // 매우 짧은 음성 버스트들
        let shortBursts = generateShortBursts()
        let results = vad.detectVoiceActivity(in: shortBursts)
        let segments = vad.createSegments(from: results)
        let speechSegments = vad.speechSegments(from: segments)
        
        // 최소 지속시간 이하의 세그먼트들은 필터링되어야 함
        for segment in speechSegments {
            XCTAssertGreaterThanOrEqual(
                segment.duration, 
                0.05, // minSpeechDuration
                "Speech segments should meet minimum duration requirement"
            )
        }
    }
    
    // MARK: - 적응적 임계값 테스트
    
    func testAdaptiveThresholds() {
        // 낮은 노이즈 환경
        let lowNoiseData = generateNoise(duration: 1.0, amplitude: 0.01)
        let lowNoiseResults = vad.detectVoiceActivity(in: lowNoiseData)
        
        vad.reset()
        
        // 높은 노이즈 환경
        let highNoiseData = generateNoise(duration: 1.0, amplitude: 0.1)
        let highNoiseResults = vad.detectVoiceActivity(in: highNoiseData)
        
        // 노이즈 레벨에 따라 적응적으로 동작해야 함
        let lowNoiseSpeechRatio = Double(lowNoiseResults.filter { $0.isSpeech }.count) / Double(lowNoiseResults.count)
        let highNoiseSpeechRatio = Double(highNoiseResults.filter { $0.isSpeech }.count) / Double(highNoiseResults.count)
        
        // 정확한 값보다는 상대적 차이를 확인
        XCTAssertNotEqual(lowNoiseSpeechRatio, highNoiseSpeechRatio, "VAD should adapt to different noise levels")
    }
    
    // MARK: - 신호 생성 헬퍼 메소드들
    
    private func generateSilence(duration: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        return Array(repeating: 0.0, count: sampleCount)
    }
    
    private func generateTone(frequency: Double, duration: Double, amplitude: Float) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var samples: [Float] = []
        
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let sample = amplitude * sin(2.0 * .pi * frequency * t)
            samples.append(Float(sample))
        }
        
        return samples
    }
    
    private func generateNoise(duration: Double, amplitude: Float) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var samples: [Float] = []
        
        for _ in 0..<sampleCount {
            let sample = amplitude * (Float.random(in: -1.0...1.0))
            samples.append(sample)
        }
        
        return samples
    }
    
    private func generateMixedSignal() -> [Float] {
        // 복합 신호: 음성 + 무음 + 노이즈 + 음성
        let speech1 = generateTone(frequency: 150.0, duration: 0.3, amplitude: 0.3)
        let silence1 = generateSilence(duration: 0.1)
        let noise = generateNoise(duration: 0.2, amplitude: 0.05)
        let speech2 = generateTone(frequency: 300.0, duration: 0.3, amplitude: 0.3)
        let silence2 = generateSilence(duration: 0.1)
        
        return speech1 + silence1 + noise + speech2 + silence2
    }
    
    private func generateShortBursts() -> [Float] {
        var result: [Float] = []
        
        // 매우 짧은 음성 버스트들 (10ms씩)
        for i in 0..<10 {
            let burst = generateTone(frequency: 200.0 + Double(i * 50), duration: 0.01, amplitude: 0.3)
            let gap = generateSilence(duration: 0.02)
            result.append(contentsOf: burst)
            result.append(contentsOf: gap)
        }
        
        return result
    }
}

// MARK: - 통합 테스트

extension VoiceActivityDetectorTests {
    
    func testVADIntegrationWithSyllableAnalysis() {
        // VAD가 SyllableAnalysisUseCase와 잘 통합되는지 테스트
        let speechPattern = generateSpeechPattern()
        let results = vad.detectVoiceActivity(in: speechPattern)
        let segments = vad.createSegments(from: results)
        let speechSegments = vad.speechSegments(from: segments)
        
        XCTAssertFalse(speechSegments.isEmpty, "Should detect speech segments for syllable analysis")
        
        // 각 음성 세그먼트는 음절 분석에 적합한 길이여야 함
        for segment in speechSegments {
            XCTAssertGreaterThan(segment.duration, 0.05, "Segments should be long enough for syllable analysis")
            XCTAssertGreaterThan(segment.averageConfidence, 0.3, "Segments should have sufficient confidence")
        }
    }
    
    private func generateSpeechPattern() -> [Float] {
        // 한국어 "안녕하세요" 비슷한 패턴 시뮬레이션
        let syllable1 = generateTone(frequency: 150.0, duration: 0.15, amplitude: 0.4) // "안"
        let gap1 = generateSilence(duration: 0.03)
        let syllable2 = generateTone(frequency: 200.0, duration: 0.12, amplitude: 0.3) // "녕"
        let gap2 = generateSilence(duration: 0.02)
        let syllable3 = generateTone(frequency: 180.0, duration: 0.14, amplitude: 0.35) // "하"
        let gap3 = generateSilence(duration: 0.03)
        let syllable4 = generateTone(frequency: 220.0, duration: 0.13, amplitude: 0.3) // "세"
        let gap4 = generateSilence(duration: 0.02)
        let syllable5 = generateTone(frequency: 170.0, duration: 0.16, amplitude: 0.3) // "요"
        
        return syllable1 + gap1 + syllable2 + gap2 + syllable3 + gap3 + syllable4 + gap4 + syllable5
    }
} 