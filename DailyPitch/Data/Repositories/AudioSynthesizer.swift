import Foundation
import AVFoundation
import Accelerate
import Combine

/// AVFoundation 기반 오디오 합성 구현체
class AudioSynthesizer: AudioSynthesisRepository {
    
    // MARK: - Private Properties
    
    private let sampleRate: Double = 44100.0
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixerNode = AVAudioMixerNode()
    
    // MARK: - Initialization
    
    init() {
        setupAudioEngine()
    }
    
    deinit {
        if engine.isRunning {
            engine.stop()
        }
    }
    
    // MARK: - AudioSynthesisRepository Implementation
    
    func synthesize(note: MusicNote, method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        return synthesizeToAudio(from: [note], method: method)
    }
    
    func synthesizeSequence(notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        return synthesizeToAudio(from: notes, method: method)
    }
    
    func synthesizeChord(notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        return synthesizeToAudio(from: notes, method: method)
    }
    
    func synthesizeFromAnalysis(
        analysisResult: AudioAnalysisResult,
        method: SynthesizedAudio.SynthesisMethod,
        noteDuration: TimeInterval
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        // 분석 결과로부터 MusicNote 생성
        guard let peakFrequency = analysisResult.averagePeakFrequency,
              let note = MusicNote.from(frequency: peakFrequency, duration: noteDuration, amplitude: 0.7) else {
            return Fail(error: AudioSynthesisError.invalidMusicNote)
                .eraseToAnyPublisher()
        }
        
        return synthesize(note: note, method: method)
    }
    
