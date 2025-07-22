import Foundation
import AVFoundation
import Combine

/// 오디오 권한 관리를 담당하는 유틸리티 클래스
class AudioPermissionManager {
    
    private let permissionStatusSubject = CurrentValueSubject<AudioPermissionStatus, Never>(.notDetermined)
    
    init() {
        updatePermissionStatus()
    }
    
    /// 현재 마이크 사용 권한 상태를 반환
    func currentPermissionStatus() -> AudioPermissionStatus {
        // iOS 17.0 이상에서는 AVAudioApplication 사용
        if #available(iOS 17.0, *) {
            let permission = AVAudioApplication.shared.recordPermission
            // AVAudioApplication.RecordPermission을 직접 변환
            switch permission {
            case .undetermined:
                return .notDetermined
            case .granted:
                return .granted
            case .denied:
                return .denied
            @unknown default:
                return .notDetermined
            }
        } else {
            let avStatus = AVAudioSession.sharedInstance().recordPermission
            return convertAVAudioSessionPermissionStatus(avStatus)
        }
    }
    
    /// AVAudioSession.RecordPermission을 AudioPermissionStatus로 변환
    func convertAVAudioSessionPermissionStatus(_ avStatus: AVAudioSession.RecordPermission) -> AudioPermissionStatus {
        switch avStatus {
        case .undetermined:
            return .notDetermined
        case .granted:
            return .granted
        case .denied:
            return .denied
        @unknown default:
            return .notDetermined
        }
    }
    
    /// 마이크 사용 권한을 요청
    func requestPermission() -> AnyPublisher<Bool, Never> {
        return Future<Bool, Never> { [weak self] promise in
            // iOS 17.0 이상에서는 AVAudioApplication 사용
            if #available(iOS 17.0, *) {
                Task {
                    let granted = await AVAudioApplication.requestRecordPermission()
                    DispatchQueue.main.async {
                        self?.updatePermissionStatus()
                        promise(.success(granted))
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        self?.updatePermissionStatus()
                        promise(.success(granted))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 권한 상태 변화를 감지할 수 있는 Publisher
    var permissionStatusPublisher: AnyPublisher<AudioPermissionStatus, Never> {
        return permissionStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    /// 현재 권한 상태를 업데이트하고 Subject에 방출
    private func updatePermissionStatus() {
        let currentStatus = currentPermissionStatus()
        permissionStatusSubject.send(currentStatus)
    }
} 