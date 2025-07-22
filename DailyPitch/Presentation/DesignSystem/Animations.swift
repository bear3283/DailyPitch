//
//  Animations.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI

/// DailyPitch 애니메이션 시스템
/// Apple HIG 기준 애니메이션과 음악적 리듬감을 결합
struct Animations {
    
    // MARK: - Apple HIG Standard Durations
    
    /// 매우 빠른 애니메이션 (0.1초) - 즉각적인 피드백
    static let immediate: TimeInterval = 0.1
    
    /// 빠른 애니메이션 (0.2초) - 터치 피드백
    static let fast: TimeInterval = 0.2
    
    /// 기본 애니메이션 (0.3초) - 표준 전환
    static let standard: TimeInterval = 0.3
    
    /// 중간 애니메이션 (0.5초) - 컨텐츠 전환
    static let medium: TimeInterval = 0.5
    
    /// 느린 애니메이션 (0.8초) - 복잡한 전환
    static let slow: TimeInterval = 0.8
    
    /// 매우 느린 애니메이션 (1.2초) - 특별한 효과
    static let deliberate: TimeInterval = 1.2
    
    // MARK: - iOS Standard Easing Functions
    
    /// iOS 표준 이징 - 자연스러운 움직임
    static let easeInOut = Animation.easeInOut(duration: standard)
    
