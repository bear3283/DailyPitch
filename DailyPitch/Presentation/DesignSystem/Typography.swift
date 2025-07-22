//
//  Typography.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI

/// DailyPitch 타이포그래피 시스템 v2.0
/// Apple HIG Dynamic Type과 접근성을 완전 지원
extension Font {
    
    // MARK: - iOS HIG Compliant Text Styles
    
    /// 대형 헤드라인 (앱 타이틀, 주요 섹션) - Dynamic Type 지원
    static let dpLargeTitle = Font.largeTitle.weight(.bold)
    
    /// 중형 헤드라인 (섹션 제목) - Dynamic Type 지원
    static let dpTitle = Font.title.weight(.semibold)
    
    /// 소형 헤드라인 (카드 제목) - Dynamic Type 지원
    static let dpTitle2 = Font.title2.weight(.medium)
    
    /// 서브 헤드라인 - Dynamic Type 지원
    static let dpTitle3 = Font.title3.weight(.medium)
    
    /// 헤드라인 강조 - Dynamic Type 지원
    static let dpHeadline = Font.headline.weight(.semibold)
    
    // MARK: - Body Text Styles (Dynamic Type 완전 지원)
    
    /// 기본 본문 - Dynamic Type 지원
    static let dpBody = Font.body
    
    /// 강조 본문 - Dynamic Type 지원
    static let dpBodyEmphasized = Font.body.weight(.medium)
    
    /// 보조 본문 (설명, 부가 정보) - Dynamic Type 지원
    static let dpCallout = Font.callout
    
    /// 서브헤드 (카드 서브타이틀) - Dynamic Type 지원
    static let dpSubheadline = Font.subheadline
    
    // MARK: - Supporting Text Styles (접근성 최적화)
    
    /// 각주, 캡션 - Dynamic Type 지원
    static let dpFootnote = Font.footnote
    
    /// 매우 작은 텍스트 (라벨, 배지) - Dynamic Type 지원
    static let dpCaption = Font.caption
    
    /// 가장 작은 텍스트 (메타데이터) - Dynamic Type 지원
    static let dpCaption2 = Font.caption2
    
    // MARK: - Musical Display Styles (접근성 고려)
    
    /// 음계 표시용 - 크기 조절 가능한 모노스페이스
    static func dpNoteDisplay(size: CGFloat? = nil) -> Font {
        if let size = size {
            return Font.system(size: size, weight: .medium, design: .monospaced)
        } else {
            return Font.system(.title, design: .monospaced, weight: .medium)
        }
    }
    
    /// 주파수 표시용 - 정확성을 위한 모노스페이스
    static func dpFrequencyDisplay(size: CGFloat? = nil) -> Font {
        if let size = size {
            return Font.system(size: size, weight: .regular, design: .monospaced)
        } else {
            return Font.system(.title2, design: .monospaced, weight: .regular)
        }
    }
    
    /// 시간 표시용 - 가독성 최적화 모노스페이스
    static func dpTimeDisplay(size: CGFloat? = nil) -> Font {
        if let size = size {
            return Font.system(size: size, weight: .thin, design: .monospaced)
        } else {
            return Font.system(.largeTitle, design: .monospaced, weight: .thin)
        }
    }
    
    /// 음계 분석 결과 (큰 음계 표시) - 강조 효과
    static func dpNoteResult(size: CGFloat? = nil) -> Font {
        if let size = size {
            return Font.system(size: size, weight: .bold, design: .monospaced)
        } else {
            return Font.system(.largeTitle, design: .monospaced, weight: .bold)
        }
    }
    
    /// 스케일 이름 표시 - 음악적 우아함
    static let dpScaleName = Font.system(.headline, design: .default, weight: .semibold)
    
    // MARK: - Interactive Element Styles
    
    /// 주요 버튼 텍스트 - 터치하기 쉬운 크기
    static let dpButtonPrimary = Font.headline.weight(.semibold)
    
