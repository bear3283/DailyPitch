//
//  MusicScaleRepositoryImpl.swift
//  DailyPitch
//
//  Created by bear on 7/9/25.
//

import Foundation
import Combine

/// MusicScaleRepository의 실제 구현
/// 미리 정의된 스케일들과 동적 검색 기능을 제공
class MusicScaleRepositoryImpl: MusicScaleRepository {
    
    // MARK: - Properties
    
    /// 캐시된 스케일 데이터
    private var cachedScales: [MusicScale] = []
    
    /// 스케일 로딩 상태
    private var isLoaded = false
    
    // MARK: - Initializer
    
    init() {
        loadScales()
    }
    
    // MARK: - Public Methods
    
    func getAllScales() -> [MusicScale] {
        ensureScalesLoaded()
        return cachedScales
    }
    
    func getScaleById(_ id: String) -> MusicScale? {
        ensureScalesLoaded()
        return cachedScales.first { $0.id == id }
    }
    
    func getScalesByType(_ type: ScaleType) -> [MusicScale] {
        ensureScalesLoaded()
        return cachedScales.filter { $0.type == type }
    }
    
    func getScalesByMood(_ mood: ScaleMood) -> [MusicScale] {
        ensureScalesLoaded()
        return cachedScales.filter { $0.mood == mood }
    }
    
    func getScalesByGenre(_ genre: MusicGenre) -> [MusicScale] {
        ensureScalesLoaded()
        return cachedScales.filter { $0.genres.contains(genre) }
    }
    
    func getScalesByComplexity(_ complexity: Int) -> [MusicScale] {
        ensureScalesLoaded()
        guard complexity >= 1 && complexity <= 5 else { return [] }
        return cachedScales.filter { $0.complexity == complexity }
    }
    
    func getScalesWithComplexityRange(_ range: ClosedRange<Int>) -> [MusicScale] {
        ensureScalesLoaded()
        return cachedScales.filter { range.contains($0.complexity) }
    }
    
    func getScalesContaining(note: Int) -> [MusicScale] {
        ensureScalesLoaded()
        let normalizedNote = note % 12
        return cachedScales.filter { $0.contains(note: normalizedNote) }
    }
    
    func getMostSimilarScales(to notes: [Int], minSimilarity: Double, maxResults: Int) -> [MusicScale] {
        ensureScalesLoaded()
        
        guard !notes.isEmpty, maxResults > 0 else { return [] }
        
        // 각 스케일의 유사도 계산
        let scalesWithSimilarity = cachedScales.map { scale -> (scale: MusicScale, similarity: Double) in
            let similarity = scale.calculateSimilarity(with: notes)
            return (scale: scale, similarity: similarity)
        }
        
        // 유사도 필터링 및 정렬
        return scalesWithSimilarity
            .filter { $0.similarity >= minSimilarity }
            .sorted { $0.similarity > $1.similarity }
            .prefix(maxResults)
            .map { $0.scale }
    }
    