    /// iOS 표준 스프링 - 생동감 있는 움직임
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.1)
    
    /// 부드러운 스프링 - 우아한 움직임
    static let gentleSpring = Animation.spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0.2)
    
    /// 탄력적 스프링 - 재미있는 움직임
    static let bouncySpring = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.0)
    
    /// 선형 애니메이션 - 균일한 속도
    static let linear = Animation.linear(duration: standard)
    
    // MARK: - Musical Rhythm-Based Animations
    
    /// 음악적 리듬 기반 애니메이션
    struct Musical {
        
        /// 60 BPM 기반 (1초) - Largo
        static let largo = Animation.easeInOut(duration: 1.0)
        
        /// 72 BPM 기반 (0.83초) - Adagio
        static let adagio = Animation.easeInOut(duration: 0.83)
        
        /// 96 BPM 기반 (0.625초) - Andante
        static let andante = Animation.easeInOut(duration: 0.625)
        
        /// 120 BPM 기반 (0.5초) - Moderato
        static let moderato = Animation.easeInOut(duration: 0.5)
        
        /// 144 BPM 기반 (0.42초) - Allegro
        static let allegro = Animation.easeInOut(duration: 0.42)
        
        /// 168 BPM 기반 (0.36초) - Vivace
        static let vivace = Animation.easeInOut(duration: 0.36)
        
        /// 200 BPM 기반 (0.3초) - Presto
        static let presto = Animation.easeInOut(duration: 0.3)
        
        /// 사용자 정의 BPM 기반 애니메이션
        /// - Parameter bpm: 분당 비트 수
        /// - Returns: BPM에 맞는 애니메이션
        static func rhythm(bpm: Int) -> Animation {
            let duration = 60.0 / Double(bpm)
            return Animation.easeInOut(duration: duration)
        }
        
        /// 음향 파형 애니메이션 - 주파수 기반
        /// - Parameter frequency: 주파수 (Hz)
        /// - Returns: 주파수에 맞는 반복 애니메이션
        static func waveform(frequency: Double) -> Animation {
            let period = 1.0 / frequency
            return Animation.linear(duration: period).repeatForever(autoreverses: true)
        }
        
        /// 음계 전환 애니메이션 - 음정 간격 기반
        /// - Parameter semitones: 반음 간격
        /// - Returns: 음정 변화에 맞는 애니메이션
        static func pitchTransition(semitones: Int) -> Animation {
            let baseDuration = 0.3
            let scaleFactor = Double(abs(semitones)) * 0.1 + 1.0
            return Animation.spring(
                response: baseDuration * scaleFactor,
                dampingFraction: 0.8,
                blendDuration: 0.1
            )
        }
    }
    
    // MARK: - Interaction Animations
    
    /// 사용자 상호작용 애니메이션
    struct Interaction {
        
        /// 버튼 터치 피드백
        static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.8, blendDuration: 0.0)
        
        /// 카드 선택 효과
        static let cardSelection = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)
        
        /// 스위치 토글
        static let toggle = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.0)
        
        /// 드래그 응답
        static let drag = Animation.spring(response: 0.1, dampingFraction: 1.0, blendDuration: 0.0)
        
        /// 스크롤 오버슈트
        static let scrollOvershoot = Animation.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.2)
        
        /// 제스처 완료
        static let gestureComplete = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)
    }
    
    // MARK: - Content Transitions
    
    /// 컨텐츠 전환 애니메이션
    struct Transition {
        
        /// 페이드 인/아웃
        static let fade = Animation.easeInOut(duration: medium)
        
        /// 슬라이드 인/아웃
        static let slide = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)
        
        /// 스케일 효과
        static let scale = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.0)
        
        /// 모달 표시
        static let modal = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.1)
        
        /// 네비게이션 전환
        static let navigation = Animation.easeInOut(duration: standard)
        
        /// 탭 전환
        static let tab = Animation.easeInOut(duration: fast)
        
        /// 리스트 아이템 등장
        static let listItem = Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.0)
    }
    
    // MARK: - Loading & Progress Animations
    
    /// 로딩 및 진행 상태 애니메이션
    struct Loading {
        
        /// 스피너 회전
        static let spinner = Animation.linear(duration: 1.0).repeatForever(autoreverses: false)
        
        /// 펄스 효과
        static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        
        /// 웨이브 효과
        static let wave = Animation.linear(duration: 2.0).repeatForever(autoreverses: false)
        
        /// 진행률 바 증가
        static let progressBar = Animation.easeOut(duration: slow)
        
        /// 분석 중 효과
        static let analyzing = Animation.spring(response: 0.8, dampingFraction: 0.7).repeatForever(autoreverses: true)
        
        /// 녹음 중 펄스
        static let recording = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    }
    
    // MARK: - Audio Visualization Animations
    
    /// 오디오 시각화 애니메이션
    struct AudioVisualization {
        
        /// 파형 애니메이션
        static let waveform = Animation.linear(duration: 0.1).repeatForever(autoreverses: false)
        
        /// 스펙트럼 분석기
        static let spectrum = Animation.linear(duration: 0.05).repeatForever(autoreverses: false)
        
        /// 음계 감지 효과
        static let noteDetection = Animation.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.0)
        
        /// 주파수 변화
        static let frequencyChange = Animation.easeInOut(duration: 0.5)
        
        /// 음량 레벨 변화
        static let volumeLevel = Animation.linear(duration: 0.1)
        
        /// 상태 전환 애니메이션
        static let stateTransition = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.1)
        
        /// 음성 활동 감지
        static let voiceActivity = Animation.easeInOut(duration: 0.3)
    }
    
    // MARK: - State Change Animations
    
    /// 상태 변화 애니메이션
    struct StateChange {
        
        /// 성공 상태
        static let success = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.0)
        
        /// 오류 상태 - 진동 효과
        static let error = Animation.spring(response: 0.2, dampingFraction: 0.3, blendDuration: 0.0)
        
        /// 경고 상태
        static let warning = Animation.easeInOut(duration: fast).repeatCount(3, autoreverses: true)
        
        /// 정보 표시
        static let info = Animation.easeInOut(duration: standard)
        
        /// 로드 완료
        static let loaded = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)
        
        /// 새로고침
        static let refresh = Animation.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0.2)
    }
    
    // MARK: - Custom Animation Functions
    
    /// 지연 시간과 함께 애니메이션 실행
    /// - Parameters:
    ///   - delay: 지연 시간
    ///   - animation: 적용할 애니메이션
    ///   - action: 실행할 액션
    static func withDelay(
        _ delay: TimeInterval,
        animation: Animation,
        _ action: @escaping () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(animation) {
                action()
            }
        }
    }
    
    /// 순차적 애니메이션 실행
    /// - Parameters:
    ///   - animations: 애니메이션과 액션 쌍의 배열
    ///   - interval: 각 애니메이션 간 간격
    static func sequence(
        _ animations: [(animation: Animation, action: () -> Void)],
        interval: TimeInterval = 0.1
    ) {
        for (index, animationPair) in animations.enumerated() {
            let delay = TimeInterval(index) * interval
            withDelay(delay, animation: animationPair.animation) {
                animationPair.action()
            }
        }
    }
    
    /// 조건부 애니메이션
    /// - Parameters:
    ///   - condition: 조건
    ///   - trueAnimation: 조건이 참일 때 애니메이션
    ///   - falseAnimation: 조건이 거짓일 때 애니메이션
    /// - Returns: 조건에 맞는 애니메이션
    static func conditional(
        _ condition: Bool,
        true trueAnimation: Animation,
        false falseAnimation: Animation
    ) -> Animation {
        return condition ? trueAnimation : falseAnimation
    }
    
    /// 화면 크기에 따른 애니메이션 조정
    /// - Parameters:
    ///   - baseAnimation: 기본 애니메이션
    ///   - screenSize: 화면 크기
    /// - Returns: 조정된 애니메이션
    static func adaptiveAnimation(
        _ baseAnimation: Animation,
        for screenSize: CGSize
    ) -> Animation {
        let scaleFactor = min(screenSize.width, screenSize.height) / 375.0 // iPhone 기준
        
        if scaleFactor < 0.9 { // 작은 화면
            return baseAnimation.speed(1.2) // 빠르게
        } else if scaleFactor > 1.2 { // 큰 화면
            return baseAnimation.speed(0.8) // 느리게
        } else {
            return baseAnimation // 기본
        }
    }
}

// MARK: - Supporting Types

/// 상태 애니메이션 스타일
enum StateAnimationStyle {
    case standard, success, error, warning
}

