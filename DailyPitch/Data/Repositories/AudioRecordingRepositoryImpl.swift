import Foundation
import Combine

/// AudioRecordingRepository의 구현체
/// AudioPermissionManager와 AVFoundationManager를 조합하여 오디오 녹음 기능을 제공
class AudioRecordingRepositoryImpl: AudioRecordingRepository {
    
    private let permissionManager: AudioPermissionManager
    private let avFoundationManager: AVFoundationManager
    private var cancellables = Set<AnyCancellable>()
    
    init(
        permissionManager: AudioPermissionManager = AudioPermissionManager(),
        avFoundationManager: AVFoundationManager = AVFoundationManager()
    ) {
        self.permissionManager = permissionManager
        self.avFoundationManager = avFoundationManager
    }
    
    // MARK: - AudioRecordingRepository Implementation
    
    func checkPermissionStatus() -> AudioPermissionStatus {
        return permissionManager.currentPermissionStatus()
    }
    
    func requestPermission() -> AnyPublisher<Bool, Never> {
        return permissionManager.requestPermission()
    }
    
    func startRecording(maxDuration: TimeInterval) -> AnyPublisher<AudioSession, AudioRecordingError> {
        // 권한 확인
        let permissionStatus = checkPermissionStatus()
        guard permissionStatus == .granted else {
            return Fail(error: AudioRecordingError.permissionDenied)
                .eraseToAnyPublisher()
        }
        
        // 이미 녹음 중인지 확인
        guard !isRecording else {
            return Fail(error: AudioRecordingError.recordingInProgress)
                .eraseToAnyPublisher()
        }
        
        return avFoundationManager.startRecording(maxDuration: maxDuration)
            .map { audioURL in
                AudioSession(
                    timestamp: Date(),
                    duration: 0, // 녹음 시작시에는 0
                    audioFileURL: audioURL,
                    sampleRate: 44100,
                    channelCount: 1
                )
            }
            .eraseToAnyPublisher()
    }
    
    func stopRecording() -> AnyPublisher<AudioSession, AudioRecordingError> {
        guard isRecording else {
            return Fail(error: AudioRecordingError.recordingFailed)
                .eraseToAnyPublisher()
        }
        
        return avFoundationManager.stopRecording()
            .map { duration in
                // 기존 AudioSession이 있다면 해당 정보 활용, 없다면 새로 생성
                AudioSession(
                    timestamp: Date().addingTimeInterval(-duration), // 녹음 시작 시간으로 역계산
                    duration: duration,
                    audioFileURL: self.getCurrentRecordingURL(),
                    sampleRate: 44100,
                    channelCount: 1
                )
            }
            .eraseToAnyPublisher()
    }
    
    var isRecording: Bool {
        return avFoundationManager.isRecording
    }
    
    var currentRecordingDuration: TimeInterval {
        return avFoundationManager.currentRecordingDuration
    }
    
    // MARK: - Private Methods
    
    /// 현재 녹음 중인 파일의 URL을 반환 (실제로는 AVFoundationManager에서 관리해야 함)
    /// 이는 임시 구현으로, 추후 AVFoundationManager에서 currentRecordingURL을 제공하도록 개선 필요
    private func getCurrentRecordingURL() -> URL? {
        // 임시 구현: 문서 디렉토리에서 가장 최근 파일을 찾음
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.creationDateKey],
                options: []
            )
            
            let audioFiles = files.filter { $0.pathExtension == "m4a" }
            let sortedFiles = audioFiles.sorted { (url1, url2) in
                let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
                let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
                return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
            }
            
            return sortedFiles.first
        } catch {
            return nil
        }
    }
} 