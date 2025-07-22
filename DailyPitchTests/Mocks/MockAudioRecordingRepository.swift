import Foundation
import Combine
@testable import DailyPitch

/// 테스트용 Mock AudioRecordingRepository
class MockAudioRecordingRepository: AudioRecordingRepository {
    
    // Mock 상태 관리
    var mockPermissionStatus: AudioPermissionStatus = .notDetermined
    var mockPermissionRequestResult: Bool = true
    var mockIsRecording: Bool = false
    var mockCurrentRecordingDuration: TimeInterval = 0
    var mockRecordingError: AudioRecordingError?
    var mockAudioSession: AudioSession?
    
    // 호출 횟수 추적
    var checkPermissionStatusCallCount = 0
    var requestPermissionCallCount = 0
    var startRecordingCallCount = 0
    var stopRecordingCallCount = 0
    
    // MARK: - AudioRecordingRepository Implementation
    
    func checkPermissionStatus() -> AudioPermissionStatus {
        checkPermissionStatusCallCount += 1
        return mockPermissionStatus
    }
    
    func requestPermission() -> AnyPublisher<Bool, Never> {
        requestPermissionCallCount += 1
        return Just(mockPermissionRequestResult)
            .eraseToAnyPublisher()
    }
    
    func startRecording(maxDuration: TimeInterval) -> AnyPublisher<AudioSession, AudioRecordingError> {
        startRecordingCallCount += 1
        
        if let error = mockRecordingError {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        mockIsRecording = true
        let session = mockAudioSession ?? AudioSession(
            duration: 0,
            audioFileURL: URL(fileURLWithPath: "/tmp/test.m4a")
        )
        
        return Just(session)
            .setFailureType(to: AudioRecordingError.self)
            .eraseToAnyPublisher()
    }
    
    func stopRecording() -> AnyPublisher<AudioSession, AudioRecordingError> {
        stopRecordingCallCount += 1
        
        if let error = mockRecordingError {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        mockIsRecording = false
        let session = mockAudioSession ?? AudioSession(
            duration: mockCurrentRecordingDuration,
            audioFileURL: URL(fileURLWithPath: "/tmp/test.m4a")
        )
        
        return Just(session)
            .setFailureType(to: AudioRecordingError.self)
            .eraseToAnyPublisher()
    }
    
    var isRecording: Bool {
        return mockIsRecording
    }
    
    var currentRecordingDuration: TimeInterval {
        return mockCurrentRecordingDuration
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        mockPermissionStatus = .notDetermined
        mockPermissionRequestResult = true
        mockIsRecording = false
        mockCurrentRecordingDuration = 0
        mockRecordingError = nil
        mockAudioSession = nil
        
        checkPermissionStatusCallCount = 0
        requestPermissionCallCount = 0
        startRecordingCallCount = 0
        stopRecordingCallCount = 0
    }
} 