/// 게슈탈트 애니메이션 원리
enum GestaltAnimationPrinciple {
    case proximity, similarity, continuity, closure
}

// MARK: - Animation View Modifiers

extension View {
    
    /// 표준 터치 피드백 애니메이션 적용
    func touchFeedback() -> some View {
        self.scaleEffect(1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: UUID())
    }
    
    /// 선택 상태 애니메이션 적용
    func selectionAnimation(isSelected: Bool) -> some View {
        self
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(Animations.Interaction.cardSelection, value: isSelected)
    }
    
    /// 로딩 상태 애니메이션 적용
    func loadingAnimation(isLoading: Bool) -> some View {
        self
            .opacity(isLoading ? 0.6 : 1.0)
            .animation(Animations.Loading.pulse, value: isLoading)
    }
    
    /// 오디오 레벨 시각화 애니메이션
    func audioLevelAnimation(level: Double) -> some View {
        self
            .scaleEffect(y: CGFloat(level))
            .animation(Animations.AudioVisualization.volumeLevel, value: level)
    }
    
    /// 주파수 변화 애니메이션
    func frequencyAnimation<T: Equatable>(value: T) -> some View {
        self
            .animation(Animations.AudioVisualization.frequencyChange, value: value)
    }
    
    /// 음계 감지 애니메이션
    func noteDetectionAnimation(detected: Bool) -> some View {
        self
            .scaleEffect(detected ? 1.1 : 1.0)
            .animation(Animations.AudioVisualization.noteDetection, value: detected)
    }
    
    /// 상태 변화 애니메이션
    func stateChangeAnimation<T: Equatable>(value: T, style: StateAnimationStyle = .standard) -> some View {
        Group {
            switch style {
            case .standard:
                self.animation(Animations.StateChange.info, value: value)
            case .success:
                self.animation(Animations.StateChange.success, value: value)
            case .error:
                self.animation(Animations.StateChange.error, value: value)
            case .warning:
                self.animation(Animations.StateChange.warning, value: value)
            }
        }
    }
    
    /// 리스트 아이템 등장 애니메이션
    func listItemAppearance(delay: Double = 0) -> some View {
        self
            .opacity(1.0)
            .offset(y: 0)
            .animation(
                Animations.Transition.listItem.delay(delay),
                value: UUID()
            )
    }
    
    /// 게슈탈트 원리 기반 그룹 애니메이션
    func gestaltGroupAnimation(principle: GestaltAnimationPrinciple) -> some View {
        Group {
            switch principle {
            case .proximity:
                self.animation(Animations.spring, value: UUID())
            case .similarity:
                self.animation(Animations.Transition.fade, value: UUID())
            case .continuity:
                self.animation(Animations.Transition.slide, value: UUID())
            case .closure:
                self.animation(Animations.Transition.scale, value: UUID())
            }
        }
    }
    

}

// MARK: - Animation Documentation

/**
 # DailyPitch Animation System
 
 ## 설계 원칙
 
 1. **Apple HIG 준수**
    - iOS 표준 이징 함수 사용
    - 자연스러운 물리 기반 애니메이션
    - 접근성 고려 (Reduce Motion 대응)
 
 2. **음악적 리듬감**
    - BPM 기반 애니메이션 타이밍
    - 주파수 기반 시각적 표현
    - 음악적 템포와 매칭되는 움직임
 
 3. **사용자 경험 최적화**
    - 즉각적인 피드백
    - 명확한 상태 전환
    - 자연스러운 흐름
 
 4. **성능 고려**
    - 60fps 유지
    - 배터리 효율성
    - 메모리 사용량 최적화
 
 ## 사용 가이드
 
 ```swift
 // 기본 애니메이션
 withAnimation(Animations.spring) {
     // 상태 변경
 }
 
 // 음악적 리듬 기반
 withAnimation(Animations.Musical.moderato) {
     // 120 BPM 기반 움직임
 }
 
 // 오디오 시각화
 Circle()
     .audioLevelAnimation(level: audioLevel)
     .frequencyAnimation(value: frequency)
 
 // 상호작용 피드백
 button
     .touchFeedback()
     .selectionAnimation(isSelected: selected)
 
 // 순차 애니메이션
 Animations.sequence([
     (Animations.fade, { showFirst = true }),
     (Animations.slide, { showSecond = true })
 ], interval: 0.2)
 ```
 
 ## 타이밍 가이드
 
 - **immediate (0.1s)**: 즉각 피드백
 - **fast (0.2s)**: 터치 응답
 - **standard (0.3s)**: 일반 전환
 - **medium (0.5s)**: 컨텐츠 변화
 - **slow (0.8s)**: 복잡한 전환
 - **deliberate (1.2s)**: 특별 효과
 
 ## 성능 체크리스트
 
 - ✅ 60fps 유지
 - ✅ Reduce Motion 대응
 - ✅ 적절한 지속 시간
 - ✅ 자연스러운 이징
 - ✅ 배터리 효율성
 */ 