import Foundation
import Combine

/// 오디오 재생 에러 타입
enum AudioPlaybackError: Error {
    case playerInitializationFailed
    case audioFileNotFound
    case unsupportedAudioFormat
    case playbackFailed
    case volumeAdjustmentFailed
    case seekFailed
}

/// 재생 상태
enum PlaybackState {
    case stopped
    case playing
    case paused
    case buffering
    case finished
}

/// 오디오 재생 기능을 추상화하는 Repository 프로토콜
protocol AudioPlaybackRepository {
    
    /// 원본 오디오 재생
    /// - Parameter audioSession: 재생할 오디오 세션
    /// - Returns: 재생 상태 Publisher
    func playOriginalAudio(_ audioSession: AudioSession) -> AnyPublisher<PlaybackState, AudioPlaybackError>
    
    /// 합성된 오디오 재생
    /// - Parameter synthesizedAudio: 재생할 합성 오디오
    /// - Returns: 재생 상태 Publisher
    func playSynthesizedAudio(_ synthesizedAudio: SynthesizedAudio) -> AnyPublisher<PlaybackState, AudioPlaybackError>
    
    /// 원본과 합성 오디오를 동시에 믹싱하여 재생
    /// - Parameters:
    ///   - audioSession: 원본 오디오 세션
    ///   - synthesizedAudio: 합성된 오디오
    ///   - originalVolume: 원본 오디오 볼륨 (0.0 ~ 1.0)
    ///   - synthesizedVolume: 합성 오디오 볼륨 (0.0 ~ 1.0)
    /// - Returns: 재생 상태 Publisher
    func playMixedAudio(
        originalAudio: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        originalVolume: Float,
        synthesizedVolume: Float
    ) -> AnyPublisher<PlaybackState, AudioPlaybackError>
    
    /// 재생 일시정지
    func pause()
    
    /// 재생 재개
    func resume()
    
    /// 재생 중지
    func stop()
    
    /// 특정 시간으로 이동
    /// - Parameter time: 이동할 시간 (초)
    /// - Returns: 성공 여부 Publisher
    func seek(to time: TimeInterval) -> AnyPublisher<Bool, AudioPlaybackError>
    
    /// 전체 볼륨 조절
    /// - Parameter volume: 볼륨 (0.0 ~ 1.0)
    func setVolume(_ volume: Float)
    
    /// 현재 재생 시간
    var currentTime: TimeInterval { get }
    
    /// 전체 재생 시간
    var duration: TimeInterval { get }
    
    /// 현재 재생 상태
    var currentState: PlaybackState { get }
    
    /// 현재 볼륨
    var currentVolume: Float { get }
    
    /// 재생 중인지 확인
    var isPlaying: Bool { get }
    
    /// 재생 상태 변화를 감지하는 Publisher
    var statePublisher: AnyPublisher<PlaybackState, Never> { get }
    
    /// 재생 시간 변화를 감지하는 Publisher (0.1초마다)
    var timePublisher: AnyPublisher<TimeInterval, Never> { get }
} 