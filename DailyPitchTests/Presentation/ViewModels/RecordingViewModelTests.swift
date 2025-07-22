import XCTest
import Combine
@testable import DailyPitch

/// RecordingViewModel의 단위 테스트
@MainActor
final class RecordingViewModelTests: XCTestCase {
    
    // MARK: - Properties
    private var sut: RecordingViewModel!
    private var mockRecordAudioUseCase: MockRecordAudioUseCase!
    private var mockAnalyzeFrequencyUseCase: MockAnalyzeFrequencyUseCase!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockRecordAudioUseCase = MockRecordAudioUseCase()
        mockAnalyzeFrequencyUseCase = MockAnalyzeFrequencyUseCase()
        cancellables = Set<AnyCancellable>()
        
        sut = RecordingViewModel(
            recordAudioUseCase: mockRecordAudioUseCase,
            analyzeFrequencyUseCase: mockAnalyzeFrequencyUseCase
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        sut = nil
        mockAnalyzeFrequencyUseCase = nil
        mockRecordAudioUseCase = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Given & When: 초기화
        
        // Then: 초기 상태가 올바른지 확인
        XCTAssertFalse(sut.isRecording)
        XCTAssertEqual(sut.recordingDuration, 0)
        XCTAssertEqual(sut.permissionStatus, .notDetermined)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.currentAudioSession)
        XCTAssertFalse(sut.showingPermissionAlert)
        XCTAssertFalse(sut.isAnalyzing)
        XCTAssertNil(sut.analysisResult)
        XCTAssertNil(sut.peakFrequency)
        XCTAssertNil(sut.detectedNote)
        XCTAssertNil(sut.frequencyAccuracy)
        XCTAssertEqual(sut.analysisProgress, 0.0)
    }
    
    // MARK: - Computed Properties Tests
    
    func testRecordingTimeString() {
        // Given: 다양한 녹음 시간
        let testCases: [(TimeInterval, String)] = [
            (0, "00:00"),
            (30, "00:30"),
            (65, "01:05"),
            (125, "02:05"),
            (3661, "61:01")
        ]
        
        // When & Then: 각 시간이 올바르게 포맷되는지 확인
        for (duration, expectedString) in testCases {
            sut.recordingDuration = duration
            XCTAssertEqual(sut.recordingTimeString, expectedString, "Duration \(duration) should format to \(expectedString)")
        }
    }
    
    func testCanStartRecording() {
        // Given: 권한이 허용되지 않은 상태
        sut.permissionStatus = .denied
        
        // Then: 녹음을 시작할 수 없어야 함
        XCTAssertFalse(sut.canStartRecording)
        
        // Given: 권한은 있지만 이미 녹음 중인 상태
        sut.permissionStatus = .granted
        sut.isRecording = true
        
        // Then: 녹음을 시작할 수 없어야 함
        XCTAssertFalse(sut.canStartRecording)
        
        // Given: 권한은 있지만 분석 중인 상태
        sut.isRecording = false
        sut.isAnalyzing = true
        
        // Then: 녹음을 시작할 수 없어야 함
        XCTAssertFalse(sut.canStartRecording)
        
        // Given: 모든 조건이 만족되는 상태
        sut.isAnalyzing = false
        
        // Then: 녹음을 시작할 수 있어야 함
        XCTAssertTrue(sut.canStartRecording)
    }
    
    func testRecordButtonTitle() {
        // Given: 분석 중인 상태
        sut.isAnalyzing = true
        
        // Then: 분석 중 메시지
        XCTAssertEqual(sut.recordButtonTitle, "분석 중...")
        
        // Given: 녹음 중인 상태
        sut.isAnalyzing = false
        sut.isRecording = true
        
        // Then: 녹음 중지 메시지
        XCTAssertEqual(sut.recordButtonTitle, "녹음 중지")
        
        // Given: 권한이 허용된 상태
        sut.isRecording = false
        sut.permissionStatus = .granted
        
        // Then: 녹음 시작 메시지
        XCTAssertEqual(sut.recordButtonTitle, "녹음 시작")
        
        // Given: 권한이 없는 상태
        sut.permissionStatus = .denied
        
        // Then: 권한 필요 메시지
        XCTAssertEqual(sut.recordButtonTitle, "권한 필요")
    }
    
    func testStatusMessage() {
        // Given: 분석 중인 상태
        sut.isAnalyzing = true
        sut.analysisProgress = 0.5
        
        // Then: 분석 진행률이 포함된 메시지
        XCTAssertEqual(sut.statusMessage, "주파수 분석 중... 50%")
        
        // Given: 분석 완료 상태 (음계 감지됨)
        sut.isAnalyzing = false
        let analysisResult = AudioAnalysisResult(
            isSuccessful: true,
            peakFrequencies: [440.0, 880.0, 1320.0],
            averagePeakFrequency: 440.0,
            frequencyRange: (80.0, 2000.0),
            analysisQuality: 0.95,
            dataPointCount: 1024,
            processingTime: 0.5,
            sampleRate: 44100.0
        )
        sut.analysisResult = analysisResult
        sut.detectedNote = "A4"
        sut.peakFrequency = 440.0
        
        // Then: 감지된 음계 정보
        XCTAssertEqual(sut.statusMessage, "감지된 음계: A4 (440.0Hz)")
        
        // Given: 분석 완료 상태 (음계 미감지)
        sut.detectedNote = nil
        sut.peakFrequency = nil
        
        // Then: 분석 완료 메시지
        XCTAssertEqual(sut.statusMessage, "분석 완료")
        
        // Given: 녹음 중인 상태
        sut.analysisResult = nil
        sut.isRecording = true
        
        // Then: 녹음 중 메시지
        XCTAssertEqual(sut.statusMessage, "녹음 중... (최대 60초)")
        
        // Given: 기본 상태
        sut.isRecording = false
        
        // Then: 기본 메시지
        XCTAssertEqual(sut.statusMessage, "녹음 버튼을 눌러 시작하세요")
    }
    
    func testHasAnalysisResult() {
        // Given: 분석 결과가 없는 상태
        sut.analysisResult = nil
        
        // Then: false
        XCTAssertFalse(sut.hasAnalysisResult)
        
        // Given: 실패한 분석 결과
        sut.analysisResult = AudioAnalysisResult(
            isSuccessful: false,
            peakFrequencies: [],
            averagePeakFrequency: nil,
            frequencyRange: (0.0, 0.0),
            analysisQuality: 0.0,
            dataPointCount: 0,
            processingTime: 0.0,
            sampleRate: 44100.0
        )
        
        // Then: false
        XCTAssertFalse(sut.hasAnalysisResult)
        
        // Given: 성공한 분석 결과
        sut.analysisResult = AudioAnalysisResult(
            isSuccessful: true,
            peakFrequencies: [440.0, 880.0, 1320.0],
            averagePeakFrequency: 440.0,
            frequencyRange: (80.0, 2000.0),
            analysisQuality: 0.95,
            dataPointCount: 1024,
            processingTime: 0.5,
            sampleRate: 44100.0
        )
        
        // Then: true
        XCTAssertTrue(sut.hasAnalysisResult)
    }
    
    // MARK: - Permission Tests
    
    func testRequestPermission_Success() {
        // Given: 권한 요청이 성공하는 상황
        mockRecordAudioUseCase.shouldGrantPermission = true
        
        let expectation = XCTestExpectation(description: "Permission granted")
        
        // When: 권한 요청
        sut.requestPermission()
        
        // Then: 권한 상태가 변경되어야 함
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.sut.permissionStatus, .granted)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRequestPermission_Denied() {
        // Given: 권한 요청이 거부되는 상황
        mockRecordAudioUseCase.shouldGrantPermission = false
        
        let expectation = XCTestExpectation(description: "Permission denied")
        
        // When: 권한 요청
        sut.requestPermission()
        
        // Then: 권한 상태와 알림이 변경되어야 함
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.sut.permissionStatus, .denied)
            XCTAssertTrue(self.sut.showingPermissionAlert)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Recording Tests
    
    func testRecordButtonTapped_WithoutPermission() {
        // Given: 권한이 없는 상태
        sut.permissionStatus = .denied
        
        // When: 녹음 버튼 탭
        sut.recordButtonTapped()
        
        // Then: 권한 알림이 표시되어야 함
        XCTAssertTrue(sut.showingPermissionAlert)
        XCTAssertFalse(sut.isRecording)
    }
    
    func testRecordButtonTapped_StartRecording() async {
        // Given: 권한이 있고 녹음 중이 아닌 상태
        sut.permissionStatus = .granted
        sut.isRecording = false
        mockRecordAudioUseCase.shouldSucceedRecording = true
        
        // When: 녹음 버튼 탭
        sut.recordButtonTapped()
        
        // Then: 녹음이 시작되어야 함
        await Task.yield() // Allow async operations to complete
        
        XCTAssertTrue(mockRecordAudioUseCase.startRecordingCalled)
        XCTAssertNotNil(sut.currentAudioSession)
    }
    
    func testRecordButtonTapped_StopRecording() async {
        // Given: 녹음 중인 상태
        sut.permissionStatus = .granted
        sut.isRecording = true
        mockRecordAudioUseCase.shouldSucceedRecording = true
        
        // When: 녹음 버튼 탭
        sut.recordButtonTapped()
        
        // Then: 녹음이 중지되어야 함
        await Task.yield() // Allow async operations to complete
        
        XCTAssertTrue(mockRecordAudioUseCase.stopRecordingCalled)
    }
    
    // MARK: - Analysis Tests
    
    func testStartAnalysis_WithoutAudioSession() {
        // Given: 오디오 세션이 없는 상태
        sut.currentAudioSession = nil
        
        // When: 분석 시작
        sut.startAnalysis()
        
        // Then: 에러 메시지가 표시되어야 함
        XCTAssertEqual(sut.errorMessage, "분석할 오디오가 없습니다.")
        XCTAssertFalse(sut.isAnalyzing)
    }
    
    func testStartAnalysis_Success() async {
        // Given: 오디오 세션이 있는 상태
        sut.currentAudioSession = AudioSession(
            id: UUID().uuidString,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3.0),
            sampleRate: 44100.0,
            audioFileURL: URL(string: "file:///test.wav")
        )
        mockAnalyzeFrequencyUseCase.shouldSucceedAnalysis = true
        
        // When: 분석 시작
        sut.startAnalysis()
        
        // Then: 분석이 시작되어야 함
        XCTAssertTrue(sut.isAnalyzing)
        XCTAssertEqual(sut.analysisProgress, 0.0)
        
        // Wait for analysis to complete
        await Task.yield()
        
        // Then: 분석이 완료되어야 함
        XCTAssertFalse(sut.isAnalyzing)
        XCTAssertNotNil(sut.analysisResult)
        XCTAssertTrue(mockAnalyzeFrequencyUseCase.analyzeAudioSessionCalled)
    }
    
    func testStartAnalysis_Failure() async {
        // Given: 오디오 세션이 있지만 분석이 실패하는 상황
        sut.currentAudioSession = AudioSession(
            id: UUID().uuidString,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3.0),
            sampleRate: 44100.0,
            audioFileURL: URL(string: "file:///test.wav")
        )
        mockAnalyzeFrequencyUseCase.shouldSucceedAnalysis = false
        mockAnalyzeFrequencyUseCase.analysisError = .fftProcessingFailed
        
        // When: 분석 시작
        sut.startAnalysis()
        
        await Task.yield()
        
        // Then: 에러가 처리되어야 함
        XCTAssertFalse(sut.isAnalyzing)
        XCTAssertEqual(sut.errorMessage, "주파수 분석에 실패했습니다.")
    }
    
    func testClearAnalysisResults() {
        // Given: 분석 결과가 있는 상태
        sut.analysisResult = AudioAnalysisResult(
            isSuccessful: true,
            peakFrequencies: [440.0, 880.0, 1320.0],
            averagePeakFrequency: 440.0,
            frequencyRange: (80.0, 2000.0),
            analysisQuality: 0.95,
            dataPointCount: 1024,
            processingTime: 0.5,
            sampleRate: 44100.0
        )
        sut.peakFrequency = 440.0
        sut.detectedNote = "A4"
        sut.frequencyAccuracy = 5.0
        sut.analysisProgress = 0.8
        
        // When: 분석 결과 초기화
        sut.clearAnalysisResults()
        
        // Then: 모든 분석 관련 데이터가 초기화되어야 함
        XCTAssertNil(sut.analysisResult)
        XCTAssertNil(sut.peakFrequency)
        XCTAssertNil(sut.detectedNote)
        XCTAssertNil(sut.frequencyAccuracy)
        XCTAssertEqual(sut.analysisProgress, 0.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleRecordingError_PermissionDenied() {
        // Given: 권한 거부 에러 발생
        mockRecordAudioUseCase.shouldSucceedRecording = false
        mockRecordAudioUseCase.recordingError = .permissionDenied
        
        // When: 녹음 시작 시도
        sut.permissionStatus = .granted
        sut.recordButtonTapped()
        
        // Then: 권한 관련 에러 처리
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.sut.errorMessage, "마이크 사용 권한이 필요합니다.")
            XCTAssertEqual(self.sut.permissionStatus, .denied)
            XCTAssertTrue(self.sut.showingPermissionAlert)
        }
    }
    
    func testHandleRecordingError_RecordingFailed() {
        // Given: 녹음 실패 에러 발생
        mockRecordAudioUseCase.shouldSucceedRecording = false
        mockRecordAudioUseCase.recordingError = .recordingFailed
        
        // When: 녹음 시작 시도
        sut.permissionStatus = .granted
        sut.recordButtonTapped()
        
        // Then: 녹음 실패 에러 처리
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.sut.errorMessage, "녹음에 실패했습니다.")
        }
    }
    
    func testHandleAnalysisError_InvalidAudioData() async {
        // Given: 분석 실패 시나리오
        sut.currentAudioSession = AudioSession(
            id: UUID().uuidString,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3.0),
            sampleRate: 44100.0,
            audioFileURL: URL(string: "file:///test.wav")
        )
        mockAnalyzeFrequencyUseCase.shouldSucceedAnalysis = false
        mockAnalyzeFrequencyUseCase.analysisError = .invalidAudioData
        
        // When: 분석 시작
        sut.startAnalysis()
        
        await Task.yield()
        
        // Then: 분석 에러 처리
        XCTAssertEqual(sut.errorMessage, "오디오 데이터가 유효하지 않습니다.")
    }
}

