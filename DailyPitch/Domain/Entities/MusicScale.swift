//
//  MusicScale.swift
//  DailyPitch
//
//  Created by bear on 7/9/25.
//

import Foundation

/// 음악 스케일을 나타내는 엔티티
/// 다양한 음악 스케일의 정보와 음정 간격을 정의
struct MusicScale: Equatable, Codable {
    
    // MARK: - Properties
    
    /// 스케일 고유 ID
    let id: String
    
    /// 스케일 이름 (한국어)
    let name: String
    
    /// 스케일 이름 (영어)
    let englishName: String
    
    /// 스케일 타입
    let type: ScaleType
    
    /// 반음 단위의 음정 간격 배열 (0부터 시작)
    /// 예: 장조 = [0, 2, 4, 5, 7, 9, 11]
    let intervals: [Int]
    
    /// 스케일의 특징 설명
    let description: String
    
    /// 스케일의 분위기/느낌
    let mood: ScaleMood
    
    /// 스케일의 복잡도 (1-5, 1이 가장 간단)
    let complexity: Int
    
    /// 이 스케일이 가장 잘 어울리는 장르들
    let genres: [MusicGenre]
    
    // MARK: - Computed Properties
    
    /// 스케일의 음계 개수
    var noteCount: Int {
        return intervals.count
    }
    
    /// 스케일이 완전한지 확인 (최소 3개 이상의 음)
    var isComplete: Bool {
        return intervals.count >= 3
    }
    
    /// 스케일의 음정 간격 패턴 (연속된 간격)
    var intervalPattern: [Int] {
        guard intervals.count > 1 else { return [] }
        
        var pattern: [Int] = []
        for i in 1..<intervals.count {
            pattern.append(intervals[i] - intervals[i-1])
        }
        return pattern
    }
    
    // MARK: - Initializer
    
    init(
        id: String,
        name: String,
        englishName: String,
        type: ScaleType,
        intervals: [Int],
        description: String,
        mood: ScaleMood,
        complexity: Int = 3,
        genres: [MusicGenre] = []
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.type = type
        self.intervals = intervals.sorted() // 항상 정렬된 상태 유지
        self.description = description
        self.mood = mood
        self.complexity = max(1, min(5, complexity)) // 1-5 범위로 제한
        self.genres = genres
    }
}

// MARK: - ScaleType

/// 스케일의 기본 타입 분류
enum ScaleType: String, CaseIterable, Codable {
    case major = "major"           // 장조
    case minor = "minor"           // 단조
    case pentatonic = "pentatonic" // 펜타토닉
    case blues = "blues"           // 블루스
    case modal = "modal"           // 교회선법
    case chromatic = "chromatic"   // 반음계
    case exotic = "exotic"         // 특수 스케일
    
    /// 타입의 한국어 이름
    var koreanName: String {
        switch self {
        case .major: return "장조"
        case .minor: return "단조"
        case .pentatonic: return "펜타토닉"
        case .blues: return "블루스"
        case .modal: return "교회선법"
        case .chromatic: return "반음계"
        case .exotic: return "특수선법"
        }
    }
}

// MARK: - ScaleMood

/// 스케일의 분위기/느낌
enum ScaleMood: String, CaseIterable, Codable {
    case bright = "bright"         // 밝은
    case dark = "dark"             // 어두운
    case peaceful = "peaceful"     // 평화로운
    case mysterious = "mysterious" // 신비로운
    case energetic = "energetic"   // 역동적인
    case melancholic = "melancholic" // 우울한
    case exotic_mood = "exotic"    // 이국적인
    case neutral = "neutral"       // 중성적인
    
    /// 분위기의 한국어 설명
    var koreanName: String {
        switch self {
        case .bright: return "밝은"
        case .dark: return "어두운"
        case .peaceful: return "평화로운"
        case .mysterious: return "신비로운"
        case .energetic: return "역동적인"
        case .melancholic: return "우울한"
        case .exotic_mood: return "이국적인"
        case .neutral: return "중성적인"
        }
    }
    
