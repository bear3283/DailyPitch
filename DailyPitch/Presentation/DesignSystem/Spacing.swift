//
//  Spacing.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI

/// DailyPitch 스페이싱 시스템
/// Apple HIG 기준 8pt 그리드와 게슈탈트 원리를 적용
struct Spacing {
    
    // MARK: - Apple HIG 8pt Grid System
    
    /// 기본 단위 (8pt)
    static let unit: CGFloat = 8
    
    /// 매우 작은 간격 (4pt)
    static let xs: CGFloat = unit * 0.5
    
    /// 작은 간격 (8pt)
    static let sm: CGFloat = unit
    
    /// 기본 간격 (16pt)
    static let md: CGFloat = unit * 2
    
    /// 큰 간격 (24pt)
    static let lg: CGFloat = unit * 3
    
    /// 매우 큰 간격 (32pt)
    static let xl: CGFloat = unit * 4
    
    /// 특대 간격 (40pt)
    static let xxl: CGFloat = unit * 5
    
    /// 점보 간격 (48pt)
    static let xxxl: CGFloat = unit * 6
    
    // MARK: - Semantic Spacing (의미론적 간격)
    
    /// 컴포넌트 내부 패딩
    static let componentPadding = md
    
    /// 카드 패딩
    static let cardPadding = lg
    
    /// 화면 가장자리 여백
    static let screenMargin = lg
    
    /// 섹션 간 간격
    static let sectionSpacing = xl
    
    /// 요소 간 최소 간격
    static let minimumSpacing = xs
    
    /// 터치 타겟 최소 크기 (iOS HIG 44pt)
    static let minimumTouchTarget: CGFloat = 44
    
    // MARK: - Gestalt Principle Spacing (게슈탈트 원리 기반)
    
    /// 근접성(Proximity) 원리 - 관련 요소들의 그룹핑
    struct Proximity {
        /// 매우 밀접한 관계 (라벨-값 쌍)
        static let intimate = xs
        
        /// 밀접한 관계 (관련 컨트롤들)
        static let close = sm
        
        /// 보통 관계 (같은 섹션 내 요소들)
        static let related = md
        
        /// 느슨한 관계 (다른 그룹이지만 관련 있는 요소들)
        static let loose = lg
        
        /// 분리된 관계 (서로 다른 기능 그룹)
        static let separated = xl
    }
    
    /// 유사성(Similarity) 원리 - 비슷한 요소들의 시각적 일관성
    struct Similarity {
        /// 같은 타입 버튼 간 간격
        static let buttonSpacing = md
        
        /// 같은 타입 카드 간 간격
        static let cardSpacing = md
        
        /// 같은 레벨 헤딩 간 간격
        static let headingSpacing = lg
        
        /// 같은 타입 리스트 아이템 간 간격
        static let listItemSpacing = sm
    }
    
    /// 연속성(Continuity) 원리 - 시각적 흐름을 위한 간격
    struct Continuity {
        /// 수평 요소 흐름
        static let horizontalFlow = md
        
        /// 수직 요소 흐름
        static let verticalFlow = lg
        
        /// 대각선 요소 배치
        static let diagonalFlow = lg
        
        /// 원형 배치 요소 간격
        static let circularFlow = md
    }
    
    /// 폐쇄성(Closure) 원리 - 그룹을 형성하는 경계 간격
    struct Closure {
        /// 컨테이너 내부 여백
        static let containerPadding = lg
        
        /// 섹션 구분 간격
        static let sectionDivider = xxl
        
        /// 카테고리 분리 간격
        static let categoryDivider = xxxl
        
        /// 페이지 구분 간격
        static let pageDivider = xxxl
    }
    
    // MARK: - Musical Interface Spacing (음악 인터페이스 전용)
    
    /// 음악적 요소들을 위한 특별 간격
    struct Musical {
        /// 음표 간 최소 간격
        static let noteSpacing = sm
        
        /// 스케일 정보 간 간격
        static let scaleInfoSpacing = md
        
        /// 주파수 표시 간 간격
        static let frequencySpacing = xs
        
        /// 파형 시각화 간격
        static let waveformSpacing = xs
        
        /// 음향 분석 결과 간 간격
        static let analysisSpacing = lg
        
