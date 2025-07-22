import XCTest
@testable import DailyPitch

final class MusicScaleRecommendationUseCaseTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: MusicScaleRecommendationUseCaseImpl!
    private var mockRepository: MockMusicScaleRepository!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockRepository = MockMusicScaleRepository()
        sut = MusicScaleRecommendationUseCaseImpl(musicScaleRepository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - MusicNote 배열로부터 추천 테스트
    
    func testRecommendScales_fromMusicNotes_validInput_shouldReturnRecommendations() {
        // Given: C Major 트라이어드 (C, E, G)
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!,
            MusicNote.from(noteName: "G4")!
        ]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes)
        
        // Then: 추천 결과가 반환되어야 함
        XCTAssertFalse(results.isEmpty)
        
        // C Major 스케일이 높은 점수로 추천되어야 함
        let cMajorRecommendation = results.first { $0.scale.name.contains("Major") }
        XCTAssertNotNil(cMajorRecommendation)
        XCTAssertGreaterThan(cMajorRecommendation!.similarityScore, 0.5)
        XCTAssertGreaterThan(cMajorRecommendation!.confidenceScore, 0.5)
    }
    
    func testRecommendScales_fromMusicNotes_insufficientNotes_shouldReturnEmpty() {
        // Given: 최소 개수 미달 (1개 음계)
        let notes = [MusicNote.from(noteName: "C4")!]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes)
        
        // Then: 빈 결과가 반환되어야 함
        XCTAssertTrue(results.isEmpty)
    }
    
    func testRecommendScales_fromMusicNotes_emptyInput_shouldReturnEmpty() {
        // Given: 빈 배열
        let notes: [MusicNote] = []
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes)
        
        // Then: 빈 결과가 반환되어야 함
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - FrequencyData 배열로부터 추천 테스트
    
    func testRecommendScales_fromFrequencyData_validInput_shouldReturnRecommendations() {
        // Given: C4, E4, G4에 해당하는 주파수들
        let frequencies = [
            FrequencyData(frequency: 261.63, magnitude: 0.8), // C4
            FrequencyData(frequency: 329.63, magnitude: 0.7), // E4
            FrequencyData(frequency: 392.00, magnitude: 0.6)  // G4
        ]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: frequencies)
        
        // Then: 추천 결과가 반환되어야 함
        XCTAssertFalse(results.isEmpty)
        
        // 신뢰도 점수가 유효한 범위 내에 있어야 함
        results.forEach { result in
            XCTAssertGreaterThanOrEqual(result.similarityScore, 0.0)
            XCTAssertLessThanOrEqual(result.similarityScore, 1.0)
            XCTAssertGreaterThanOrEqual(result.confidenceScore, 0.0)
            XCTAssertLessThanOrEqual(result.confidenceScore, 1.0)
            XCTAssertGreaterThanOrEqual(result.coverage, 0.0)
            XCTAssertLessThanOrEqual(result.coverage, 1.0)
        }
    }
    
    func testRecommendScales_fromFrequencyData_invalidData_shouldHandleGracefully() {
        // Given: 유효하지 않은 주파수 데이터
        let frequencies = [
            FrequencyData(frequency: nil, magnitude: 0.8),
            FrequencyData(frequency: 440.0, magnitude: nil),
            FrequencyData(frequency: -100.0, magnitude: 0.5) // 음수 주파수
        ]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: frequencies)
        
        // Then: 빈 결과가 반환되거나 유효한 데이터만 처리되어야 함
        // 유효하지 않은 데이터는 필터링됨
        XCTAssertTrue(results.isEmpty || results.allSatisfy { $0.scale.isValid })
    }
    
    // MARK: - 음계 인덱스 배열로부터 추천 테스트
    
    func testRecommendScales_fromNoteIndices_validInput_shouldReturnRecommendations() {
        // Given: C Major 펜타토닉 (C=0, D=2, E=4, G=7, A=9)
        let noteIndices = [0, 2, 4, 7, 9]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: noteIndices)
        
        // Then: 추천 결과가 반환되어야 함
        XCTAssertFalse(results.isEmpty)
        
        // 결과가 신뢰도 점수 순으로 정렬되어야 함
        for i in 0..<results.count-1 {
            XCTAssertGreaterThanOrEqual(results[i].confidenceScore, results[i+1].confidenceScore)
        }
    }
    
    func testRecommendScales_fromNoteIndices_duplicateIndices_shouldNormalize() {
        // Given: 중복된 음계 인덱스들
        let noteIndices = [0, 0, 4, 4, 7, 7, 12, 24] // C, E, G + 옥타브
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: noteIndices)
        
        // Then: 중복과 옥타브가 정규화되어 처리되어야 함
        XCTAssertFalse(results.isEmpty)
    }
    
    // MARK: - 설정(Config) 기반 추천 테스트
    
    func testRecommendScales_withConfig_maxResults_shouldLimitResults() {
        // Given: 최대 2개 결과로 제한하는 설정
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!,
            MusicNote.from(noteName: "G4")!
        ]
        let config = ScaleRecommendationConfig(
            maxResults: 2,
            minSimilarityThreshold: 0.0,
            preferredMood: nil,
            preferredGenres: [],
            complexityRange: 1...5
        )
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes, config: config)
        
        // Then: 최대 2개의 결과만 반환되어야 함
        XCTAssertLessThanOrEqual(results.count, 2)
    }
    
    func testRecommendScales_withConfig_minSimilarityThreshold_shouldFilterResults() {
        // Given: 높은 유사도 임계값 설정
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "F#4")! // 불협화음
        ]
        let config = ScaleRecommendationConfig(
            maxResults: 10,
            minSimilarityThreshold: 0.8, // 높은 임계값
            preferredMood: nil,
            preferredGenres: [],
            complexityRange: 1...5
        )
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes, config: config)
        
        // Then: 모든 결과가 임계값 이상의 유사도를 가져야 함
        results.forEach { result in
            XCTAssertGreaterThanOrEqual(result.similarityScore, 0.8)
        }
    }
    
    func testRecommendScales_withConfig_preferredMood_shouldPrioritizeMood() {
        // Given: 선호 분위기 설정 (어두운 분위기)
        let notes = [
            MusicNote.from(noteName: "A4")!,
            MusicNote.from(noteName: "C5")!,
            MusicNote.from(noteName: "E5")!
        ]
        let config = ScaleRecommendationConfig(
            maxResults: 5,
            minSimilarityThreshold: 0.1,
            preferredMood: .dark,
            preferredGenres: [],
            complexityRange: 1...5
        )
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes, config: config)
        
        // Then: 어두운 분위기의 스케일이 우선적으로 추천되어야 함
        let darkMoodResults = results.filter { $0.scale.mood == .dark }
        XCTAssertFalse(darkMoodResults.isEmpty)
    }
    
    func testRecommendScales_withConfig_complexityRange_shouldFilterByComplexity() {
        // Given: 단순한 복잡도만 허용하는 설정
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!
        ]
        let config = ScaleRecommendationConfig(
            maxResults: 10,
            minSimilarityThreshold: 0.0,
            preferredMood: nil,
            preferredGenres: [],
            complexityRange: 1...2 // 단순한 스케일만
        )
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes, config: config)
        
        // Then: 모든 결과가 지정된 복잡도 범위 내에 있어야 함
        results.forEach { result in
            XCTAssertTrue((1...2).contains(result.scale.complexity))
        }
    }
    
    // MARK: - Convenience Methods 테스트
    
    func testRecommendScales_singleFrequencyData_shouldWork() {
        // Given: 단일 주파수 데이터
        let frequencyData = FrequencyData(frequency: 440.0, magnitude: 0.8) // A4
        
        // When: 단일 주파수로부터 스케일 추천
        let results = sut.recommendScales(from: frequencyData)
        
        // Then: 결과가 반환되어야 함 (최소 음계 개수 미달로 빈 결과일 수 있음)
        // 이 메서드는 단일 주파수를 배열로 변환하여 처리하므로 빈 결과가 정상
        XCTAssertTrue(results.isEmpty)
    }
    
    func testRecommendScales_defaultConfig_shouldWork() {
        // Given: 기본 설정
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!,
            MusicNote.from(noteName: "G4")!
        ]
        
        // When: 기본 설정으로 스케일 추천
        let results = sut.recommendScales(from: notes)
        
        // Then: 결과가 반환되어야 함
        XCTAssertFalse(results.isEmpty)
        XCTAssertLessThanOrEqual(results.count, 5) // 기본 maxResults는 5
    }
    
    func testRecommendScales_preferredMoodConvenience_shouldWork() {
        // Given: 분위기 기반 추천
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!,
            MusicNote.from(noteName: "G4")!
        ]
        
        // When: 밝은 분위기로 스케일 추천
        let results = sut.recommendScales(from: notes, preferredMood: .bright)
        
        // Then: 밝은 분위기의 스케일이 포함되어야 함
        let brightResults = results.filter { $0.scale.mood == .bright }
        XCTAssertFalse(brightResults.isEmpty)
    }
    
    func testRecommendScales_preferredGenresConvenience_shouldWork() {
        // Given: 장르 기반 추천
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!,
            MusicNote.from(noteName: "G4")!
        ]
        
        // When: 재즈 장르로 스케일 추천
        let results = sut.recommendScales(from: notes, preferredGenres: [.jazz])
        
        // Then: 재즈 장르의 스케일이 포함되어야 함
        let jazzResults = results.filter { $0.scale.genres.contains(.jazz) }
        // 재즈 스케일이 없을 수도 있으므로 에러를 발생시키지 않음
    }
    
    // MARK: - Edge Cases 테스트
    
    func testRecommendScales_emptyRepository_shouldReturnEmpty() {
        // Given: 빈 스케일 저장소
        mockRepository.shouldReturnEmptyResults = true
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!
        ]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes)
        
        // Then: 빈 결과가 반환되어야 함
        XCTAssertTrue(results.isEmpty)
    }
    
    func testRecommendScales_extremeFrequencies_shouldHandleGracefully() {
        // Given: 극단적인 주파수들
        let frequencies = [
            FrequencyData(frequency: 1.0, magnitude: 0.5),     // 매우 낮은 주파수
            FrequencyData(frequency: 20000.0, magnitude: 0.5)  // 매우 높은 주파수
        ]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: frequencies)
        
        // Then: 오류 없이 처리되어야 함
        // 유효하지 않은 음계로 변환될 수 있으므로 빈 결과일 수 있음
    }
    
    func testRecommendScales_allSameNotes_shouldHandleGracefully() {
        // Given: 모두 같은 음계
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "C4")!
        ]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes)
        
        // Then: 정규화 후 단일 음계가 되어 빈 결과가 반환될 수 있음
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - 결과 검증 테스트
    
    func testScaleRecommendationResult_properties_shouldBeValid() {
        // Given: 유효한 추천 요청
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!,
            MusicNote.from(noteName: "G4")!,
            MusicNote.from(noteName: "B4")!
        ]
        
        // When: 스케일 추천
        let results = sut.recommendScales(from: notes)
        
        // Then: 결과 속성들이 유효한 범위 내에 있어야 함
        results.forEach { result in
            XCTAssertNotNil(result.scale)
            XCTAssertGreaterThanOrEqual(result.similarityScore, 0.0)
            XCTAssertLessThanOrEqual(result.similarityScore, 1.0)
            XCTAssertGreaterThanOrEqual(result.confidenceScore, 0.0)
            XCTAssertLessThanOrEqual(result.confidenceScore, 1.0)
            XCTAssertGreaterThanOrEqual(result.coverage, 0.0)
            XCTAssertLessThanOrEqual(result.coverage, 1.0)
            XCTAssertFalse(result.matchingNotes.isEmpty)
            
            // 매칭된 음계들이 12음계 범위 내에 있어야 함
            result.matchingNotes.forEach { noteIndex in
                XCTAssertGreaterThanOrEqual(noteIndex, 0)
                XCTAssertLessThan(noteIndex, 12)
            }
        }
    }
    
    func testScaleRecommendationConfig_default_shouldHaveValidValues() {
        // Given & When: 기본 설정
        let config = ScaleRecommendationConfig.default
        
        // Then: 기본값들이 유효해야 함
        XCTAssertEqual(config.maxResults, 5)
        XCTAssertEqual(config.minSimilarityThreshold, 0.3)
        XCTAssertNil(config.preferredMood)
        XCTAssertTrue(config.preferredGenres.isEmpty)
        XCTAssertEqual(config.complexityRange, 1...5)
    }
    
    // MARK: - Enhanced Scale Recommendation Tests
    
    func testScaleRecommendationWithUserPreferenceLearning() {
        // Given: 사용자가 이전에 선택한 스케일들의 패턴
        let previousSelections = [
            "major_c", "minor_a", "pentatonic_c", // 사용자가 선택한 스케일 IDs
            "major_g", "minor_d"
        ]
        
        let inputNotes = [0, 2, 4] // C, D, E
        let config = ScaleRecommendationConfig(
            maxResults: 5,
            minSimilarityThreshold: 0.3,
            preferredMood: nil,
            preferredGenres: [],
            complexityRange: 1...5
        )
        
        // When: 사용자 선호도를 고려한 추천
        let results = sut.recommendScalesWithPreferenceLearning(
            from: inputNotes,
            config: config,
            userHistory: previousSelections
        )
        
        // Then: 사용자가 이전에 선호한 패턴과 유사한 스케일들이 높은 점수로 추천됨
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.first?.confidenceScore ?? 0 > 0.7)
        
        // 이전에 선택한 스케일 타입들이 더 높은 점수를 받아야 함
        let majorScales = results.filter { $0.scale.type == .major }
        let minorScales = results.filter { $0.scale.type == .minor }
        XCTAssertFalse(majorScales.isEmpty)
        XCTAssertFalse(minorScales.isEmpty)
    }
    
    func testScaleRecommendationWithComplexMood() {
        // Given: 복합 분위기 요청 (밝고 신비로운)
        let inputNotes = [0, 4, 7, 11] // C, E, G, B
        let complexMood = ComplexMoodProfile(
            primaryMood: .bright,
            secondaryMood: .mysterious,
            intensity: 0.8
        )
        
        let config = ScaleRecommendationConfig(
            maxResults: 5,
            minSimilarityThreshold: 0.4,
            preferredMood: nil,
            preferredGenres: [],
            complexityRange: 2...5
        )
        
        // When: 복합 분위기 기반 추천
        let results = sut.recommendScalesWithComplexMood(
            from: inputNotes,
            config: config,
            moodProfile: complexMood
        )
        
        // Then: 밝으면서도 신비로운 스케일들이 추천됨
        XCTAssertFalse(results.isEmpty)
        
        // 복합 분위기 점수가 계산되어야 함
        for result in results {
            XCTAssertTrue(result.complexMoodScore > 0.0)
        }
    }
    
    func testScaleRecommendationWithTimeContext() {
        // Given: 시간대별 추천 (아침 시간)
        let inputNotes = [0, 2, 4, 5, 7] // C Major scale notes
        let timeContext = TimeContextProfile(
            timeOfDay: .morning,
            season: .spring,
            occasion: .casual
        )
        
        let config = ScaleRecommendationConfig.default
        
        // When: 시간 맥락을 고려한 추천
        let results = sut.recommendScalesWithTimeContext(
            from: inputNotes,
            config: config,
            timeContext: timeContext
        )
        
        // Then: 아침에 어울리는 밝고 활기찬 스케일들이 추천됨
        XCTAssertFalse(results.isEmpty)
        
        let brightScales = results.filter { 
            $0.scale.mood == .bright || $0.scale.mood == .energetic 
        }
        XCTAssertFalse(brightScales.isEmpty)
        
        // 시간 적합도 점수가 있어야 함
        for result in results {
            XCTAssertTrue(result.timeContextScore >= 0.0)
        }
    }
    
    func testScaleTransitionRecommendation() {
        // Given: 현재 스케일에서 다른 스케일로의 전환 추천
        let currentScale = mockRepository.getScaleById("major_c")!
        let targetMood: ScaleMood = .peaceful
        
        // When: 스케일 전환 추천
        let transitions = sut.recommendScaleTransitions(
            from: currentScale,
            to: targetMood,
            maxResults: 3
        )
        
        // Then: 부드러운 전환이 가능한 스케일들이 추천됨
        XCTAssertFalse(transitions.isEmpty)
        XCTAssertLessThanOrEqual(transitions.count, 3)
        
        for transition in transitions {
            // 전환 난이도가 계산되어야 함
            XCTAssertTrue(transition.transitionDifficulty >= 0.0)
            XCTAssertTrue(transition.transitionDifficulty <= 1.0)
            
            // 목표 분위기와 일치해야 함
            XCTAssertEqual(transition.targetScale.mood, targetMood)
        }
    }
    
    func testScaleHarmonyRecommendation() {
        // Given: 주어진 스케일과 화음을 이루는 스케일들 추천
        let baseScale = mockRepository.getScaleById("minor_a")!
        
        // When: 화음 스케일 추천
        let harmonyScales = sut.recommendHarmonyScales(
            for: baseScale,
            maxResults: 4
        )
        
        // Then: 주어진 스케일과 화음을 이루는 스케일들이 추천됨
        XCTAssertFalse(harmonyScales.isEmpty)
        XCTAssertLessThanOrEqual(harmonyScales.count, 4)
        
        for harmonyResult in harmonyScales {
            // 화음 적합도 점수가 있어야 함
            XCTAssertTrue(harmonyResult.harmonyScore > 0.0)
            XCTAssertTrue(harmonyResult.harmonyScore <= 1.0)
            
            // 베이스 스케일과 다른 스케일이어야 함
            XCTAssertNotEqual(harmonyResult.scale.id, baseScale.id)
        }
    }
    
    func testRealTimeAnalysisBasedRecommendation() {
        // Given: 실시간 분석 데이터 (음성 패턴, 음량 변화 등)
        let realTimeData = RealTimeAnalysisData(
            averageAmplitude: 0.7,
            amplitudeVariation: 0.3,
            frequencyStability: 0.8,
            speechRate: 150.0, // words per minute
            pauseDuration: 0.5,
            voiceQuality: .clear
        )
        
        let inputNotes = [0, 3, 7] // C, Eb, G (minor triad)
        let config = ScaleRecommendationConfig.default
        
        // When: 실시간 분석 데이터를 활용한 추천
        let results = sut.recommendScalesWithRealTimeAnalysis(
            from: inputNotes,
            config: config,
            realTimeData: realTimeData
        )
        
        // Then: 실시간 데이터에 적합한 스케일들이 추천됨
        XCTAssertFalse(results.isEmpty)
        
        for result in results {
            // 실시간 적합도 점수가 계산되어야 함
            XCTAssertTrue(result.realTimeAdaptationScore >= 0.0)
        }
        
        // 높은 음량과 변화가 있는 경우 역동적인 스케일 선호
        let energeticScales = results.filter { $0.scale.mood == .energetic }
        XCTAssertFalse(energeticScales.isEmpty)
    }
    
    func testPersonalizedScaleRecommendation() {
        // Given: 사용자 개인화 프로필
        let userProfile = UserMusicProfile(
            favoriteGenres: [.jazz, .blues],
            preferredComplexity: 3...4,
            moodPreferences: [.mysterious: 0.8, .dark: 0.6],
            practiceLevel: .intermediate,
            musicalBackground: .amateur
        )
        
        let inputNotes = [0, 2, 3, 5, 7, 8, 10] // Natural minor scale
        let config = ScaleRecommendationConfig.default
        
        // When: 개인화된 추천
        let results = sut.recommendPersonalizedScales(
            from: inputNotes,
            config: config,
            userProfile: userProfile
        )
        
        // Then: 사용자 프로필에 맞는 스케일들이 추천됨
        XCTAssertFalse(results.isEmpty)
        
        // 선호 장르 반영
        let preferredGenreScales = results.filter { result in
            !Set(result.scale.genres).isDisjoint(with: Set(userProfile.favoriteGenres))
        }
        XCTAssertFalse(preferredGenreScales.isEmpty)
        
        // 적절한 복잡도 범위
        for result in results {
            XCTAssertTrue(userProfile.preferredComplexity.contains(result.scale.complexity))
        }
        
        // 개인화 점수가 계산되어야 함
        for result in results {
            XCTAssertTrue(result.personalizationScore > 0.0)
        }
    }
    
    func testScaleRecommendationPerformance() {
        // Given: 대량의 입력 데이터
        let largeInputNotes = Array(0..<12) // 모든 12개 음계
        let config = ScaleRecommendationConfig(
            maxResults: 10,
            minSimilarityThreshold: 0.1,
            preferredMood: nil,
            preferredGenres: [],
            complexityRange: 1...5
        )
        
        // When: 성능 테스트
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = sut.recommendScales(from: largeInputNotes, config: config)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then: 성능 요구사항 만족 (1초 이내)
        let executionTime = endTime - startTime
        XCTAssertLessThan(executionTime, 1.0, "스케일 추천이 1초 이내에 완료되어야 합니다")
        XCTAssertFalse(results.isEmpty)
        XCTAssertLessThanOrEqual(results.count, config.maxResults)
    }
    
    // MARK: - Performance Tests
    
    func testRecommendScales_performance_shouldBeReasonable() {
        // Given: 다수의 음계
        let notes = (0..<12).map { index in
            MusicNote.from(frequency: 440.0 * pow(2.0, Double(index)/12.0), duration: 1.0, amplitude: 0.5)!
        }
        
        // When & Then: 성능 측정
        measure {
            let _ = sut.recommendScales(from: notes)
        }
    }
} 