    /// 분위기에 대한 상세 설명
    var description: String {
        switch self {
        case .bright: return "기쁘고 활기찬 느낌을 주는 밝은 분위기"
        case .dark: return "진중하고 무거운 느낌의 어두운 분위기"
        case .peaceful: return "차분하고 안정적인 평화로운 분위기"
        case .mysterious: return "신비롭고 몽환적인 분위기"
        case .energetic: return "활동적이고 역동적인 에너지 넘치는 분위기"
        case .melancholic: return "슬프고 감성적인 우울한 분위기"
        case .exotic_mood: return "독특하고 이국적인 분위기"
        case .neutral: return "특별한 색채 없는 중성적인 분위기"
        }
    }
}

// MARK: - MusicGenre

/// 음악 장르
enum MusicGenre: String, CaseIterable, Codable {
    case classical = "classical"
    case jazz = "jazz"
    case pop = "pop"
    case rock = "rock"
    case blues = "blues"
    case country = "country"
    case folk = "folk"
    case electronic = "electronic"
    case latin = "latin"
    case world = "world"
    
    /// 장르의 한국어 이름
    var koreanName: String {
        switch self {
        case .classical: return "클래식"
        case .jazz: return "재즈"
        case .pop: return "팝"
        case .rock: return "록"
        case .blues: return "블루스"
        case .country: return "컨트리"
        case .folk: return "민요"
        case .electronic: return "일렉트로닉"
        case .latin: return "라틴"
        case .world: return "월드뮤직"
        }
    }
}

// MARK: - MusicScale Extensions

extension MusicScale {
    
    /// 주어진 음정 간격과 이 스케일의 유사도를 계산 (0.0 ~ 1.0)
    /// - Parameter notes: 분석할 음정들 (반음 단위, 0-11)
    /// - Returns: 유사도 점수 (1.0이 완전 일치)
    func calculateSimilarity(with notes: [Int]) -> Double {
        guard !notes.isEmpty, !intervals.isEmpty else { return 0.0 }
        
        // 음정들을 0-11 범위로 정규화 (한 옥타브 내)
        let normalizedNotes = Set(notes.map { $0 % 12 })
        let normalizedIntervals = Set(intervals.map { $0 % 12 })
        
        // 교집합과 합집합 계산
        let intersection = normalizedNotes.intersection(normalizedIntervals)
        let union = normalizedNotes.union(normalizedIntervals)
        
        // Jaccard 유사도 계산
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    /// 이 스케일에 주어진 음이 포함되는지 확인
    /// - Parameter note: 확인할 음 (반음 단위, 0-11)
    /// - Returns: 포함 여부
    func contains(note: Int) -> Bool {
        let normalizedNote = note % 12
        return intervals.contains { $0 % 12 == normalizedNote }
    }
    
    /// 스케일의 주요 3화음 코드들을 반환
    var primaryChords: [String] {
        switch type {
        case .major:
            return ["I", "IV", "V"] // 1도, 4도, 5도
        case .minor:
            return ["i", "iv", "V"] // 1도, 4도, 5도
        case .pentatonic:
            return ["I", "vi", "IV"] // 펜타토닉 주요 코드
        case .blues:
            return ["I7", "IV7", "V7"] // 블루스 7화음
        default:
            return ["I", "III", "V"] // 기본 3화음
        }
    }
}

// MARK: - Predefined Scales

extension MusicScale {
    
