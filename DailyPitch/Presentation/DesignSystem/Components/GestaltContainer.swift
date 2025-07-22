//
//  GestaltContainer.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI

// MARK: - Gestalt Container

/// Gestalt 원칙을 적용한 컨테이너 컴포넌트
/// 근접성, 유사성, 연속성, 폐쇄성 원칙을 시각적으로 구현
struct GestaltContainer<Content: View>: View {
    let principle: GestaltPrinciple
    let spacing: GestaltSpacing
    let content: () -> Content
    
    init(
        principle: GestaltPrinciple,
        spacing: GestaltSpacing = .related,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.principle = principle
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        switch principle {
        case .proximity:
            proximityContainer
        case .similarity:
            similarityContainer
        case .continuity:
            continuityContainer
        case .closure:
            closureContainer
        }
    }
    
    // MARK: - Proximity Container (근접성)
    
    private var proximityContainer: some View {
        VStack(spacing: spacing.value) {
            content()
        }
    }
    
    // MARK: - Similarity Container (유사성)
    
    private var similarityContainer: some View {
        content()
            .padding(spacing.value)
    }
    
    // MARK: - Continuity Container (연속성)
    
    private var continuityContainer: some View {
        ScrollView {
            LazyVStack(spacing: spacing.value) {
                content()
            }
            .padding(.horizontal, AppSpacing.medium)
        }
    }
    
    // MARK: - Closure Container (폐쇄성)
    
    private var closureContainer: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
                    .shadow(color: Color.adaptiveShadow, radius: 8, x: 0, y: 4)
            )
    }
}

// MARK: - Gestalt Principle

/// Gestalt 원칙 유형
enum GestaltPrinciple {
    case proximity    // 근접성: 가까운 요소들이 하나의 그룹으로 인식됨
    case similarity   // 유사성: 비슷한 요소들이 하나의 그룹으로 인식됨
    case continuity   // 연속성: 연속적인 선이나 패턴이 하나로 인식됨
    case closure      // 폐쇄성: 완결되지 않은 형태도 완전한 형태로 인식됨
}

// MARK: - Gestalt Spacing

/// Gestalt 원칙에 따른 간격 정의
enum GestaltSpacing {
    case intimate     // 매우 가까운 관련성
    case close        // 가까운 관련성
    case related      // 관련된 요소들
    case loose        // 느슨한 관련성
    case separated    // 분리된 요소들
    
    var value: CGFloat {
        switch self {
        case .intimate: return AppSpacing.xsmall
        case .close: return AppSpacing.small
        case .related: return AppSpacing.medium
        case .loose: return AppSpacing.large
        case .separated: return AppSpacing.xlarge
        }
    }
}

// MARK: - Gestalt Grid

/// Gestalt 원칙을 적용한 그리드 컨테이너
struct GestaltGrid<Content: View>: View {
    let principle: GestaltPrinciple
    let columns: Int
    let spacing: GestaltSpacing
    let content: () -> Content
    
    init(
        principle: GestaltPrinciple,
        columns: Int = 3,
        spacing: GestaltSpacing = .related,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.principle = principle
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing.value), count: columns),
            spacing: spacing.value
        ) {
            content()
        }
        .modifier(GestaltGridModifier(principle: principle))
    }
}

// MARK: - Gestalt Grid Modifier

struct GestaltGridModifier: ViewModifier {
    let principle: GestaltPrinciple
    
    func body(content: Content) -> some View {
        switch principle {
        case .proximity:
            content
                .padding(AppSpacing.small)
        case .similarity:
            content
                .padding(AppSpacing.medium)
        case .continuity:
            content
                .padding(.horizontal, AppSpacing.medium)
        case .closure:
            content
                .padding(AppSpacing.large)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cardBackground.opacity(0.5))
                )
        }
    }
}

// MARK: - Gestalt Card

/// Gestalt 원칙을 적용한 카드 컴포넌트
struct GestaltCard<Content: View>: View {
    let principle: GestaltPrinciple
    let isSelected: Bool
    let themeColor: Color?
    let content: () -> Content
    
    init(
        principle: GestaltPrinciple = .closure,
        isSelected: Bool = false,
        themeColor: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.principle = principle
        self.isSelected = isSelected
        self.themeColor = themeColor
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(AppSpacing.medium)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(cardOverlay)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(Animations.Musical.pitchTransition(semitones: 1), value: isSelected)
    }
    
    private var cardBackground: Color {
        if isSelected, let themeColor = themeColor {
            return themeColor
        }
        return Color.cardBackground
    }
    
    private var cardOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                isSelected ? Color.clear : Color.cardBorder,
                lineWidth: 1
            )
    }
    
    private var shadowColor: Color {
        if isSelected, let themeColor = themeColor {
            return themeColor.opacity(0.3)
        }
        return Color.adaptiveShadow
    }
    
    private var shadowRadius: CGFloat {
        return isSelected ? 8 : 2
    }
    
    private var shadowY: CGFloat {
        return isSelected ? 4 : 1
    }
}

// MARK: - Gestalt Flow Layout

/// Gestalt 연속성 원칙을 적용한 플로우 레이아웃
struct GestaltFlowLayout<Content: View>: View {
    let spacing: GestaltSpacing
    let alignment: HorizontalAlignment
    let content: () -> Content
    
    init(
        spacing: GestaltSpacing = .related,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: spacing.value) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .init(horizontal: alignment, vertical: .center))
    }
}

// MARK: - Gestalt Separator

/// Gestalt 원칙을 적용한 구분선
struct GestaltSeparator: View {
    let style: SeparatorStyle
    
    enum SeparatorStyle {
        case subtle     // 미묘한 구분
        case clear      // 명확한 구분
        case emphasized // 강조된 구분
    }
    
    var body: some View {
        Rectangle()
            .fill(separatorColor)
            .frame(height: separatorHeight)
            .padding(.horizontal, horizontalPadding)
    }
    
    private var separatorColor: Color {
        switch style {
        case .subtle: return Color.cardBorder.opacity(0.3)
        case .clear: return Color.cardBorder
        case .emphasized: return Color.textTertiary
        }
    }
    
    private var separatorHeight: CGFloat {
        switch style {
        case .subtle: return 0.5
        case .clear: return 1
        case .emphasized: return 2
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .subtle: return AppSpacing.large
        case .clear: return AppSpacing.medium
        case .emphasized: return AppSpacing.small
        }
    }
} 