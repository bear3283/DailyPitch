import XCTest
import Combine
@testable import DailyPitch

final class AnalyzeFrequencyUseCaseTests: XCTestCase {
    
    private var sut: AnalyzeFrequencyUseCase!
    private var mockRepository: MockAudioAnalysisRepository!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockAudioAnalysisRepository()
        sut = AnalyzeFrequencyUseCase(audioAnalysisRepository: mockRepository)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Audio Session Analysis Tests
    
    func test_analyzeAudioSession_whenValidSession_shouldReturnAnalysisResult() {
        // Given
        let audioSession = createValidAudioSession()
        let expectedResult = createSampleAnalysisResult(for: audioSession)
        mockRepository.mockAnalysisResult = expectedResult
        
        let expectation = XCTestExpectation(description: "Analysis should complete successfully")
        var receivedResult: AudioAnalysisResult?
        
        // When
        sut.analyzeAudioSession(audioSession)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Analysis should not fail")
                    }
                },
                receiveValue: { result in
                    receivedResult = result
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedResult)
        XCTAssertEqual(mockRepository.analyzeAudioCallCount, 1)
        XCTAssertEqual(mockRepository.lastAnalyzedAudioSession?.id, audioSession.id)
    }
    
    func test_analyzeAudioSession_whenNoAudioFile_shouldFail() {
        // Given
        var audioSession = createValidAudioSession()
        audioSession = AudioSession(
            id: audioSession.id,
            timestamp: audioSession.timestamp,
            duration: audioSession.duration,
            audioFileURL: nil, // 파일 없음
            sampleRate: audioSession.sampleRate,
            channelCount: audioSession.channelCount
        )
        
        let expectation = XCTestExpectation(description: "Analysis should fail")
        var receivedError: AudioAnalysisError?
        
        // When
        sut.analyzeAudioSession(audioSession)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive result when file is missing")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .fileReadError)
        XCTAssertEqual(mockRepository.analyzeAudioCallCount, 0)
    }
    
    func test_analyzeAudioSession_whenZeroDuration_shouldFail() {
        // Given
        var audioSession = createValidAudioSession()
        audioSession = AudioSession(
            id: audioSession.id,
            timestamp: audioSession.timestamp,
            duration: 0, // 지속시간 0
            audioFileURL: audioSession.audioFileURL,
            sampleRate: audioSession.sampleRate,
            channelCount: audioSession.channelCount
        )
        
        let expectation = XCTestExpectation(description: "Analysis should fail")
        var receivedError: AudioAnalysisError?
        
        // When
        sut.analyzeAudioSession(audioSession)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive result when duration is zero")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .insufficientData)
        XCTAssertEqual(mockRepository.analyzeAudioCallCount, 0)
    }
    
    // MARK: - Raw Audio Data Analysis Tests
    
    func test_analyzeRawAudioData_whenValidData_shouldReturnFrequencyData() {
        // Given
        let audioData: [Float] = Array(0..<1024).map { _ in Float.random(in: -1...1) }
        let sampleRate: Double = 44100.0
        let expectedFrequencyData = createSampleFrequencyData(sampleRate: sampleRate)
        mockRepository.mockFrequencyData = expectedFrequencyData
        
        let expectation = XCTestExpectation(description: "Data analysis should complete")
        var receivedData: FrequencyData?
        
        // When
        sut.analyzeRawAudioData(audioData, sampleRate: sampleRate)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Analysis should not fail")
                    }
                },
                receiveValue: { data in
                    receivedData = data
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedData)
        XCTAssertEqual(mockRepository.analyzeAudioDataCallCount, 1)
        XCTAssertEqual(mockRepository.lastAnalyzedAudioData?.count, audioData.count)
        XCTAssertEqual(mockRepository.lastAnalyzedSampleRate, sampleRate)
    }
    
    func test_analyzeRawAudioData_whenEmptyData_shouldFail() {
        // Given
        let audioData: [Float] = []
        let sampleRate: Double = 44100.0
        
        let expectation = XCTestExpectation(description: "Analysis should fail")
        var receivedError: AudioAnalysisError?
        
        // When
        sut.analyzeRawAudioData(audioData, sampleRate: sampleRate)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive result with empty data")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .insufficientData)
        XCTAssertEqual(mockRepository.analyzeAudioDataCallCount, 0)
    }
    
    func test_analyzeRawAudioData_whenInvalidSampleRate_shouldFail() {
        // Given
        let audioData: [Float] = [1.0, 2.0, 3.0]
        let sampleRate: Double = 0 // 유효하지 않은 샘플 레이트
        
        let expectation = XCTestExpectation(description: "Analysis should fail")
        var receivedError: AudioAnalysisError?
        
        // When
        sut.analyzeRawAudioData(audioData, sampleRate: sampleRate)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive result with invalid sample rate")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .invalidAudioData)
        XCTAssertEqual(mockRepository.analyzeAudioDataCallCount, 0)
    }
    
    // MARK: - Realtime Analysis Tests
    
    func test_startRealtimeAnalysis_whenValidParameters_shouldStartAnalysis() {
        // Given
        let sampleRate: Double = 44100.0
        let expectedData = createSampleFrequencyData(sampleRate: sampleRate)
        mockRepository.mockFrequencyData = expectedData
        
        let expectation = XCTestExpectation(description: "Realtime analysis should start")
        var receivedDataCount = 0
        
        // When
        sut.startRealtimeAnalysis(sampleRate: sampleRate)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    receivedDataCount += 1
                    if receivedDataCount >= 2 {
                        expectation.fulfill()
                    }
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(mockRepository.startRealtimeAnalysisCallCount, 1)
        XCTAssertTrue(sut.isCurrentlyAnalyzing)
        XCTAssertTrue(receivedDataCount >= 2)
    }
    
    func test_stopRealtimeAnalysis_shouldStopAnalysis() {
        // Given
        sut.startRealtimeAnalysis()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        // When
        sut.stopRealtimeAnalysis()
        
        // Then
        XCTAssertEqual(mockRepository.stopRealtimeAnalysisCallCount, 1)
        XCTAssertFalse(sut.isCurrentlyAnalyzing)
    }
    
    // MARK: - Noise Filtering Tests
    
    func test_filterNoise_whenHighMagnitude_shouldKeepData() {
        // Given
        let audioSession = createValidAudioSession()
        let highMagnitudeData = FrequencyData(
            frequencies: [440.0],
            magnitudes: [1.0], // 높은 진폭
            sampleRate: 44100.0,
            windowSize: 1024
        )
        
        let result = AudioAnalysisResult(
            audioSession: audioSession,
            frequencyDataSequence: [highMagnitudeData],
            status: .completed
        )
        
        // When
        let filteredResult = sut.filterNoise(from: result, threshold: 0.5)
        
        // Then
        XCTAssertEqual(filteredResult.frequencyDataSequence.count, 1)
    }
    
    func test_filterNoise_whenLowMagnitude_shouldRemoveData() {
        // Given
        let audioSession = createValidAudioSession()
        let lowMagnitudeData = FrequencyData(
            frequencies: [440.0],
            magnitudes: [0.05], // 낮은 진폭
            sampleRate: 44100.0,
            windowSize: 1024
        )
        
        let result = AudioAnalysisResult(
            audioSession: audioSession,
            frequencyDataSequence: [lowMagnitudeData],
            status: .completed
        )
        
        // When
        let filteredResult = sut.filterNoise(from: result, threshold: 0.1)
        
        // Then
        XCTAssertEqual(filteredResult.frequencyDataSequence.count, 0)
    }
    
    // MARK: - Frequency Range Extraction Tests
    
    func test_extractFrequencyRange_shouldReturnOnlySpecifiedRange() {
        // Given
        let audioSession = createValidAudioSession()
        let frequencyData = FrequencyData(
            frequencies: [100.0, 440.0, 1000.0, 2000.0],
            magnitudes: [0.5, 1.0, 0.8, 0.3],
            sampleRate: 44100.0,
            windowSize: 1024
        )
        
        let result = AudioAnalysisResult(
            audioSession: audioSession,
            frequencyDataSequence: [frequencyData],
            status: .completed
        )
        
        // When - 200Hz ~ 800Hz 범위만 추출
        let extractedResult = sut.extractFrequencyRange(from: result, range: 200.0...800.0)
        
        // Then
        XCTAssertEqual(extractedResult.frequencyDataSequence.count, 1)
        let extractedData = extractedResult.frequencyDataSequence[0]
        XCTAssertEqual(extractedData.frequencies, [440.0]) // 440Hz만 범위 내
        XCTAssertEqual(extractedData.magnitudes, [1.0])
    }
    
    // MARK: - Helper Methods
    
    private func createValidAudioSession() -> AudioSession {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_audio.m4a")
        
        // 임시 파일 생성 (실제 파일은 없지만 경로는 유효)
        return AudioSession(
            duration: 5.0,
            audioFileURL: tempURL,
            sampleRate: 44100.0,
            channelCount: 1
        )
    }
    
    private func createSampleAnalysisResult(for audioSession: AudioSession) -> AudioAnalysisResult {
        let frequencyData = createSampleFrequencyData(sampleRate: audioSession.sampleRate)
        
        return AudioAnalysisResult(
            audioSession: audioSession,
            frequencyDataSequence: [frequencyData],
            status: .completed,
            analysisStartTime: Date().addingTimeInterval(-1),
            analysisEndTime: Date()
        )
    }
    
    private func createSampleFrequencyData(sampleRate: Double) -> FrequencyData {
        return FrequencyData(
            frequencies: [440.0, 880.0, 1320.0],
            magnitudes: [1.0, 0.5, 0.3],
            sampleRate: sampleRate,
            windowSize: 1024
        )
    }
} 