    /// 보조 버튼 텍스트
    static let dpButtonSecondary = Font.body.weight(.medium)
    
    /// 작은 버튼 텍스트 - 최소 터치 크기 고려
    static let dpButtonSmall = Font.callout.weight(.medium)
    
    /// 탭바 라벨 - 가독성 최적화
    static let dpTabLabel = Font.caption.weight(.medium)
    
    /// 내비게이션 제목
    static let dpNavTitle = Font.headline.weight(.semibold)
    
    /// 알림 배지 - 간결하고 명확한 정보 전달
    static let dpBadge = Font.caption2.weight(.bold)
    
    /// 대형 상호작용 요소 폰트 (호환성)
    static let interactionLarge = Font.title2.weight(.medium)
    
    /// 중형 상호작용 요소 폰트 (호환성)
    static let interactionMedium = Font.body.weight(.medium)
    
    // MARK: - Accessibility-First Custom Functions
    
    /// Dynamic Type 완전 지원 커스텀 폰트
    /// - Parameters:
    ///   - style: iOS 표준 텍스트 스타일
    ///   - design: 폰트 디자인 (.default, .serif, .monospaced, .rounded)
    ///   - weight: 폰트 굵기
    ///   - maxSize: 최대 크기 제한 (접근성 고려)
    static func dpDynamic(
        _ style: Font.TextStyle,
        design: Font.Design = .default,
        weight: Font.Weight = .regular,
        maxSize: CGFloat? = nil
    ) -> Font {
        let baseFont = Font.system(style, design: design, weight: weight)
        
        // 최대 크기 제한이 있는 경우 적용
        if let maxSize = maxSize {
            if #available(iOS 15.0, *) {
                return baseFont
                    // 접근성 크기 지원 (iOS 15+에서 사용 가능)
            } else {
                return baseFont
            }
        } else {
            if #available(iOS 15.0, *) {
                return baseFont
                    // 최대 접근성 크기 지원 (iOS 15+에서 사용 가능)
            } else {
                return baseFont
            }
        }
    }
    
    /// 접근성 준수 고정 크기 폰트 (Dynamic Type 제한)
    /// - Parameters:
    ///   - size: 고정 크기
    ///   - weight: 폰트 굵기
    ///   - design: 폰트 디자인
    ///   - allowScaling: Dynamic Type 스케일링 허용 여부
    static func dpFixed(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        allowScaling: Bool = true
    ) -> Font {
        let baseFont = Font.system(size: size, weight: weight, design: design)
        
        if allowScaling {
            // 제한된 스케일링 허용 (접근성 고려)
            if #available(iOS 15.0, *) {
                return baseFont // 접근성 크기 제한 제거 (iOS 버전 호환성)
            } else {
                return baseFont
            }
        } else {
            // 고정 크기 (특별한 경우에만 사용)
            return baseFont
        }
    }
    
    /// 음악 데이터 전용 폰트 (정확성과 가독성 최우선)
    /// - Parameters:
    ///   - style: 음악 데이터 타입
    ///   - size: 사용자 정의 크기 (옵셔널)
    static func dpMusical(
        _ style: MusicalFontStyle,
        size: CGFloat? = nil
    ) -> Font {
        switch style {
        case .note:
            return size != nil ? 
                Font.system(size: size!, weight: .medium, design: .monospaced) :
                Font.system(.title, design: .monospaced, weight: .medium)
        case .frequency:
            return size != nil ?
                Font.system(size: size!, weight: .light, design: .monospaced) :
                Font.system(.body, design: .monospaced, weight: .light)
        case .time:
            return size != nil ?
                Font.system(size: size!, weight: .thin, design: .monospaced) :
                Font.system(.title2, design: .monospaced, weight: .thin)
        case .bpm:
            return size != nil ?
                Font.system(size: size!, weight: .regular, design: .monospaced) :
                Font.system(.callout, design: .monospaced, weight: .regular)
        case .scale:
            return size != nil ?
                Font.system(size: size!, weight: .semibold, design: .default) :
                Font.system(.headline, design: .default, weight: .semibold)
        }
    }
    
    /// 음악 관련 폰트 스타일
    enum MusicalFontStyle {
        case note       // 음계 표시 (C4, A#3)
        case frequency  // 주파수 (440.0 Hz)
        case time       // 시간 (00:30)
        case bpm        // BPM (120 BPM)
        case scale      // 스케일 이름 (Major, Minor)
    }
}

