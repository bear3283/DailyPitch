//
//  MusicScaleRecommendationUseCase.swift
//  DailyPitch
//
//  Created by bear on 7/9/25.
//

import Foundation

/// 음악 스케일 추천 결과
struct ScaleRecommendationResult {
    let scale: MusicScale
    let similarityScore: Double    // 0.0 ~ 1.0
    let confidenceScore: Double    // 0.0 ~ 1.0 (전체 신뢰도)
    let matchingNotes: [Int]       // 매칭된 음계 인덱스들 (0-11)
    let coverage: Double           // 입력 음계 대비 커버리지 (0.0 ~ 1.0)
    
    // Enhanced scoring fields
    let complexMoodScore: Double           // 복합 분위기 적합도 (0.0 ~ 1.0)
    let timeContextScore: Double           // 시간 맥락 적합도 (0.0 ~ 1.0)
    let realTimeAdaptationScore: Double    // 실시간 적응 점수 (0.0 ~ 1.0)
    let personalizationScore: Double       // 개인화 점수 (0.0 ~ 1.0)
    let harmonyScore: Double              // 화음 적합도 (0.0 ~ 1.0)
    let transitionDifficulty: Double      // 전환 난이도 (0.0 ~ 1.0)
    
    init(
        scale: MusicScale,
        similarityScore: Double,
        confidenceScore: Double,
        matchingNotes: [Int],
        coverage: Double,
        complexMoodScore: Double = 0.0,
        timeContextScore: Double = 0.0,
        realTimeAdaptationScore: Double = 0.0,
        personalizationScore: Double = 0.0,
        harmonyScore: Double = 0.0,
        transitionDifficulty: Double = 0.0
    ) {
        self.scale = scale
        self.similarityScore = similarityScore
        self.confidenceScore = confidenceScore
        self.matchingNotes = matchingNotes
        self.coverage = coverage
        self.complexMoodScore = complexMoodScore
        self.timeContextScore = timeContextScore
        self.realTimeAdaptationScore = realTimeAdaptationScore
        self.personalizationScore = personalizationScore
        self.harmonyScore = harmonyScore
        self.transitionDifficulty = transitionDifficulty
    }
}

/// 스케일 추천 설정
struct ScaleRecommendationConfig {
    let maxResults: Int
    let minSimilarityThreshold: Double
    let preferredMood: ScaleMood?
    let preferredGenres: [MusicGenre]
    let complexityRange: ClosedRange<Int>
    
    static let `default` = ScaleRecommendationConfig(
        maxResults: 5,
        minSimilarityThreshold: 0.3,
        preferredMood: nil,
        preferredGenres: [],
        complexityRange: 1...5
    )
}

/// 음악 스케일 추천 UseCase
protocol MusicScaleRecommendationUseCase {
    func recommendScales(from notes: [MusicNote], config: ScaleRecommendationConfig) -> [ScaleRecommendationResult]
    func recommendScales(from frequencies: [FrequencyData], config: ScaleRecommendationConfig) -> [ScaleRecommendationResult]
    func recommendScales(from noteIndices: [Int], config: ScaleRecommendationConfig) -> [ScaleRecommendationResult]
    
    // Enhanced recommendation methods
    func recommendScalesWithPreferenceLearning(from noteIndices: [Int], config: ScaleRecommendationConfig, userHistory: [String]) -> [ScaleRecommendationResult]
    func recommendScalesWithComplexMood(from noteIndices: [Int], config: ScaleRecommendationConfig, moodProfile: ComplexMoodProfile) -> [ScaleRecommendationResult]
    func recommendScalesWithTimeContext(from noteIndices: [Int], config: ScaleRecommendationConfig, timeContext: TimeContextProfile) -> [ScaleRecommendationResult]
    func recommendScaleTransitions(from currentScale: MusicScale, to targetMood: ScaleMood, maxResults: Int) -> [ScaleTransitionResult]
    func recommendHarmonyScales(for baseScale: MusicScale, maxResults: Int) -> [HarmonyScaleResult]
    func recommendScalesWithRealTimeAnalysis(from noteIndices: [Int], config: ScaleRecommendationConfig, realTimeData: RealTimeAnalysisData) -> [ScaleRecommendationResult]
    func recommendPersonalizedScales(from noteIndices: [Int], config: ScaleRecommendationConfig, userProfile: UserMusicProfile) -> [ScaleRecommendationResult]
}

