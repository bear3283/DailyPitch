import XCTest
import Combine
@testable import DailyPitch

final class RecordAudioUseCaseTests: XCTestCase {
    
    private var sut: RecordAudioUseCase!
    private var mockRepository: MockAudioRecordingRepository!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockAudioRecordingRepository()
        sut = RecordAudioUseCase(audioRepository: mockRepository)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - 권한 확인 테스트
    
    func test_checkRecordingReadiness_whenPermissionGranted_shouldReturnTrue() {
        // Given
        mockRepository.mockPermissionStatus = .granted
        let expectation = XCTestExpectation(description: "Permission check should succeed")
        var result: Bool?
        
        // When
        sut.checkRecordingReadiness()
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Should not fail when permission is granted")
                    }
                },
                receiveValue: { value in
                    result = value
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(result == true)
        XCTAssertEqual(mockRepository.checkPermissionStatusCallCount, 1)
        XCTAssertEqual(mockRepository.requestPermissionCallCount, 0)
    }
    
    func test_checkRecordingReadiness_whenPermissionDenied_shouldFail() {
        // Given
        mockRepository.mockPermissionStatus = .denied
        let expectation = XCTestExpectation(description: "Permission check should fail")
        var receivedError: AudioRecordingError?
        
        // When
        sut.checkRecordingReadiness()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed when permission is denied")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .permissionDenied)
        XCTAssertEqual(mockRepository.checkPermissionStatusCallCount, 1)
    }
    
    func test_checkRecordingReadiness_whenPermissionNotDeterminedAndGranted_shouldRequestAndReturnTrue() {
        // Given
        mockRepository.mockPermissionStatus = .notDetermined
        mockRepository.mockPermissionRequestResult = true
        let expectation = XCTestExpectation(description: "Permission request should succeed")
        var result: Bool?
        
        // When
        sut.checkRecordingReadiness()
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Should not fail when permission is granted after request")
                    }
                },
                receiveValue: { value in
                    result = value
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(result == true)
        XCTAssertEqual(mockRepository.checkPermissionStatusCallCount, 1)
        XCTAssertEqual(mockRepository.requestPermissionCallCount, 1)
    }
    
    func test_checkRecordingReadiness_whenPermissionNotDeterminedAndDenied_shouldRequestAndFail() {
        // Given
        mockRepository.mockPermissionStatus = .notDetermined
        mockRepository.mockPermissionRequestResult = false
        let expectation = XCTestExpectation(description: "Permission request should fail")
        var receivedError: AudioRecordingError?
        
        // When
        sut.checkRecordingReadiness()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed when permission is denied after request")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .permissionDenied)
        XCTAssertEqual(mockRepository.requestPermissionCallCount, 1)
    }
    
    // MARK: - 녹음 시작 테스트
    
    func test_startRecording_whenPermissionGranted_shouldStartRecording() {
        // Given
        mockRepository.mockPermissionStatus = .granted
        mockRepository.mockIsRecording = false
        let expectation = XCTestExpectation(description: "Recording should start successfully")
        var receivedSession: AudioSession?
        
        // When
        sut.startRecording()
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Recording should start successfully")
                    }
                },
                receiveValue: { session in
                    receivedSession = session
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedSession)
        XCTAssertEqual(mockRepository.startRecordingCallCount, 1)
        XCTAssertTrue(mockRepository.mockIsRecording)
    }
    
    func test_startRecording_whenAlreadyRecording_shouldFail() {
        // Given
        mockRepository.mockIsRecording = true
        let expectation = XCTestExpectation(description: "Recording should fail when already recording")
        var receivedError: AudioRecordingError?
        
        // When
        sut.startRecording()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not start recording when already recording")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .recordingInProgress)
        XCTAssertEqual(mockRepository.startRecordingCallCount, 0)
    }
    
    func test_startRecording_whenPermissionDenied_shouldFail() {
        // Given
        mockRepository.mockPermissionStatus = .denied
        mockRepository.mockIsRecording = false
        let expectation = XCTestExpectation(description: "Recording should fail when permission denied")
        var receivedError: AudioRecordingError?
        
        // When
        sut.startRecording()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not start recording when permission denied")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .permissionDenied)
        XCTAssertEqual(mockRepository.startRecordingCallCount, 0)
    }
    
    // MARK: - 녹음 중지 테스트
    
    func test_stopRecording_whenRecording_shouldStopSuccessfully() {
        // Given
        mockRepository.mockIsRecording = true
        mockRepository.mockCurrentRecordingDuration = 10.0
        let expectation = XCTestExpectation(description: "Recording should stop successfully")
        var receivedSession: AudioSession?
        
        // When
        sut.stopRecording()
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Recording should stop successfully")
                    }
                },
                receiveValue: { session in
                    receivedSession = session
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedSession)
        XCTAssertEqual(receivedSession?.duration, 10.0)
        XCTAssertEqual(mockRepository.stopRecordingCallCount, 1)
        XCTAssertFalse(mockRepository.mockIsRecording)
    }
    
    func test_stopRecording_whenNotRecording_shouldFail() {
        // Given
        mockRepository.mockIsRecording = false
        let expectation = XCTestExpectation(description: "Stop recording should fail when not recording")
        var receivedError: AudioRecordingError?
        
        // When
        sut.stopRecording()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not stop recording when not recording")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedError, .recordingFailed)
    }
    
    // MARK: - 상태 확인 테스트
    
    func test_isCurrentlyRecording_shouldReturnRepositoryState() {
        // Given
        mockRepository.mockIsRecording = true
        
        // When & Then
        XCTAssertTrue(sut.isCurrentlyRecording)
        
        // Given
        mockRepository.mockIsRecording = false
        
        // When & Then
        XCTAssertFalse(sut.isCurrentlyRecording)
    }
    
    func test_currentDuration_shouldReturnRepositoryDuration() {
        // Given
        let expectedDuration: TimeInterval = 25.5
        mockRepository.mockCurrentRecordingDuration = expectedDuration
        
        // When & Then
        XCTAssertEqual(sut.currentDuration, expectedDuration)
    }
} 