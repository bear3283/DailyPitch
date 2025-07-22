import Foundation

/// 시간 기반 오디오 분석의 전체 결과를 담는 엔터티
/// "안녕하세요" 전체에 대한 음절별 분석 결과와 종합 정보
struct TimeBasedAnalysisResult {
    /// 고유 식별자
    let id: UUID
    
    /// 분석 대상 오디오 세션
    let audioSession: AudioSession
    
    /// 개별 음절 세그먼트들 (시간순)
    let syllableSegments: [SyllableSegment]
    
    /// 분석 상태
    let status: AnalysisStatus
    
    /// 분석 시작 시간
    let analysisStartTime: Date
    
    /// 분석 완료 시간
    let analysisEndTime: Date?
    
    /// 분석 에러 (있는 경우)
    let error: AudioAnalysisError?
    
    /// 분석 메타데이터
    let metadata: AnalysisMetadata
    
    // MARK: - Computed Properties
    
    /// 분석이 성공적으로 완료되었는지 확인
    var isSuccessful: Bool {
        return status == .completed && error == nil && !syllableSegments.isEmpty
    }
    
    /// 분석에 걸린 시간 (초)
    var processingDuration: TimeInterval? {
        guard let endTime = analysisEndTime else { return nil }
        return endTime.timeIntervalSince(analysisStartTime)
    }
    
    /// 유효한 음성 세그먼트들
    var validSpeechSegments: [SyllableSegment] {
        return syllableSegments.speechSegments
    }
    
    /// 추출된 음계들 (시간순)
    var extractedNotes: [MusicNote] {
        return validSpeechSegments.compactMap { $0.musicNote }
    }
    
    /// 각 음절의 음계명들 (시간순)
    var syllableNotes: [String] {
        return validSpeechSegments.compactMap { $0.noteName }
    }
    
    /// 전체 분석 신뢰도 평균
    var overallConfidence: Double {
        return syllableSegments.averageConfidence
    }
    
    /// 총 음성 지속 시간
    var totalSpeechDuration: TimeInterval {
        return syllableSegments.totalSpeechDuration
    }
    
    /// 음성 활동 비율 (전체 시간 대비 음성 시간)
    var speechActivityRatio: Double {
        let totalDuration = audioSession.duration
        return totalDuration > 0 ? totalSpeechDuration / totalDuration : 0.0
    }
    
    /// 주파수 범위 (최소 ~ 최대)
    var frequencyRange: ClosedRange<Double>? {
        return syllableSegments.frequencyRange
    }
    
    /// 평균 주파수
    var averageFrequency: Double? {
        let frequencies = validSpeechSegments.compactMap { $0.primaryFrequency }
        guard !frequencies.isEmpty else { return nil }
        return frequencies.reduce(0, +) / Double(frequencies.count)
    }
    