/// 음악 스케일 추천 UseCase 구현
class MusicScaleRecommendationUseCaseImpl: MusicScaleRecommendationUseCase {
    
    // MARK: - Properties
    
    private let musicScaleRepository: MusicScaleRepository
    private let minimumNotesRequired = 2 // 최소 2개 음계 필요
    
    // MARK: - Initializer
    
    init(musicScaleRepository: MusicScaleRepository) {
        self.musicScaleRepository = musicScaleRepository
    }
    
    // MARK: - Public Methods
    
    func recommendScales(from notes: [MusicNote], config: ScaleRecommendationConfig = .default) -> [ScaleRecommendationResult] {
        // MusicNote를 12음계 인덱스로 변환
        let noteIndices = notes.map { $0.noteIndex }
        return recommendScales(from: noteIndices, config: config)
    }
    
    func recommendScales(from frequencies: [FrequencyData], config: ScaleRecommendationConfig = .default) -> [ScaleRecommendationResult] {
        // FrequencyData를 MusicNote로 변환 후 처리
        let notes = frequencies.compactMap { frequencyData -> MusicNote? in
            guard let peakFrequency = frequencyData.peakFrequency,
                  let peakMagnitude = frequencyData.peakMagnitude else { return nil }
            
            // 진폭을 정규화 (0.0 ~ 1.0)
            let normalizedAmplitude = min(1.0, max(0.0, peakMagnitude / 100.0))
            
            return MusicNote.from(
                frequency: peakFrequency,
                duration: 1.0,
                amplitude: normalizedAmplitude
            )
        }
        
        return recommendScales(from: notes, config: config)
    }
    
    func recommendScales(from noteIndices: [Int], config: ScaleRecommendationConfig = .default) -> [ScaleRecommendationResult] {
        // 입력 검증
        guard noteIndices.count >= minimumNotesRequired else { return [] }
        
        // 12음계 범위로 정규화 및 중복 제거
        let normalizedIndices = Array(Set(noteIndices.map { $0 % 12 })).sorted()
        
        // 사용 가능한 스케일들 가져오기
        let availableScales = musicScaleRepository.getAllScales()
        
        // 각 스케일에 대해 추천 점수 계산
        let recommendations = availableScales.compactMap { scale -> ScaleRecommendationResult? in
            calculateRecommendationScore(for: scale, with: normalizedIndices, config: config)
        }
        
        // 필터링 및 정렬
        return recommendations
            .filter { $0.similarityScore >= config.minSimilarityThreshold }
            .filter { config.complexityRange.contains($0.scale.complexity) }
            .filter { isMatchingPreferences(scale: $0.scale, config: config) }
            .sorted { $0.confidenceScore > $1.confidenceScore }
            .prefix(config.maxResults)
            .map { $0 }
    }
    
    // MARK: - Private Methods
    
    private func calculateRecommendationScore(
        for scale: MusicScale,
        with noteIndices: [Int],
        config: ScaleRecommendationConfig
    ) -> ScaleRecommendationResult? {
        
        // 1. 기본 유사도 계산
        let similarityScore = scale.calculateSimilarity(with: noteIndices)
        
        // 2. 매칭된 음계들 찾기
        let scaleIndices = scale.intervals.map { $0 % 12 }
        let matchingNotes = noteIndices.filter { scaleIndices.contains($0) }
        
        // 3. 커버리지 계산 (입력 음계 중 스케일에 포함된 비율)
        let coverage = Double(matchingNotes.count) / Double(noteIndices.count)
        
        // 4. 신뢰도 점수 계산
        let confidenceScore = calculateConfidenceScore(
            similarity: similarityScore,
            coverage: coverage,
            scale: scale,
            config: config
        )
        
        return ScaleRecommendationResult(
            scale: scale,
            similarityScore: similarityScore,
            confidenceScore: confidenceScore,
            matchingNotes: matchingNotes,
            coverage: coverage
        )
    }
    
