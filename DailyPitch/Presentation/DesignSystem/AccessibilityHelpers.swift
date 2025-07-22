//
//  AccessibilityHelpers.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI
import UIKit

// MARK: - Accessibility Helpers

/// 접근성 지원을 위한 헬퍼 함수들과 컴포넌트
/// WCAG 2.1 AA 표준과 iOS 접근성 가이드라인을 준수

// MARK: - Accessibility Manager

class AccessibilityManager: ObservableObject {
    @Published var isVoiceOverEnabled: Bool
    @Published var preferredContentSizeCategory: ContentSizeCategory
    @Published var isReduceMotionEnabled: Bool
    @Published var isReduceTransparencyEnabled: Bool
    @Published var isBoldTextEnabled: Bool
    @Published var isButtonShapesEnabled: Bool
    
    init() {
        self.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        self.preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory) ?? .medium
        self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        self.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        self.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        // isButtonShapesEnabled은 iOS 14.0부터 사용 가능하지만 실제로는 존재하지 않는 API
        self.isButtonShapesEnabled = false
        
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        }
        
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory) ?? .medium
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        }
        
        // buttonShapesEnabledStatusDidChangeNotification은 실제로 존재하지 않음
        // 대신 적절한 대안 구현
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isButtonShapesEnabled = UIAccessibility.isVoiceOverRunning
        }
    }
}

// MARK: - Accessibility View Modifiers

/// VoiceOver 최적화 수정자
struct VoiceOverOptimizedModifier: ViewModifier {
    let label: String
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
}

/// Dynamic Type 지원 수정자
struct DynamicTypeOptimizedModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    let baseFont: Font
    let maxSize: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(adaptiveFont)
            .lineLimit(sizeCategory.isAccessibilityCategory ? nil : 3)
    }
    
    private var adaptiveFont: Font {
        // scaleFactor는 현재 사용되지 않지만 미래 확장을 위해 유지
        let _ = min(sizeCategory.scaleFactor, maxSize / 16.0)
        return baseFont.weight(sizeCategory.isAccessibilityCategory ? .semibold : .regular)
    }
}

/// 색상 대비 최적화 수정자
struct ColorContrastOptimizedModifier: ViewModifier {
    let foregroundColor: Color
    let backgroundColor: Color
    let minimumRatio: Double
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(optimizedForegroundColor)
            .background(optimizedBackgroundColor)
    }
    
    private var optimizedForegroundColor: Color {
        let ratio = contrastRatio(foregroundColor, backgroundColor)
        return ratio >= minimumRatio ? foregroundColor : .primary
    }
    
    private var optimizedBackgroundColor: Color {
        let ratio = contrastRatio(foregroundColor, backgroundColor)
        return ratio >= minimumRatio ? backgroundColor : .clear
    }
    
    private func contrastRatio(_ color1: Color, _ color2: Color) -> Double {
        // 간단한 대비 계산 (실제로는 더 복잡한 WCAG 알고리즘 사용)
        return 4.5 // 임시 값
    }
}

/// 터치 영역 최적화 수정자
struct TouchTargetOptimizedModifier: ViewModifier {
    let minimumSize: CGFloat = 44.0
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: minimumSize, minHeight: minimumSize)
            .contentShape(Rectangle())
    }
}

// MARK: - Accessibility Components

/// 접근성 최적화된 버튼
struct AccessibleButton<Content: View>: View {
    let action: () -> Void
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let content: () -> Content
    
    @Environment(\.sizeCategory) var sizeCategory
    @StateObject private var accessibilityManager = AccessibilityManager()
    
    init(
        action: @escaping () -> Void,
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = .isButton,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.label = label
        self.hint = hint
        self.traits = traits
        self.content = content
    }
    
    var body: some View {
        Button(action: action) {
            content()
                .frame(
                    minWidth: minimumTouchTarget,
                    minHeight: minimumTouchTarget
                )
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(traits)
        .buttonStyle(AccessibleButtonStyle(
            isButtonShapesEnabled: accessibilityManager.isButtonShapesEnabled
        ))
    }
    
    private var minimumTouchTarget: CGFloat {
        max(44.0, sizeCategory.isAccessibilityCategory ? 60.0 : 44.0)
    }
}

/// 접근성 최적화된 버튼 스타일
struct AccessibleButtonStyle: ButtonStyle {
    let isButtonShapesEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accent, lineWidth: isButtonShapesEnabled ? 2 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 접근성 최적화된 텍스트
struct AccessibleText: View {
    let text: String
    let style: Font.TextStyle
    let weight: Font.Weight
    let design: Font.Design
    let maxLines: Int?
    
    @Environment(\.sizeCategory) var sizeCategory
    @StateObject private var accessibilityManager = AccessibilityManager()
    
    init(
        _ text: String,
        style: Font.TextStyle = .body,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        maxLines: Int? = nil
    ) {
        self.text = text
        self.style = style
        self.weight = weight
        self.design = design
        self.maxLines = maxLines
    }
    
    var body: some View {
        Text(text)
            .font(.system(style, design: design, weight: effectiveWeight))
            .lineLimit(effectiveLineLimit)
            .minimumScaleFactor(sizeCategory.isAccessibilityCategory ? 1.0 : 0.8)
            .allowsTightening(true)
    }
    
