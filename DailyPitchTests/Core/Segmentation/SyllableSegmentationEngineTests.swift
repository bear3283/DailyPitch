import XCTest
import AVFoundation
@testable import DailyPitch

/// SyllableSegmentationEngine 테스트 클래스
/// 고급 음절 세그멘테이션의 정확도와 성능을 종합적으로 검증
class SyllableSegmentationEngineTests: XCTestCase {
    
    var segmentationEngine: SyllableSegmentationEngine!
    var mockVAD: VoiceActivityDetector!
    let sampleRate: Double = 44100.0
    let frameSize: Int = 1024
    
    override func setUp() {
        super.setUp()
        
        // 테스트용 세그멘테이션 설정
        let testConfig = SyllableSegmentationEngine.SegmentationConfiguration.korean
        
        segmentationEngine = SyllableSegmentationEngine(
            configuration: testConfig,
            sampleRate: sampleRate,
            frameSize: frameSize
        )
        
        // 테스트용 VAD 설정
        let vadConfig = VoiceActivityDetector.VADConfiguration.default
        mockVAD = VoiceActivityDetector(
            configuration: vadConfig,
            sampleRate: sampleRate,
            frameSize: frameSize
        )
    }
    
    override func tearDown() {
        segmentationEngine = nil
        mockVAD = nil
        super.tearDown()
    }
    
    // MARK: - 기본 기능 테스트
    
    func testSegmentationEngineInitialization() {
        XCTAssertNotNil(segmentationEngine, "SyllableSegmentationEngine should initialize successfully")
    }
    
