//
//  ErrorRecovery.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import Foundation
import UIKit

/// Jakob 휴리스틱 9번 "Help Users Recognize, Diagnose, and Recover from Errors"를 구현하는 향상된 에러 시스템

// MARK: - Enhanced Error Types

/// 사용자 친화적 에러 정보
struct UserFriendlyError {
    /// 에러 고유 ID
    let id: String
    
    /// 사용자에게 보여줄 간단한 제목
    let title: String
    
    /// 사용자에게 보여줄 상세 설명
    let message: String
    
    /// 에러가 발생한 이유 (진단)
    let diagnosis: String
    
    /// 사용자가 할 수 있는 복구 행동들
    let recoveryActions: [RecoveryAction]
    
    /// 에러 심각도
    let severity: ErrorSeverity
    
    /// 자동 복구 가능 여부
    let isAutoRecoverable: Bool
    
    /// 에러 발생 시간
    let timestamp: Date
    
    /// 원본 기술적 에러 (로깅용)
    let underlyingError: Error?
}

/// 에러 심각도
enum ErrorSeverity {
    case low        // 정보성, 작업 계속 가능
    case medium     // 경고, 일부 기능 제한
    case high       // 심각, 주요 기능 사용 불가
    case critical   // 치명적, 앱 사용 불가
    
    var color: String {
        switch self {
        case .low: return "blue"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
    
    var systemImage: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

/// 복구 행동
struct RecoveryAction {
    /// 행동 ID
    let id: String
    
    /// 사용자에게 보여줄 행동 제목
    let title: String
    
    /// 행동에 대한 설명
    let description: String
    
    /// 행동 타입
    let type: RecoveryActionType
    
    /// SF Symbol 아이콘 이름
    let systemImage: String
    
    /// 행동이 실행되는 곳 (앱 내부 vs 외부)
    let destination: ActionDestination
    
    /// 실행 우선순위 (높을수록 먼저 표시)
    let priority: Int
    
    /// 실행 함수
    let action: () -> Void
}

/// 복구 행동 타입
enum RecoveryActionType {
    case retry          // 다시 시도
    case skipStep       // 단계 건너뛰기
    case alternative    // 대안 방법
    case settings       // 설정 변경
    case help          // 도움말 보기
    case contact       // 지원 요청
    case reset         // 초기화
    
    var color: String {
        switch self {
        case .retry: return "green"
        case .skipStep: return "blue"
        case .alternative: return "orange"
        case .settings: return "gray"
        case .help: return "purple"
        case .contact: return "red"
        case .reset: return "red"
        }
    }
}

/// 행동 목적지
enum ActionDestination {
    case inApp          // 앱 내부
    case systemSettings // 시스템 설정
    case external       // 외부 앱/웹사이트
}

// MARK: - Error Recovery Manager

/// 에러 복구 관리자
class ErrorRecoveryManager: ObservableObject {
    
    @Published var currentError: UserFriendlyError?
    @Published var errorHistory: [UserFriendlyError] = []
    @Published var autoRecoveryInProgress = false
    
    private let maxHistoryCount = 50
    
    /// 에러 표시 및 복구 제안
    func handleError(_ error: Error, in context: ErrorContext) {
        let userFriendlyError = convertToUserFriendlyError(error, context: context)
        
        DispatchQueue.main.async {
            self.currentError = userFriendlyError
            self.addToHistory(userFriendlyError)
            
            // 자동 복구 시도
            if userFriendlyError.isAutoRecoverable {
                self.attemptAutoRecovery(userFriendlyError)
            }
            
            // 접근성 안내
            self.announceErrorForAccessibility(userFriendlyError)
        }
    }
    
    /// 에러 해결
    func resolveError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.autoRecoveryInProgress = false
        }
    }
    
    /// 자동 복구 시도
    private func attemptAutoRecovery(_ error: UserFriendlyError) {
        guard !autoRecoveryInProgress else { return }
        
        autoRecoveryInProgress = true
        
        // 자동 복구 가능한 에러들에 대한 처리
        switch error.id {
        case "microphone_permission_denied":
            // 3초 후 권한 재요청
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.retryMicrophonePermission()
            }
            
        case "recording_failed":
            // 2초 후 자동 재시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.retryRecording()
            }
            
        case "analysis_timeout":
            // 간단한 분석으로 재시도
            self.retryWithSimpleAnalysis()
            
        default:
            autoRecoveryInProgress = false
        }
    }
    
    /// 에러를 사용자 친화적 형태로 변환
    private func convertToUserFriendlyError(_ error: Error, context: ErrorContext) -> UserFriendlyError {
        let errorMapping = ErrorMappingService()
        return errorMapping.mapError(error, context: context)
    }
    
    /// 에러 기록에 추가
    private func addToHistory(_ error: UserFriendlyError) {
        errorHistory.insert(error, at: 0)
        if errorHistory.count > maxHistoryCount {
            errorHistory.removeLast()
        }
    }
    
    /// 접근성 안내
    private func announceErrorForAccessibility(_ error: UserFriendlyError) {
        let message = "\(error.title). \(error.message)"
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    // MARK: - Recovery Actions
    
    private func retryMicrophonePermission() {
        // 마이크 권한 재요청 로직
        print("Retrying microphone permission...")
        autoRecoveryInProgress = false
    }
    
    private func retryRecording() {
        // 녹음 재시도 로직
        print("Retrying recording...")
        autoRecoveryInProgress = false
    }
    
    private func retryWithSimpleAnalysis() {
        // 간단한 분석으로 재시도
        print("Retrying with simple analysis...")
        autoRecoveryInProgress = false
    }
}

