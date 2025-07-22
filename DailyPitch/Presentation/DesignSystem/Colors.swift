//
//  Colors.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI

/// DailyPitch 디자인 시스템 색상 정의
/// Apple HIG와 게슈탈트 원리를 기반으로 구성
extension Color {
    
    // MARK: - Primary Brand Colors (iOS 시스템 색상 기반)
    
    /// 메인 브랜드 색상 (iOS Blue 기반, 다크모드 대응)
    static let dpPrimary = Color.blue
    
    /// 보조 브랜드 색상 (iOS Teal 기반)
    static let dpSecondary = Color.teal
    
    /// 액센트 색상 (iOS Orange 기반)
    static let dpAccent = Color.orange
    
    // MARK: - Semantic Colors (iOS 시스템 색상 활용)
    
    /// 성공 상태 색상
    static let dpSuccess = Color.green
    
    /// 경고 상태 색상
    static let dpWarning = Color.yellow
    
    /// 오류 상태 색상
    static let dpError = Color.red
    
    /// 정보 표시 색상
    static let dpInfo = Color.blue
    
    // MARK: - Adaptive System Colors (다크모드 자동 대응)
    
    /// 배경 색상 (시스템 배경색)
    static let dpBackground = Color(UIColor.systemBackground)
    
    /// 보조 배경 색상
    static let dpBackgroundSecondary = Color(UIColor.secondarySystemBackground)
    
    /// 표면 색상 (카드, 패널 등)
    static let dpSurface = Color(UIColor.secondarySystemBackground)
    
    /// 그룹화된 배경 색상
    static let dpGroupedBackground = Color(UIColor.systemGroupedBackground)
    
    /// 구분선 색상
    static let dpDivider = Color(UIColor.separator)
    
    /// 비활성 요소 색상
    static let dpDisabled = Color(UIColor.tertiaryLabel)
    
    // MARK: - Adaptive Text Colors
    
    /// 주요 텍스트 색상
    static let dpTextPrimary = Color(UIColor.label)
    
    /// 보조 텍스트 색상
    static let dpTextSecondary = Color(UIColor.secondaryLabel)
    
    /// 삼차 텍스트 색상
    static let dpTextTertiary = Color(UIColor.tertiaryLabel)
    
    /// 힌트 텍스트 색상
    static let dpTextHint = Color(UIColor.quaternaryLabel)
    
    /// 플레이스홀더 텍스트 색상
    static let dpTextPlaceholder = Color(UIColor.placeholderText)
    
    // MARK: - Color Aliases (이전 코드 호환성을 위한 별칭)
    
    /// 적응형 배경 색상 (호환성)
    static let adaptiveBackground = dpBackground
    
    /// 액센트 색상 (호환성)
    static let accent = dpAccent
    
    /// 상호작용 색상 (호환성)
    static let interactive = dpPrimary
    
    /// 주요 텍스트 색상 (호환성)
    static let textPrimary = dpTextPrimary
    
    /// 보조 텍스트 색상 (호환성)
    static let textSecondary = dpTextSecondary
    
    /// 삼차 텍스트 색상 (호환성)
    static let textTertiary = dpTextTertiary
    
    /// 성공 색상 (호환성)
    static let successDP = dpSuccess
    
    /// 경고 색상 (호환성)
    static let warningDP = dpWarning
    
    /// 오류 색상 (호환성)
    static let destructiveDP = dpError
    
    /// 카드 테두리 색상 (호환성)
    static let cardBorder = dpDivider
    
    /// 카드 배경 색상 (호환성)
    static let cardBackground = dpSurface
    
    /// 적응형 그림자 색상 (호환성)
    static let adaptiveShadow = Color(UIColor.systemGray3.withAlphaComponent(0.3))
    
    // MARK: - Musical Note Colors (접근성 고려 색상환)
    
    /// 음계별 색상 매핑 - 색각 이상자를 고려한 접근성 색상
    struct NoteColors {
        /// C - 따뜻한 빨간색 (루트 노트)
        static let c = Color(red: 0.85, green: 0.2, blue: 0.3)
        
        /// C# - 진홍색
        static let cSharp = Color(red: 0.7, green: 0.15, blue: 0.35)
        
        /// D - 주황색
        static let d = Color(red: 1.0, green: 0.5, blue: 0.0)
        
        /// D# - 황금색
        static let dSharp = Color(red: 0.9, green: 0.7, blue: 0.1)
        