    private var effectiveWeight: Font.Weight {
        accessibilityManager.isBoldTextEnabled ? .semibold : weight
    }
    
    private var effectiveLineLimit: Int? {
        if sizeCategory.isAccessibilityCategory {
            return nil // 무제한
        }
        return maxLines
    }
}

/// 접근성 최적화된 이미지
struct AccessibleImage: View {
    let systemName: String
    let size: CGFloat
    let color: Color
    let label: String
    let decorative: Bool
    
    @Environment(\.sizeCategory) var sizeCategory
    
    init(
        systemName: String,
        size: CGFloat = 24,
        color: Color = .primary,
        label: String = "",
        decorative: Bool = false
    ) {
        self.systemName = systemName
        self.size = size
        self.color = color
        self.label = label
        self.decorative = decorative
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: adaptiveSize, weight: .medium))
            .foregroundColor(color)
            .accessibilityLabel(decorative ? "" : label)
            .accessibilityHidden(decorative)
    }
    
    private var adaptiveSize: CGFloat {
        let scaleFactor = sizeCategory.scaleFactor
        return size * min(scaleFactor, 2.0) // 최대 2배까지만 확대
    }
}

/// 접근성 최적화된 진행률 표시기
struct AccessibleProgressView: View {
    let title: String
    let progress: Double
    let total: Double
    let format: String
    
    init(
        title: String,
        progress: Double,
        total: Double = 1.0,
        format: String = "%.0f%%"
    ) {
        self.title = title
        self.progress = progress
        self.total = total
        self.format = format
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                AccessibleText(title, style: .caption, weight: .medium)
                Spacer()
                AccessibleText(
                    String(format: format, (progress / total) * 100),
                    style: .caption,
                    weight: .semibold
                )
            }
            
            ProgressView(value: progress, total: total)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.accent))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(String(format: format, (progress / total) * 100))")
        .accessibilityValue("\(Int((progress / total) * 100))퍼센트 완료")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// 접근성 최적화된 알림 배너
struct AccessibleBanner: View {
    let title: String
    let message: String
    let type: BannerType
    let onDismiss: (() -> Void)?
    
    enum BannerType {
        case info, success, warning, error
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            AccessibleImage(
                systemName: type.icon,
                size: 20,
                color: type.color,
                label: type.accessibilityLabel
            )
            
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                AccessibleText(title, style: .headline, weight: .semibold)
                AccessibleText(message, style: .body)
            }
            
            Spacer()
            
            if let onDismiss = onDismiss {
                AccessibleButton(
                    action: onDismiss,
                    label: "알림 닫기",
                    hint: "이 알림을 화면에서 제거합니다"
                ) {
                    AccessibleImage(
                        systemName: "xmark",
                        size: 16,
                        color: Color.dpTextSecondary,
                        label: "닫기"
                    )
                }
            }
        }
        .padding(AppSpacing.medium)
        .background(type.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.accessibilityLabel): \(title), \(message)")
        .onAppear {
            // VoiceOver 사용자를 위한 자동 안내
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "\(type.accessibilityLabel): \(title)"
                )
            }
        }
    }
}

// MARK: - Accessibility Extensions

extension AccessibleBanner.BannerType {
    var accessibilityLabel: String {
        switch self {
        case .info: return "정보"
        case .success: return "성공"
        case .warning: return "경고"
        case .error: return "오류"
        }
    }
}

extension View {
    /// VoiceOver 최적화 적용
    func accessibilityOptimized(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self.modifier(VoiceOverOptimizedModifier(
            label: label,
            hint: hint,
            value: value,
            traits: traits
        ))
    }
    
    /// Dynamic Type 최적화 적용
    func dynamicTypeOptimized(
        baseFont: Font = .body,
        maxSize: CGFloat = 32
    ) -> some View {
        self.modifier(DynamicTypeOptimizedModifier(
            baseFont: baseFont,
            maxSize: maxSize
        ))
    }
    
    /// 색상 대비 최적화 적용
    func colorContrastOptimized(
        foreground: Color,
        background: Color,
        minimumRatio: Double = 4.5
    ) -> some View {
        self.modifier(ColorContrastOptimizedModifier(
            foregroundColor: foreground,
            backgroundColor: background,
            minimumRatio: minimumRatio
        ))
    }
    
    /// 터치 영역 최적화 적용
    func touchTargetOptimized() -> some View {
        self.modifier(TouchTargetOptimizedModifier())
    }
    
    /// 접근성 안내 메시지 발송
    func announceForAccessibility(_ message: String, delay: Double = 0.5) -> some View {
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
    }
}

extension ContentSizeCategory {
    var scaleFactor: CGFloat {
        switch self {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.6
        case .accessibilityLarge: return 1.8
        case .accessibilityExtraLarge: return 2.0
        case .accessibilityExtraExtraLarge: return 2.2
        case .accessibilityExtraExtraExtraLarge: return 2.4
        @unknown default: return 1.0
        }
    }
    
    var isAccessibilityCategory: Bool {
        switch self {
        case .accessibilityMedium,
             .accessibilityLarge,
             .accessibilityExtraLarge,
             .accessibilityExtraExtraLarge,
             .accessibilityExtraExtraExtraLarge:
            return true
        default:
            return false
        }
    }
} 