        /// 재생 컨트롤 간 간격
        static let playbackControlSpacing = lg
    }
    
    // MARK: - Device-Specific Adjustments
    
    /// 기기별 조정된 간격
    struct DeviceAdjusted {
        /// iPhone SE 등 작은 화면용 조정
        static func compact(base: CGFloat) -> CGFloat {
            return base * 0.75
        }
        
        /// iPhone Pro Max 등 큰 화면용 조정
        static func expanded(base: CGFloat) -> CGFloat {
            return base * 1.25
        }
        
        /// iPad용 조정
        static func tablet(base: CGFloat) -> CGFloat {
            return base * 1.5
        }
    }
    
    // MARK: - Dynamic Spacing Functions
    
    /// 화면 크기에 따른 동적 간격 계산
    /// - Parameters:
    ///   - base: 기본 간격
    ///   - screenWidth: 화면 너비
    /// - Returns: 조정된 간격
    static func dynamic(base: CGFloat, for screenWidth: CGFloat) -> CGFloat {
        switch screenWidth {
        case 0..<375:  // iPhone SE
            return DeviceAdjusted.compact(base: base)
        case 375..<414: // iPhone 표준
            return base
        case 414..<428: // iPhone Plus
            return base * 1.1
        case 428...: // iPhone Pro Max
            return DeviceAdjusted.expanded(base: base)
        default:
            return base
        }
    }
    
    /// 컨텐츠 밀도에 따른 간격 조정
    /// - Parameters:
    ///   - base: 기본 간격
    ///   - density: 컨텐츠 밀도 (.low, .medium, .high)
    /// - Returns: 밀도에 맞는 간격
    static func density(_ density: ContentDensity, base: CGFloat) -> CGFloat {
        switch density {
        case .low: return base * 1.5
        case .medium: return base
        case .high: return base * 0.75
        }
    }
    
    /// 컨텐츠 밀도 열거형
    enum ContentDensity {
        case low, medium, high
    }
}

// MARK: - Layout Extensions

extension View {
    
    /// 표준 화면 패딩 적용
    func screenPadding() -> some View {
        self.padding(.horizontal, Spacing.screenMargin)
    }
    
    /// 카드 스타일 패딩 적용
    func cardPadding() -> some View {
        self.padding(Spacing.cardPadding)
    }
    
    /// 컴포넌트 패딩 적용
    func componentPadding() -> some View {
        self.padding(Spacing.componentPadding)
    }
    
    /// 게슈탈트 근접성 원리 적용
    func proximitySpacing(_ type: ProximityType) -> some View {
        Group {
            switch type {
            case .intimate:
                self.padding(.vertical, Spacing.Proximity.intimate)
            case .close:
                self.padding(.vertical, Spacing.Proximity.close)
            case .related:
                self.padding(.vertical, Spacing.Proximity.related)
            case .loose:
                self.padding(.vertical, Spacing.Proximity.loose)
            case .separated:
                self.padding(.vertical, Spacing.Proximity.separated)
            }
        }
    }
    
    /// 최소 터치 타겟 크기 보장
    func minimumTouchTarget() -> some View {
        self.frame(minWidth: Spacing.minimumTouchTarget, minHeight: Spacing.minimumTouchTarget)
    }
    
    /// 음악 인터페이스 간격 적용
    func musicalSpacing(_ type: MusicalSpacingType) -> some View {
        Group {
            switch type {
            case .note:
                self.padding(Spacing.Musical.noteSpacing)
            case .scale:
                self.padding(Spacing.Musical.scaleInfoSpacing)
            case .frequency:
                self.padding(Spacing.Musical.frequencySpacing)
            case .waveform:
                self.padding(Spacing.Musical.waveformSpacing)
            case .analysis:
                self.padding(Spacing.Musical.analysisSpacing)
            case .playback:
                self.padding(Spacing.Musical.playbackControlSpacing)
            }
        }
    }
}

// MARK: - Spacing Aliases (이전 코드 호환성을 위한 별칭)

/// 앱 전체에서 사용하는 간격 값들 (호환성을 위한 별칭)
struct AppSpacing {
    static let xsmall = Spacing.xs
    static let small = Spacing.sm  
    static let medium = Spacing.md
    static let large = Spacing.lg
    static let xlarge = Spacing.xl
    static let xxlarge = Spacing.xxl
}

