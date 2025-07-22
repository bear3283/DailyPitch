import Foundation
import Combine

/// 오디오 합성 Use Case
/// 분석 결과를 기반으로 음계를 합성하는 비즈니스 로직을 담당
class SynthesizeAudioUseCase {
    
    private let audioSynthesisRepository: AudioSynthesisRepository
    
    init(audioSynthesisRepository: AudioSynthesisRepository) {
        self.audioSynthesisRepository = audioSynthesisRepository
    }
    
    /// 분석 결과로부터 자동으로 음계 합성
    /// - Parameters:
    ///   - analysisResult: FFT 분석 결과
    ///   - method: 합성 방식 (기본값: 사인파)
    ///   - segmentDuration: 각 음계 세그먼트의 지속 시간 (기본값: 0.5초)
    /// - Returns: 합성된 오디오 Publisher
    func synthesizeFromAnalysis(
        _ analysisResult: AudioAnalysisResult,
        method: SynthesizedAudio.SynthesisMethod = .sineWave,
        segmentDuration: TimeInterval = 0.5
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        
        // 분석 결과 유효성 검증
        guard analysisResult.isSuccessful else {
            return Fail(error: AudioSynthesisError.synthesisProcessingFailed)
                .eraseToAnyPublisher()
        }
        
        return audioSynthesisRepository.synthesizeFromAnalysis(
            analysisResult: analysisResult,
            method: method,
            noteDuration: segmentDuration
        )
        .map { synthesizedAudio in
            // 후처리: 볼륨 정규화 등
            self.postProcessSynthesizedAudio(synthesizedAudio)
        }
        .eraseToAnyPublisher()
    }
    
    /// 단일 주파수를 음계로 변환하여 합성
    /// - Parameters:
    ///   - frequency: 원본 주파수
    ///   - duration: 지속 시간
    ///   - amplitude: 진폭 (0.0 ~ 1.0)
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오 Publisher
    func synthesizeFromFrequency(
        frequency: Double,
        duration: TimeInterval = 1.0,
        amplitude: Double = 0.5,
        method: SynthesizedAudio.SynthesisMethod = .sineWave
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        
        guard let musicNote = MusicNote.from(frequency: frequency, duration: duration, amplitude: amplitude) else {
            return Fail(error: AudioSynthesisError.invalidMusicNote)
                .eraseToAnyPublisher()
        }
        
        return audioSynthesisRepository.synthesize(note: musicNote, method: method)
            .eraseToAnyPublisher()
    }
    
    /// 여러 주파수를 순차적으로 합성
    /// - Parameters:
    ///   - frequencies: 주파수 배열
    ///   - segmentDuration: 각 음계의 지속 시간
    ///   - amplitude: 진폭
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오 Publisher
    func synthesizeSequenceFromFrequencies(
        frequencies: [Double],
        segmentDuration: TimeInterval = 0.5,
        amplitude: Double = 0.5,
        method: SynthesizedAudio.SynthesisMethod = .sineWave
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        
        let musicNotes = frequencies.compactMap { frequency in
            MusicNote.from(frequency: frequency, duration: segmentDuration, amplitude: amplitude)
        }
        
        guard !musicNotes.isEmpty else {
            return Fail(error: AudioSynthesisError.invalidMusicNote)
                .eraseToAnyPublisher()
        }
        
        return audioSynthesisRepository.synthesizeSequence(notes: musicNotes, method: method)
            .map { synthesizedAudio in
                self.postProcessSynthesizedAudio(synthesizedAudio)
            }
            .eraseToAnyPublisher()
    }
    
    /// 음계명들로부터 화음 합성
    /// - Parameters:
    ///   - noteNames: 음계명 배열 (예: ["C4", "E4", "G4"])
    ///   - duration: 화음 지속 시간
    ///   - amplitude: 진폭
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오 Publisher
    func synthesizeChordFromNoteNames(
        noteNames: [String],
        duration: TimeInterval = 2.0,
        amplitude: Double = 0.3,
        method: SynthesizedAudio.SynthesisMethod = .sineWave
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        
        let musicNotes = noteNames.compactMap { noteName in
            MusicNote.from(noteName: noteName, duration: duration, amplitude: amplitude)
        }
        
        guard !musicNotes.isEmpty else {
            return Fail(error: AudioSynthesisError.invalidMusicNote)
                .eraseToAnyPublisher()
        }
        
        return audioSynthesisRepository.synthesizeChord(notes: musicNotes, method: method)
            .map { synthesizedAudio in
                self.postProcessSynthesizedAudio(synthesizedAudio)
            }
            .eraseToAnyPublisher()
    }
    