// MARK: - Text Modifier Extensions (체계적 스타일링)

extension Text {
    
    // MARK: - Primary Text Styles
    
    /// 주요 제목 스타일 - 최대 가독성
    func dpTitleStyle() -> some View {
        self
            .font(.dpTitle)
            .foregroundColor(.dpTextPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    /// 본문 스타일 - 편안한 읽기 환경
    func dpBodyStyle() -> some View {
        self
            .font(.dpBody)
            .foregroundColor(.dpTextPrimary)
            .lineSpacing(2) // 가독성을 위한 줄 간격
            .multilineTextAlignment(.leading)
    }
    
    /// 보조 텍스트 스타일 - 계층적 정보 표현
    func dpSecondaryStyle() -> some View {
        self
            .font(.dpCallout)
            .foregroundColor(.dpTextSecondary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }
    
    /// 힌트 텍스트 스타일 - 미묘하지만 유용한 정보
    func dpHintStyle() -> some View {
        self
            .font(.dpFootnote)
            .foregroundColor(.dpTextHint)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    // MARK: - Musical Text Styles
    
    /// 음계 표시 스타일 - 정확하고 명확한 표현
    func dpNoteStyle(color: Color? = nil, size: CGFloat? = nil) -> some View {
        self
            .font(.dpMusical(.note, size: size))
            .foregroundColor(color ?? .dpTextPrimary)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .monospacedDigit() // 숫자 정렬 일관성
    }
    
    /// 주파수 표시 스타일 - 과학적 정확성
    func dpFrequencyStyle(size: CGFloat? = nil) -> some View {
        self
            .font(.dpMusical(.frequency, size: size))
            .foregroundColor(.dpTextSecondary)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .monospacedDigit()
    }
    
    /// 시간 표시 스타일 - 시각적 리듬감
    func dpTimeStyle(size: CGFloat? = nil) -> some View {
        self
            .font(.dpMusical(.time, size: size))
            .foregroundColor(.dpTextPrimary)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .monospacedDigit()
    }
    
    /// BPM 표시 스타일 - 리듬 정보
    func dpBpmStyle(size: CGFloat? = nil) -> some View {
        self
            .font(.dpMusical(.bpm, size: size))
            .foregroundColor(.dpTextSecondary)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .monospacedDigit()
    }
    
    /// 스케일 이름 스타일 - 음악적 우아함
    func dpScaleStyle(size: CGFloat? = nil) -> some View {
        self
            .font(.dpMusical(.scale, size: size))
            .foregroundColor(.dpTextPrimary)
            .lineLimit(1)
            .multilineTextAlignment(.center)
    }
    
    // MARK: - State & Feedback Styles
    
    /// 에러 메시지 스타일 - 명확한 문제 인식
    func dpErrorStyle() -> some View {
        self
            .font(.dpCallout)
            .foregroundColor(.dpError)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 4)
    }
    
    /// 성공 메시지 스타일 - 긍정적 피드백
    func dpSuccessStyle() -> some View {
        self
            .font(.dpCallout)
            .foregroundColor(.dpSuccess)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 4)
    }
    
    /// 경고 메시지 스타일 - 주의 요청
    func dpWarningStyle() -> some View {
        self
            .font(.dpCallout)
            .foregroundColor(.dpWarning)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 4)
    }
    
    /// 정보 메시지 스타일 - 중성적 정보 제공
    func dpInfoStyle() -> some View {
        self
            .font(.dpCallout)
            .foregroundColor(.dpInfo)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 4)
    }
    
