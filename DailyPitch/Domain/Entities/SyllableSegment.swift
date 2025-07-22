import Foundation

/// 개별 음절 세그먼트를 나타내는 엔터티
/// "안녕하세요"에서 "안", "녕", "하", "세", "요" 각각을 나타냄
struct SyllableSegment {
    /// 고유 식별자
    let id: UUID
    
    /// 세그먼트 순서 (0부터 시작)
    let index: Int
    
    /// 시작 시간 (초)
    let startTime: TimeInterval
    
    /// 종료 시간 (초)
    let endTime: TimeInterval
    
    /// 주파수 분석 결과
    let frequencyData: FrequencyData
    
    /// 추출된 음계 (가장 가까운 음)
    let musicNote: MusicNote?
    
    /// 세그먼트의 에너지 레벨 (0.0 ~ 1.0)
    let energy: Double
    
    /// 신뢰도 점수 (0.0 ~ 1.0)
    let confidence: Double
    
    /// 세그먼트 타입
    let type: SegmentType
    
    // MARK: - Computed Properties
    
    /// 지속 시간 (초)
    var duration: TimeInterval {
        return endTime - startTime
    }
    
    /// 중심 시간 (초)
    var centerTime: TimeInterval {
        return (startTime + endTime) / 2.0
    }
    
    /// 주요 주파수 (Hz)
    var primaryFrequency: Double? {
        return frequencyData.peakFrequency
    }
    
    /// 음계명 (간단 표기)
    var noteName: String? {
        return musicNote?.name
    }
    
    /// 세그먼트가 유효한지 확인
    var isValid: Bool {
        return duration > 0 &&
               energy > 0.01 &&
               confidence > 0.1 &&
               type != .silence
    }
    
    /// 세그먼트의 품질 등급
    var qualityGrade: QualityGrade {
        if confidence > 0.8 && energy > 0.5 {
            return .excellent
        } else if confidence > 0.6 && energy > 0.3 {
            return .good
        } else if confidence > 0.4 && energy > 0.1 {
            return .fair
        } else {
            return .poor
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        index: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        frequencyData: FrequencyData,
        musicNote: MusicNote? = nil,
        energy: Double = 0.0,
        confidence: Double = 0.0,
        type: SegmentType = .speech
    ) {
        self.id = id
        self.index = index
        self.startTime = startTime
        self.endTime = endTime
        self.frequencyData = frequencyData
        self.musicNote = musicNote
        self.energy = max(0.0, min(1.0, energy))
        self.confidence = max(0.0, min(1.0, confidence))
        self.type = type
    }
    
    /// FrequencyData로부터 SyllableSegment 생성
    /// - Parameters:
    ///   - frequencyData: 주파수 분석 결과
    ///   - index: 세그먼트 순서
    ///   - windowDuration: 창 지속시간 (초)
    /// - Returns: 생성된 SyllableSegment
    static func from(
        frequencyData: FrequencyData,
        index: Int,
        windowDuration: TimeInterval
    ) -> SyllableSegment {
        // 시간 계산 (FrequencyData의 timestamp 기반)
        let centerTime = frequencyData.timestamp.timeIntervalSinceNow * -1 // 현재로부터 얼마 전인지
        let startTime = centerTime - windowDuration / 2.0
        let endTime = centerTime + windowDuration / 2.0
        
        // 음계 추출
        var musicNote: MusicNote? = nil
        if let peakFreq = frequencyData.peakFrequency {
            musicNote = MusicNote.from(frequency: peakFreq)
        }
        
        // 에너지 계산
        let totalEnergy = frequencyData.magnitudes.reduce(0, +)
        let normalizedEnergy = min(1.0, totalEnergy * 10.0) // 임의의 스케일링
        
        // 신뢰도 계산 (피크의 뚜렷함 기반)
        let confidence = calculateConfidence(from: frequencyData)
        
        // 세그먼트 타입 결정
        let segmentType: SegmentType = normalizedEnergy > 0.05 ? .speech : .silence
        
        return SyllableSegment(
            index: index,
            startTime: startTime,
            endTime: endTime,
            frequencyData: frequencyData,
            musicNote: musicNote,
            energy: normalizedEnergy,
            confidence: confidence,
            type: segmentType
        )
    }
    
    /// 주파수 데이터로부터 신뢰도 계산
    /// - Parameter frequencyData: 분석할 주파수 데이터
    /// - Returns: 신뢰도 점수 (0.0 ~ 1.0)
    private static func calculateConfidence(from frequencyData: FrequencyData) -> Double {
        guard let peakMagnitude = frequencyData.peakMagnitude else { return 0.0 }
        
        // 전체 에너지 대비 피크 에너지 비율
        let totalEnergy = frequencyData.magnitudes.reduce(0, +)
        let peakRatio = totalEnergy > 0 ? peakMagnitude / totalEnergy : 0.0
        
        // 주변 주파수 대비 피크의 뚜렷함
        let sharpness = calculatePeakSharpness(frequencyData)
        
        // 종합 신뢰도 (가중 평균)
        return min(1.0, (peakRatio * 0.6 + sharpness * 0.4) * 2.0)
    }
    
    /// 피크의 뚜렷함 계산
    /// - Parameter frequencyData: 분석할 주파수 데이터
    /// - Returns: 뚜렷함 점수 (0.0 ~ 1.0)
    private static func calculatePeakSharpness(_ frequencyData: FrequencyData) -> Double {
        guard let peakFreq = frequencyData.peakFrequency,
              let peakIndex = frequencyData.frequencies.firstIndex(where: { abs($0 - peakFreq) < 1.0 }) else {
            return 0.0
        }
        
        let magnitudes = frequencyData.magnitudes
        guard peakIndex < magnitudes.count else { return 0.0 }
        
        let peakMag = magnitudes[peakIndex]
        
        // 주변 5개 빈의 평균과 비교
        let surroundingIndices = max(0, peakIndex - 5)..<min(magnitudes.count, peakIndex + 6)
        let surroundingMagnitudes = surroundingIndices.compactMap { i in
            i == peakIndex ? nil : magnitudes[i]
        }
        
        guard !surroundingMagnitudes.isEmpty else { return 0.0 }
        
        let averageSurrounding = surroundingMagnitudes.reduce(0, +) / Double(surroundingMagnitudes.count)
        
        return averageSurrounding > 0 ? min(1.0, peakMag / averageSurrounding / 10.0) : 1.0
    }
}

// MARK: - SegmentType

/// 세그먼트의 타입
enum SegmentType: String, CaseIterable {
    case speech = "speech"           // 음성
    case silence = "silence"         // 무음
    case noise = "noise"             // 노이즈
    case breath = "breath"           // 숨소리
    case transition = "transition"   // 전환 구간
    
