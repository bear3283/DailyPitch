import Foundation
import Combine

/// 오디오 주파수 분석 Use Case
/// 녹음된 오디오를 분석하여 주파수 데이터를 추출하는 비즈니스 로직을 담당
class AnalyzeFrequencyUseCase {
    
    private let audioAnalysisRepository: AudioAnalysisRepository
    
    init(audioAnalysisRepository: AudioAnalysisRepository) {
        self.audioAnalysisRepository = audioAnalysisRepository
    }
    
    /// 오디오 세션을 분석하여 전체 주파수 데이터를 추출
    /// - Parameter audioSession: 분석할 오디오 세션
    /// - Returns: 분석 결과 Publisher
    func analyzeAudioSession(_ audioSession: AudioSession) -> AnyPublisher<AudioAnalysisResult, AudioAnalysisError> {
        // 오디오 파일 존재 여부 확인
        guard let audioURL = audioSession.audioFileURL,
              FileManager.default.fileExists(atPath: audioURL.path) else {
            return Fail(error: AudioAnalysisError.fileReadError)
                .eraseToAnyPublisher()
        }
        
        // 오디오 지속 시간 확인
        guard audioSession.duration > 0 else {
            return Fail(error: AudioAnalysisError.insufficientData)
                .eraseToAnyPublisher()
        }
        
        return audioAnalysisRepository.analyzeAudio(from: audioSession)
            .map { result in
                // 분석 결과 후처리
                self.postProcessAnalysisResult(result)
            }
            .eraseToAnyPublisher()
    }
    
    /// 원시 오디오 데이터를 직접 분석
    /// - Parameters:
    ///   - audioData: 오디오 샘플 데이터
    ///   - sampleRate: 샘플 레이트
    /// - Returns: 주파수 데이터 Publisher
    func analyzeRawAudioData(_ audioData: [Float], sampleRate: Double) -> AnyPublisher<FrequencyData, AudioAnalysisError> {
        // 데이터 유효성 검증
        guard !audioData.isEmpty else {
            return Fail(error: AudioAnalysisError.insufficientData)
                .eraseToAnyPublisher()
        }
        
        guard sampleRate > 0 else {
            return Fail(error: AudioAnalysisError.invalidAudioData)
                .eraseToAnyPublisher()
        }
        
        return audioAnalysisRepository.analyzeAudioData(audioData, sampleRate: sampleRate)
            .map { frequencyData in
                // 주파수 데이터 검증 및 후처리
                self.validateAndCleanFrequencyData(frequencyData)
            }
            .eraseToAnyPublisher()
    }
    
    /// 실시간 주파수 분석 시작
    /// - Parameter sampleRate: 샘플 레이트
    /// - Returns: 실시간 주파수 데이터 스트림
    func startRealtimeAnalysis(sampleRate: Double = 44100.0) -> AnyPublisher<FrequencyData, AudioAnalysisError> {
        guard sampleRate > 0 else {
            return Fail(error: AudioAnalysisError.invalidAudioData)
                .eraseToAnyPublisher()
        }
        
        return audioAnalysisRepository.startRealtimeAnalysis(sampleRate: sampleRate)
            .map { frequencyData in
                self.validateAndCleanFrequencyData(frequencyData)
            }
            .eraseToAnyPublisher()
    }
    
    /// 실시간 분석 중지
    func stopRealtimeAnalysis() {
        audioAnalysisRepository.stopRealtimeAnalysis()
    }
    
    /// 현재 분석 중인지 확인
    var isCurrentlyAnalyzing: Bool {
        return audioAnalysisRepository.isAnalyzing
    }
    
    /// 주요 주파수에서 노이즈 필터링
    /// - Parameter result: 원본 분석 결과
    /// - Returns: 필터링된 분석 결과
    func filterNoise(from result: AudioAnalysisResult, threshold: Double = 0.01) -> AudioAnalysisResult {
        let filteredSequence = result.frequencyDataSequence.compactMap { frequencyData -> FrequencyData? in
            guard let peakMagnitude = frequencyData.peakMagnitude,
                  peakMagnitude > threshold else {
                return nil
            }
            return frequencyData
        }
        
        return AudioAnalysisResult(
            audioSession: result.audioSession,
            frequencyDataSequence: filteredSequence,
            status: result.status,
            analysisStartTime: result.analysisStartTime,
            analysisEndTime: result.analysisEndTime,
            error: result.error
        )
    }
    