    func testSingleSyllableSegmentation() {
        // 단일 음절 시뮬레이션 ("안")
        let singleSyllableAudio = generateSingleSyllable(frequency: 150.0, duration: 0.2)
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 0.2, confidence: 0.8)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: singleSyllableAudio
        )
        
        XCTAssertEqual(result.syllableBoundaries.count, 2, "Single syllable should have start and end boundaries")
        XCTAssertGreaterThan(result.confidence, 0.5, "Single syllable segmentation should have good confidence")
        XCTAssertEqual(result.method, .hybrid, "Should use hybrid method")
    }
    
    func testMultiSyllableSegmentation() {
        // 다중 음절 시뮬레이션 ("안녕하세요")
        let multiSyllableAudio = generateMultiSyllableSequence()
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 1.0, confidence: 0.9)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: multiSyllableAudio
        )
        
        // 5개 음절 + 시작/끝 = 6개 경계 예상
        XCTAssertGreaterThanOrEqual(result.syllableBoundaries.count, 3, "Multi-syllable should have multiple boundaries")
        XCTAssertLessThanOrEqual(result.syllableBoundaries.count, 7, "Should not over-segment")
        
        // 경계들이 시간 순서대로 정렬되어 있는지 확인
        for i in 1..<result.syllableBoundaries.count {
            XCTAssertGreaterThan(result.syllableBoundaries[i], result.syllableBoundaries[i-1], 
                               "Boundaries should be in chronological order")
        }
    }
    
    func testEnergyBasedSegmentation() {
        // 에너지 변화가 뚜렷한 신호
        let energyVariableAudio = generateEnergyVariableSignal()
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 0.8, confidence: 0.8)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: energyVariableAudio
        )
        
        XCTAssertGreaterThan(result.syllableBoundaries.count, 2, "Energy-variable signal should be segmented")
        XCTAssertFalse(result.energyProfile.isEmpty, "Should provide energy profile")
        
        // 에너지 프로파일 유효성 검증
        for energy in result.energyProfile {
            XCTAssertGreaterThanOrEqual(energy, 0.0, "Energy should be non-negative")
        }
    }
    
    func testSpectralBasedSegmentation() {
        // 스펙트럼 변화가 뚜렷한 신호 (주파수 변화)
        let spectralVariableAudio = generateSpectralVariableSignal()
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 0.6, confidence: 0.7)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: spectralVariableAudio
        )
        
        XCTAssertGreaterThan(result.syllableBoundaries.count, 2, "Spectral-variable signal should be segmented")
        XCTAssertFalse(result.spectralCentroidProfile.isEmpty, "Should provide spectral centroid profile")
        
        // 스펙트럼 중심 프로파일 유효성 검증
        for centroid in result.spectralCentroidProfile {
            XCTAssertGreaterThanOrEqual(centroid, 0.0, "Spectral centroid should be non-negative")
            XCTAssertLessThan(centroid, sampleRate / 2, "Spectral centroid should be below Nyquist frequency")
        }
    }
    
    // MARK: - 한국어 최적화 테스트
    
    func testKoreanOptimization() {
        // 한국어 특성을 반영한 신호 (자음-모음 패턴)
        let koreanPatternAudio = generateKoreanSpeechPattern()
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 1.2, confidence: 0.85)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: koreanPatternAudio
        )
        
        // 한국어 평균 음절 지속시간 확인 (0.1~0.4초)
        for i in 0..<result.syllableBoundaries.count - 1 {
            let syllableDuration = result.syllableBoundaries[i + 1] - result.syllableBoundaries[i]
            XCTAssertGreaterThanOrEqual(syllableDuration, 0.08, "Korean syllables should meet minimum duration")
            XCTAssertLessThanOrEqual(syllableDuration, 0.6, "Korean syllables should not exceed maximum duration")
        }
    }
    
    func testMinimumSyllableDuration() {
        // 매우 짧은 버스트들 포함
        let shortBurstAudio = generateShortBurstSequence()
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 0.5, confidence: 0.6)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: shortBurstAudio
        )
        
        // 최소 지속시간 이하의 세그먼트들은 병합되어야 함
        for i in 0..<result.syllableBoundaries.count - 1 {
            let syllableDuration = result.syllableBoundaries[i + 1] - result.syllableBoundaries[i]
            XCTAssertGreaterThanOrEqual(syllableDuration, 0.08, 
                                      "All syllables should meet minimum duration after merging")
        }
    }
    
    // MARK: - 일괄 처리 테스트
    
    func testMultipleSegmentProcessing() {
        // 여러 VAD 세그먼트들
        let audioData = generateComplexSpeechSequence()
        let vadResults = mockVAD.detectVoiceActivity(in: audioData)
        let vadSegments = mockVAD.createSegments(from: vadResults)
        let speechSegments = mockVAD.speechSegments(from: vadSegments)
        
        let results = segmentationEngine.segmentMultipleSpeechSegments(
            vadSegments: speechSegments,
            audioData: audioData
        )
        
        XCTAssertEqual(results.count, speechSegments.count, 
                      "Should process all input segments")
        
        // 각 결과의 유효성 검증
        for result in results {
            XCTAssertGreaterThanOrEqual(result.syllableBoundaries.count, 2, 
                                      "Each segment should have at least start/end boundaries")
            XCTAssertGreaterThan(result.confidence, 0.0, 
                               "Each result should have positive confidence")
        }
    }
    
    // MARK: - 품질 및 성능 테스트
    
    func testSegmentationConfidence() {
        // 고품질 신호
        let highQualityAudio = generateHighQualitySignal()
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 0.8, confidence: 0.95)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: highQualityAudio
        )
        
        XCTAssertGreaterThan(result.confidence, 0.6, "High-quality signal should have high confidence")
        
        // 저품질 신호
        let lowQualityAudio = generateNoisySignal()
        let noisyVADSegment = createMockVADSegment(startTime: 0.0, endTime: 0.8, confidence: 0.4)
        
        let noisyResult = segmentationEngine.segmentIntoSyllables(
            vadSegment: noisyVADSegment,
            audioData: lowQualityAudio
        )
        
        XCTAssertLessThan(noisyResult.confidence, result.confidence, 
                         "Noisy signal should have lower confidence than clean signal")
    }
    
    func testSegmentationPerformance() {
        let longAudioData = generateLongSpeechSequence(duration: 10.0)
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 10.0, confidence: 0.8)
        
        measure {
            let _ = segmentationEngine.segmentIntoSyllables(
                vadSegment: vadSegment,
                audioData: longAudioData
            )
        }
    }
    
    func testBoundaryAccuracy() {
        // 알려진 경계를 가진 합성 신호
        let knownBoundaryAudio = generateKnownBoundarySignal()
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 1.0, confidence: 0.9)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: knownBoundaryAudio
        )
        
        // 예상 경계: 0.0, 0.25, 0.5, 0.75, 1.0 (0.25초 간격 4개 음절)
        let expectedBoundaries = [0.0, 0.25, 0.5, 0.75, 1.0]
        let tolerance = 0.05 // 50ms 허용 오차
        
        XCTAssertEqual(result.syllableBoundaries.count, expectedBoundaries.count, 
                      "Should detect expected number of boundaries")
        
        // 경계 정확도 검증 (순서는 무시하고 가장 가까운 매칭)
        for expectedBoundary in expectedBoundaries {
            let closestActual = result.syllableBoundaries.min { boundary in
                abs(boundary - expectedBoundary) < abs($1 - expectedBoundary)
            }
            
            if let closest = closestActual {
                let error = abs(closest - expectedBoundary)
                XCTAssertLessThan(error, tolerance, 
                                "Boundary detection should be within tolerance")
            }
        }
    }
    
    // MARK: - 에지 케이스 테스트
    
    func testEmptyAudioData() {
        let emptyAudio: [Float] = []
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 0.0, confidence: 0.0)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: emptyAudio
        )
        
        // 빈 데이터는 최소한의 경계만 가져야 함
        XCTAssertLessThanOrEqual(result.syllableBoundaries.count, 2, 
                               "Empty audio should have minimal boundaries")
    }
    
    func testVeryShortAudio() {
        let shortAudio = generateTone(frequency: 200.0, duration: 0.01, amplitude: 0.3)
        let vadSegment = createMockVADSegment(startTime: 0.0, endTime: 0.01, confidence: 0.5)
        
        let result = segmentationEngine.segmentIntoSyllables(
            vadSegment: vadSegment,
            audioData: shortAudio
        )
        
        XCTAssertEqual(result.syllableBoundaries.count, 2, 
                      "Very short audio should have start and end boundaries only")
    }
    
    // MARK: - 헬퍼 메소드들
    
    private func createMockVADSegment(startTime: TimeInterval, endTime: TimeInterval, confidence: Double) -> VoiceActivityDetector.VADSegment {
        return VoiceActivityDetector.VADSegment(
            startTime: startTime,
            endTime: endTime,
            isSpeech: true,
            averageConfidence: confidence,
            averageEnergy: 0.5
        )
    }
    
    private func generateSingleSyllable(frequency: Double, duration: TimeInterval) -> [Float] {
        return generateTone(frequency: frequency, duration: duration, amplitude: 0.4)
    }
    
    private func generateMultiSyllableSequence() -> [Float] {
        // "안녕하세요" 패턴 시뮬레이션
        let syllable1 = generateTone(frequency: 150.0, duration: 0.15, amplitude: 0.4) // "안"
        let gap1 = generateSilence(duration: 0.03)
        let syllable2 = generateTone(frequency: 200.0, duration: 0.12, amplitude: 0.35) // "녕"
        let gap2 = generateSilence(duration: 0.025)
        let syllable3 = generateTone(frequency: 180.0, duration: 0.14, amplitude: 0.38) // "하"
        let gap3 = generateSilence(duration: 0.03)
        let syllable4 = generateTone(frequency: 220.0, duration: 0.13, amplitude: 0.36) // "세"
        let gap4 = generateSilence(duration: 0.025)
        let syllable5 = generateTone(frequency: 170.0, duration: 0.16, amplitude: 0.37) // "요"
        
        return syllable1 + gap1 + syllable2 + gap2 + syllable3 + gap3 + syllable4 + gap4 + syllable5
    }
    
    private func generateEnergyVariableSignal() -> [Float] {
        // 에너지가 급격히 변하는 신호
        let highEnergy = generateTone(frequency: 200.0, duration: 0.2, amplitude: 0.6)
        let lowEnergy = generateTone(frequency: 200.0, duration: 0.2, amplitude: 0.2)
        let mediumEnergy = generateTone(frequency: 200.0, duration: 0.2, amplitude: 0.4)
        
        return highEnergy + lowEnergy + mediumEnergy
    }
    
    private func generateSpectralVariableSignal() -> [Float] {
        // 주파수가 급격히 변하는 신호
        let lowFreq = generateTone(frequency: 150.0, duration: 0.15, amplitude: 0.4)
        let highFreq = generateTone(frequency: 400.0, duration: 0.15, amplitude: 0.4)
        let midFreq = generateTone(frequency: 250.0, duration: 0.15, amplitude: 0.4)
        
        return lowFreq + highFreq + midFreq
    }
    
    private func generateKoreanSpeechPattern() -> [Float] {
        // 한국어 자음-모음 패턴을 반영한 복합 신호
        var pattern: [Float] = []
        
        // 4개 음절, 각각 자음-모음 구조
        for i in 0..<4 {
            // 자음 부분 (짧고 노이즈 성분)
            let consonant = generateNoise(duration: 0.04, amplitude: 0.2)
            // 모음 부분 (길고 톤 성분)
            let vowel = generateTone(frequency: 150.0 + Double(i * 30), duration: 0.12, amplitude: 0.4)
            // 음절간 간격
            let gap = generateSilence(duration: 0.03)
            
            pattern.append(contentsOf: consonant + vowel + gap)
        }
        
        return pattern
    }
    
    private func generateShortBurstSequence() -> [Float] {
        var sequence: [Float] = []
        
        // 매우 짧은 버스트들 (병합 테스트용)
        for i in 0..<8 {
            let burst = generateTone(frequency: 200.0 + Double(i * 25), duration: 0.02, amplitude: 0.3)
            let gap = generateSilence(duration: 0.01)
            sequence.append(contentsOf: burst + gap)
        }
        
        return sequence
    }
    
    private func generateComplexSpeechSequence() -> [Float] {
        // 여러 음성 구간이 포함된 복합 신호
        let speech1 = generateMultiSyllableSequence()
        let silence1 = generateSilence(duration: 0.3)
        let speech2 = generateKoreanSpeechPattern()
        let silence2 = generateSilence(duration: 0.2)
        let speech3 = generateEnergyVariableSignal()
        
        return speech1 + silence1 + speech2 + silence2 + speech3
    }
    
    private func generateHighQualitySignal() -> [Float] {
        // 깨끗하고 뚜렷한 음절 경계를 가진 신호
        let clear1 = generateTone(frequency: 180.0, duration: 0.2, amplitude: 0.5)
        let clearGap = generateSilence(duration: 0.05)
        let clear2 = generateTone(frequency: 220.0, duration: 0.2, amplitude: 0.5)
        let clear3 = generateTone(frequency: 160.0, duration: 0.2, amplitude: 0.5)
        
        return clear1 + clearGap + clear2 + clearGap + clear3
    }
    
    private func generateNoisySignal() -> [Float] {
        // 노이즈가 많은 신호
        let signal = generateTone(frequency: 200.0, duration: 0.8, amplitude: 0.3)
        let noise = generateNoise(duration: 0.8, amplitude: 0.15)
        
        return zip(signal, noise).map { $0 + $1 }
    }
    
    private func generateLongSpeechSequence(duration: TimeInterval) -> [Float] {
        var longSequence: [Float] = []
        let segmentDuration = 0.5
        let segmentCount = Int(duration / segmentDuration)
        
        for i in 0..<segmentCount {
            let segment = generateMultiSyllableSequence()
            let pause = generateSilence(duration: 0.1)
            longSequence.append(contentsOf: segment + pause)
        }
        
        return longSequence
    }
    
    private func generateKnownBoundarySignal() -> [Float] {
        // 정확히 0.25초 간격으로 경계가 있는 신호
        let seg1 = generateTone(frequency: 150.0, duration: 0.25, amplitude: 0.4)
        let seg2 = generateTone(frequency: 200.0, duration: 0.25, amplitude: 0.4)
        let seg3 = generateTone(frequency: 180.0, duration: 0.25, amplitude: 0.4)
        let seg4 = generateTone(frequency: 220.0, duration: 0.25, amplitude: 0.4)
        
        return seg1 + seg2 + seg3 + seg4
    }
    
    // 기본 신호 생성 헬퍼들
    private func generateTone(frequency: Double, duration: TimeInterval, amplitude: Float) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var samples: [Float] = []
        
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let sample = amplitude * sin(2.0 * .pi * frequency * t)
            samples.append(Float(sample))
        }
        
        return samples
    }
    
    private func generateSilence(duration: TimeInterval) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        return Array(repeating: 0.0, count: sampleCount)
    }
    
    private func generateNoise(duration: TimeInterval, amplitude: Float) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var samples: [Float] = []
        
        for _ in 0..<sampleCount {
            let sample = amplitude * (Float.random(in: -1.0...1.0))
            samples.append(sample)
        }
        
        return samples
    }
} 