    /// 원본 오디오와 합성 오디오 믹싱
    /// - Parameters:
    ///   - originalAudio: 원본 오디오 세션
    ///   - synthesizedAudio: 합성된 오디오
    ///   - originalVolume: 원본 볼륨 (0.0 ~ 1.0)
    ///   - synthesizedVolume: 합성 볼륨 (0.0 ~ 1.0)
    /// - Returns: 믹싱된 오디오 Publisher
    func mixWithOriginalAudio(
        originalAudio: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        originalVolume: Float = 0.7,
        synthesizedVolume: Float = 0.5
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        
        // 볼륨 값 검증
        let validOriginalVolume = max(0.0, min(1.0, originalVolume))
        let validSynthesizedVolume = max(0.0, min(1.0, synthesizedVolume))
        
        return audioSynthesisRepository.mixAudio(
            originalAudio: originalAudio,
            synthesizedAudio: synthesizedAudio,
            originalVolume: validOriginalVolume,
            synthesizedVolume: validSynthesizedVolume
        )
        .map { mixedAudio in
            self.postProcessSynthesizedAudio(mixedAudio)
        }
        .eraseToAnyPublisher()
    }
    
    /// 합성된 오디오 저장
    /// - Parameters:
    ///   - synthesizedAudio: 저장할 합성 오디오
    ///   - fileName: 파일명 (확장자 제외)
    /// - Returns: 저장된 파일 URL Publisher
    func saveAudio(
        _ synthesizedAudio: SynthesizedAudio,
        fileName: String = "synthesized_audio"
    ) -> AnyPublisher<URL, AudioSynthesisError> {
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsPath.appendingPathComponent("\(fileName).wav")
        
        return audioSynthesisRepository.saveAudio(synthesizedAudio, to: fileURL)
            .tryMap { success -> URL in
                if success {
                    return fileURL
                } else {
                    throw AudioSynthesisError.fileWriteError
                }
            }
            .mapError { error in
                if let audioError = error as? AudioSynthesisError {
                    return audioError
                } else {
                    return AudioSynthesisError.fileWriteError
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// 지원되는 합성 방식 목록
    var availableSynthesisMethods: [SynthesizedAudio.SynthesisMethod] {
        return audioSynthesisRepository.supportedSynthesisMethods
    }
    
    /// 현재 합성 중인지 확인
    var isCurrentlySynthesizing: Bool {
        return audioSynthesisRepository.isSynthesizing
    }
    
    /// 주파수 범위 필터링
    /// - Parameters:
    ///   - frequencies: 필터링할 주파수 배열
    ///   - minFreq: 최소 주파수
    ///   - maxFreq: 최대 주파수
    /// - Returns: 필터링된 주파수 배열
    func filterFrequencies(
        _ frequencies: [Double],
        minFreq: Double = 80.0,
        maxFreq: Double = 2000.0
    ) -> [Double] {
        return frequencies.filter { freq in
            freq >= minFreq && freq <= maxFreq
        }
    }
    
    /// 음계 추천 (기본 코드 진행)
    /// - Parameter rootNote: 루트 음계
    /// - Returns: 추천 코드 진행
    func recommendChordProgression(from rootNote: MusicNote) -> [String] {
        let progressions: [[Int]] = [
            [0, 4, 7],           // Major triad (C, E, G)
            [0, 3, 7],           // Minor triad (C, Eb, G)
            [0, 4, 7, 10],       // Major 7th (C, E, G, B)
            [0, 3, 7, 10]        // Minor 7th (C, Eb, G, Bb)
        ]
        
        let baseOctave = rootNote.octave
        let rootIndex = rootNote.noteIndex
        
        // Major triad 기본 추천
        let intervals = progressions[0]
        
        return intervals.compactMap { interval in
            let noteIndex = (rootIndex + interval) % 12
            let octaveAdjustment = (rootIndex + interval) / 12
            let octave = baseOctave + octaveAdjustment
            
            return "\(MusicNote.noteNames[noteIndex])\(octave)"
        }
    }
    
    // MARK: - Private Methods
    
    private func postProcessSynthesizedAudio(_ audio: SynthesizedAudio) -> SynthesizedAudio {
        // 볼륨 정규화
        let maxAmplitude = audio.peakAmplitude
        if maxAmplitude > 0.95 {
            // 클리핑 방지를 위한 볼륨 조정
            let normalizedData = audio.audioData.map { $0 * 0.8 / maxAmplitude }
            
            return SynthesizedAudio(
                musicNotes: audio.musicNotes,
                audioData: normalizedData,
                sampleRate: audio.sampleRate,
                channelCount: audio.channelCount,
                synthesisMethod: audio.synthesisMethod,
                originalAudioSession: audio.originalAudioSession
            )
        }
        
        return audio
    }
} 