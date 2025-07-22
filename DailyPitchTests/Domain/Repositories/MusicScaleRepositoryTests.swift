//
//  MusicScaleRepositoryTests.swift
//  DailyPitchTests
//
//  Created by bear on 7/9/25.
//

import XCTest
@testable import DailyPitch

class MusicScaleRepositoryTests: XCTestCase {
    
    // MARK: - Properties
    
    var repository: MockMusicScaleRepository!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        repository = MockMusicScaleRepository()
    }
    
    override func tearDown() {
        repository = nil
        super.tearDown()
    }
    
    // MARK: - getAllScales Tests
    
    func test_getAllScales_WhenScalesExist_ReturnsAllScales() {
        // Given
        let expectedCount = MusicScale.predefinedScales.count
        
        // When
        let result = repository.getAllScales()
        
        // Then
        XCTAssertEqual(result.count, expectedCount)
        XCTAssertTrue(result.contains { $0.id == "major-scale" })
        XCTAssertTrue(result.contains { $0.id == "natural-minor" })
    }
    
    func test_getAllScales_WhenEmptyResults_ReturnsEmptyArray() {
        // Given
        repository.shouldReturnEmptyResults = true
        
        // When
        let result = repository.getAllScales()
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - getScaleById Tests
    
    func test_getScaleById_WhenScaleExists_ReturnsCorrectScale() {
        // Given
        let scaleId = "major-scale"
        
        // When
        let result = repository.getScaleById(scaleId)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, scaleId)
        XCTAssertEqual(result?.name, "장조")
        XCTAssertEqual(result?.type, .major)
    }
    
    func test_getScaleById_WhenScaleDoesNotExist_ReturnsNil() {
        // Given
        let nonExistentId = "non-existent-scale"
        
        // When
        let result = repository.getScaleById(nonExistentId)
        
        // Then
        XCTAssertNil(result)
    }
    
    // MARK: - getScalesByType Tests
    
    func test_getScalesByType_WithMajorType_ReturnsOnlyMajorScales() {
        // Given
        let targetType = ScaleType.major
        
        // When
        let result = repository.getScalesByType(targetType)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.type == targetType })
        XCTAssertTrue(result.contains { $0.id == "major-scale" })
    }
    
    func test_getScalesByType_WithMinorType_ReturnsOnlyMinorScales() {
        // Given
        let targetType = ScaleType.minor
        
        // When
        let result = repository.getScalesByType(targetType)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.type == targetType })
        XCTAssertTrue(result.contains { $0.id == "natural-minor" })
    }
    
    // MARK: - getScalesByMood Tests
    
    func test_getScalesByMood_WithBrightMood_ReturnsOnlyBrightScales() {
        // Given
        let targetMood = ScaleMood.bright
        
        // When
        let result = repository.getScalesByMood(targetMood)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.mood == targetMood })
    }
    
    func test_getScalesByMood_WithEnergeticMood_ReturnsOnlyEnergeticScales() {
        // Given
        let targetMood = ScaleMood.energetic
        
        // When
        let result = repository.getScalesByMood(targetMood)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.mood == targetMood })
    }
    
    // MARK: - getScalesByGenre Tests
    
    func test_getScalesByGenre_WithJazzGenre_ReturnsJazzScales() {
        // Given
        let targetGenre = MusicGenre.jazz
        
        // When
        let result = repository.getScalesByGenre(targetGenre)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.genres.contains(targetGenre) })
    }
    
    func test_getScalesByGenre_WithRockGenre_ReturnsRockScales() {
        // Given
        let targetGenre = MusicGenre.rock
        
        // When
        let result = repository.getScalesByGenre(targetGenre)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.genres.contains(targetGenre) })
    }
    
    // MARK: - getScalesByComplexity Tests
    
    func test_getScalesByComplexity_WithComplexity1_ReturnsSimpleScales() {
        // Given
        let targetComplexity = 1
        
        // When
        let result = repository.getScalesByComplexity(targetComplexity)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.complexity == targetComplexity })
    }
    
    func test_getScalesByComplexity_WithComplexity4_ReturnsComplexScales() {
        // Given
        let targetComplexity = 4
        
        // When
        let result = repository.getScalesByComplexity(targetComplexity)
        
        // Then
        XCTAssertTrue(result.allSatisfy { $0.complexity == targetComplexity })
    }
    
    // MARK: - getScalesWithComplexityRange Tests
    
    func test_getScalesWithComplexityRange_WithRange1to3_ReturnsCorrectScales() {
        // Given
        let targetRange = 1...3
        
        // When
        let result = repository.getScalesWithComplexityRange(targetRange)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { targetRange.contains($0.complexity) })
    }
    
    func test_getScalesWithComplexityRange_WithRange4to5_ReturnsCorrectScales() {
        // Given
        let targetRange = 4...5
        
        // When
        let result = repository.getScalesWithComplexityRange(targetRange)
        
        // Then
        XCTAssertTrue(result.allSatisfy { targetRange.contains($0.complexity) })
    }
    
    // MARK: - getScalesContaining Tests
    
    func test_getScalesContaining_WithNoteC_ReturnsScalesContainingC() {
        // Given
        let noteC = 0 // C
        
        // When
        let result = repository.getScalesContaining(note: noteC)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.contains(note: noteC) })
    }
    
    func test_getScalesContaining_WithNoteFs_ReturnsScalesContainingFs() {
        // Given
        let noteFs = 6 // F#
        
        // When
        let result = repository.getScalesContaining(note: noteFs)
        
        // Then
        XCTAssertTrue(result.allSatisfy { $0.contains(note: noteFs) })
    }
    
    // MARK: - getMostSimilarScales Tests
    
    func test_getMostSimilarScales_WithMajorScaleNotes_ReturnsMajorScaleFirst() {
        // Given
        let majorScaleNotes = [0, 2, 4, 5, 7, 9, 11] // C Major
        let minSimilarity = 0.5
        let maxResults = 3
        
        // When
        let result = repository.getMostSimilarScales(
            to: majorScaleNotes,
            minSimilarity: minSimilarity,
            maxResults: maxResults
        )
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertLessThanOrEqual(result.count, maxResults)
        // 첫 번째 결과가 Major Scale이어야 함 (완전 일치)
        XCTAssertEqual(result.first?.id, "major-scale")
    }
    
    func test_getMostSimilarScales_WithMinorScaleNotes_ReturnsMinorScalesFirst() {
        // Given
        let minorScaleNotes = [0, 2, 3, 5, 7, 8, 10] // C Natural Minor
        let minSimilarity = 0.5
        let maxResults = 5
        
        // When
        let result = repository.getMostSimilarScales(
            to: minorScaleNotes,
            minSimilarity: minSimilarity,
            maxResults: maxResults
        )
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertLessThanOrEqual(result.count, maxResults)
        // 첫 번째 결과가 Natural Minor Scale이어야 함
        XCTAssertEqual(result.first?.id, "natural-minor")
    }
    
    func test_getMostSimilarScales_WithHighMinSimilarity_ReturnsFilteredResults() {
        // Given
        let someNotes = [0, 1, 2] // 매우 제한적인 음표들
        let highMinSimilarity = 0.9
        let maxResults = 10
        
        // When
        let result = repository.getMostSimilarScales(
            to: someNotes,
            minSimilarity: highMinSimilarity,
            maxResults: maxResults
        )
        
        // Then
        // 높은 유사도 조건으로 인해 결과가 적거나 없을 수 있음
        XCTAssertLessThanOrEqual(result.count, maxResults)
    }
    
    // MARK: - searchScales Tests
    
    func test_searchScales_WithTypesCriteria_ReturnsMatchingScales() {
        // Given
        let criteria = ScaleSearchCriteria(types: [.major, .minor])
        
        // When
        let result = repository.searchScales(criteria: criteria)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { [ScaleType.major, ScaleType.minor].contains($0.type) })
        XCTAssertEqual(repository.lastSearchCriteria?.types, criteria.types)
    }
    
    func test_searchScales_WithComplexCriteria_ReturnsMatchingScales() {
        // Given
        let criteria = ScaleSearchCriteria(
            types: [.pentatonic],
            moods: [.bright, .energetic],
            genres: [.rock, .blues],
            complexityRange: 1...3
        )
        
        // When
        let result = repository.searchScales(criteria: criteria)
        
        // Then
        XCTAssertTrue(result.allSatisfy { scale in
            criteria.types?.contains(scale.type) ?? true &&
            criteria.moods?.contains(scale.mood) ?? true &&
            !(Set(scale.genres).isDisjoint(with: Set(criteria.genres ?? []))) &&
            criteria.complexityRange?.contains(scale.complexity) ?? true
        })
    }
    
    func test_searchScales_WithRequiredNotes_ReturnsMatchingScales() {
        // Given
        let requiredNotes = [0, 4, 7] // C, E, G (C Major triad)
        let criteria = ScaleSearchCriteria(requiredNotes: requiredNotes)
        
        // When
        let result = repository.searchScales(criteria: criteria)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { scale in
            requiredNotes.allSatisfy { scale.contains(note: $0) }
        })
    }
    
    func test_searchScales_WithExcludedNotes_ReturnsMatchingScales() {
        // Given
        let excludedNotes = [1, 6] // C#, F#
        let criteria = ScaleSearchCriteria(excludedNotes: excludedNotes)
        
        // When
        let result = repository.searchScales(criteria: criteria)
        
        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { scale in
            !excludedNotes.contains { scale.contains(note: $0) }
        })
    }
    
    func test_searchScales_WithEmptyResults_ReturnsEmptyArray() {
        // Given
        repository.shouldReturnEmptyResults = true
        let criteria = ScaleSearchCriteria(types: [.major])
        
        // When
        let result = repository.searchScales(criteria: criteria)
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Edge Cases Tests
    
    func test_getScalesByComplexity_WithInvalidComplexity_ReturnsEmptyArray() {
        // Given
        let invalidComplexity = 10 // 범위를 벗어난 복잡도
        
        // When
        let result = repository.getScalesByComplexity(invalidComplexity)
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    func test_getMostSimilarScales_WithEmptyNotes_ReturnsEmptyArray() {
        // Given
        let emptyNotes: [Int] = []
        let minSimilarity = 0.1
        let maxResults = 5
        
        // When
        let result = repository.getMostSimilarScales(
            to: emptyNotes,
            minSimilarity: minSimilarity,
            maxResults: maxResults
        )
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
    
    func test_getMostSimilarScales_WithZeroMaxResults_ReturnsEmptyArray() {
        // Given
        let someNotes = [0, 2, 4]
        let minSimilarity = 0.1
        let maxResults = 0
        
        // When
        let result = repository.getMostSimilarScales(
            to: someNotes,
            minSimilarity: minSimilarity,
            maxResults: maxResults
        )
        
        // Then
        XCTAssertTrue(result.isEmpty)
    }
} 