// MARK: - Supporting Types

/// 근접성 타입
enum ProximityType {
    case intimate, close, related, loose, separated
}

/// 음악 간격 타입
enum MusicalSpacingType {
    case note, scale, frequency, waveform, analysis, playback
}

// MARK: - Container Styles (GestaltContainer는 GestaltContainer.swift에서 정의됨)

// MARK: - Grid Systems

/// Apple HIG 기준 그리드 시스템
struct GridSystem {
    
    /// 표준 컬럼 그리드
    struct Columns {
        /// 모바일 2컬럼
        static let mobile2 = [GridItem(.flexible()), GridItem(.flexible())]
        
        /// 모바일 3컬럼
        static let mobile3 = Array(repeating: GridItem(.flexible()), count: 3)
        
        /// 태블릿 4컬럼
        static let tablet4 = Array(repeating: GridItem(.flexible()), count: 4)
        
        /// 태블릿 6컬럼
        static let tablet6 = Array(repeating: GridItem(.flexible()), count: 6)
        
        /// 동적 컬럼 (최소 너비 기반)
        static func adaptive(minWidth: CGFloat) -> [GridItem] {
            return [GridItem(.adaptive(minimum: minWidth))]
        }
    }
    
    /// 음악 인터페이스 전용 그리드
    struct Musical {
        /// 음계 표시 그리드 (12음계)
        static let chromaticScale = Array(repeating: GridItem(.flexible()), count: 12)
        
        /// 스케일 추천 그리드
        static let scaleRecommendation = Array(repeating: GridItem(.flexible()), count: 2)
        
        /// 재생 컨트롤 그리드
        static let playbackControls = Array(repeating: GridItem(.flexible()), count: 3)
        
        /// 분석 결과 그리드
        static let analysisResults = Array(repeating: GridItem(.flexible()), count: 2)
    }
}

// MARK: - Spacing Documentation

/**
 # DailyPitch Spacing System
 
 ## 설계 원칙
 
 1. **Apple HIG 8pt Grid 준수**
    - 모든 간격은 8pt의 배수
    - 일관된 시각적 리듬 조성
    - 다양한 화면 크기 대응
 
 2. **게슈탈트 원리 적용**
    - 근접성: 관련 요소들의 그룹핑
    - 유사성: 비슷한 요소들의 일관된 간격
    - 연속성: 자연스러운 시각적 흐름
    - 폐쇄성: 명확한 그룹 경계
 
 3. **접근성 최우선**
    - 최소 44pt 터치 타겟
    - 충분한 여백으로 가독성 확보
    - 동적 타입 크기 변화 대응
 
 4. **음악적 인터페이스 특화**
    - 음악 데이터 표시 최적화
    - 리듬감 있는 레이아웃
    - 직관적인 정보 구조
 
 ## 사용 가이드
 
 ```swift
 // 기본 간격 사용
 VStack(spacing: Spacing.md) { ... }
 
 // 게슈탈트 원리 적용
 VStack(spacing: Spacing.Proximity.related) { ... }
 
 // 확장 함수 사용
 someView
     .screenPadding()
     .proximitySpacing(.close)
 
 // 게슈탈트 컨테이너
 GestaltContainer(principle: .proximity) {
     // 관련 요소들
 }
 
 // 동적 간격
 let spacing = Spacing.dynamic(base: Spacing.md, for: screenWidth)
 ```
 
 ## 간격 가이드
 
 - **xs (4pt)**: 매우 밀접한 요소 (라벨-값)
 - **sm (8pt)**: 관련 컨트롤
 - **md (16pt)**: 표준 간격
 - **lg (24pt)**: 섹션 내 그룹
 - **xl (32pt)**: 섹션 간 구분
 - **xxl (40pt)**: 주요 영역 구분
 - **xxxl (48pt)**: 페이지 레벨 구분
 
 ## 접근성 체크리스트
 
 - ✅ 최소 44pt 터치 타겟
 - ✅ 8pt 그리드 시스템
 - ✅ 충분한 가독성 여백
 - ✅ 동적 화면 크기 대응
 */ 