    private func calculateConfidenceScore(
        similarity: Double,
        coverage: Double,
        scale: MusicScale,
        config: ScaleRecommendationConfig
    ) -> Double {
        var score = 0.0
        
        // 1. 유사도 (40% 가중치)
        score += similarity * 0.4
        
        // 2. 커버리지 (30% 가중치)
        score += coverage * 0.3
        
        // 3. 스케일 완성도 (10% 가중치)
        let completenessBonus = scale.isComplete ? 0.1 : 0.0
        score += completenessBonus
        
        // 4. 복잡도 보너스 (10% 가중치) - 중간 복잡도 선호
        let complexityBonus = calculateComplexityBonus(scale.complexity) * 0.1
        score += complexityBonus
        
        // 5. 선호도 보너스 (10% 가중치)
        let preferenceBonus = calculatePreferenceBonus(scale: scale, config: config) * 0.1
        score += preferenceBonus
        
        return min(1.0, max(0.0, score))
    }
    
    private func calculateComplexityBonus(_ complexity: Int) -> Double {
        // 복잡도 3-4를 가장 선호 (일반적으로 사용하기 좋음)
        switch complexity {
        case 1: return 0.7  // 너무 단순
        case 2: return 0.85
        case 3: return 1.0  // 최적
        case 4: return 1.0  // 최적
        case 5: return 0.6  // 너무 복잡
        default: return 0.5
        }
    }
    
    private func calculatePreferenceBonus(scale: MusicScale, config: ScaleRecommendationConfig) -> Double {
        var bonus = 0.0
        
        // 선호 분위기 매칭
        if let preferredMood = config.preferredMood, scale.mood == preferredMood {
            bonus += 0.5
        }
        
        // 선호 장르 매칭
        if !config.preferredGenres.isEmpty {
            let genreMatch = !Set(scale.genres).isDisjoint(with: Set(config.preferredGenres))
            if genreMatch {
                bonus += 0.5
            }
        }
        
        return min(1.0, bonus)
    }
    