/// 에러 발생 맥락
enum ErrorContext {
    case recording
    case analysis
    case playback
    case synthesis
    case fileOperation
    case network
    case initialization
    
    var displayName: String {
        switch self {
        case .recording: return "녹음"
        case .analysis: return "분석"
        case .playback: return "재생"
        case .synthesis: return "음성 합성"
        case .fileOperation: return "파일 작업"
        case .network: return "네트워크"
        case .initialization: return "초기화"
        }
    }
}

// MARK: - Error Mapping Service

/// 기술적 에러를 사용자 친화적 에러로 변환하는 서비스
class ErrorMappingService {
    
    func mapError(_ error: Error, context: ErrorContext) -> UserFriendlyError {
        
        // AudioRecordingError 매핑
        if let recordingError = error as? AudioRecordingError {
            return mapRecordingError(recordingError, context: context)
        }
        
        // AudioAnalysisError 매핑
        if let analysisError = error as? AudioAnalysisError {
            return mapAnalysisError(analysisError, context: context)
        }
        
        // AudioPlaybackError 매핑
        if let playbackError = error as? AudioPlaybackError {
            return mapPlaybackError(playbackError, context: context)
        }
        
        // AudioSynthesisError 매핑
        if let synthesisError = error as? AudioSynthesisError {
            return mapSynthesisError(synthesisError, context: context)
        }
        
        // 기본 에러 매핑
        return createGenericError(error, context: context)
    }
    
