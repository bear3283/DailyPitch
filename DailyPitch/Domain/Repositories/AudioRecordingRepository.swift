import Foundation
import Combine

/// 오디오 녹음 권한 상태
enum AudioPermissionStatus {
    case notDetermined
    case granted
    case denied
}

/// 오디오 녹음 에러 타입
enum AudioRecordingError: Error {
    case permissionDenied
    case recordingFailed
    case invalidAudioFormat
    case fileSystemError
    case recordingInProgress
    case maxDurationExceeded
}

/// 오디오 녹음 기능을 추상화하는 Repository 프로토콜
protocol AudioRecordingRepository {
    /// 마이크 사용 권한 상태 확인
    func checkPermissionStatus() -> AudioPermissionStatus
    
    /// 마이크 사용 권한 요청
    func requestPermission() -> AnyPublisher<Bool, Never>
    
    /// 녹음 시작
    /// - Parameter maxDuration: 최대 녹음 시간 (초)
    /// - Returns: 녹음 진행 상태를 방출하는 Publisher
    func startRecording(maxDuration: TimeInterval) -> AnyPublisher<AudioSession, AudioRecordingError>
    
    /// 녹음 중지
    func stopRecording() -> AnyPublisher<AudioSession, AudioRecordingError>
    
    /// 현재 녹음 중인지 확인
    var isRecording: Bool { get }
    
    /// 현재 녹음 시간
    var currentRecordingDuration: TimeInterval { get }
} 