    func searchScales(criteria: ScaleSearchCriteria) -> [MusicScale] {
        ensureScalesLoaded()
        
        var results = cachedScales
        
        // 타입 필터링
        if let types = criteria.types, !types.isEmpty {
            results = results.filter { types.contains($0.type) }
        }
        
        // 분위기 필터링
        if let moods = criteria.moods, !moods.isEmpty {
            results = results.filter { moods.contains($0.mood) }
        }
        
        // 장르 필터링
        if let genres = criteria.genres, !genres.isEmpty {
            results = results.filter { scale in
                !Set(scale.genres).isDisjoint(with: Set(genres))
            }
        }
        
        // 복잡도 범위 필터링
        if let complexityRange = criteria.complexityRange {
            results = results.filter { complexityRange.contains($0.complexity) }
        }
        
        // 필수 음표 포함 확인
        if let requiredNotes = criteria.requiredNotes, !requiredNotes.isEmpty {
            results = results.filter { scale in
                requiredNotes.allSatisfy { scale.contains(note: $0) }
            }
        }
        
        // 제외 음표 확인
        if let excludedNotes = criteria.excludedNotes, !excludedNotes.isEmpty {
            results = results.filter { scale in
                !excludedNotes.contains { scale.contains(note: $0) }
            }
        }
        
        // 최소 유사도 확인 (requiredNotes가 있는 경우에만)
        if let requiredNotes = criteria.requiredNotes,
           let minSimilarity = criteria.minSimilarity,
           !requiredNotes.isEmpty {
            results = results.filter { scale in
                scale.calculateSimilarity(with: requiredNotes) >= minSimilarity
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    /// 스케일 데이터가 로드되었는지 확인하고, 필요시 로드
    private func ensureScalesLoaded() {
        if !isLoaded {
            loadScales()
        }
    }
    
    /// 스케일 데이터 로드
    private func loadScales() {
        // 기본 제공 스케일들 로드
        cachedScales = MusicScale.predefinedScales
        
        // 추가 스케일들 로드 (확장성을 위해)
        loadAdditionalScales()
        
        isLoaded = true
    }
    
    /// 추가 스케일들을 로드 (향후 확장 가능)
    private func loadAdditionalScales() {
        let additionalScales: [MusicScale] = [
            // 추가 교회선법들
            MusicScale(
                id: "phrygian",
                name: "프리지안 선법",
                englishName: "Phrygian Mode",
                type: .modal,
                intervals: [0, 1, 3, 5, 7, 8, 10],
                description: "어둡고 신비로운 느낌의 교회선법, 플라멩코에서 사용",
                mood: .mysterious,
                complexity: 4,
                genres: [.world, .classical]
            ),
            
            MusicScale(
                id: "lydian",
                name: "리디안 선법",
                englishName: "Lydian Mode",
                type: .modal,
                intervals: [0, 2, 4, 6, 7, 9, 11],
                description: "밝고 몽환적인 느낌의 교회선법, 영화음악에서 사용",
                mood: .bright,
                complexity: 4,
                genres: [.classical, .electronic]
            ),
            
            MusicScale(
                id: "locrian",
                name: "로크리안 선법",
                englishName: "Locrian Mode",
                type: .modal,
                intervals: [0, 1, 3, 5, 6, 8, 10],
                description: "불안정하고 긴장감이 있는 교회선법",
                mood: .dark,
                complexity: 5,
                genres: [.jazz, .classical]
            ),
            
            // 재즈 스케일들
            MusicScale(
                id: "bebop-dominant",
                name: "비밥 도미넌트",
                englishName: "Bebop Dominant Scale",
                type: .jazz,
                intervals: [0, 2, 4, 5, 7, 9, 10, 11],
                description: "재즈 비밥 스타일에서 사용되는 8음계",
                mood: .energetic,
                complexity: 4,
                genres: [.jazz]
            ),
            
            MusicScale(
                id: "whole-tone",
                name: "온음계",
                englishName: "Whole Tone Scale",
                type: .exotic,
                intervals: [0, 2, 4, 6, 8, 10],
                description: "모든 음정이 온음으로 이루어진 6음계, 인상주의 음악",
                mood: .mysterious,
                complexity: 3,
                genres: [.classical, .jazz]
            ),
            
            // 블루스 변형들
            MusicScale(
                id: "major-blues",
                name: "메이저 블루스",
                englishName: "Major Blues Scale",
                type: .blues,
                intervals: [0, 2, 3, 4, 7, 9],
                description: "장조 느낌의 블루스 스케일",
                mood: .energetic,
                complexity: 2,
                genres: [.blues, .country, .rock]
            ),
            
            // 민족 음계들
            MusicScale(
                id: "japanese-hirajoshi",
                name: "일본 히라조시",
                englishName: "Japanese Hirajoshi",
                type: .exotic,
                intervals: [0, 2, 3, 7, 8],
                description: "전통 일본 음계, 평화롭고 동양적인 느낌",
                mood: .peaceful,
                complexity: 3,
                genres: [.world, .classical]
            ),
            
            MusicScale(
                id: "arabic-maqam",
                name: "아랍 마캄",
                englishName: "Arabic Maqam",
                type: .exotic,
                intervals: [0, 1, 4, 5, 7, 8, 11],
                description: "중동 전통 음계, 이국적인 분위기",
                mood: .exotic_mood,
                complexity: 4,
                genres: [.world]
            ),
            
            // 현대 스케일들
            MusicScale(
                id: "diminished",
                name: "디미니시드",
                englishName: "Diminished Scale",
                type: .exotic,
                intervals: [0, 1, 3, 4, 6, 7, 9, 10],
                description: "반음-온음 패턴의 8음계, 재즈와 현대음악에서 사용",
                mood: .dark,
                complexity: 5,
                genres: [.jazz, .classical]
            )
        ]
        
        cachedScales.append(contentsOf: additionalScales)
    }
}

// MARK: - Scale Type Extension

extension ScaleType {
    static let jazz: ScaleType = .modal // 재즈 타입을 modal로 매핑
}

// MARK: - Convenience Extensions

extension MusicScaleRepositoryImpl {
    
    /// 특정 키의 스케일들 반환 (루트 노트 기준)
    func getScalesForKey(root: Int) -> [MusicScale] {
        return getScalesContaining(note: root)
    }
    
    /// 인기있는/추천 스케일들 반환
    func getPopularScales(limit: Int = 10) -> [MusicScale] {
        ensureScalesLoaded()
        
        // 복잡도가 낮고 일반적으로 사용되는 스케일들 우선
        return cachedScales
            .filter { $0.complexity <= 3 }
            .sorted { scale1, scale2 in
                // 복잡도 우선, 그 다음 장르 수로 정렬
                if scale1.complexity != scale2.complexity {
                    return scale1.complexity < scale2.complexity
                }
                return scale1.genres.count > scale2.genres.count
            }
            .prefix(limit)
            .map { $0 }
    }
    
    /// 초보자용 스케일들 반환
    func getBeginnerFriendlyScales() -> [MusicScale] {
        return getScalesByComplexity(1) + getScalesByComplexity(2)
    }
    
    /// 고급자용 스케일들 반환
    func getAdvancedScales() -> [MusicScale] {
        return getScalesByComplexity(4) + getScalesByComplexity(5)
    }
} 