import Foundation

/// 오디오 분석 처리 상태
enum AudioAnalysisStatus {
    case processing
    case completed
    case failed
}

/// 오디오 분석 에러 타입
enum AudioAnalysisError: Error {
    case invalidAudioData
    case analysisTimeout
    case insufficientData
    case fftProcessingFailed
    case fileReadError
}

/// 전체 오디오 분석 결과를 담는 엔터티
struct AudioAnalysisResult {
    /// 분석 대상 오디오 세션
    let audioSession: AudioSession
    
    /// FFT 분석 결과 (시간별 주파수 데이터 배열)
    let frequencyDataSequence: [FrequencyData]
    
    /// 분석 상태
    let status: AudioAnalysisStatus
    
    /// 분석 시작 시간
    let analysisStartTime: Date
    
    /// 분석 완료 시간
    let analysisEndTime: Date?
    
    /// 분석 에러 (있는 경우)
    let error: AudioAnalysisError?
    
    /// 전체 분석 기간 동안의 평균 주요 주파수
    var averagePeakFrequency: Double? {
        let peakFrequencies = frequencyDataSequence.compactMap { $0.peakFrequency }
        guard !peakFrequencies.isEmpty else { return nil }
        
        return peakFrequencies.reduce(0, +) / Double(peakFrequencies.count)
    }
    
    /// 전체 분석 기간 동안의 최대 주파수
    var maximumFrequency: Double? {
        return frequencyDataSequence.compactMap { $0.peakFrequency }.max()
    }
    
    /// 전체 분석 기간 동안의 최소 주파수
    var minimumFrequency: Double? {
        return frequencyDataSequence.compactMap { $0.peakFrequency }.min()
    }
    
    /// 분석에 걸린 시간 (초)
    var processingDuration: TimeInterval? {
        guard let endTime = analysisEndTime else { return nil }
        return endTime.timeIntervalSince(analysisStartTime)
    }
    
    /// 주파수 데이터 수
    var dataPointCount: Int {
        return frequencyDataSequence.count
    }
    
    /// 분석이 성공적으로 완료되었는지 확인
    var isSuccessful: Bool {
        return status == .completed && error == nil && !frequencyDataSequence.isEmpty
    }
    
    /// 특정 주파수 범위에서 가장 활발한 구간 찾기
    /// - Parameter range: 찾고자 하는 주파수 범위
    /// - Returns: 해당 범위에서 가장 큰 진폭을 가진 FrequencyData
    func mostActiveSegment(in range: ClosedRange<Double>) -> FrequencyData? {
        return frequencyDataSequence.max { first, second in
            let firstAvg = first.averageMagnitude(in: range)
            let secondAvg = second.averageMagnitude(in: range)
            return firstAvg < secondAvg
        }
    }
    
    /// 주파수 분포 히스토그램 생성
    /// - Parameter binCount: 히스토그램 구간 수
    /// - Returns: 주파수별 빈도수
    func frequencyHistogram(binCount: Int = 20) -> [Double: Int] {
        let allPeakFreqs = frequencyDataSequence.compactMap { $0.peakFrequency }
        guard !allPeakFreqs.isEmpty else { return [:] }
        
        let minFreq = allPeakFreqs.min() ?? 0
        let maxFreq = allPeakFreqs.max() ?? 0
        let binSize = (maxFreq - minFreq) / Double(binCount)
        
        var histogram: [Double: Int] = [:]
        
        for freq in allPeakFreqs {
            let binIndex = Int((freq - minFreq) / binSize)
            let binCenter = minFreq + (Double(binIndex) + 0.5) * binSize
            histogram[binCenter, default: 0] += 1
        }
        
        return histogram
    }
    
    init(
        audioSession: AudioSession,
        frequencyDataSequence: [FrequencyData] = [],
        status: AudioAnalysisStatus = .processing,
        analysisStartTime: Date = Date(),
        analysisEndTime: Date? = nil,
        error: AudioAnalysisError? = nil
    ) {
        self.audioSession = audioSession
        self.frequencyDataSequence = frequencyDataSequence
        self.status = status
        self.analysisStartTime = analysisStartTime
        self.analysisEndTime = analysisEndTime
        self.error = error
    }
}

extension AudioAnalysisResult: Equatable {
    static func == (lhs: AudioAnalysisResult, rhs: AudioAnalysisResult) -> Bool {
        return lhs.audioSession == rhs.audioSession &&
               lhs.frequencyDataSequence == rhs.frequencyDataSequence &&
               lhs.status == rhs.status &&
               lhs.analysisStartTime == rhs.analysisStartTime &&
               lhs.analysisEndTime == rhs.analysisEndTime
    }
} 