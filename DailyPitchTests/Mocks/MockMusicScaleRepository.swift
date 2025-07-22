//
//  MockMusicScaleRepository.swift
//  DailyPitchTests
//
//  Created by bear on 7/9/25.
//

import Foundation
@testable import DailyPitch

/// 테스트용 MusicScaleRepository Mock 구현
class MockMusicScaleRepository: MusicScaleRepository {
    
    // MARK: - Mock Data
    
    private var mockScales: [MusicScale] = MusicScale.predefinedScales
    
    // MARK: - Test Control Properties
    
    var shouldReturnEmptyResults = false
    var shouldThrowError = false
    var lastSearchCriteria: ScaleSearchCriteria?
    
    // MARK: - MusicScaleRepository Implementation
    
    func getAllScales() -> [MusicScale] {
        if shouldReturnEmptyResults { return [] }
        return mockScales
    }
    
    func getScaleById(_ id: String) -> MusicScale? {
        if shouldReturnEmptyResults { return nil }
        return mockScales.first { $0.id == id }
    }
    
    func getScalesByType(_ type: ScaleType) -> [MusicScale] {
        if shouldReturnEmptyResults { return [] }
        return mockScales.filter { $0.type == type }
    }
    
    func getScalesByMood(_ mood: ScaleMood) -> [MusicScale] {
        if shouldReturnEmptyResults { return [] }
        return mockScales.filter { $0.mood == mood }
    }
    
    func getScalesByGenre(_ genre: MusicGenre) -> [MusicScale] {
        if shouldReturnEmptyResults { return [] }
        return mockScales.filter { $0.genres.contains(genre) }
    }
    
    func getScalesByComplexity(_ complexity: Int) -> [MusicScale] {
        if shouldReturnEmptyResults { return [] }
        return mockScales.filter { $0.complexity == complexity }
    }
    
    func getScalesWithComplexityRange(_ range: ClosedRange<Int>) -> [MusicScale] {
        if shouldReturnEmptyResults { return [] }
        return mockScales.filter { range.contains($0.complexity) }
    }
    
    func getScalesContaining(note: Int) -> [MusicScale] {
        if shouldReturnEmptyResults { return [] }
        return mockScales.filter { $0.contains(note: note) }
    }
    
    func getMostSimilarScales(to notes: [Int], minSimilarity: Double, maxResults: Int) -> [MusicScale] {
        if shouldReturnEmptyResults { return [] }
        
        let scalesWithSimilarity = mockScales.map { scale -> (scale: MusicScale, similarity: Double) in
            (scale: scale, similarity: scale.calculateSimilarity(with: notes))
        }
        
        return scalesWithSimilarity
            .filter { $0.similarity >= minSimilarity }
            .sorted { $0.similarity > $1.similarity }
            .prefix(maxResults)
            .map { $0.scale }
    }
    
    func searchScales(criteria: ScaleSearchCriteria) -> [MusicScale] {
        lastSearchCriteria = criteria
        
        if shouldReturnEmptyResults { return [] }
        
        var filteredScales = mockScales
        
        // 타입 필터링
        if let types = criteria.types {
            filteredScales = filteredScales.filter { types.contains($0.type) }
        }
        
        // 분위기 필터링
        if let moods = criteria.moods {
            filteredScales = filteredScales.filter { moods.contains($0.mood) }
        }
        
        // 장르 필터링
        if let genres = criteria.genres {
            filteredScales = filteredScales.filter { scale in
                !Set(scale.genres).isDisjoint(with: Set(genres))
            }
        }
        
        // 복잡도 범위 필터링
        if let complexityRange = criteria.complexityRange {
            filteredScales = filteredScales.filter { complexityRange.contains($0.complexity) }
        }
        
        // 필수 음표 포함 확인
        if let requiredNotes = criteria.requiredNotes {
            filteredScales = filteredScales.filter { scale in
                requiredNotes.allSatisfy { scale.contains(note: $0) }
            }
        }
        
        // 제외 음표 확인
        if let excludedNotes = criteria.excludedNotes {
            filteredScales = filteredScales.filter { scale in
                !excludedNotes.contains { scale.contains(note: $0) }
            }
        }
        
        // 최소 유사도 확인
        if let requiredNotes = criteria.requiredNotes, let minSimilarity = criteria.minSimilarity {
            filteredScales = filteredScales.filter { scale in
                scale.calculateSimilarity(with: requiredNotes) >= minSimilarity
            }
        }
        
        return filteredScales
    }
    
    // MARK: - Mock Helper Methods
    
    func addMockScale(_ scale: MusicScale) {
        mockScales.append(scale)
    }
    
    func clearMockScales() {
        mockScales.removeAll()
    }
    
    func resetMockScales() {
        mockScales = MusicScale.predefinedScales
    }
} 