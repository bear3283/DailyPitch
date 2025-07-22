import Foundation
import AVFoundation

/// 합성된 오디오 데이터를 나타내는 엔터티
struct SynthesizedAudio {
    /// 고유 식별자
    let id: UUID
    
    /// 합성된 음계들
    let musicNotes: [MusicNote]
    
    /// 오디오 데이터 (PCM 형태)
    let audioData: [Float]
    
    /// 샘플 레이트
    let sampleRate: Double
    
    /// 전체 지속 시간
    let duration: TimeInterval
    
    /// 채널 수
    let channelCount: Int
    
    /// 합성 방식
    let synthesisMethod: SynthesisMethod
    
    /// 원본 오디오 세션 (연결된 경우)
    let originalAudioSession: AudioSession?
    
    /// 합성 완료 시간
    let synthesizedAt: Date
    
    /// 오디오 파일 URL (저장된 경우)
    var audioFileURL: URL?
    
    /// 합성 방식 열거형
    enum SynthesisMethod: String, CaseIterable {
        case sineWave = "사인파"
        case squareWave = "사각파"
        case sawtoothWave = "톱니파"
        case triangleWave = "삼각파"
        case harmonic = "하모닉"
        
        /// 웨이브 함수
        func waveFunction(phase: Double) -> Double {
            switch self {
            case .sineWave:
                return sin(phase)
            case .squareWave:
                return phase.truncatingRemainder(dividingBy: 2 * .pi) < .pi ? 1.0 : -1.0
            case .sawtoothWave:
                return 2.0 * (phase.truncatingRemainder(dividingBy: 2 * .pi) / (2 * .pi)) - 1.0
            case .triangleWave:
                let normalizedPhase = phase.truncatingRemainder(dividingBy: 2 * .pi) / (2 * .pi)
                return normalizedPhase < 0.5 ? 4.0 * normalizedPhase - 1.0 : 3.0 - 4.0 * normalizedPhase
            case .harmonic:
                // 기본 주파수와 배음들을 조합
                let harmonics = [1.0, 0.5, 0.25, 0.125] // 배음의 진폭 비율
                var sample = 0.0
                for (harmonic, amplitude) in harmonics.enumerated() {
                    let harmonicPhase = phase * Double(harmonic + 1)
                    sample += amplitude * sin(harmonicPhase)
                }
                return sample / Double(harmonics.count)
            }
        }
    }
    
    /// 재생 모드
    enum PlaybackMode: String, CaseIterable {
        case originalOnly = "원본만"
        case synthesizedOnly = "변환된 음계만"
        case mixed = "원본 + 변환"
        
        var description: String {
            return self.rawValue
        }
        
        var icon: String {
            switch self {
            case .originalOnly:
                return "waveform"
            case .synthesizedOnly:
                return "music.note"
            case .mixed:
                return "waveform.and.person.filled"
            }
        }
    }
    
    /// 기본 초기화
    init(
        musicNotes: [MusicNote],
        audioData: [Float],
        sampleRate: Double,
        channelCount: Int = 1,
        synthesisMethod: SynthesisMethod = .sineWave,
        originalAudioSession: AudioSession? = nil
    ) {
        self.id = UUID()
        self.musicNotes = musicNotes
        self.audioData = audioData
        self.sampleRate = sampleRate
        self.duration = Double(audioData.count) / sampleRate
        self.channelCount = channelCount
        self.synthesisMethod = synthesisMethod
        self.originalAudioSession = originalAudioSession
        self.synthesizedAt = Date()
        self.audioFileURL = nil
    }
    
    /// 빈 오디오 생성 (무음)
    static func silence(duration: TimeInterval, sampleRate: Double = 44100.0) -> SynthesizedAudio {
        let sampleCount = Int(duration * sampleRate)
        let audioData = Array(repeating: Float(0.0), count: sampleCount)
        
        return SynthesizedAudio(
            musicNotes: [],
            audioData: audioData,
            sampleRate: sampleRate,
            synthesisMethod: .sineWave
        )
    }
    
    /// 단일 음계로부터 오디오 생성
    /// - Parameters:
    ///   - note: 음계
    ///   - sampleRate: 샘플 레이트
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오
    static func from(
        note: MusicNote,
        sampleRate: Double = 44100.0,
        method: SynthesisMethod = .sineWave
    ) -> SynthesizedAudio {
        let sampleCount = Int(note.duration * sampleRate)
        var audioData: [Float] = []
        
        let phaseIncrement = 2.0 * .pi * note.frequency / sampleRate
        
        for i in 0..<sampleCount {
            let phase = Double(i) * phaseIncrement
            let envelope = calculateEnvelope(sampleIndex: i, totalSamples: sampleCount)
            let sample = Float(method.waveFunction(phase: phase) * note.amplitude * envelope)
            audioData.append(sample)
        }
        
        return SynthesizedAudio(
            musicNotes: [note],
            audioData: audioData,
            sampleRate: sampleRate,
            synthesisMethod: method
        )
    }
    