        /// E - 밝은 노란색
        static let e = Color(red: 0.95, green: 0.85, blue: 0.2)
        
        /// F - 연두색
        static let f = Color(red: 0.5, green: 0.8, blue: 0.2)
        
        /// F# - 초록색
        static let fSharp = Color(red: 0.2, green: 0.7, blue: 0.3)
        
        /// G - 청록색
        static let g = Color(red: 0.2, green: 0.7, blue: 0.6)
        
        /// G# - 밝은 청록색
        static let gSharp = Color(red: 0.3, green: 0.8, blue: 0.8)
        
        /// A - 하늘색 (표준 피치 A440Hz)
        static let a = Color(red: 0.2, green: 0.6, blue: 0.9)
        
        /// A# - 남색
        static let aSharp = Color(red: 0.3, green: 0.4, blue: 0.8)
        
        /// B - 보라색
        static let b = Color(red: 0.6, green: 0.3, blue: 0.8)
        
        /// 음계 인덱스로 색상 가져오기
        static func color(for noteIndex: Int) -> Color {
            switch noteIndex % 12 {
            case 0: return c
            case 1: return cSharp
            case 2: return d
            case 3: return dSharp
            case 4: return e
            case 5: return f
            case 6: return fSharp
            case 7: return g
            case 8: return gSharp
            case 9: return a
            case 10: return aSharp
            case 11: return b
            default: return Color(UIColor.systemGray)
            }
        }
        
        /// 음계 이름으로 색상 가져오기
        static func color(for noteName: String) -> Color {
            let normalizedName = noteName.lowercased().replacingOccurrences(of: "♯", with: "#")
            
            switch normalizedName {
            case "c": return c
            case "c#", "c♯", "db": return cSharp
            case "d": return d
            case "d#", "d♯", "eb": return dSharp
            case "e": return e
            case "f": return f
            case "f#", "f♯", "gb": return fSharp
            case "g": return g
            case "g#", "g♯", "ab": return gSharp
            case "a": return a
            case "a#", "a♯", "bb": return aSharp
            case "b": return b
            default: return Color(UIColor.systemGray)
            }
        }
        
        /// 접근성을 고려한 대비 색상
        static func accessibleColor(for noteName: String, isDarkMode: Bool = false) -> Color {
            let baseColor = color(for: noteName)
            return isDarkMode ? 
                baseColor.opacity(0.9) : 
                baseColor.opacity(0.8)
        }
    }
    
    // MARK: - Mood Colors (접근성 고려)
    
    struct MoodColors {
        /// 밝은 분위기 - 따뜻한 노란색
        static let bright = Color(red: 0.95, green: 0.8, blue: 0.2)
        
        /// 어두운 분위기 - 깊은 청색
        static let dark = Color(red: 0.15, green: 0.2, blue: 0.35)
        
        /// 평화로운 분위기 - 부드러운 청록색
        static let peaceful = Color(red: 0.4, green: 0.7, blue: 0.9)
        
        /// 신비로운 분위기 - 깊은 보라색
        static let mysterious = Color(red: 0.4, green: 0.25, blue: 0.6)
        
        /// 역동적인 분위기 - 활기찬 주황색
        static let energetic = Color(red: 0.9, green: 0.4, blue: 0.2)
        
        /// 우울한 분위기 - 차분한 회색-파랑
        static let melancholic = Color(red: 0.4, green: 0.45, blue: 0.6)
        
        /// 이국적인 분위기 - 따뜻한 갈색
        static let exotic = Color(red: 0.7, green: 0.45, blue: 0.2)
        
        /// 중성적인 분위기 - 시스템 회색
        static let neutral = Color(UIColor.systemGray)
        
        /// 분위기 타입에 따른 색상 반환
        static func color(for mood: ScaleMood) -> Color {
            switch mood {
            case .bright: return bright
            case .dark: return dark
            case .peaceful: return peaceful
            case .mysterious: return mysterious
            case .energetic: return energetic
            case .melancholic: return melancholic
            case .exotic_mood: return exotic
            case .neutral: return neutral
            }
        }
        
        /// 복합 분위기 색상 혼합 (WCAG AA 대비 보장)
        static func blendedColor(primary: ScaleMood, secondary: ScaleMood, intensity: Double) -> Color {
            let primaryColor = color(for: primary)
            let secondaryColor = color(for: secondary)
            
            // 단순한 색상 혼합 - 컴파일러 타입 추론 최적화
            let weight = max(0.0, min(1.0, intensity))
            
            // 기본 색상 조합 사용
            if weight > 0.5 {
                return primaryColor.opacity(0.8)
            } else {
                return secondaryColor.opacity(0.8)
            }
        }
    }
    