// MARK: - Mock Classes

/// RecordAudioUseCase Mock
class MockRecordAudioUseCase: RecordAudioUseCase {
    var shouldGrantPermission = true
    var shouldSucceedRecording = true
    var recordingError: AudioRecordingError = .recordingFailed
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var isCurrentlyRecording = false
    var currentDuration: TimeInterval = 0
    
    override func checkRecordingReadiness() -> AnyPublisher<Bool, AudioRecordingError> {
        if shouldGrantPermission {
            return Just(true)
                .setFailureType(to: AudioRecordingError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: AudioRecordingError.permissionDenied)
                .eraseToAnyPublisher()
        }
    }
    
    override func startRecording() -> AnyPublisher<AudioSession, AudioRecordingError> {
        startRecordingCalled = true
        
        if shouldSucceedRecording {
            let audioSession = AudioSession(
                id: UUID().uuidString,
                startTime: Date(),
                endTime: Date().addingTimeInterval(3.0),
                sampleRate: 44100.0,
                audioFileURL: URL(string: "file:///test.wav")
            )
            return Just(audioSession)
                .setFailureType(to: AudioRecordingError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: recordingError)
                .eraseToAnyPublisher()
        }
    }
    
    override func stopRecording() -> AnyPublisher<AudioSession, AudioRecordingError> {
        stopRecordingCalled = true
        
        if shouldSucceedRecording {
            let audioSession = AudioSession(
                id: UUID().uuidString,
                startTime: Date(),
                endTime: Date().addingTimeInterval(3.0),
                sampleRate: 44100.0,
                audioFileURL: URL(string: "file:///test.wav")
            )
            return Just(audioSession)
                .setFailureType(to: AudioRecordingError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: recordingError)
                .eraseToAnyPublisher()
        }
    }
}

/// AnalyzeFrequencyUseCase Mock
class MockAnalyzeFrequencyUseCase: AnalyzeFrequencyUseCase {
    var shouldSucceedAnalysis = true
    var analysisError: AudioAnalysisError = .fftProcessingFailed
    var analyzeAudioSessionCalled = false
    
    override func analyzeAudioSession(_ audioSession: AudioSession) -> AnyPublisher<AudioAnalysisResult, AudioAnalysisError> {
        analyzeAudioSessionCalled = true
        
        if shouldSucceedAnalysis {
            let result = AudioAnalysisResult(
                isSuccessful: true,
                peakFrequencies: [440.0, 880.0, 1320.0],
                averagePeakFrequency: 440.0,
                frequencyRange: (80.0, 2000.0),
                analysisQuality: 0.95,
                dataPointCount: 1024,
                processingTime: 0.5,
                sampleRate: 44100.0
            )
            return Just(result)
                .setFailureType(to: AudioAnalysisError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: analysisError)
                .eraseToAnyPublisher()
        }
    }
}

 