    /// 미리 정의된 주요 스케일들
    static let predefinedScales: [MusicScale] = [
        
        // 장조 스케일들
        MusicScale(
            id: "major-scale",
            name: "장조",
            englishName: "Major Scale",
            type: .major,
            intervals: [0, 2, 4, 5, 7, 9, 11],
            description: "가장 기본적이고 밝은 느낌의 7음계 스케일",
            mood: .bright,
            complexity: 1,
            genres: [.pop, .classical, .country]
        ),
        
        // 단조 스케일들
        MusicScale(
            id: "natural-minor",
            name: "자연 단조",
            englishName: "Natural Minor Scale",
            type: .minor,
            intervals: [0, 2, 3, 5, 7, 8, 10],
            description: "자연스러운 단조 스케일, 슬프고 차분한 느낌",
            mood: .melancholic,
            complexity: 2,
            genres: [.classical, .folk, .rock]
        ),
        
        MusicScale(
            id: "harmonic-minor",
            name: "화성 단조",
            englishName: "Harmonic Minor Scale",
            type: .minor,
            intervals: [0, 2, 3, 5, 7, 8, 11],
            description: "7번째 음이 올려진 단조, 클래식에서 많이 사용",
            mood: .mysterious,
            complexity: 3,
            genres: [.classical, .world]
        ),
        
        // 펜타토닉 스케일들
        MusicScale(
            id: "major-pentatonic",
            name: "장조 펜타토닉",
            englishName: "Major Pentatonic Scale",
            type: .pentatonic,
            intervals: [0, 2, 4, 7, 9],
            description: "5음계로 이루어진 밝고 단순한 스케일",
            mood: .bright,
            complexity: 1,
            genres: [.folk, .country, .pop]
        ),
        
        MusicScale(
            id: "minor-pentatonic",
            name: "단조 펜타토닉",
            englishName: "Minor Pentatonic Scale",
            type: .pentatonic,
            intervals: [0, 3, 5, 7, 10],
            description: "블루스와 록에서 광범위하게 사용되는 5음계",
            mood: .energetic,
            complexity: 2,
            genres: [.blues, .rock, .jazz]
        ),
        
        // 블루스 스케일
        MusicScale(
            id: "blues-scale",
            name: "블루스 스케일",
            englishName: "Blues Scale",
            type: .blues,
            intervals: [0, 3, 5, 6, 7, 10],
            description: "블루스 음악의 특징적인 6음계, 블루 노트 포함",
            mood: .energetic,
            complexity: 3,
            genres: [.blues, .jazz, .rock]
        ),
        
        // 교회선법들
        MusicScale(
            id: "dorian",
            name: "도리안 선법",
            englishName: "Dorian Mode",
            type: .modal,
            intervals: [0, 2, 3, 5, 7, 9, 10],
            description: "재즈에서 많이 사용되는 교회선법, 단조와 장조의 중간",
            mood: .neutral,
            complexity: 4,
            genres: [.jazz, .classical]
        ),
        
        MusicScale(
            id: "mixolydian",
            name: "믹솔리디안 선법",
            englishName: "Mixolydian Mode",
            type: .modal,
            intervals: [0, 2, 4, 5, 7, 9, 10],
            description: "7번째 음이 내려간 장조, 블루스와 록에서 사용",
            mood: .energetic,
            complexity: 4,
            genres: [.blues, .rock, .jazz]
        )
    ]
    
    /// ID로 미리 정의된 스케일 찾기
    static func predefined(id: String) -> MusicScale? {
        return predefinedScales.first { $0.id == id }
    }
    
    /// 타입으로 미리 정의된 스케일들 필터링
    static func predefined(type: ScaleType) -> [MusicScale] {
        return predefinedScales.filter { $0.type == type }
    }
    
    /// 분위기로 미리 정의된 스케일들 필터링
    static func predefined(mood: ScaleMood) -> [MusicScale] {
        return predefinedScales.filter { $0.mood == mood }
    }
}

// MARK: - Enhanced Recommendation Data Types

/// 복합 분위기 프로필
struct ComplexMoodProfile: Codable {
    let primaryMood: ScaleMood
    let secondaryMood: ScaleMood
    let intensity: Double // 0.0 ~ 1.0
    
    init(primaryMood: ScaleMood, secondaryMood: ScaleMood, intensity: Double) {
        self.primaryMood = primaryMood
        self.secondaryMood = secondaryMood
        self.intensity = max(0.0, min(1.0, intensity))
    }
    
    /// 복합 분위기 설명
    var description: String {
        let intensityText = intensity > 0.7 ? "강하게" : intensity > 0.4 ? "적당히" : "약하게"
        return "\(intensityText) \(primaryMood.koreanName)하면서 \(secondaryMood.koreanName)한"
    }
}

/// 시간 맥락 프로필
struct TimeContextProfile: Codable, Equatable {
    var timeOfDay: TimeOfDay
    var season: Season
    var occasion: Occasion
    