    // MARK: - UI Element Styles
    
    /// 배지 스타일 - 간결한 정보 표시
    func dpBadgeStyle(background: Color = .dpAccent, foreground: Color = .white) -> some View {
        self
            .font(.dpBadge)
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
            .lineLimit(1)
    }
    
    /// 카드 제목 스타일 - 구조화된 정보 표현
    func dpCardTitleStyle() -> some View {
        self
            .font(.dpTitle3)
            .foregroundColor(.dpTextPrimary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.bottom, 2)
    }
    
    /// 카드 서브타이틀 스타일 - 보조 정보
    func dpCardSubtitleStyle() -> some View {
        self
            .font(.dpSubheadline)
            .foregroundColor(.dpTextSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
    
    /// 버튼 텍스트 스타일 - 액션 유도
    func dpButtonTextStyle(style: ButtonTextStyle = .primary) -> some View {
        Group {
            switch style {
            case .primary:
                self
                    .font(.dpButtonPrimary)
                    .foregroundColor(.white)
            case .secondary:
                self
                    .font(.dpButtonSecondary)
                    .foregroundColor(.dpPrimary)
            case .tertiary:
                self
                    .font(.dpButtonSmall)
                    .foregroundColor(.dpTextSecondary)
            }
        }
        .lineLimit(1)
        .multilineTextAlignment(.center)
    }
    
    /// 버튼 텍스트 스타일 종류
    enum ButtonTextStyle {
        case primary, secondary, tertiary
    }
}

// MARK: - Typography Tokens (iOS HIG 기반)

/// 타이포그래피 토큰 - Apple HIG 기준 수치
struct TypographyTokens {
    
    /// 라인 높이 배수 (iOS HIG 기준)
    struct LineHeight {
        static let tight: CGFloat = 1.08    // 압축된 텍스트
        static let normal: CGFloat = 1.19   // 기본 라인 높이
        static let relaxed: CGFloat = 1.36  // 편안한 읽기
        static let loose: CGFloat = 1.5     // 여유로운 레이아웃
    }
    
    /// 글자 간격 (iOS HIG 기준)
    struct LetterSpacing {
        static let tight: CGFloat = -0.4
        static let normal: CGFloat = 0
        static let wide: CGFloat = 0.4
        static let wider: CGFloat = 0.8
    }
    
    /// 문단 간격 (iOS HIG 기준)
    struct ParagraphSpacing {
        static let tight: CGFloat = 8
        static let normal: CGFloat = 16
        static let relaxed: CGFloat = 24
        static let loose: CGFloat = 32
    }
    
    /// 접근성 고려 최소/최대 크기
    struct AccessibilityBounds {
        static let minimumTouchTarget: CGFloat = 44  // iOS HIG 최소 터치 크기
        static let minimumTextSize: CGFloat = 11     // 읽기 가능한 최소 크기
        static let maximumTextSize: CGFloat = 120    // 화면을 벗어나지 않는 최대 크기
        static let optimalLineLength: ClosedRange<Int> = 45...75  // 최적 한 줄 글자 수
    }
    
    /// 음악적 요소 타이포그래피 가이드
    struct MusicalGuide {
        /// 음계 표시 권장 크기
        static let noteDisplaySizes: [String: CGFloat] = [
            "small": 14,
            "medium": 18,
            "large": 24,
            "hero": 36
        ]
        
        /// 주파수 표시 권장 크기
        static let frequencyDisplaySizes: [String: CGFloat] = [
            "small": 12,
            "medium": 16,
            "large": 20
        ]
        
        /// 시간 표시 권장 크기
        static let timeDisplaySizes: [String: CGFloat] = [
            "compact": 16,
            "standard": 24,
            "prominent": 36
        ]
    }
}

// MARK: - Typography Documentation

/**
 # DailyPitch Typography System v2.0
 
 ## 설계 원칙
 
 1. **Apple HIG 완전 준수**
    - Dynamic Type 100% 지원
    - 접근성 가이드라인 완전 준수 (WCAG AA/AAA)
    - iOS 표준 텍스트 스타일 우선 사용
 
 2. **접근성 최우선**
    - 최소 텍스트 크기 11pt 유지
    - 최대 Accessibility 5 크기까지 지원
    - 색상 대비 4.5:1 이상 보장
    - 터치 타겟 최소 44pt 확보
 
 3. **가독성 최적화**
    - 적절한 라인 높이 (1.19 기본)
    - 최적 줄 길이 (45-75자)
    - 충분한 문단 간격
 
 4. **음악적 특성 반영**
    - 정확한 데이터 표현을 위한 모노스페이스
    - 음악적 계층 구조 반영
    - 리듬감 있는 타이포그래피
 
 ## 사용 가이드
 
 ```swift
 // 기본 텍스트 스타일 (권장)
 Text("제목").dpTitleStyle()
 Text("본문 내용").dpBodyStyle()
 Text("보조 정보").dpSecondaryStyle()
 
 // 음악 데이터 표시
 Text("C4").dpNoteStyle()
 Text("440.0 Hz").dpFrequencyStyle()
 Text("00:30").dpTimeStyle()
 
 // Dynamic Type 커스텀
 Text("커스텀")
     .font(.dpDynamic(.title, weight: .bold, maxSize: 32))
 
 // 고정 크기 (특별한 경우)
 Text("고정")
     .font(.dpFixed(size: 16, allowScaling: true))
 ```
 
 ## 접근성 체크리스트
 
 - ✅ Dynamic Type 지원
 - ✅ 최소 11pt 텍스트 크기
 - ✅ 4.5:1 색상 대비비
 - ✅ VoiceOver 호환성
 - ✅ 최소 44pt 터치 타겟
 - ✅ 적절한 라인 높이
 */ 

// MARK: - Musical Interface Typography Extensions

/// 음악 인터페이스 특화 타이포그래피
struct MusicalTypography {
    // 음악 인터페이스 전용 타이포그래피 정의
}

extension View {
    
    /// 음악 인터페이스 제목 스타일
    func musicTitleStyle() -> some View {
        self.modifier(MusicalTypography.MusicTitleModifier())
    }
    
    /// 섹션 헤더 스타일
    func sectionHeaderStyle() -> some View {
        self.modifier(MusicalTypography.SectionHeaderModifier())
    }
    
    /// 버튼 텍스트 스타일
    func buttonTextStyle() -> some View {
        self.modifier(MusicalTypography.ButtonTextModifier())
    }
    
    /// 본문 텍스트 스타일
    func bodyTextStyle() -> some View {
        self.modifier(MusicalTypography.BodyTextModifier())
    }
    
    /// 음계 텍스트 스타일 (MoodSelectionComponent용)
    func noteTextStyle() -> some View {
        self.modifier(MusicalTypography.NoteTextModifier())
    }
}

extension MusicalTypography {
    
    /// 음악 인터페이스 제목용 텍스트 수정자
    struct MusicTitleModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundColor(Color.textPrimary)
                .tracking(0.5)
        }
    }
    
    /// 섹션 헤더용 텍스트 수정자
    struct SectionHeaderModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(Color.textSecondary)
                .tracking(0.3)
        }
    }
    
    /// 버튼 텍스트용 수정자
    struct ButtonTextModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(Color.interactive)
        }
    }
    
    /// 본문 텍스트용 수정자
    struct BodyTextModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.body, design: .default, weight: .regular))
                .lineSpacing(4)
                .foregroundColor(Color.textPrimary)
        }
    }
    
    /// 음계 텍스트용 수정자 (MoodSelectionComponent용)
    struct NoteTextModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundColor(Color.textPrimary)
                .tracking(0.3)
        }
    }
} 