    private func mapRecordingError(_ error: AudioRecordingError, context: ErrorContext) -> UserFriendlyError {
        switch error {
        case .permissionDenied:
            return UserFriendlyError(
                id: "microphone_permission_denied",
                title: "마이크 권한 필요",
                message: "음성을 녹음하려면 마이크 사용 권한이 필요합니다.",
                diagnosis: "앱에서 마이크에 접근할 수 있는 권한이 허용되지 않았습니다.",
                recoveryActions: createMicrophonePermissionRecoveryActions(),
                severity: .high,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .recordingFailed:
            return UserFriendlyError(
                id: "recording_failed",
                title: "녹음 실패",
                message: "음성 녹음 중 문제가 발생했습니다.",
                diagnosis: "마이크가 다른 앱에서 사용 중이거나 하드웨어 문제가 있을 수 있습니다.",
                recoveryActions: createRecordingFailedRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .recordingInProgress:
            return UserFriendlyError(
                id: "recording_in_progress",
                title: "이미 녹음 중",
                message: "현재 녹음이 진행 중입니다.",
                diagnosis: "이전 녹음이 아직 완료되지 않았습니다.",
                recoveryActions: createRecordingInProgressRecoveryActions(),
                severity: .low,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .maxDurationExceeded:
            return UserFriendlyError(
                id: "max_duration_exceeded",
                title: "최대 녹음 시간 초과",
                message: "최대 녹음 시간에 도달했습니다.",
                diagnosis: "녹음 시간이 설정된 최대 시간을 초과했습니다.",
                recoveryActions: createMaxDurationRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .invalidAudioFormat:
            return UserFriendlyError(
                id: "unsupported_audio_format",
                title: "지원하지 않는 오디오 형식",
                message: "현재 오디오 형식을 지원하지 않습니다.",
                diagnosis: "기기의 오디오 설정이 앱에서 지원하지 않는 형식으로 되어 있습니다.",
                recoveryActions: createUnsupportedFormatRecoveryActions(),
                severity: .high,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .fileSystemError:
            return UserFriendlyError(
                id: "file_system_error",
                title: "파일 저장 실패",
                message: "녹음 파일을 저장할 수 없습니다.",
                diagnosis: "기기의 저장 공간이 부족하거나 파일 시스템에 문제가 있습니다.",
                recoveryActions: createFileSystemErrorRecoveryActions(),
                severity: .high,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
        }
    }
    
    private func mapAnalysisError(_ error: AudioAnalysisError, context: ErrorContext) -> UserFriendlyError {
        switch error {
        case .invalidAudioData:
            return UserFriendlyError(
                id: "invalid_audio_data",
                title: "오디오 데이터 오류",
                message: "녹음된 오디오를 분석할 수 없습니다.",
                diagnosis: "녹음된 오디오 파일이 손상되었거나 형식이 올바르지 않습니다.",
                recoveryActions: createInvalidAudioRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .analysisTimeout:
            return UserFriendlyError(
                id: "analysis_timeout",
                title: "분석 시간 초과",
                message: "음성 분석이 너무 오래 걸립니다.",
                diagnosis: "오디오가 너무 길거나 복잡하여 분석에 시간이 오래 걸리고 있습니다.",
                recoveryActions: createAnalysisTimeoutRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .insufficientData:
            return UserFriendlyError(
                id: "insufficient_data",
                title: "분석할 데이터 부족",
                message: "녹음 시간이 너무 짧습니다.",
                diagnosis: "의미 있는 분석을 위해서는 최소 2-3초 이상의 녹음이 필요합니다.",
                recoveryActions: createInsufficientDataRecoveryActions(),
                severity: .low,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .fftProcessingFailed:
            return UserFriendlyError(
                id: "fft_processing_failed",
                title: "주파수 분석 실패",
                message: "음성의 주파수 분석에 실패했습니다.",
                diagnosis: "고급 음성 분석 과정에서 기술적 문제가 발생했습니다.",
                recoveryActions: createFFTFailedRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .fileReadError:
            return UserFriendlyError(
                id: "file_read_error",
                title: "파일 읽기 실패",
                message: "오디오 파일을 읽을 수 없습니다.",
                diagnosis: "저장된 오디오 파일에 접근할 수 없습니다.",
                recoveryActions: createFileReadErrorRecoveryActions(),
                severity: .high,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
        }
    }
    
    private func mapPlaybackError(_ error: AudioPlaybackError, context: ErrorContext) -> UserFriendlyError {
        switch error {
        case .audioFileNotFound:
            return UserFriendlyError(
                id: "playback_file_not_found",
                title: "파일을 찾을 수 없음",
                message: "재생할 오디오 파일이 없습니다.",
                diagnosis: "요청된 오디오 파일이 삭제되었거나 이동되었습니다.",
                recoveryActions: createFileNotFoundRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .unsupportedAudioFormat:
            return UserFriendlyError(
                id: "playback_unsupported_format",
                title: "재생 불가능한 형식",
                message: "이 오디오 형식은 재생할 수 없습니다.",
                diagnosis: "오디오 파일의 형식이 재생 엔진에서 지원되지 않습니다.",
                recoveryActions: createPlaybackFormatRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .playbackFailed:
            return UserFriendlyError(
                id: "playback_failed",
                title: "재생 실패",
                message: "오디오 재생 중 문제가 발생했습니다.",
                diagnosis: "오디오 시스템에서 재생 오류가 발생했습니다.",
                recoveryActions: createPlaybackFailedRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .seekFailed:
            return UserFriendlyError(
                id: "seek_failed",
                title: "시간 이동 실패",
                message: "오디오의 특정 시간으로 이동할 수 없습니다.",
                diagnosis: "재생 위치 변경 중 오류가 발생했습니다.",
                recoveryActions: createSeekFailedRecoveryActions(),
                severity: .low,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .playerInitializationFailed:
            return UserFriendlyError(
                id: "player_init_failed",
                title: "플레이어 초기화 실패",
                message: "오디오 플레이어를 시작할 수 없습니다.",
                diagnosis: "오디오 재생 시스템 초기화에 실패했습니다.",
                recoveryActions: createPlayerInitRecoveryActions(),
                severity: .high,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .volumeAdjustmentFailed:
            return UserFriendlyError(
                id: "volume_control_failed",
                title: "볼륨 조절 실패",
                message: "볼륨을 조절할 수 없습니다.",
                diagnosis: "오디오 볼륨 제어에 문제가 발생했습니다.",
                recoveryActions: createVolumeControlRecoveryActions(),
                severity: .low,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
        }
    }
    
    private func mapSynthesisError(_ error: AudioSynthesisError, context: ErrorContext) -> UserFriendlyError {
        switch error {
        case .invalidMusicNote:
            return UserFriendlyError(
                id: "synthesis_invalid_params",
                title: "잘못된 설정",
                message: "음성 합성 설정이 올바르지 않습니다.",
                diagnosis: "입력된 음계나 합성 방법이 유효하지 않습니다.",
                recoveryActions: createSynthesisParamsRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .synthesisTimedOut:
            return UserFriendlyError(
                id: "synthesis_timed_out",
                title: "음성 합성 시간 초과",
                message: "음성 합성에 너무 오래 걸리고 있습니다.",
                diagnosis: "합성 작업이 예상보다 오래 걸리거나 시스템 리소스가 부족합니다.",
                recoveryActions: createSynthesisTimeoutRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .unsupportedSynthesisMethod:
            return UserFriendlyError(
                id: "unsupported_synthesis_method",
                title: "지원되지 않는 합성 방법",
                message: "선택된 합성 방법을 지원하지 않습니다.",
                diagnosis: "요청된 합성 방법이 현재 기기에서 지원되지 않습니다.",
                recoveryActions: createUnsupportedSynthesisMethodRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .synthesisProcessingFailed:
            return UserFriendlyError(
                id: "synthesis_failed",
                title: "음성 합성 실패",
                message: "음계를 소리로 변환할 수 없습니다.",
                diagnosis: "음성 합성 엔진에서 오류가 발생했습니다.",
                recoveryActions: createSynthesisFailedRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .insufficientMemory:
            return UserFriendlyError(
                id: "synthesis_memory_error",
                title: "메모리 부족",
                message: "음성 합성을 위한 메모리가 부족합니다.",
                diagnosis: "기기의 사용 가능한 메모리가 부족합니다.",
                recoveryActions: createMemoryErrorRecoveryActions(),
                severity: .high,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .audioFormatError:
            return UserFriendlyError(
                id: "synthesis_format_error",
                title: "오디오 형식 오류",
                message: "합성된 오디오 형식에 문제가 있습니다.",
                diagnosis: "생성된 오디오의 형식이 올바르지 않습니다.",
                recoveryActions: createSynthesisFormatRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: true,
                timestamp: Date(),
                underlyingError: error
            )
            
        case .fileWriteError:
            return UserFriendlyError(
                id: "synthesis_file_write_error",
                title: "파일 쓰기 실패",
                message: "합성된 오디오를 저장할 수 없습니다.",
                diagnosis: "저장 공간 부족 또는 파일 시스템 오료입니다.",
                recoveryActions: createSynthesisFileWriteRecoveryActions(),
                severity: .medium,
                isAutoRecoverable: false,
                timestamp: Date(),
                underlyingError: error
            )
        }
    }
    
    private func createGenericError(_ error: Error, context: ErrorContext) -> UserFriendlyError {
        return UserFriendlyError(
            id: "generic_error",
            title: "\(context.displayName) 오류",
            message: "예상치 못한 오류가 발생했습니다.",
            diagnosis: "알 수 없는 이유로 오류가 발생했습니다.",
            recoveryActions: createGenericRecoveryActions(),
            severity: .medium,
            isAutoRecoverable: false,
            timestamp: Date(),
            underlyingError: error
        )
    }
    
    // MARK: - Recovery Actions Factory Methods
    
    private func createMicrophonePermissionRecoveryActions() -> [RecoveryAction] {
        return [
            RecoveryAction(
                id: "open_settings",
                title: "설정으로 이동",
                description: "앱 설정에서 마이크 권한을 허용해주세요",
                type: .settings,
                systemImage: "gear",
                destination: .systemSettings,
                priority: 10,
                action: { openAppSettings() }
            ),
            RecoveryAction(
                id: "retry_permission",
                title: "다시 시도",
                description: "마이크 권한을 다시 요청합니다",
                type: .retry,
                systemImage: "arrow.clockwise",
                destination: .inApp,
                priority: 8,
                action: { /* 권한 재요청 */ }
            ),
            RecoveryAction(
                id: "help_permission",
                title: "도움말 보기",
                description: "마이크 권한 설정 방법을 자세히 알아보세요",
                type: .help,
                systemImage: "questionmark.circle",
                destination: .inApp,
                priority: 5,
                action: { /* 도움말 표시 */ }
            )
        ]
    }
    
    private func createRecordingFailedRecoveryActions() -> [RecoveryAction] {
        return [
            RecoveryAction(
                id: "retry_recording",
                title: "다시 녹음",
                description: "녹음을 다시 시도합니다",
                type: .retry,
                systemImage: "mic.circle",
                destination: .inApp,
                priority: 10,
                action: { /* 녹음 재시도 */ }
            ),
            RecoveryAction(
                id: "check_microphone",
                title: "마이크 확인",
                description: "다른 앱에서 마이크를 사용 중인지 확인해보세요",
                type: .help,
                systemImage: "mic.slash",
                destination: .inApp,
                priority: 7,
                action: { /* 마이크 상태 안내 */ }
            ),
            RecoveryAction(
                id: "restart_app",
                title: "앱 재시작",
                description: "앱을 완전히 종료 후 다시 실행해보세요",
                type: .reset,
                systemImage: "restart.circle",
                destination: .inApp,
                priority: 3,
                action: { /* 앱 재시작 안내 */ }
            )
        ]
    }
    
    private func createRecordingInProgressRecoveryActions() -> [RecoveryAction] {
        return [
            RecoveryAction(
                id: "stop_current_recording",
                title: "현재 녹음 중지",
                description: "진행 중인 녹음을 중지합니다",
                type: .skipStep,
                systemImage: "stop.circle",
                destination: .inApp,
                priority: 10,
                action: { /* 녹음 중지 */ }
            ),
            RecoveryAction(
                id: "wait_for_completion",
                title: "완료까지 대기",
                description: "현재 녹음이 완료될 때까지 기다립니다",
                type: .alternative,
                systemImage: "clock",
                destination: .inApp,
                priority: 5,
                action: { /* 대기 */ }
            )
        ]
    }
    
    private func createMaxDurationRecoveryActions() -> [RecoveryAction] {
        return [
            RecoveryAction(
                id: "analyze_current_recording",
                title: "현재 녹음 분석",
                description: "지금까지 녹음된 내용을 분석합니다",
                type: .alternative,
                systemImage: "waveform.path.ecg",
                destination: .inApp,
                priority: 10,
                action: { /* 현재 녹음 분석 */ }
            ),
            RecoveryAction(
                id: "start_new_recording",
                title: "새로 녹음",
                description: "새로운 녹음을 시작합니다",
                type: .retry,
                systemImage: "mic.badge.plus",
                destination: .inApp,
                priority: 8,
                action: { /* 새 녹음 시작 */ }
            ),
            RecoveryAction(
                id: "extend_duration_settings",
                title: "최대 시간 연장",
                description: "설정에서 최대 녹음 시간을 늘릴 수 있습니다",
                type: .settings,
                systemImage: "timer",
                destination: .inApp,
                priority: 3,
                action: { /* 설정 화면으로 */ }
            )
        ]
    }
    
    private func createUnsupportedFormatRecoveryActions() -> [RecoveryAction] {
        return [
            RecoveryAction(
                id: "check_audio_settings",
                title: "오디오 설정 확인",
                description: "기기의 오디오 설정을 확인해보세요",
                type: .settings,
                systemImage: "speaker.wave.3",
                destination: .systemSettings,
                priority: 10,
                action: { /* 오디오 설정으로 */ }
            ),
            RecoveryAction(
                id: "restart_device",
                title: "기기 재시작",
                description: "기기를 재시작하면 오디오 설정이 초기화될 수 있습니다",
                type: .reset,
                systemImage: "restart",
                destination: .external,
                priority: 5,
                action: { /* 재시작 안내 */ }
            )
        ]
    }
    
    private func createFileSystemErrorRecoveryActions() -> [RecoveryAction] {
        return [
            RecoveryAction(
                id: "check_storage",
                title: "저장 공간 확인",
                description: "기기의 남은 저장 공간을 확인해보세요",
                type: .settings,
                systemImage: "internaldrive",
                destination: .systemSettings,
                priority: 10,
                action: { /* 저장소 설정으로 */ }
            ),
            RecoveryAction(
                id: "clear_app_cache",
                title: "앱 데이터 정리",
                description: "불필요한 임시 파일들을 정리합니다",
                type: .reset,
                systemImage: "trash",
                destination: .inApp,
                priority: 8,
                action: { /* 캐시 정리 */ }
            ),
            RecoveryAction(
                id: "free_storage_guide",
                title: "저장 공간 확보 방법",
                description: "저장 공간을 확보하는 방법을 안내합니다",
                type: .help,
                systemImage: "questionmark.circle",
                destination: .inApp,
                priority: 3,
                action: { /* 저장소 도움말 */ }
            )
        ]
    }
    
    // 추가 복구 액션들 (간단히 구현)
    private func createInvalidAudioRecoveryActions() -> [RecoveryAction] { return [] }
    private func createAnalysisTimeoutRecoveryActions() -> [RecoveryAction] { return [] }
    private func createInsufficientDataRecoveryActions() -> [RecoveryAction] { return [] }
    private func createFFTFailedRecoveryActions() -> [RecoveryAction] { return [] }
    private func createFileReadErrorRecoveryActions() -> [RecoveryAction] { return [] }
    private func createFileNotFoundRecoveryActions() -> [RecoveryAction] { return [] }
    private func createPlaybackFormatRecoveryActions() -> [RecoveryAction] { return [] }
    private func createPlaybackFailedRecoveryActions() -> [RecoveryAction] { return [] }
    private func createSeekFailedRecoveryActions() -> [RecoveryAction] { return [] }
    private func createPlayerInitRecoveryActions() -> [RecoveryAction] { return [] }
    private func createVolumeControlRecoveryActions() -> [RecoveryAction] { return [] }
    private func createSynthesisParamsRecoveryActions() -> [RecoveryAction] { return [] }
    private func createSynthesisTimeoutRecoveryActions() -> [RecoveryAction] { return [] }
    private func createUnsupportedSynthesisMethodRecoveryActions() -> [RecoveryAction] { return [] }
    private func createSynthesisFailedRecoveryActions() -> [RecoveryAction] { return [] }
    private func createMemoryErrorRecoveryActions() -> [RecoveryAction] { return [] }
    private func createSynthesisFormatRecoveryActions() -> [RecoveryAction] { return [] }
    private func createSynthesisFileWriteRecoveryActions() -> [RecoveryAction] { return [] }
    private func createGenericRecoveryActions() -> [RecoveryAction] { return [] }
}

// MARK: - Helper Functions

private func openAppSettings() {
    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsURL)
    }
}

// MARK: - Error Types (기존 에러 타입들은 각각의 Repository에서 정의됨)