    enum TimeOfDay: String, CaseIterable, Codable {
        case morning = "morning"
        case afternoon = "afternoon"
        case evening = "evening"
        case night = "night"
        case lateNight = "lateNight"
        
        var koreanName: String {
            switch self {
            case .morning: return "아침"
            case .afternoon: return "오후"
            case .evening: return "저녁"
            case .night: return "밤"
            case .lateNight: return "심야"
            }
        }
        
        var preferredMoods: [ScaleMood] {
            switch self {
            case .morning: return [.bright, .energetic, .peaceful]
            case .afternoon: return [.neutral, .energetic]
            case .evening: return [.peaceful, .mysterious]
            case .night: return [.dark, .melancholic, .mysterious]
            case .lateNight: return [.dark, .peaceful]
            }
        }
    }
    
    enum Season: String, CaseIterable, Codable {
        case spring = "spring"
        case summer = "summer"
        case autumn = "autumn"
        case winter = "winter"
        
        var koreanName: String {
            switch self {
            case .spring: return "봄"
            case .summer: return "여름"
            case .autumn: return "가을"
            case .winter: return "겨울"
            }
        }
        
        var preferredMoods: [ScaleMood] {
            switch self {
            case .spring: return [.bright, .peaceful]
            case .summer: return [.energetic, .bright]
            case .autumn: return [.melancholic, .peaceful]
            case .winter: return [.dark, .mysterious]
            }
        }
    }
    
    enum Occasion: String, CaseIterable, Codable {
        case casual = "casual"
        case work = "work"
        case study = "study"
        case relaxation = "relaxation"
        case exercise = "exercise"
        case creative = "creative"
        
        var koreanName: String {
            switch self {
            case .casual: return "일상"
            case .work: return "업무"
            case .study: return "공부"
            case .relaxation: return "휴식"
            case .exercise: return "운동"
            case .creative: return "창작"
            }
        }
        
        var preferredMoods: [ScaleMood] {
            switch self {
            case .casual: return [.neutral, .peaceful]
            case .work: return [.neutral, .energetic]
            case .study: return [.peaceful, .neutral]
            case .relaxation: return [.peaceful, .melancholic]
            case .exercise: return [.energetic, .bright]
            case .creative: return [.mysterious, .exotic_mood]
            }
        }
    }
}

/// 실시간 분석 데이터
struct RealTimeAnalysisData: Codable {
    let averageAmplitude: Double // 평균 음량 (0.0 ~ 1.0)
    let amplitudeVariation: Double // 음량 변화 정도 (0.0 ~ 1.0)
    let frequencyStability: Double // 주파수 안정성 (0.0 ~ 1.0)
    let speechRate: Double // 말하기 속도 (words per minute)
    let pauseDuration: Double // 평균 쉼 길이 (초)
    let voiceQuality: VoiceQuality
    
    enum VoiceQuality: String, CaseIterable, Codable {
        case clear = "clear"
        case rough = "rough"
        case breathy = "breathy"
        case nasal = "nasal"
        case deep = "deep"
        case high = "high"
        
        var koreanName: String {
            switch self {
            case .clear: return "맑은"
            case .rough: return "거친"
            case .breathy: return "숨소리가 많은"
            case .nasal: return "비음"
            case .deep: return "깊은"
            case .high: return "높은"
            }
        }
        
        var suggestedMoods: [ScaleMood] {
            switch self {
            case .clear: return [.bright, .peaceful]
            case .rough: return [.energetic, .dark]
            case .breathy: return [.peaceful, .mysterious]
            case .nasal: return [.neutral]
            case .deep: return [.dark, .melancholic]
            case .high: return [.bright, .energetic]
            }
        }
    }
    
    /// 실시간 데이터 기반 추천 분위기
    var suggestedMood: ScaleMood {
        // 음량과 변화를 기반으로 분위기 추론
        if averageAmplitude > 0.7 && amplitudeVariation > 0.5 {
            return .energetic
        } else if averageAmplitude < 0.3 && frequencyStability > 0.8 {
            return .peaceful
        } else if amplitudeVariation > 0.6 {
            return .mysterious
        } else if speechRate < 100 {
            return .melancholic
        } else {
            return voiceQuality.suggestedMoods.first ?? .neutral
        }
    }
}

/// 사용자 음악 프로필
struct UserMusicProfile: Codable {
    let favoriteGenres: [MusicGenre]
    let preferredComplexity: ClosedRange<Int>
    let moodPreferences: [ScaleMood: Double] // 각 분위기에 대한 선호도 (0.0 ~ 1.0)
    let practiceLevel: PracticeLevel
    let musicalBackground: MusicalBackground
    