    func saveAudio(_ audio: SynthesizedAudio, to url: URL) -> AnyPublisher<Bool, AudioSynthesisError> {
        return Future<Bool, AudioSynthesisError> { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // PCM 데이터를 WAV 파일로 저장
                    let format = AVAudioFormat(
                        standardFormatWithSampleRate: audio.sampleRate,
                        channels: AVAudioChannelCount(audio.channelCount)
                    )!
                    
                    let audioFile = try AVAudioFile(
                        forWriting: url,
                        settings: format.settings
                    )
                    
                    let buffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: AVAudioFrameCount(audio.audioData.count)
                    )!
                    
                    buffer.frameLength = AVAudioFrameCount(audio.audioData.count)
                    let channelData = buffer.floatChannelData![0]
                    
                    for i in 0..<audio.audioData.count {
                        channelData[i] = audio.audioData[i]
                    }
                    
                    try audioFile.write(from: buffer)
                    promise(.success(true))
                    
                } catch {
                    promise(.failure(.synthesisProcessingFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func mixAudio(
        originalAudio: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        originalVolume: Float,
        synthesizedVolume: Float
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        return Future<SynthesizedAudio, AudioSynthesisError> { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // 원본 오디오 로드
                    guard let audioFileURL = originalAudio.audioFileURL,
                          FileManager.default.fileExists(atPath: audioFileURL.path) else {
                        promise(.failure(.invalidMusicNote))
                        return
                    }
                    
                    let audioFile = try AVAudioFile(forReading: audioFileURL)
                    let originalFrameCount = AVAudioFrameCount(audioFile.length)
                    let synthesizedFrameCount = synthesizedAudio.audioData.count
                    let maxFrameCount = max(Int(originalFrameCount), synthesizedFrameCount)
                    
                    // 원본 오디오 데이터 읽기
                    let buffer = AVAudioPCMBuffer(
                        pcmFormat: audioFile.processingFormat,
                        frameCapacity: originalFrameCount
                    )!
                    
                    try audioFile.read(into: buffer)
                    let originalData = buffer.floatChannelData![0]
                    
                    // 믹싱된 오디오 데이터 생성
                    var mixedData: [Float] = []
                    
                    for i in 0..<maxFrameCount {
                        var sample: Float = 0.0
                        
                        // 원본 오디오 추가
                        if i < Int(originalFrameCount) {
                            sample += originalData[i] * originalVolume
                        }
                        
                        // 합성 오디오 추가
                        if i < synthesizedFrameCount {
                            sample += synthesizedAudio.audioData[i] * synthesizedVolume
                        }
                        
                        mixedData.append(sample)
                    }
                    
                    // 정규화
                    let normalizedData = self.normalizeAudioData(mixedData)
                    
                    // 새로운 SynthesizedAudio 생성
                    let mixedAudio = SynthesizedAudio(
                        musicNotes: synthesizedAudio.musicNotes,
                        audioData: normalizedData,
                        sampleRate: synthesizedAudio.sampleRate,
                        channelCount: synthesizedAudio.channelCount,
                        synthesisMethod: synthesizedAudio.synthesisMethod,
                        originalAudioSession: originalAudio
                    )
                    
                    promise(.success(mixedAudio))
                    
                } catch {
                    promise(.failure(.synthesisProcessingFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    var supportedSynthesisMethods: [SynthesizedAudio.SynthesisMethod] {
        return getSupportedSynthesisMethods()
    }
    
    var isSynthesizing: Bool {
        // 실제 구현에서는 합성 진행 상태를 추적해야 함
        return false
    }
    
    func synthesizeToAudio(from notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        return Future<SynthesizedAudio, AudioSynthesisError> { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // 입력 검증
                    guard !notes.isEmpty else {
                        promise(.failure(.invalidMusicNote))
                        return
                    }
                    
                    // 오디오 데이터 합성
                    let audioData = try self.generateAudioData(from: notes, method: method)
                    
                    // SynthesizedAudio 객체 생성
                    let synthesizedAudio = SynthesizedAudio(
                        musicNotes: notes,
                        audioData: audioData,
                        sampleRate: self.sampleRate,
                        synthesisMethod: method
                    )
                    
                    // 품질 검증
                    let quality = self.validateAudioQuality(synthesizedAudio)
                    guard quality != .failed else {
                        promise(.failure(.audioFormatError))
                        return
                    }
                    
                    promise(.success(synthesizedAudio))
                    
                } catch let error as AudioSynthesisError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(.synthesisProcessingFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func analyzeToneQuality(_ audioData: [Float]) -> AudioQuality {
        guard !audioData.isEmpty else {
            return AudioQuality(
                rms: 0.0,
                peak: 0.0,
                dynamicRange: 0.0,
                signalToNoiseRatio: 0.0,
                totalHarmonicDistortion: 1.0
            )
        }
        
        // RMS (Root Mean Square) 계산
        let rms = calculateRMS(audioData)
        
        // Peak 값 계산
        let peak = audioData.map { abs($0) }.max() ?? 0.0
        
        // Dynamic Range 계산
        let dynamicRange = calculateDynamicRange(audioData)
        
        // Signal to Noise Ratio 계산
        let snr = calculateSNR(audioData)
        
        // Total Harmonic Distortion 추정
        let thd = estimateTHD(audioData)
        
        return AudioQuality(
            rms: rms,
            peak: peak,
            dynamicRange: dynamicRange,
            signalToNoiseRatio: snr,
            totalHarmonicDistortion: thd
        )
    }
    
    func getSupportedSynthesisMethods() -> [SynthesizedAudio.SynthesisMethod] {
        return [.sineWave, .squareWave, .triangleWave, .sawtoothWave, .harmonic]
    }
    
    func estimateSynthesisTime(for notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) -> TimeInterval {
        let totalDuration = notes.reduce(0.0) { $0 + $1.duration }
        let complexityMultiplier = getComplexityMultiplier(for: method)
        let baseProcessingTime = totalDuration * 0.1 // 기본 처리 시간
        
        return baseProcessingTime * complexityMultiplier
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        // 오디오 엔진 설정
        engine.attach(playerNode)
        engine.attach(mixerNode)
        
        // 모노 포맷으로 통일 (44.1kHz, 1채널)
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        
        engine.connect(playerNode, to: mixerNode, format: monoFormat)
        engine.connect(mixerNode, to: engine.outputNode, format: monoFormat)
        
        do {
            try engine.start()
        } catch {
            print("오디오 엔진 시작 실패: \(error)")
        }
    }
    
    private func generateAudioData(from notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) throws -> [Float] {
        // 전체 오디오 길이 계산
        let totalDuration = notes.reduce(into: 0.0) { result, note in
            result = max(result, note.duration)
        }
        let totalSamples = Int(totalDuration * sampleRate)
        
        guard totalSamples > 0 else {
            throw AudioSynthesisError.audioFormatError
        }
        
        var audioBuffer = [Float](repeating: 0.0, count: totalSamples)
        
        // 각 음계에 대해 오디오 데이터 생성 및 믹싱
        for note in notes {
            let noteAudioData = try generateSingleNoteAudio(note: note, method: method, totalDuration: totalDuration)
            
            // 오디오 데이터 믹싱 (순차적으로 배치)
            let endSample = min(noteAudioData.count, totalSamples)
            
            for i in 0..<endSample {
                if i < noteAudioData.count {
                    audioBuffer[i] += noteAudioData[i] * Float(note.amplitude)
                }
            }
        }
        
        // 정규화 (클리핑 방지)
        return normalizeAudioData(audioBuffer)
    }
    
    private func generateSingleNoteAudio(note: MusicNote, method: SynthesizedAudio.SynthesisMethod, totalDuration: TimeInterval) throws -> [Float] {
        let noteDuration = note.duration
        let sampleCount = Int(noteDuration * sampleRate)
        let frequency = note.frequency
        
        guard sampleCount > 0 && frequency > 0 else {
            throw AudioSynthesisError.invalidMusicNote
        }
        
        var audioData = [Float](repeating: 0.0, count: sampleCount)
        
        switch method {
        case .sineWave:
            audioData = generateSineWave(frequency: frequency, duration: noteDuration, sampleRate: sampleRate)
            
        case .squareWave:
            audioData = generateSquareWave(frequency: frequency, duration: noteDuration, sampleRate: sampleRate)
            
        case .triangleWave:
            audioData = generateTriangleWave(frequency: frequency, duration: noteDuration, sampleRate: sampleRate)
            
        case .sawtoothWave:
            audioData = generateSawtoothWave(frequency: frequency, duration: noteDuration, sampleRate: sampleRate)
            
        case .harmonic:
            audioData = generateHarmonicWave(frequency: frequency, duration: noteDuration, sampleRate: sampleRate)
        }
        
        // ADSR 엔벨로프 적용
        return applyADSREnvelope(to: audioData, duration: noteDuration)
    }
    
    // MARK: - 파형 생성 메소드들
    
    private func generateSineWave(frequency: Double, duration: TimeInterval, sampleRate: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var audioData = [Float](repeating: 0.0, count: sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let sample = sin(2.0 * .pi * frequency * time)
            audioData[i] = Float(sample)
        }
        
        return audioData
    }
    
    private func generateSquareWave(frequency: Double, duration: TimeInterval, sampleRate: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var audioData = [Float](repeating: 0.0, count: sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let cycle = (time * frequency).truncatingRemainder(dividingBy: 1.0)
            audioData[i] = cycle < 0.5 ? 1.0 : -1.0
        }
        
        return audioData
    }
    
    private func generateTriangleWave(frequency: Double, duration: TimeInterval, sampleRate: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var audioData = [Float](repeating: 0.0, count: sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let cycle = (time * frequency).truncatingRemainder(dividingBy: 1.0)
            let sample = cycle < 0.5 ? (4.0 * cycle - 1.0) : (3.0 - 4.0 * cycle)
            audioData[i] = Float(sample)
        }
        
        return audioData
    }
    
    private func generateSawtoothWave(frequency: Double, duration: TimeInterval, sampleRate: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var audioData = [Float](repeating: 0.0, count: sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let cycle = (time * frequency).truncatingRemainder(dividingBy: 1.0)
            audioData[i] = Float(2.0 * cycle - 1.0)
        }
        
        return audioData
    }
    
    private func generateHarmonicWave(frequency: Double, duration: TimeInterval, sampleRate: Double) -> [Float] {
        let sampleCount = Int(duration * sampleRate)
        var audioData = [Float](repeating: 0.0, count: sampleCount)
        
        // 기본 주파수와 배음들을 조합
        let harmonics = [1.0, 0.5, 0.25, 0.125] // 배음의 진폭 비율
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            var sample = 0.0
            
            for (harmonic, amplitude) in harmonics.enumerated() {
                let harmonicFreq = frequency * Double(harmonic + 1)
                sample += amplitude * sin(2.0 * .pi * harmonicFreq * time)
            }
            
            audioData[i] = Float(sample / Double(harmonics.count))
        }
        
        return audioData
    }
    
    // MARK: - 오디오 처리 유틸리티들
    
    private func applyADSREnvelope(to audioData: [Float], duration: TimeInterval) -> [Float] {
        let sampleCount = audioData.count
        var processedData = audioData
        
        // ADSR 파라미터 (총 길이에 비례)
        let attackTime = min(duration * 0.1, 0.05)  // 최대 50ms
        let decayTime = min(duration * 0.1, 0.1)    // 최대 100ms
        let sustainLevel: Float = 0.7
        let releaseTime = min(duration * 0.2, 0.2)  // 최대 200ms
        
        let attackSamples = Int(attackTime * sampleRate)
        let decaySamples = Int(decayTime * sampleRate)
        let releaseSamples = Int(releaseTime * sampleRate)
        let sustainSamples = sampleCount - attackSamples - decaySamples - releaseSamples
        
        for i in 0..<sampleCount {
            var envelope: Float = 1.0
            
            if i < attackSamples {
                // Attack
                envelope = Float(i) / Float(attackSamples)
            } else if i < attackSamples + decaySamples {
                // Decay
                let decayProgress = Float(i - attackSamples) / Float(decaySamples)
                envelope = 1.0 - decayProgress * (1.0 - sustainLevel)
            } else if i < attackSamples + decaySamples + sustainSamples {
                // Sustain
                envelope = sustainLevel
            } else {
                // Release
                let releaseProgress = Float(i - attackSamples - decaySamples - sustainSamples) / Float(releaseSamples)
                envelope = sustainLevel * (1.0 - releaseProgress)
            }
            
            processedData[i] *= envelope
        }
        
        return processedData
    }
    
    private func normalizeAudioData(_ audioData: [Float]) -> [Float] {
        guard !audioData.isEmpty else { return audioData }
        
        let maxAmplitude = audioData.map { abs($0) }.max() ?? 1.0
        guard maxAmplitude > 0.0 else { return audioData }
        
        let normalizationFactor = min(1.0, 0.95 / maxAmplitude) // 95%로 정규화하여 여유 공간 확보
        
        return audioData.map { $0 * normalizationFactor }
    }
    
    // MARK: - 오디오 품질 분석
    
    private func calculateRMS(_ audioData: [Float]) -> Float {
        guard !audioData.isEmpty else { return 0.0 }
        
        let squareSum = audioData.reduce(0.0) { $0 + $1 * $1 }
        return sqrt(squareSum / Float(audioData.count))
    }
    
    private func calculateDynamicRange(_ audioData: [Float]) -> Float {
        guard !audioData.isEmpty else { return 0.0 }
        
        let absoluteValues = audioData.map { abs($0) }
        let maxValue = absoluteValues.max() ?? 0.0
        let minValue = absoluteValues.filter { $0 > 0.001 }.min() ?? 0.001 // 노이즈 플로어 고려
        
        guard maxValue > minValue else { return 0.0 }
        
        return 20.0 * log10(maxValue / minValue) // dB 단위
    }
    
    private func calculateSNR(_ audioData: [Float]) -> Float {
        // 신호와 노이즈의 비율을 추정 (단순화된 계산)
        let rms = calculateRMS(audioData)
        let estimatedNoise: Float = 0.001 // 추정된 노이즈 레벨
        
        guard rms > estimatedNoise else { return 0.0 }
        
        return 20.0 * log10(rms / estimatedNoise)
    }
    
    private func estimateTHD(_ audioData: [Float]) -> Float {
        // THD 추정을 위한 단순화된 계산
        // 실제로는 FFT를 사용하여 고조파 분석이 필요
        let rms = calculateRMS(audioData)
        let peak = audioData.map { abs($0) }.max() ?? 0.0
        
        guard peak > 0.0 else { return 1.0 }
        
        let crestFactor = peak / rms
        // Crest Factor를 기반으로 THD 추정 (경험적 공식)
        return max(0.0, min(1.0, (crestFactor - 1.414) / 10.0))
    }
    
    private func validateAudioQuality(_ synthesizedAudio: SynthesizedAudio) -> AudioQualityLevel {
        let quality = analyzeToneQuality(synthesizedAudio.audioData)
        
        // 품질 기준
        if quality.rms < 0.001 || quality.peak < 0.01 {
            return .failed
        } else if quality.rms > 0.1 && quality.peak > 0.5 && quality.dynamicRange > 20.0 {
            return .excellent
        } else if quality.rms > 0.05 && quality.peak > 0.3 && quality.dynamicRange > 15.0 {
            return .good
        } else if quality.rms > 0.02 && quality.peak > 0.1 && quality.dynamicRange > 10.0 {
            return .fair
        } else {
            return .poor
        }
    }
    
    private func getComplexityMultiplier(for method: SynthesizedAudio.SynthesisMethod) -> Double {
        switch method {
        case .sineWave:
            return 1.0
        case .squareWave, .triangleWave, .sawtoothWave:
            return 1.2
        case .harmonic:
            return 2.0
        }
    }
}

// MARK: - Supporting Types 