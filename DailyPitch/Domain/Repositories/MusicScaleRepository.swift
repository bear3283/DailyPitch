//
//  MusicScaleRepository.swift
//  DailyPitch
//
//  Created by bear on 7/9/25.
//

import Foundation
import Combine

/// 음악 스케일 데이터 관리 에러 타입
enum MusicScaleError: Error {
    case scaleNotFound
    case invalidParameter
    case dataLoadingFailed
    case noScalesAvailable
}

/// 음악 스케일 데이터 관리를 위한 Repository 프로토콜
protocol MusicScaleRepository {
    
    /// 모든 사용 가능한 스케일들을 반환
    /// - Returns: 전체 스케일 배열
    func getAllScales() -> [MusicScale]
    
    /// ID로 특정 스케일을 찾아 반환
    /// - Parameter id: 찾을 스케일의 고유 ID
    /// - Returns: 해당 스케일 (없으면 nil)
    func getScaleById(_ id: String) -> MusicScale?
    
    /// 스케일 타입으로 필터링된 스케일들을 반환
    /// - Parameter type: 스케일 타입
    /// - Returns: 해당 타입의 스케일 배열
    func getScalesByType(_ type: ScaleType) -> [MusicScale]
    
    /// 분위기로 필터링된 스케일들을 반환
    /// - Parameter mood: 스케일 분위기
    /// - Returns: 해당 분위기의 스케일 배열
    func getScalesByMood(_ mood: ScaleMood) -> [MusicScale]
    
    /// 장르로 필터링된 스케일들을 반환
    /// - Parameter genre: 음악 장르
    /// - Returns: 해당 장르에 적합한 스케일 배열
    func getScalesByGenre(_ genre: MusicGenre) -> [MusicScale]
    
    /// 복잡도로 필터링된 스케일들을 반환
    /// - Parameter complexity: 스케일 복잡도 (1-5)
    /// - Returns: 해당 복잡도의 스케일 배열
    func getScalesByComplexity(_ complexity: Int) -> [MusicScale]
    
    /// 복잡도 범위로 필터링된 스케일들을 반환
    /// - Parameter range: 복잡도 범위
    /// - Returns: 해당 복잡도 범위의 스케일 배열
    func getScalesWithComplexityRange(_ range: ClosedRange<Int>) -> [MusicScale]
    
    /// 특정 음표를 포함하는 스케일들을 반환
    /// - Parameter note: 포함되어야 할 음표 (0-11)
    /// - Returns: 해당 음표를 포함하는 스케일 배열
    func getScalesContaining(note: Int) -> [MusicScale]
    
    /// 주어진 음표들과 가장 유사한 스케일들을 반환 (유사도 순)
    /// - Parameters:
    ///   - notes: 비교할 음표들 (0-11)
    ///   - minSimilarity: 최소 유사도 (0.0-1.0)
    ///   - maxResults: 최대 결과 개수
    /// - Returns: 유사도 순으로 정렬된 스케일 배열
    func getMostSimilarScales(
        to notes: [Int], 
        minSimilarity: Double,
        maxResults: Int
    ) -> [MusicScale]
    
    /// 복합 조건으로 스케일들을 검색
    /// - Parameter criteria: 검색 조건
    /// - Returns: 조건에 맞는 스케일 배열
    func searchScales(criteria: ScaleSearchCriteria) -> [MusicScale]
}

/// 스케일 검색 조건
struct ScaleSearchCriteria {
    let types: [ScaleType]?
    let moods: [ScaleMood]?
    let genres: [MusicGenre]?
    let complexityRange: ClosedRange<Int>?
    let requiredNotes: [Int]?      // 반드시 포함해야 할 음표들
    let excludedNotes: [Int]?      // 제외해야 할 음표들
    let minSimilarity: Double?     // requiredNotes와의 최소 유사도
    
    init(
        types: [ScaleType]? = nil,
        moods: [ScaleMood]? = nil,
        genres: [MusicGenre]? = nil,
        complexityRange: ClosedRange<Int>? = nil,
        requiredNotes: [Int]? = nil,
        excludedNotes: [Int]? = nil,
        minSimilarity: Double? = nil
    ) {
        self.types = types
        self.moods = moods
        self.genres = genres
        self.complexityRange = complexityRange
        self.requiredNotes = requiredNotes
        self.excludedNotes = excludedNotes
        self.minSimilarity = minSimilarity
    }
} 