    /// 여러 음계를 순차적으로 연결하여 오디오 생성
    /// - Parameters:
    ///   - notes: 음계 배열
    ///   - sampleRate: 샘플 레이트
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오
    static func fromSequence(
        notes: [MusicNote],
        sampleRate: Double = 44100.0,
        method: SynthesisMethod = .sineWave
    ) -> SynthesizedAudio {
        var combinedAudioData: [Float] = []
        
        for note in notes {
            let noteAudio = from(note: note, sampleRate: sampleRate, method: method)
            combinedAudioData.append(contentsOf: noteAudio.audioData)
        }
        
        return SynthesizedAudio(
            musicNotes: notes,
            audioData: combinedAudioData,
            sampleRate: sampleRate,
            synthesisMethod: method
        )
    }
    
    /// 여러 음계를 동시에 믹싱하여 오디오 생성 (화음)
    /// - Parameters:
    ///   - notes: 음계 배열
    ///   - sampleRate: 샘플 레이트
    ///   - method: 합성 방식
    /// - Returns: 합성된 오디오
    static func fromChord(
        notes: [MusicNote],
        sampleRate: Double = 44100.0,
        method: SynthesisMethod = .sineWave
    ) -> SynthesizedAudio {
        guard !notes.isEmpty else {
            return silence(duration: 1.0, sampleRate: sampleRate)
        }
        
        let maxDuration = notes.map { $0.duration }.max() ?? 1.0
        let sampleCount = Int(maxDuration * sampleRate)
        var combinedAudioData = Array(repeating: Float(0.0), count: sampleCount)
        
        for note in notes {
            let noteAudio = from(note: note, sampleRate: sampleRate, method: method)
            
            // 믹싱 (각 샘플을 더함)
            for i in 0..<min(noteAudio.audioData.count, combinedAudioData.count) {
                combinedAudioData[i] += noteAudio.audioData[i]
            }
        }
        
        // 정규화 (클리핑 방지)
        let maxAmplitude = combinedAudioData.map { abs($0) }.max() ?? 1.0
        if maxAmplitude > 1.0 {
            for i in 0..<combinedAudioData.count {
                combinedAudioData[i] /= maxAmplitude
            }
        }
        
        return SynthesizedAudio(
            musicNotes: notes,
            audioData: combinedAudioData,
            sampleRate: sampleRate,
            synthesisMethod: method
        )
    }
    
    /// ADSR 엔벨로프 계산
    /// - Parameters:
    ///   - sampleIndex: 현재 샘플 인덱스
    ///   - totalSamples: 전체 샘플 수
    /// - Returns: 엔벨로프 값 (0.0 ~ 1.0)
    private static func calculateEnvelope(sampleIndex: Int, totalSamples: Int) -> Double {
        let progress = Double(sampleIndex) / Double(totalSamples)
        
        // 간단한 페이드 인/아웃 엔벨로프
        if progress < 0.1 {
            // Attack (10%)
            return progress / 0.1
        } else if progress > 0.9 {
            // Release (마지막 10%)
            return (1.0 - progress) / 0.1
        } else {
            // Sustain (중간 80%)
            return 1.0
        }
    }
    
    /// 오디오 데이터를 AVAudioPCMBuffer로 변환
    /// - Returns: PCM 버퍼 (옵셔널)
    func toAVAudioPCMBuffer() -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        ) else {
            return nil
        }
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(audioData.count)
        ) else {
            return nil
        }
        
        buffer.frameLength = AVAudioFrameCount(audioData.count)
        
        guard let channelData = buffer.floatChannelData else { return nil }
        
        // 모노 채널 데이터 복사
        for i in 0..<audioData.count {
            channelData[0][i] = audioData[i]
        }
        
        return buffer
    }
    
    /// 오디오의 최대 진폭
    var peakAmplitude: Float {
        return audioData.map { abs($0) }.max() ?? 0.0
    }
    
    /// 오디오의 RMS (Root Mean Square) 값
    var rmsAmplitude: Float {
        let sumOfSquares = audioData.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(audioData.count))
    }
    
    /// 음계 수
    var noteCount: Int {
        return musicNotes.count
    }
    
    /// 주요 주파수들
    var frequencies: [Double] {
        return musicNotes.map { $0.frequency }
    }
    
    /// 오디오가 유효한지 확인
    var isValid: Bool {
        return !audioData.isEmpty && duration > 0 && sampleRate > 0
    }
}

extension SynthesizedAudio: Equatable {
    static func == (lhs: SynthesizedAudio, rhs: SynthesizedAudio) -> Bool {
        return lhs.id == rhs.id
    }
}

extension SynthesizedAudio: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SynthesizedAudio: CustomStringConvertible {
    var description: String {
        let noteNames = musicNotes.map { $0.name }.joined(separator: ", ")
        return "SynthesizedAudio(notes: [\(noteNames)], duration: \(String(format: "%.2f", duration))s, method: \(synthesisMethod.rawValue))"
    }
} 