    private func isMatchingPreferences(scale: MusicScale, config: ScaleRecommendationConfig) -> Bool {
        // 선호 분위기가 설정되어 있고 매칭되지 않으면 제외
        if let preferredMood = config.preferredMood, scale.mood != preferredMood {
            // 하지만 중성적인 분위기는 허용
            if scale.mood != .neutral {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Enhanced Recommendation Methods
    
    func recommendScalesWithPreferenceLearning(from noteIndices: [Int], config: ScaleRecommendationConfig, userHistory: [String]) -> [ScaleRecommendationResult] {
        // 기본 추천 결과 가져오기
        let baseResults = recommendScales(from: noteIndices, config: config)
        
        // 사용자 히스토리에서 패턴 분석
        let historyScales = userHistory.compactMap { musicScaleRepository.getScaleById($0) }
        let preferredTypes = Set(historyScales.map { $0.type })
        let preferredMoods = Set(historyScales.map { $0.mood })
        let averageComplexity = historyScales.isEmpty ? 3.0 : Double(historyScales.map { $0.complexity }.reduce(0, +)) / Double(historyScales.count)
        
        // 사용자 선호도 기반 점수 조정
        return baseResults.map { result in
            var enhancedConfidence = result.confidenceScore
            
            // 타입 선호도 반영
            if preferredTypes.contains(result.scale.type) {
                enhancedConfidence += 0.2
            }
            
            // 분위기 선호도 반영
            if preferredMoods.contains(result.scale.mood) {
                enhancedConfidence += 0.15
            }
            
            // 복잡도 선호도 반영
            let complexityDiff = abs(Double(result.scale.complexity) - averageComplexity)
            let complexityBonus = max(0.0, 0.1 - (complexityDiff * 0.05))
            enhancedConfidence += complexityBonus
            
            return ScaleRecommendationResult(
                scale: result.scale,
                similarityScore: result.similarityScore,
                confidenceScore: min(1.0, enhancedConfidence),
                matchingNotes: result.matchingNotes,
                coverage: result.coverage
            )
        }.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    func recommendScalesWithComplexMood(from noteIndices: [Int], config: ScaleRecommendationConfig, moodProfile: ComplexMoodProfile) -> [ScaleRecommendationResult] {
        let baseResults = recommendScales(from: noteIndices, config: config)
        
        return baseResults.map { result in
            let complexMoodScore = calculateComplexMoodScore(for: result.scale, moodProfile: moodProfile)
            
            let enhancedConfidence = (result.confidenceScore * 0.7) + (complexMoodScore * 0.3)
            
            return ScaleRecommendationResult(
                scale: result.scale,
                similarityScore: result.similarityScore,
                confidenceScore: enhancedConfidence,
                matchingNotes: result.matchingNotes,
                coverage: result.coverage,
                complexMoodScore: complexMoodScore
            )
        }.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    func recommendScalesWithTimeContext(from noteIndices: [Int], config: ScaleRecommendationConfig, timeContext: TimeContextProfile) -> [ScaleRecommendationResult] {
        let baseResults = recommendScales(from: noteIndices, config: config)
        
        return baseResults.map { result in
            let timeContextScore = calculateTimeContextScore(for: result.scale, timeContext: timeContext)
            
            let enhancedConfidence = (result.confidenceScore * 0.8) + (timeContextScore * 0.2)
            
            return ScaleRecommendationResult(
                scale: result.scale,
                similarityScore: result.similarityScore,
                confidenceScore: enhancedConfidence,
                matchingNotes: result.matchingNotes,
                coverage: result.coverage,
                timeContextScore: timeContextScore
            )
        }.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    func recommendScaleTransitions(from currentScale: MusicScale, to targetMood: ScaleMood, maxResults: Int) -> [ScaleTransitionResult] {
        let availableScales = musicScaleRepository.getScalesByMood(targetMood)
        
        return availableScales.compactMap { targetScale -> ScaleTransitionResult? in
            guard targetScale.id != currentScale.id else { return nil }
            
            let sharedNotes = Set(currentScale.intervals).intersection(Set(targetScale.intervals))
            let transitionDifficulty = calculateTransitionDifficulty(from: currentScale, to: targetScale)
            let technique = determineTransitionTechnique(from: currentScale, to: targetScale)
            
            return ScaleTransitionResult(
                targetScale: targetScale,
                transitionDifficulty: transitionDifficulty,
                sharedNotes: Array(sharedNotes),
                transitionTechnique: technique
            )
        }
        .sorted { $0.transitionDifficulty < $1.transitionDifficulty }
        .prefix(maxResults)
        .map { $0 }
    }
    
    func recommendHarmonyScales(for baseScale: MusicScale, maxResults: Int) -> [HarmonyScaleResult] {
        let allScales = musicScaleRepository.getAllScales()
        
        return allScales.compactMap { scale -> HarmonyScaleResult? in
            guard scale.id != baseScale.id else { return nil }
            
            let harmonyScore = calculateHarmonyScore(between: baseScale, and: scale)
            let harmonyType = determineHarmonyType(between: baseScale, and: scale)
            let intervalRelation = calculateIntervalRelation(between: baseScale, and: scale)
            
            guard harmonyScore > 0.3 else { return nil }
            
            return HarmonyScaleResult(
                scale: scale,
                harmonyScore: harmonyScore,
                harmonyType: harmonyType,
                intervalRelation: intervalRelation
            )
        }
        .sorted { $0.harmonyScore > $1.harmonyScore }
        .prefix(maxResults)
        .map { $0 }
    }
    
    func recommendScalesWithRealTimeAnalysis(from noteIndices: [Int], config: ScaleRecommendationConfig, realTimeData: RealTimeAnalysisData) -> [ScaleRecommendationResult] {
        let baseResults = recommendScales(from: noteIndices, config: config)
        
        return baseResults.map { result in
            let realTimeScore = calculateRealTimeAdaptationScore(for: result.scale, realTimeData: realTimeData)
            
            let enhancedConfidence = (result.confidenceScore * 0.75) + (realTimeScore * 0.25)
            
            return ScaleRecommendationResult(
                scale: result.scale,
                similarityScore: result.similarityScore,
                confidenceScore: enhancedConfidence,
                matchingNotes: result.matchingNotes,
                coverage: result.coverage,
                realTimeAdaptationScore: realTimeScore
            )
        }.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    func recommendPersonalizedScales(from noteIndices: [Int], config: ScaleRecommendationConfig, userProfile: UserMusicProfile) -> [ScaleRecommendationResult] {
        let baseResults = recommendScales(from: noteIndices, config: config)
        
        return baseResults.map { result in
            let personalizationScore = userProfile.calculateWeight(for: result.scale)
            let normalizedPersonalizationScore = min(1.0, personalizationScore / 2.0) // 정규화
            
            let enhancedConfidence = (result.confidenceScore * 0.6) + (normalizedPersonalizationScore * 0.4)
            
            return ScaleRecommendationResult(
                scale: result.scale,
                similarityScore: result.similarityScore,
                confidenceScore: enhancedConfidence,
                matchingNotes: result.matchingNotes,
                coverage: result.coverage,
                personalizationScore: normalizedPersonalizationScore
            )
        }
        .filter { userProfile.preferredComplexity.contains($0.scale.complexity) }
        .sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
    // MARK: - Helper Methods for Enhanced Features
    
    private func calculateComplexMoodScore(for scale: MusicScale, moodProfile: ComplexMoodProfile) -> Double {
        var score = 0.0
        
        // 주요 분위기 매칭
        if scale.mood == moodProfile.primaryMood {
            score += 0.7 * moodProfile.intensity
        }
        
        // 보조 분위기 매칭
        if scale.mood == moodProfile.secondaryMood {
            score += 0.3 * moodProfile.intensity
        }
        
        // 호환성 검사 (밝은 + 어두운 조합 등의 충돌 감지)
        let moodCompatibility = checkMoodCompatibility(primary: moodProfile.primaryMood, secondary: moodProfile.secondaryMood, scaleMood: scale.mood)
        score *= moodCompatibility
        
        return min(1.0, max(0.0, score))
    }
    
    private func calculateTimeContextScore(for scale: MusicScale, timeContext: TimeContextProfile) -> Double {
        var score = 0.0
        
        // 시간대 적합성
        if timeContext.timeOfDay.preferredMoods.contains(scale.mood) {
            score += 0.4
        }
        
        // 계절 적합성
        if timeContext.season.preferredMoods.contains(scale.mood) {
            score += 0.3
        }
        
        // 상황 적합성
        if timeContext.occasion.preferredMoods.contains(scale.mood) {
            score += 0.3
        }
        
        return min(1.0, max(0.0, score))
    }
    
    private func calculateRealTimeAdaptationScore(for scale: MusicScale, realTimeData: RealTimeAnalysisData) -> Double {
        var score = 0.0
        
        // 음성 품질에 따른 분위기 적합성
        if realTimeData.voiceQuality.suggestedMoods.contains(scale.mood) {
            score += 0.4
        }
        
        // 실시간 데이터 기반 추천 분위기와의 매칭
        if scale.mood == realTimeData.suggestedMood {
            score += 0.6
        }
        
        return min(1.0, max(0.0, score))
    }
    
    private func calculateTransitionDifficulty(from currentScale: MusicScale, to targetScale: MusicScale) -> Double {
        let sharedNotesCount = Set(currentScale.intervals).intersection(Set(targetScale.intervals)).count
        let totalNotesCount = max(currentScale.intervals.count, targetScale.intervals.count)
        
        let sharedRatio = Double(sharedNotesCount) / Double(totalNotesCount)
        let complexityDiff = abs(currentScale.complexity - targetScale.complexity)
        
        // 공통 음이 많을수록, 복잡도 차이가 적을수록 전환이 쉬움
        let difficulty = 1.0 - (sharedRatio * 0.7) - (max(0.0, 1.0 - Double(complexityDiff) / 5.0) * 0.3)
        
        return max(0.0, min(1.0, difficulty))
    }
    
    private func determineTransitionTechnique(from currentScale: MusicScale, to targetScale: MusicScale) -> ScaleTransitionResult.TransitionTechnique {
        let sharedNotes = Set(currentScale.intervals).intersection(Set(targetScale.intervals))
        
        if sharedNotes.count >= 4 {
            return .pivotChord
        } else if sharedNotes.count >= 2 {
            return .sequential
        } else if abs(currentScale.complexity - targetScale.complexity) <= 1 {
            return .chromatic
        } else {
            return .directModulation
        }
    }
    
    private func calculateHarmonyScore(between scale1: MusicScale, and scale2: MusicScale) -> Double {
        let intervals1 = Set(scale1.intervals)
        let intervals2 = Set(scale2.intervals)
        
        // 보완적 관계 (한 스케일의 빈 음들을 다른 스케일이 채움)
        let union = intervals1.union(intervals2)
        let intersection = intervals1.intersection(intervals2)
        
        let complementarity = Double(union.count) / 12.0 // 12음계 대비 커버리지
        let overlap = Double(intersection.count) / Double(min(intervals1.count, intervals2.count))
        
        // 적당한 겹침과 높은 보완성이 좋은 화음
        let harmonyScore = (complementarity * 0.6) + ((1.0 - overlap) * 0.4)
        
        return min(1.0, max(0.0, harmonyScore))
    }
    
    private func determineHarmonyType(between scale1: MusicScale, and scale2: MusicScale) -> HarmonyScaleResult.HarmonyType {
        let sharedNotes = Set(scale1.intervals).intersection(Set(scale2.intervals))
        let sharedRatio = Double(sharedNotes.count) / Double(min(scale1.intervals.count, scale2.intervals.count))
        
        if sharedRatio > 0.6 {
            return .parallel
        } else if sharedRatio < 0.3 {
            return .contrary
        } else if scale1.type == .modal || scale2.type == .modal {
            return .modal
        } else {
            return .complementary
        }
    }
    
    private func calculateIntervalRelation(between scale1: MusicScale, and scale2: MusicScale) -> String {
        let rootInterval = scale2.intervals.first ?? 0
        let intervalName = ["완전1도", "단2도", "장2도", "단3도", "장3도", "완전4도", "증4도", "완전5도", "단6도", "장6도", "단7도", "장7도"]
        
        return intervalName[rootInterval % 12]
    }
    
    private func checkMoodCompatibility(primary: ScaleMood, secondary: ScaleMood, scaleMood: ScaleMood) -> Double {
        // 상충되는 분위기 조합 검사
        let conflictingPairs: [(ScaleMood, ScaleMood)] = [
            (.bright, .dark),
            (.energetic, .peaceful),
            (.melancholic, .bright)
        ]
        
        for (mood1, mood2) in conflictingPairs {
            if (primary == mood1 && secondary == mood2) || (primary == mood2 && secondary == mood1) {
                // 스케일이 양쪽 중 하나와 매칭되면 호환성 감소
                if scaleMood == mood1 || scaleMood == mood2 {
                    return 0.7 // 70% 호환성
                }
            }
        }
        
        return 1.0 // 100% 호환성
    }
}

// MARK: - Convenience Extensions

extension MusicScaleRecommendationUseCaseImpl {
    
    /// 단일 FrequencyData로부터 스케일 추천
    func recommendScales(from frequencyData: FrequencyData, config: ScaleRecommendationConfig = .default) -> [ScaleRecommendationResult] {
        return recommendScales(from: [frequencyData], config: config)
    }
    
    /// 간단한 추천 (기본 설정 사용)
    func recommendScales(from notes: [MusicNote]) -> [ScaleRecommendationResult] {
        return recommendScales(from: notes, config: .default)
    }
    
    /// 분위기 기반 추천
    func recommendScales(from notes: [MusicNote], preferredMood: ScaleMood) -> [ScaleRecommendationResult] {
        let config = ScaleRecommendationConfig(
            maxResults: 5,
            minSimilarityThreshold: 0.3,
            preferredMood: preferredMood,
            preferredGenres: [],
            complexityRange: 1...5
        )
        return recommendScales(from: notes, config: config)
    }
    
    /// 장르 기반 추천
    func recommendScales(from notes: [MusicNote], preferredGenres: [MusicGenre]) -> [ScaleRecommendationResult] {
        let config = ScaleRecommendationConfig(
            maxResults: 5,
            minSimilarityThreshold: 0.3,
            preferredMood: nil,
            preferredGenres: preferredGenres,
            complexityRange: 1...5
        )
        return recommendScales(from: notes, config: config)
    }
} 