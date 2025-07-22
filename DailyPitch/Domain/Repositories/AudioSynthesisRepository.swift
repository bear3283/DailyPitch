import Foundation
import Combine

/// 오디오 합성 에러 타입
enum AudioSynthesisError: Error {
    case invalidMusicNote
    case synthesisTimedOut
    case insufficientMemory
    case synthesisProcessingFailed
    case unsupportedSynthesisMethod
    case audioFormatError
    case fileWriteError
}

/// 오디오 합성 기능을 추상화하는 Repository 프로토콜
protocol AudioSynthesisRepository {
    
    /// 단일 음계를 합성하여 오디오 생성
    /// - Parameters:
    ///   - note: 합성할 음계
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오 Publisher
    func synthesize(note: MusicNote, method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError>
    
    /// 여러 음계를 순차적으로 합성하여 오디오 생성
    /// - Parameters:
    ///   - notes: 합성할 음계 배열
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오 Publisher
    func synthesizeSequence(notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError>
    
    /// 여러 음계를 동시에 합성하여 화음 생성
    /// - Parameters:
    ///   - notes: 합성할 음계 배열
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오 Publisher
    func synthesizeChord(notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError>
    
    /// 분석 결과로부터 음계들을 자동으로 합성
    /// - Parameters:
    ///   - analysisResult: FFT 분석 결과
    ///   - method: 합성 방식
    ///   - noteDuration: 각 음계의 지속 시간
    /// - Returns: 합성된 오디오 Publisher
    func synthesizeFromAnalysis(
        analysisResult: AudioAnalysisResult,
        method: SynthesizedAudio.SynthesisMethod,
        noteDuration: TimeInterval
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError>
    
    /// 합성된 오디오를 파일로 저장
    /// - Parameters:
    ///   - audio: 저장할 합성 오디오
    ///   - url: 저장할 파일 경로
    /// - Returns: 저장 성공 여부 Publisher
    func saveAudio(_ audio: SynthesizedAudio, to url: URL) -> AnyPublisher<Bool, AudioSynthesisError>
    
    /// 원본 오디오와 합성 오디오를 믹싱
    /// - Parameters:
    ///   - originalAudio: 원본 오디오 세션
    ///   - synthesizedAudio: 합성된 오디오
    ///   - originalVolume: 원본 오디오 볼륨 (0.0 ~ 1.0)
    ///   - synthesizedVolume: 합성 오디오 볼륨 (0.0 ~ 1.0)
    /// - Returns: 믹싱된 오디오 Publisher
    func mixAudio(
        originalAudio: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        originalVolume: Float,
        synthesizedVolume: Float
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError>
    
    /// 지원되는 합성 방식 목록
    var supportedSynthesisMethods: [SynthesizedAudio.SynthesisMethod] { get }
    
    /// 현재 합성 중인지 확인
    var isSynthesizing: Bool { get }
} 