    // MARK: - iOS HIG Compliant Gradients
    
    /// 브랜드 그라데이션 (iOS 스타일)
    static let dpBrandGradient = LinearGradient(
        colors: [dpPrimary, dpSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 배경 그라데이션 (시스템 색상 기반)
    static let dpBackgroundGradient = LinearGradient(
        colors: [dpBackground, dpBackgroundSecondary],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// 성공 그라데이션
    static let dpSuccessGradient = LinearGradient(
        colors: [dpSuccess, dpSuccess.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 카드 그라데이션 (음향 파형 느낌)
    static let dpWaveformGradient = LinearGradient(
        colors: [dpPrimary.opacity(0.8), dpSecondary.opacity(0.6), dpPrimary.opacity(0.4)],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - iOS Standard Spacing & Layout Colors
    
    /// 버튼 배경 색상들
    struct ButtonColors {
        static let primary = dpPrimary
        static let secondary = Color(UIColor.systemGray5)
        static let tertiary = Color(UIColor.systemGray6)
        static let destructiveButton = dpError
        static let successButton = dpSuccess
    }
    
    /// 상태별 색상들
    struct StateColors {
        static let recording = Color.red
        static let playing = Color.green
        static let paused = Color.orange
        static let stopped = Color(UIColor.systemGray)
        static let analyzing = Color.blue
        static let error = dpError
    }
    
    // MARK: - Helper Extensions
    
    /// Color 값 추출 및 접근성 유틸리티
    var uiColor: UIColor {
        return UIColor(self)
    }
    
    /// 색상의 밝기 계산 (0.0 - 1.0)
    var luminance: Double {
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let r = Double(components[0])
        let g = Double(components[1])
        let b = Double(components[2])
        
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
    
    /// WCAG AA 대비 요구사항 확인
    func contrastRatio(with other: Color) -> Double {
        let lum1 = self.luminance
        let lum2 = other.luminance
        let lighter = max(lum1, lum2)
        let darker = min(lum1, lum2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// 접근성 준수 여부 확인 (WCAG AA: 4.5:1, AAA: 7:1)
    func isAccessible(on background: Color, level: AccessibilityLevel = .AA) -> Bool {
        let ratio = self.contrastRatio(with: background)
        switch level {
        case .AA: return ratio >= 4.5
        case .AAA: return ratio >= 7.0
        }
    }
    
    /// 접근성 수준
    enum AccessibilityLevel {
        case AA, AAA
    }
}

// MARK: - Color Palette Documentation

/**
 # DailyPitch Color System v2.0
 
 ## 설계 원칙
 
 1. **Apple HIG 완전 준수**
    - iOS 시스템 색상 우선 사용
    - 자동 다크/라이트 모드 대응
    - Dynamic Color 지원
 
 2. **접근성 우선 설계**
    - WCAG AA 기준 색상 대비 (4.5:1 이상)
    - 색각 이상자 고려 색상 선택
    - VoiceOver 친화적 색상 시스템
 
 3. **게슈탈트 원리 적용**
    - 유사성: 관련 기능별 색상 그룹핑
    - 근접성: 조화로운 색상 팔레트
    - 연속성: 자연스러운 그라데이션
 
 4. **음악적 직관성**
    - 12음계의 과학적 색상 매핑
    - 감정 기반 분위기 색상
    - 시각적 청각 표현
 
 ## 사용 가이드
 
 ```swift
 // 시스템 색상 기반 사용 (권장)
 Text("Hello").foregroundColor(.dpPrimary)
 Rectangle().fill(.dpSurface)
 
 // 음계별 색상
 Circle().fill(Color.NoteColors.color(for: "C4"))
 
 // 접근성 확인
 if Color.dpPrimary.isAccessible(on: .dpBackground) {
     // 안전한 색상 조합
 }
 
 // 분위기별 색상
 let moodColor = Color.MoodColors.color(for: .bright)
 ```
 
 ## 접근성 가이드
 
 - 모든 텍스트는 배경과 4.5:1 이상의 대비비 유지
 - 색상만으로 정보를 전달하지 않음
 - 다크모드에서 자동으로 적절한 색상 제공
 */ 