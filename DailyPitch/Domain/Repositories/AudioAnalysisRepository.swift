import Foundation
import Combine

/// 오디오 분석 기능을 추상화하는 Repository 프로토콜
protocol AudioAnalysisRepository {
    /// 오디오 파일을 분석하여 주파수 데이터를 추출
    /// - Parameter audioSession: 분석할 오디오 세션
    /// - Returns: 분석 결과를 방출하는 Publisher
    func analyzeAudio(from audioSession: AudioSession) -> AnyPublisher<AudioAnalysisResult, AudioAnalysisError>
    
    /// 오디오 데이터(버퍼)를 직접 분석
    /// - Parameters:
    ///   - audioData: 분석할 오디오 데이터 (Float 배열)
    ///   - sampleRate: 샘플 레이트
    /// - Returns: 주파수 데이터 Publisher
    func analyzeAudioData(_ audioData: [Float], sampleRate: Double) -> AnyPublisher<FrequencyData, AudioAnalysisError>
    
    /// 실시간 오디오 스트림 분석 시작
    /// - Parameter sampleRate: 샘플 레이트
    /// - Returns: 실시간 주파수 데이터 스트림
    func startRealtimeAnalysis(sampleRate: Double) -> AnyPublisher<FrequencyData, AudioAnalysisError>
    
    /// 실시간 분석 중지
    func stopRealtimeAnalysis()
    
    /// 현재 분석 중인지 확인
    var isAnalyzing: Bool { get }
} 