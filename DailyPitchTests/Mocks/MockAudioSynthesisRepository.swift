import Foundation
import Combine
@testable import DailyPitch

/// 테스트용 AudioSynthesisRepository Mock 구현체
class MockAudioSynthesisRepository: AudioSynthesisRepository {
    
    // MARK: - Mock 설정 프로퍼티들
    
    var shouldReturnError = false
    var errorToReturn: AudioSynthesisError = .synthesisProcessingFailed
    var delayInSeconds: TimeInterval = 0.0
    var mockSynthesizedAudio: SynthesizedAudio?
    var mockSaveResult = true
    
    // MARK: - 호출 추적 프로퍼티들
    
    var synthesizeCallCount = 0
    var synthesizeSequenceCallCount = 0
    var synthesizeChordCallCount = 0
    var synthesizeFromAnalysisCallCount = 0
    var saveAudioCallCount = 0
    var mixAudioCallCount = 0
    
    var lastSynthesizedNote: MusicNote?
    var lastSynthesizedNotes: [MusicNote]?
    var lastSynthesisMethod: SynthesizedAudio.SynthesisMethod?
    var lastAnalysisResult: AudioAnalysisResult?
    var lastSaveURL: URL?
    var lastMixParameters: (AudioSession, SynthesizedAudio, Float, Float)?
    
    // MARK: - Repository 프로퍼티들
    
    var supportedSynthesisMethods: [SynthesizedAudio.SynthesisMethod] = [
        .sineWave, .squareWave, .sawtoothWave, .triangleWave
    ]
    
    private var _isSynthesizing = false
    var isSynthesizing: Bool {
        return _isSynthesizing
    }
    
    // MARK: - Mock 설정 메소드들
    
    func reset() {
        shouldReturnError = false
        errorToReturn = .synthesisProcessingFailed
        delayInSeconds = 0.0
        mockSynthesizedAudio = nil
        mockSaveResult = true
        
        synthesizeCallCount = 0
        synthesizeSequenceCallCount = 0
        synthesizeChordCallCount = 0
        synthesizeFromAnalysisCallCount = 0
        saveAudioCallCount = 0
        mixAudioCallCount = 0
        
        lastSynthesizedNote = nil
        lastSynthesizedNotes = nil
        lastSynthesisMethod = nil
        lastAnalysisResult = nil
        lastSaveURL = nil
        lastMixParameters = nil
        
        _isSynthesizing = false
    }
    
    func setMockResult(_ audio: SynthesizedAudio) {
        mockSynthesizedAudio = audio
    }
    
    func setError(_ error: AudioSynthesisError) {
        shouldReturnError = true
        errorToReturn = error
    }
    
    func setDelay(_ delay: TimeInterval) {
        delayInSeconds = delay
    }
    
    // MARK: - Repository 메소드 구현
    
    func synthesize(note: MusicNote, method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        synthesizeCallCount += 1
        lastSynthesizedNote = note
        lastSynthesisMethod = method
        
        return createMockPublisher {
            if let mockAudio = self.mockSynthesizedAudio {
                return mockAudio
            } else {
                // 기본 Mock 오디오 생성
                return SynthesizedAudio.from(note: note, method: method)
            }
        }
    }
    
    func synthesizeSequence(notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        synthesizeSequenceCallCount += 1
        lastSynthesizedNotes = notes
        lastSynthesisMethod = method
        
        return createMockPublisher {
            if let mockAudio = self.mockSynthesizedAudio {
                return mockAudio
            } else {
                return SynthesizedAudio.fromSequence(notes: notes, method: method)
            }
        }
    }
    
    func synthesizeChord(notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        synthesizeChordCallCount += 1
        lastSynthesizedNotes = notes
        lastSynthesisMethod = method
        
        return createMockPublisher {
            if let mockAudio = self.mockSynthesizedAudio {
                return mockAudio
            } else {
                return SynthesizedAudio.fromChord(notes: notes, method: method)
            }
        }
    }
    
    func synthesizeFromAnalysis(
        analysisResult: AudioAnalysisResult,
        method: SynthesizedAudio.SynthesisMethod,
        noteDuration: TimeInterval
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        synthesizeFromAnalysisCallCount += 1
        lastAnalysisResult = analysisResult
        lastSynthesisMethod = method
        
        return createMockPublisher {
            if let mockAudio = self.mockSynthesizedAudio {
                return mockAudio
            } else {
                // 분석 결과에서 주파수 추출하여 음계 생성
                guard let peakFrequency = analysisResult.peakFrequency,
                      let note = MusicNote.from(frequency: peakFrequency, duration: noteDuration) else {
                    throw AudioSynthesisError.invalidMusicNote
                }
                
                return SynthesizedAudio.from(note: note, method: method)
            }
        }
    }
    
    func saveAudio(_ audio: SynthesizedAudio, to url: URL) -> AnyPublisher<Bool, AudioSynthesisError> {
        saveAudioCallCount += 1
        lastSaveURL = url
        
        return createMockPublisher {
            return self.mockSaveResult
        }
    }
    
    func mixAudio(
        originalAudio: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        originalVolume: Float,
        synthesizedVolume: Float
    ) -> AnyPublisher<SynthesizedAudio, AudioSynthesisError> {
        mixAudioCallCount += 1
        lastMixParameters = (originalAudio, synthesizedAudio, originalVolume, synthesizedVolume)
        
        return createMockPublisher {
            if let mockAudio = self.mockSynthesizedAudio {
                return mockAudio
            } else {
                // 간단한 믹싱 시뮬레이션 (실제로는 synthesizedAudio 반환)
                return synthesizedAudio
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func createMockPublisher<T>(_ closure: @escaping () throws -> T) -> AnyPublisher<T, AudioSynthesisError> {
        _isSynthesizing = true
        
        let publisher = Future<T, AudioSynthesisError> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + self.delayInSeconds) {
                self._isSynthesizing = false
                
                if self.shouldReturnError {
                    promise(.failure(self.errorToReturn))
                } else {
                    do {
                        let result = try closure()
                        promise(.success(result))
                    } catch {
                        let synthesisError = error as? AudioSynthesisError ?? .synthesisProcessingFailed
                        promise(.failure(synthesisError))
                    }
                }
            }
        }
        
        return publisher.eraseToAnyPublisher()
    }
}

// MARK: - Mock Factory 메소드들

extension MockAudioSynthesisRepository {
    
    /// 성공적인 합성을 시뮬레이션하는 Mock
    static func successMock() -> MockAudioSynthesisRepository {
        let mock = MockAudioSynthesisRepository()
        mock.shouldReturnError = false
        
        // 기본 Mock 오디오 생성
        let testNote = MusicNote.from(frequency: 440.0, duration: 1.0, amplitude: 0.5)!
        mock.setMockResult(SynthesizedAudio.from(note: testNote))
        
        return mock
    }
    
    /// 실패를 시뮬레이션하는 Mock
    static func failureMock(error: AudioSynthesisError = .synthesisProcessingFailed) -> MockAudioSynthesisRepository {
        let mock = MockAudioSynthesisRepository()
        mock.setError(error)
        return mock
    }
    
    /// 지연을 시뮬레이션하는 Mock
    static func delayedMock(delay: TimeInterval) -> MockAudioSynthesisRepository {
        let mock = MockAudioSynthesisRepository()
        mock.setDelay(delay)
        return mock.successMock()
    }
    
    /// 특정 오디오를 반환하는 Mock
    static func customAudioMock(_ audio: SynthesizedAudio) -> MockAudioSynthesisRepository {
        let mock = MockAudioSynthesisRepository()
        mock.setMockResult(audio)
        return mock
    }
} 