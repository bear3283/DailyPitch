import Foundation
import Combine

/// 오디오 녹음 Use Case
/// 마이크 권한 확인부터 녹음 완료까지의 전체 플로우를 관리
class RecordAudioUseCase {
    
    private let audioRepository: AudioRecordingRepository
    private let maxRecordingDuration: TimeInterval = 60.0 // 60초 제한
    
    init(audioRepository: AudioRecordingRepository) {
        self.audioRepository = audioRepository
    }
    
    /// 녹음 준비 상태 확인 (권한 체크)
    func checkRecordingReadiness() -> AnyPublisher<Bool, AudioRecordingError> {
        let permissionStatus = audioRepository.checkPermissionStatus()
        
        switch permissionStatus {
        case .granted:
            return Just(true)
                .setFailureType(to: AudioRecordingError.self)
                .eraseToAnyPublisher()
        case .denied:
            return Fail(error: AudioRecordingError.permissionDenied)
                .eraseToAnyPublisher()
        case .notDetermined:
            return audioRepository.requestPermission()
                .map { granted in
                    return granted
                }
                .setFailureType(to: AudioRecordingError.self)
                .flatMap { granted -> AnyPublisher<Bool, AudioRecordingError> in
                    if granted {
                        return Just(true)
                            .setFailureType(to: AudioRecordingError.self)
                            .eraseToAnyPublisher()
                    } else {
                        return Fail(error: AudioRecordingError.permissionDenied)
                            .eraseToAnyPublisher()
                    }
                }
                .eraseToAnyPublisher()
        }
    }
    
    /// 녹음 시작
    func startRecording() -> AnyPublisher<AudioSession, AudioRecordingError> {
        // 이미 녹음 중인지 확인
        guard !audioRepository.isRecording else {
            return Fail(error: AudioRecordingError.recordingInProgress)
                .eraseToAnyPublisher()
        }
        
        return checkRecordingReadiness()
            .flatMap { [weak self] _ -> AnyPublisher<AudioSession, AudioRecordingError> in
                guard let self = self else {
                    return Fail(error: AudioRecordingError.recordingFailed)
                        .eraseToAnyPublisher()
                }
                return self.audioRepository.startRecording(maxDuration: self.maxRecordingDuration)
            }
            .eraseToAnyPublisher()
    }
    
    /// 녹음 중지
    func stopRecording() -> AnyPublisher<AudioSession, AudioRecordingError> {
        guard audioRepository.isRecording else {
            return Fail(error: AudioRecordingError.recordingFailed)
                .eraseToAnyPublisher()
        }
        
        return audioRepository.stopRecording()
    }
    
    /// 현재 녹음 상태 확인
    var isCurrentlyRecording: Bool {
        return audioRepository.isRecording
    }
    
    /// 현재 녹음 시간
    var currentDuration: TimeInterval {
        return audioRepository.currentRecordingDuration
    }
} 