    /// 타입의 한국어 이름
    var koreanName: String {
        switch self {
        case .speech: return "음성"
        case .silence: return "무음"
        case .noise: return "노이즈"
        case .breath: return "숨소리"
        case .transition: return "전환"
        }
    }
    
    /// 타입의 아이콘
    var icon: String {
        switch self {
        case .speech: return "waveform.and.person.filled"
        case .silence: return "speaker.slash"
        case .noise: return "exclamationmark.triangle"
        case .breath: return "wind"
        case .transition: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - QualityGrade

/// 세그먼트의 품질 등급
enum QualityGrade: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    /// 등급의 한국어 이름
    var koreanName: String {
        switch self {
        case .excellent: return "우수"
        case .good: return "양호"
        case .fair: return "보통"
        case .poor: return "미흡"
        }
    }
    
    /// 등급의 색상 (SwiftUI Color 문자열)
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    /// 등급의 별점 (1-5점)
    var stars: Int {
        switch self {
        case .excellent: return 5
        case .good: return 4
        case .fair: return 3
        case .poor: return 2
        }
    }
    
    /// 등급의 상세 설명 (koreanName과 동일)
    var description: String {
        return koreanName
    }
}

// MARK: - Extensions

extension SyllableSegment: Equatable {
    static func == (lhs: SyllableSegment, rhs: SyllableSegment) -> Bool {
        return lhs.id == rhs.id
    }
}

extension SyllableSegment: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SyllableSegment: CustomStringConvertible {
    var description: String {
        let noteDesc = musicNote?.name ?? "N/A"
        let freqDesc = primaryFrequency.map { String(format: "%.1f", $0) } ?? "N/A"
        return "SyllableSegment[\(index)]: \(noteDesc) (\(freqDesc)Hz) at \(String(format: "%.3f", startTime))s"
    }
}

/// 여러 음절 세그먼트의 집합 분석
extension Array where Element == SyllableSegment {
    
    /// 유효한 음성 세그먼트만 필터링
    var speechSegments: [SyllableSegment] {
        return self.filter { $0.type == .speech && $0.isValid }
    }
    
    /// 추출된 음계들
    var extractedNotes: [MusicNote] {
        return self.compactMap { $0.musicNote }
    }
    
    /// 평균 신뢰도
    var averageConfidence: Double {
        let validSegments = speechSegments
        guard !validSegments.isEmpty else { return 0.0 }
        
        let totalConfidence = validSegments.reduce(0) { $0 + $1.confidence }
        return totalConfidence / Double(validSegments.count)
    }
    
    /// 총 음성 지속 시간
    var totalSpeechDuration: TimeInterval {
        return speechSegments.reduce(0) { $0 + $1.duration }
    }
    
    /// 주요 주파수 범위
    var frequencyRange: ClosedRange<Double>? {
        let frequencies = speechSegments.compactMap { $0.primaryFrequency }
        guard let min = frequencies.min(), let max = frequencies.max() else { return nil }
        return min...max
    }
} 