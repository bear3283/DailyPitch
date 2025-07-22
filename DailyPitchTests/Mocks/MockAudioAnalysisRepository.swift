import Foundation
import Combine
@testable import DailyPitch

/// 테스트용 Mock AudioAnalysisRepository
class MockAudioAnalysisRepository: AudioAnalysisRepository {
    
    // MARK: - Mock State
    var mockAnalysisResult: AudioAnalysisResult?
    var mockFrequencyData: FrequencyData?
    var mockAnalysisError: AudioAnalysisError?
    var mockIsAnalyzing: Bool = false
    var mockAnalysisDelay: TimeInterval = 0.1
    
    // MARK: - Call Tracking
    var analyzeAudioCallCount = 0
    var analyzeAudioDataCallCount = 0
    var startRealtimeAnalysisCallCount = 0
    var stopRealtimeAnalysisCallCount = 0
    
    // MARK: - Last Called Parameters
    var lastAnalyzedAudioSession: AudioSession?
    var lastAnalyzedAudioData: [Float]?
    var lastAnalyzedSampleRate: Double?
    
    // MARK: - Subjects for Publishers
    private let realtimeSubject = PassthroughSubject<FrequencyData, AudioAnalysisError>()
    
    // MARK: - AudioAnalysisRepository Implementation
    
    func analyzeAudio(from audioSession: AudioSession) -> AnyPublisher<AudioAnalysisResult, AudioAnalysisError> {
        analyzeAudioCallCount += 1
        lastAnalyzedAudioSession = audioSession
        
        if let error = mockAnalysisError {
            return Fail(error: error)
                .delay(for: .seconds(mockAnalysisDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        let result = mockAnalysisResult ?? createDefaultAnalysisResult(for: audioSession)
        
        return Just(result)
            .setFailureType(to: AudioAnalysisError.self)
            .delay(for: .seconds(mockAnalysisDelay), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func analyzeAudioData(_ audioData: [Float], sampleRate: Double) -> AnyPublisher<FrequencyData, AudioAnalysisError> {
        analyzeAudioDataCallCount += 1
        lastAnalyzedAudioData = audioData
        lastAnalyzedSampleRate = sampleRate
        
        if let error = mockAnalysisError {
            return Fail(error: error)
                .delay(for: .seconds(mockAnalysisDelay), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        let frequencyData = mockFrequencyData ?? createDefaultFrequencyData(sampleRate: sampleRate)
        
        return Just(frequencyData)
            .setFailureType(to: AudioAnalysisError.self)
            .delay(for: .seconds(mockAnalysisDelay), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func startRealtimeAnalysis(sampleRate: Double) -> AnyPublisher<FrequencyData, AudioAnalysisError> {
        startRealtimeAnalysisCallCount += 1
        lastAnalyzedSampleRate = sampleRate
        mockIsAnalyzing = true
        
        // 실시간 분석 시뮬레이션을 위한 타이머
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.mockIsAnalyzing else {
                timer.invalidate()
                return
            }
            
            if let error = self.mockAnalysisError {
                self.realtimeSubject.send(completion: .failure(error))
                timer.invalidate()
            } else {
                let frequencyData = self.mockFrequencyData ?? self.createDefaultFrequencyData(sampleRate: sampleRate)
                self.realtimeSubject.send(frequencyData)
            }
        }
        
        return realtimeSubject.eraseToAnyPublisher()
    }
    
    func stopRealtimeAnalysis() {
        stopRealtimeAnalysisCallCount += 1
        mockIsAnalyzing = false
        realtimeSubject.send(completion: .finished)
    }
    
    var isAnalyzing: Bool {
        return mockIsAnalyzing
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        mockAnalysisResult = nil
        mockFrequencyData = nil
        mockAnalysisError = nil
        mockIsAnalyzing = false
        mockAnalysisDelay = 0.1
        
        analyzeAudioCallCount = 0
        analyzeAudioDataCallCount = 0
        startRealtimeAnalysisCallCount = 0
        stopRealtimeAnalysisCallCount = 0
        
        lastAnalyzedAudioSession = nil
        lastAnalyzedAudioData = nil
        lastAnalyzedSampleRate = nil
    }
    
    func simulateRealtimeData(_ frequencyData: FrequencyData) {
        realtimeSubject.send(frequencyData)
    }
    
    func simulateRealtimeError(_ error: AudioAnalysisError) {
        realtimeSubject.send(completion: .failure(error))
    }
    
    // MARK: - Private Methods
    
    private func createDefaultAnalysisResult(for audioSession: AudioSession) -> AudioAnalysisResult {
        let frequencyData = createDefaultFrequencyData(sampleRate: audioSession.sampleRate)
        
        return AudioAnalysisResult(
            audioSession: audioSession,
            frequencyDataSequence: [frequencyData],
            status: .completed,
            analysisStartTime: Date().addingTimeInterval(-1),
            analysisEndTime: Date(),
            error: nil
        )
    }
    
    private func createDefaultFrequencyData(sampleRate: Double) -> FrequencyData {
        // 테스트용 가짜 주파수 데이터 생성
        let windowSize = 1024
        let frequencies = Array(0..<windowSize/2).map { Double($0) * sampleRate / Double(windowSize) }
        
        // 440Hz(A4) 근처에 피크를 가지는 가짜 데이터
        let magnitudes = frequencies.map { freq in
            if abs(freq - 440.0) < 10.0 {
                return 1.0 // 440Hz 근처에서 높은 진폭
            } else {
                return 0.1 + Double.random(in: 0...0.2) // 배경 노이즈
            }
        }
        
        return FrequencyData(
            frequencies: frequencies,
            magnitudes: magnitudes,
            sampleRate: sampleRate,
            windowSize: windowSize
        )
    }
} 