    /// 주파수 데이터에서 특정 범위 추출
    /// - Parameters:
    ///   - result: 분석 결과
    ///   - range: 관심 주파수 범위
    /// - Returns: 해당 범위의 데이터만 포함한 결과
    func extractFrequencyRange(from result: AudioAnalysisResult, range: ClosedRange<Double>) -> AudioAnalysisResult {
        let filteredSequence = result.frequencyDataSequence.map { frequencyData in
            let filteredIndices = frequencyData.frequencies.enumerated().compactMap { index, freq in
                range.contains(freq) ? index : nil
            }
            
            let filteredFreqs = filteredIndices.map { frequencyData.frequencies[$0] }
            let filteredMags = filteredIndices.map { frequencyData.magnitudes[$0] }
            
            return FrequencyData(
                frequencies: filteredFreqs,
                magnitudes: filteredMags,
                sampleRate: frequencyData.sampleRate,
                windowSize: frequencyData.windowSize,
                timestamp: frequencyData.timestamp
            )
        }
        
        return AudioAnalysisResult(
            audioSession: result.audioSession,
            frequencyDataSequence: filteredSequence,
            status: result.status,
            analysisStartTime: result.analysisStartTime,
            analysisEndTime: result.analysisEndTime,
            error: result.error
        )
    }
    
    // MARK: - Private Methods
    
    private func postProcessAnalysisResult(_ result: AudioAnalysisResult) -> AudioAnalysisResult {
        print("🔍 분석 후처리 시작 - 데이터 수: \(result.frequencyDataSequence.count)")
        
        // 분석 결과가 유효한지 확인
        guard result.isSuccessful else {
            print("❌ 분석 결과가 유효하지 않음")
            return result
        }
        
        // 원본 주파수들 로깅
        let originalPeakFreqs = result.frequencyDataSequence.compactMap { $0.peakFrequency }
        print("🔍 원본 피크 주파수들: \(originalPeakFreqs.prefix(10).map { String(format: "%.1f", $0) })")
        
        // 노이즈 필터링 적용
        let filteredResult = filterNoise(from: result)
        let filteredPeakFreqs = filteredResult.frequencyDataSequence.compactMap { $0.peakFrequency }
        print("🔍 필터링 후 피크 주파수들: \(filteredPeakFreqs.prefix(10).map { String(format: "%.1f", $0) })")
        
        // 음향 분석 범위로 제한 (10Hz - 20kHz) - 환경음 포함
        let humanAudioRange = extractFrequencyRange(from: filteredResult, range: 10.0...20000.0)
        let finalPeakFreqs = humanAudioRange.frequencyDataSequence.compactMap { $0.peakFrequency }
        print("🔍 최종 피크 주파수들: \(finalPeakFreqs.prefix(10).map { String(format: "%.1f", $0) })")
        print("🔍 최종 평균 주파수: \(humanAudioRange.averagePeakFrequency ?? 0.0)")
        
        return humanAudioRange
    }
    
    private func validateAndCleanFrequencyData(_ frequencyData: FrequencyData) -> FrequencyData {
        // 데이터 유효성 검증
        guard frequencyData.isValid else {
            return frequencyData
        }
        
        // NaN이나 무한대 값 제거
        let cleanedFrequencies = frequencyData.frequencies.map { freq in
            freq.isNaN || freq.isInfinite ? 0.0 : freq
        }
        
        let cleanedMagnitudes = frequencyData.magnitudes.map { mag in
            mag.isNaN || mag.isInfinite ? 0.0 : mag
        }
        
        return FrequencyData(
            frequencies: cleanedFrequencies,
            magnitudes: cleanedMagnitudes,
            sampleRate: frequencyData.sampleRate,
            windowSize: frequencyData.windowSize,
            timestamp: frequencyData.timestamp
        )
    }
} 