    enum PracticeLevel: String, CaseIterable, Codable {
        case beginner = "beginner"
        case intermediate = "intermediate"
        case advanced = "advanced"
        case professional = "professional"
        
        var koreanName: String {
            switch self {
            case .beginner: return "초급"
            case .intermediate: return "중급"
            case .advanced: return "고급"
            case .professional: return "전문가"
            }
        }
        
        var recommendedComplexity: ClosedRange<Int> {
            switch self {
            case .beginner: return 1...2
            case .intermediate: return 2...3
            case .advanced: return 3...4
            case .professional: return 3...5
            }
        }
    }
    
    enum MusicalBackground: String, CaseIterable, Codable {
        case none = "none"
        case amateur = "amateur"
        case academic = "academic"
        case performer = "performer"
        case composer = "composer"
        
        var koreanName: String {
            switch self {
            case .none: return "없음"
            case .amateur: return "아마추어"
            case .academic: return "학업"
            case .performer: return "연주자"
            case .composer: return "작곡가"
            }
        }
    }
    
    /// 사용자 프로필 기반 스케일 가중치 계산
    func calculateWeight(for scale: MusicScale) -> Double {
        var weight = 1.0
        
        // 장르 선호도
        if !Set(scale.genres).isDisjoint(with: Set(favoriteGenres)) {
            weight += 0.3
        }
        
        // 복잡도 선호도
        if preferredComplexity.contains(scale.complexity) {
            weight += 0.2
        }
        
        // 분위기 선호도
        if let moodWeight = moodPreferences[scale.mood] {
            weight += moodWeight * 0.3
        }
        
        // 실력 수준에 따른 조정
        let complexityBonus = practiceLevel.recommendedComplexity.contains(scale.complexity) ? 0.2 : -0.1
        weight += complexityBonus
        
        return max(0.0, weight)
    }
}

/// 스케일 전환 결과
struct ScaleTransitionResult: Codable {
    let targetScale: MusicScale
    let transitionDifficulty: Double // 0.0 ~ 1.0 (낮을수록 쉬운 전환)
    let sharedNotes: [Int] // 공통 음계들
    let transitionTechnique: TransitionTechnique
    
    enum TransitionTechnique: String, CaseIterable, Codable {
        case directModulation = "directModulation"
        case pivotChord = "pivotChord"
        case chromatic = "chromatic"
        case sequential = "sequential"
        
        var koreanName: String {
            switch self {
            case .directModulation: return "직접 전조"
            case .pivotChord: return "피벗 코드"
            case .chromatic: return "반음계적 전환"
            case .sequential: return "순차적 전환"
            }
        }
        
        var description: String {
            switch self {
            case .directModulation: return "갑작스러운 조성 변화"
            case .pivotChord: return "공통 화음을 통한 부드러운 전환"
            case .chromatic: return "반음계를 이용한 점진적 전환"
            case .sequential: return "단계별 음계 변화"
            }
        }
    }
}

/// 화음 스케일 추천 결과
struct HarmonyScaleResult: Codable {
    let scale: MusicScale
    let harmonyScore: Double // 화음 적합도 (0.0 ~ 1.0)
    let harmonyType: HarmonyType
    let intervalRelation: String // 음정 관계 설명
    
    enum HarmonyType: String, CaseIterable, Codable {
        case parallel = "parallel" // 평행 화음
        case contrary = "contrary" // 반진행
        case complementary = "complementary" // 보완적
        case modal = "modal" // 선법적
        
        var koreanName: String {
            switch self {
            case .parallel: return "평행 화음"
            case .contrary: return "반진행"
            case .complementary: return "보완적"
            case .modal: return "선법적"
            }
        }
    }
}