    /// 분석 품질 등급
    var qualityGrade: OverallQualityGrade {
        let confidence = overallConfidence
        let speechRatio = speechActivityRatio
        let segmentCount = validSpeechSegments.count
        
        if confidence > 0.8 && speechRatio > 0.5 && segmentCount >= 3 {
            return .excellent
        } else if confidence > 0.6 && speechRatio > 0.3 && segmentCount >= 2 {
            return .good
        } else if confidence > 0.4 && speechRatio > 0.1 && segmentCount >= 1 {
            return .fair
        } else {
            return .poor
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        audioSession: AudioSession,
        syllableSegments: [SyllableSegment] = [],
        status: AnalysisStatus = .processing,
        analysisStartTime: Date = Date(),
        analysisEndTime: Date? = nil,
        error: AudioAnalysisError? = nil,
        metadata: AnalysisMetadata = AnalysisMetadata()
    ) {
        self.id = id
        self.audioSession = audioSession
        self.syllableSegments = syllableSegments.sorted { $0.startTime < $1.startTime }
        self.status = status
        self.analysisStartTime = analysisStartTime
        self.analysisEndTime = analysisEndTime
        self.error = error
        self.metadata = metadata
    }
    
    /// FrequencyData 배열로부터 TimeBasedAnalysisResult 생성
    /// - Parameters:
    ///   - frequencyDataArray: 시간순 주파수 분석 결과 배열
    ///   - audioSession: 오디오 세션 정보
    ///   - windowDuration: 각 창의 지속시간
    /// - Returns: 생성된 분석 결과
    static func from(
        frequencyDataArray: [FrequencyData],
        audioSession: AudioSession,
        windowDuration: TimeInterval = 0.023 // ~23ms (일반적인 음성 분석 창 크기)
    ) -> TimeBasedAnalysisResult {
        
        let startTime = Date()
        
        // FrequencyData를 SyllableSegment로 변환
        let syllableSegments = frequencyDataArray.enumerated().map { index, frequencyData in
            SyllableSegment.from(
                frequencyData: frequencyData,
                index: index,
                windowDuration: windowDuration
            )
        }
        
        // 분석 메타데이터 생성
        let metadata = AnalysisMetadata(
            totalSegments: syllableSegments.count,
            validSegments: syllableSegments.speechSegments.count,
            averageEnergy: syllableSegments.speechSegments.isEmpty ? 0.0 : 
                syllableSegments.speechSegments.reduce(0) { $0 + $1.energy } / Double(syllableSegments.speechSegments.count),
            frequencyRange: syllableSegments.frequencyRange,
            analysisMethod: .timeDomain,
            windowSize: windowDuration
        )
        
        return TimeBasedAnalysisResult(
            audioSession: audioSession,
            syllableSegments: syllableSegments,
            status: .completed,
            analysisStartTime: startTime,
            analysisEndTime: Date(),
            error: nil,
            metadata: metadata
        )
    }
    
    /// 특정 시간 범위의 세그먼트들 필터링
    /// - Parameter timeRange: 시간 범위 (초)
    /// - Returns: 해당 시간 범위의 세그먼트들
    func segments(in timeRange: ClosedRange<TimeInterval>) -> [SyllableSegment] {
        return syllableSegments.filter { segment in
            timeRange.overlaps(segment.startTime...segment.endTime)
        }
    }
    
    /// 특정 품질 등급 이상의 세그먼트들 필터링
    /// - Parameter minQuality: 최소 품질 등급
    /// - Returns: 해당 품질 이상의 세그먼트들
    func segments(withMinQuality minQuality: QualityGrade) -> [SyllableSegment] {
        let qualityOrder: [QualityGrade] = [.poor, .fair, .good, .excellent]
        guard let minIndex = qualityOrder.firstIndex(of: minQuality) else { return [] }
        
        return syllableSegments.filter { segment in
            if let segmentIndex = qualityOrder.firstIndex(of: segment.qualityGrade) {
                return segmentIndex >= minIndex
            }
            return false
        }
    }
    
    /// 음악 스케일 추천을 위한 데이터 제공
    /// - Returns: 스케일 분석용 음정 배열 (반음 단위)
    func getScaleAnalysisData() -> [Int] {
        return extractedNotes.map { $0.noteIndex }
    }
}

// MARK: - Supporting Types

/// 분석 상태
enum AnalysisStatus: String, CaseIterable {
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var koreanName: String {
        switch self {
        case .processing: return "분석 중"
        case .completed: return "완료"
        case .failed: return "실패"
        case .cancelled: return "취소됨"
        }
    }
}

/// 전체 품질 등급
enum OverallQualityGrade: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"  
    case fair = "fair"
    case poor = "poor"
    
    var koreanName: String {
        switch self {
        case .excellent: return "우수"
        case .good: return "양호"
        case .fair: return "보통"
        case .poor: return "미흡"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "checkmark.circle.fill"
        case .fair: return "minus.circle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }
}

/// 분석 메타데이터
struct AnalysisMetadata {
    /// 총 세그먼트 수
    let totalSegments: Int
    
    /// 유효한 세그먼트 수
    let validSegments: Int
    
    /// 평균 에너지
    let averageEnergy: Double
    
    /// 주파수 범위
    let frequencyRange: ClosedRange<Double>?
    
    /// 분석 방법
    let analysisMethod: AnalysisMethod
    
    /// 윈도우 크기 (초)
    let windowSize: TimeInterval
    
    /// 기본 초기화
    init(
        totalSegments: Int = 0,
        validSegments: Int = 0,
        averageEnergy: Double = 0.0,
        frequencyRange: ClosedRange<Double>? = nil,
        analysisMethod: AnalysisMethod = .timeDomain,
        windowSize: TimeInterval = 0.023
    ) {
        self.totalSegments = totalSegments
        self.validSegments = validSegments
        self.averageEnergy = averageEnergy
        self.frequencyRange = frequencyRange
        self.analysisMethod = analysisMethod
        self.windowSize = windowSize
    }
    
    /// 유효 세그먼트 비율
    var validSegmentRatio: Double {
        return totalSegments > 0 ? Double(validSegments) / Double(totalSegments) : 0.0
    }
}

/// 분석 방법
enum AnalysisMethod: String, CaseIterable {
    case timeDomain = "time_domain"
    case frequencyDomain = "frequency_domain"
    case hybrid = "hybrid"
    
    var koreanName: String {
        switch self {
        case .timeDomain: return "시간 영역"
        case .frequencyDomain: return "주파수 영역"
        case .hybrid: return "하이브리드"
        }
    }
}

// MARK: - Extensions

extension TimeBasedAnalysisResult: Equatable {
    static func == (lhs: TimeBasedAnalysisResult, rhs: TimeBasedAnalysisResult) -> Bool {
        return lhs.id == rhs.id
    }
}

extension TimeBasedAnalysisResult: CustomStringConvertible {
    var description: String {
        let noteNames = syllableNotes.joined(separator: " → ")
        return "TimeBasedAnalysis: [\(noteNames)] (품질: \(qualityGrade.koreanName), 신뢰도: \(String(format: "%.1f%%", overallConfidence * 100)))"
    }
} 