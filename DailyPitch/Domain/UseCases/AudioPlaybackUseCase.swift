import Foundation
import Combine

/// 오디오 재생 Use Case
/// 원본 오디오, 합성 오디오, 믹싱 오디오의 재생을 관리하는 비즈니스 로직
class AudioPlaybackUseCase {
    
    private let audioPlaybackRepository: AudioPlaybackRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(audioPlaybackRepository: AudioPlaybackRepository) {
        self.audioPlaybackRepository = audioPlaybackRepository
    }
    
    /// 원본 오디오만 재생
    /// - Parameter audioSession: 재생할 오디오 세션
    /// - Returns: 재생 상태 Publisher
    func playOriginalAudio(_ audioSession: AudioSession) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        guard let audioURL = audioSession.audioFileURL,
              FileManager.default.fileExists(atPath: audioURL.path) else {
            return Fail(error: AudioPlaybackError.audioFileNotFound)
                .eraseToAnyPublisher()
        }
        
        return audioPlaybackRepository.playOriginalAudio(audioSession)
            .eraseToAnyPublisher()
    }
    
    /// 합성된 음계만 재생
    /// - Parameter synthesizedAudio: 재생할 합성 오디오
    /// - Returns: 재생 상태 Publisher
    func playSynthesizedAudio(_ synthesizedAudio: SynthesizedAudio) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        guard synthesizedAudio.isValid else {
            return Fail(error: AudioPlaybackError.unsupportedAudioFormat)
                .eraseToAnyPublisher()
        }
        
        return audioPlaybackRepository.playSynthesizedAudio(synthesizedAudio)
            .eraseToAnyPublisher()
    }
    
    /// 원본과 합성 오디오를 동시에 재생 (믹싱 모드)
    /// - Parameters:
    ///   - audioSession: 원본 오디오 세션
    ///   - synthesizedAudio: 합성된 오디오
    ///   - originalVolume: 원본 볼륨 (기본값: 0.6)
    ///   - synthesizedVolume: 합성 볼륨 (기본값: 0.4)
    /// - Returns: 재생 상태 Publisher
    func playMixedAudio(
        originalAudio: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        originalVolume: Float = 0.6,
        synthesizedVolume: Float = 0.4
    ) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        
        // 유효성 검증
        guard let audioURL = originalAudio.audioFileURL,
              FileManager.default.fileExists(atPath: audioURL.path) else {
            return Fail(error: AudioPlaybackError.audioFileNotFound)
                .eraseToAnyPublisher()
        }
        
        guard synthesizedAudio.isValid else {
            return Fail(error: AudioPlaybackError.unsupportedAudioFormat)
                .eraseToAnyPublisher()
        }
        
        // 볼륨 값 정규화
        let normalizedOriginalVolume = max(0.0, min(1.0, originalVolume))
        let normalizedSynthesizedVolume = max(0.0, min(1.0, synthesizedVolume))
        
        return audioPlaybackRepository.playMixedAudio(
            originalAudio: originalAudio,
            synthesizedAudio: synthesizedAudio,
            originalVolume: normalizedOriginalVolume,
            synthesizedVolume: normalizedSynthesizedVolume
        )
        .eraseToAnyPublisher()
    }
    
    /// 재생 모드에 따른 자동 재생
    /// - Parameters:
    ///   - mode: 재생 모드
    ///   - audioSession: 원본 오디오 세션
    ///   - synthesizedAudio: 합성된 오디오 (옵셔널)
    ///   - originalVolume: 원본 볼륨
    ///   - synthesizedVolume: 합성 볼륨
    /// - Returns: 재생 상태 Publisher
    func playWithMode(
        mode: SynthesizedAudio.PlaybackMode,
        audioSession: AudioSession,
        synthesizedAudio: SynthesizedAudio?,
        originalVolume: Float = 0.6,
        synthesizedVolume: Float = 0.4
    ) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        
        switch mode {
        case .originalOnly:
            return playOriginalAudio(audioSession)
            
        case .synthesizedOnly:
            guard let synthesizedAudio = synthesizedAudio else {
                return Fail(error: AudioPlaybackError.unsupportedAudioFormat)
                    .eraseToAnyPublisher()
            }
            return playSynthesizedAudio(synthesizedAudio)
            
        case .mixed:
            guard let synthesizedAudio = synthesizedAudio else {
                return Fail(error: AudioPlaybackError.unsupportedAudioFormat)
                    .eraseToAnyPublisher()
            }
            return playMixedAudio(
                originalAudio: audioSession,
                synthesizedAudio: synthesizedAudio,
                originalVolume: originalVolume,
                synthesizedVolume: synthesizedVolume
            )
        }
    }
    
    /// 순차적 재생 (원본 → 합성 → 믹싱)
    /// - Parameters:
    ///   - audioSession: 원본 오디오 세션
    ///   - synthesizedAudio: 합성된 오디오
    ///   - pauseDuration: 각 재생 사이의 일시정지 시간 (기본값: 1초)
    /// - Returns: 전체 재생 과정의 상태 Publisher
    func playSequentially(
        audioSession: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        pauseDuration: TimeInterval = 1.0
    ) -> AnyPublisher<(mode: SynthesizedAudio.PlaybackMode, state: PlaybackState), AudioPlaybackError> {
        
        let sequence: [SynthesizedAudio.PlaybackMode] = [.originalOnly, .synthesizedOnly, .mixed]
        
        return Publishers.Sequence(sequence: sequence)
            .setFailureType(to: AudioPlaybackError.self)
            .flatMap { mode in
                // 각 모드 재생
                return self.playWithMode(
                    mode: mode,
                    audioSession: audioSession,
                    synthesizedAudio: synthesizedAudio
                )
                .map { state in (mode, state) }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// 재생 제어 메소드들
    
    func pause() {
        audioPlaybackRepository.pause()
    }
    
    func resume() {
        audioPlaybackRepository.resume()
    }
    
    func stop() {
        audioPlaybackRepository.stop()
    }
    
    func seek(to time: TimeInterval) -> AnyPublisher<Bool, AudioPlaybackError> {
        guard time >= 0 && time <= duration else {
            return Fail(error: AudioPlaybackError.seekFailed)
                .eraseToAnyPublisher()
        }
        
        return audioPlaybackRepository.seek(to: time)
            .eraseToAnyPublisher()
    }
    
    func setVolume(_ volume: Float) {
        let normalizedVolume = max(0.0, min(1.0, volume))
        audioPlaybackRepository.setVolume(normalizedVolume)
    }
    
    /// 재생 정보 접근자들
    
    var currentTime: TimeInterval {
        return audioPlaybackRepository.currentTime
    }
    
    var duration: TimeInterval {
        return audioPlaybackRepository.duration
    }
    
    var currentState: PlaybackState {
        return audioPlaybackRepository.currentState
    }
    
    var currentVolume: Float {
        return audioPlaybackRepository.currentVolume
    }
    
    var isPlaying: Bool {
        return audioPlaybackRepository.isPlaying
    }
    
    /// 재생 진행률 (0.0 ~ 1.0)
    var progress: Double {
        guard duration > 0 else { return 0.0 }
        return currentTime / duration
    }
    
    /// 남은 시간
    var remainingTime: TimeInterval {
        return max(0, duration - currentTime)
    }
    
    /// 상태 변화 Publisher
    var statePublisher: AnyPublisher<PlaybackState, Never> {
        return audioPlaybackRepository.statePublisher
    }
    
    /// 시간 변화 Publisher
    var timePublisher: AnyPublisher<TimeInterval, Never> {
        return audioPlaybackRepository.timePublisher
    }
    
    /// 진행률 변화 Publisher
    var progressPublisher: AnyPublisher<Double, Never> {
        return timePublisher
            .map { [weak self] currentTime in
                guard let self = self, self.duration > 0 else { return 0.0 }
                return currentTime / self.duration
            }
            .eraseToAnyPublisher()
    }
    
    /// 재생 가능한지 확인
    /// - Parameters:
    ///   - audioSession: 확인할 오디오 세션
    ///   - synthesizedAudio: 확인할 합성 오디오 (옵셔널)
    /// - Returns: 재생 가능 여부와 이유
    func canPlay(audioSession: AudioSession, synthesizedAudio: SynthesizedAudio? = nil) -> (canPlay: Bool, reason: String?) {
        
        // 원본 오디오 확인
        guard let audioURL = audioSession.audioFileURL else {
            return (false, "오디오 파일이 없습니다.")
        }
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            return (false, "오디오 파일을 찾을 수 없습니다.")
        }
        
        guard audioSession.duration > 0 else {
            return (false, "오디오 지속 시간이 유효하지 않습니다.")
        }
        
        // 합성 오디오 확인 (있는 경우)
        if let synthesizedAudio = synthesizedAudio {
            guard synthesizedAudio.isValid else {
                return (false, "합성된 오디오가 유효하지 않습니다.")
            }
            
            guard !synthesizedAudio.audioData.isEmpty else {
                return (false, "합성된 오디오 데이터가 없습니다.")
            }
        }
        
        return (true, nil)
    }
    
    /// 재생 품질 확인
    /// - Parameter synthesizedAudio: 확인할 합성 오디오
    /// - Returns: 품질 등급과 설명
    func checkPlaybackQuality(_ synthesizedAudio: SynthesizedAudio) -> (quality: PlaybackQuality, description: String) {
        
        let rms = synthesizedAudio.rmsAmplitude
        let peak = synthesizedAudio.peakAmplitude
        let noteCount = synthesizedAudio.noteCount
        
        // 품질 평가 기준
        if peak > 0.95 {
            return (.poor, "클리핑이 발생할 수 있습니다.")
        } else if rms < 0.01 {
            return (.poor, "볼륨이 너무 낮습니다.")
        } else if noteCount == 0 {
            return (.poor, "감지된 음계가 없습니다.")
        } else if rms > 0.1 && peak < 0.8 && noteCount > 0 {
            return (.excellent, "최적의 재생 품질입니다.")
        } else if rms > 0.05 && peak < 0.9 {
            return (.good, "양호한 재생 품질입니다.")
        } else {
            return (.fair, "보통 수준의 재생 품질입니다.")
        }
    }
    
    enum PlaybackQuality {
        case excellent
        case good
        case fair
        case poor
        
        var description: String {
            switch self {
            case .excellent: return "최고"
            case .good: return "양호"
            case .fair: return "보통"
            case .poor: return "낮음"
            }
        }
    }
} 