//
//  NativeComponents.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI

// MARK: - Native iOS Components

/// Apple HIG를 완전히 준수하는 네이티브 iOS 컴포넌트들
/// iOS 표준 패턴과 인터랙션을 제공

// MARK: - Native Navigation Components

/// iOS 표준 네비게이션 바 스타일
struct NativeNavigationBar<Content: View>: View {
    let title: String
    let displayMode: NavigationBarItem.TitleDisplayMode
    let content: () -> Content
    
    init(
        title: String,
        displayMode: NavigationBarItem.TitleDisplayMode = .large,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.displayMode = displayMode
        self.content = content
    }
    
    var body: some View {
        NavigationView {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(displayMode)
                .background(Color.adaptiveBackground)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

/// iOS 표준 탭 바 스타일
struct NativeTabView<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        TabView {
            content()
        }
        .accentColor(Color.accent)
        .background(Color.adaptiveBackground)
    }
}

// MARK: - Native List Components

/// iOS 표준 리스트 스타일
struct NativeList<Content: View>: View {
    let content: () -> Content
    let style: UITableView.Style
    
    init(
        style: UITableView.Style = .insetGrouped,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.style = style
    }
    
    var body: some View {
        Group {
            if style == .insetGrouped {
                List {
                    content()
                }
                .listStyle(.insetGrouped)
                .background(Color.adaptiveBackground)
            } else {
                List {
                    content()
                }
                .listStyle(.plain)
                .background(Color.adaptiveBackground)
            }
        }
    }
}

/// iOS 표준 리스트 행
struct NativeListRow<Content: View>: View {
    let content: () -> Content
    let accessoryType: UITableViewCell.AccessoryType
    let onTap: (() -> Void)?
    
    init(
        accessoryType: UITableViewCell.AccessoryType = .none,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.accessoryType = accessoryType
        self.onTap = onTap
    }
    
    var body: some View {
        HStack {
            content()
            
            Spacer()
            
            if accessoryType == .disclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.textTertiary)
            } else if accessoryType == .checkmark {
                Image(systemName: "checkmark")
                    .font(.subheadline)
                    .foregroundColor(Color.accent)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Native Form Components

/// iOS 표준 폼 스타일
struct NativeForm<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        Form {
            content()
        }
        .background(Color.adaptiveBackground)
    }
}

/// iOS 표준 섹션 헤더
struct NativeSectionHeader: View {
    let title: String
    let subtitle: String?
    
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(title)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

/// iOS 표준 섹션 푸터
struct NativeSectionFooter: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}

// MARK: - Native Input Components

/// iOS 표준 텍스트 필드
struct NativeTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let autocapitalization: TextInputAutocapitalization
    
    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(Color.textPrimary)
                
                Spacer()
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(Color.textSecondary)
            }
        }
    }
}

/// iOS 표준 토글
struct NativeToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(title)
                    .font(.body)
                    .foregroundColor(Color.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

/// iOS 표준 스테퍼
struct NativeStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    
    init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        format: String = "%.0f"
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(Color.textPrimary)
            
            Spacer()
            
            Stepper(
                value: $value,
                in: range,
                step: step
            ) {
                Text(String(format: format, value))
                    .font(.body)
                    .foregroundColor(Color.textSecondary)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Native Button Components

/// iOS 표준 액션 시트 버튼
struct NativeActionButton: View {
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let action: () -> Void
    
    init(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }
    
    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: AppSpacing.small) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.body)
                        .foregroundColor(buttonColor)
                }
                
                Text(title)
                    .font(.body)
                    .foregroundColor(buttonColor)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var buttonColor: Color {
        switch role {
        case .destructive:
            return Color.dpError
        case .cancel:
            return Color.interactive
        default:
            return Color.interactive
        }
    }
}

/// iOS 표준 프롬프트 버튼
struct NativePromptButton: View {
    let title: String
    let style: UIAlertAction.Style
    let action: () -> Void
    
    init(
        _ title: String,
        style: UIAlertAction.Style = .default,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(style == .cancel ? .regular : .semibold)
                .foregroundColor(buttonColor)
        }
    }
    
    private var buttonColor: Color {
        switch style {
        case .destructive:
            return Color.dpError
        case .cancel:
            return Color.textSecondary
        default:
            return Color.interactive
        }
    }
}

// MARK: - Native Card Components

/// iOS 표준 카드 스타일
struct NativeCard<Content: View>: View {
    let content: () -> Content
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 2,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    var body: some View {
        content()
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.adaptiveShadow, radius: shadowRadius, x: 0, y: 1)
    }
}

/// iOS 표준 정보 카드
struct NativeInfoCard: View {
    let title: String
    let message: String
    let systemImage: String
    let backgroundColor: Color
    let foregroundColor: Color
    
    init(
        title: String,
        message: String,
        systemImage: String,
        style: InfoCardStyle = .info
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        
        switch style {
        case .info:
            self.backgroundColor = Color.interactive.opacity(0.1)
            self.foregroundColor = Color.interactive
        case .warning:
            self.backgroundColor = Color.dpWarning.opacity(0.1)
            self.foregroundColor = Color.dpWarning
        case .error:
            self.backgroundColor = Color.dpError.opacity(0.1)
            self.foregroundColor = Color.dpError
        case .success:
            self.backgroundColor = Color.dpSuccess.opacity(0.1)
            self.foregroundColor = Color.dpSuccess
        }
    }
    
    enum InfoCardStyle {
        case info, warning, error, success
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(foregroundColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.textPrimary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(AppSpacing.medium)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Native Progress Components

/// iOS 표준 프로그레스 뷰
struct NativeProgressView: View {
    let title: String?
    let value: Double?
    let total: Double
    
    init(_ title: String? = nil, value: Double? = nil, total: Double = 1.0) {
        self.title = title
        self.value = value
        self.total = total
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            
            if let value = value {
                ProgressView(value: value, total: total)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.accent))
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))
            }
        }
    }
}

/// iOS 표준 액티비티 인디케이터
struct NativeActivityIndicator: View {
    let isAnimating: Bool
    let style: UIActivityIndicatorView.Style
    
    init(isAnimating: Bool = true, style: UIActivityIndicatorView.Style = .medium) {
        self.isAnimating = isAnimating
        self.style = style
    }
    
    var body: some View {
        if isAnimating {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.accent))
                .scaleEffect(style == .large ? 1.5 : 1.0)
        }
    }
}

// MARK: - Native Gesture Components

/// iOS 표준 제스처 핸들러
struct NativeGestureHandler<Content: View>: View {
    let content: () -> Content
    let onTap: (() -> Void)?
    let onLongPress: (() -> Void)?
    let onSwipeLeft: (() -> Void)?
    let onSwipeRight: (() -> Void)?
    
    init(
        onTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        onSwipeLeft: (() -> Void)? = nil,
        onSwipeRight: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
    }
    
    var body: some View {
        content()
            .contentShape(Rectangle())
            .onTapGesture {
                withHapticFeedback(.light) {
                    onTap?()
                }
            }
            .onLongPressGesture {
                withHapticFeedback(.medium) {
                    onLongPress?()
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 100 {
                            withHapticFeedback(.light) {
                                onSwipeRight?()
                            }
                        } else if value.translation.width < -100 {
                            withHapticFeedback(.light) {
                                onSwipeLeft?()
                            }
                        }
                    }
            )
    }
}

// MARK: - Native Accessibility Components

/// iOS 접근성 최적화 컨테이너
struct NativeAccessibilityContainer<Content: View>: View {
    let content: () -> Content
    let label: String?
    let hint: String?
    let value: String?
    let traits: AccessibilityTraits
    
    init(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.label = label
        self.hint = hint
        self.value = value
        self.traits = traits
    }
    
    var body: some View {
        content()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
}

// MARK: - Helper Extensions

extension View {
    /// 햅틱 피드백과 함께 액션 실행
    func withHapticFeedback<T>(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        action: () -> T
    ) -> T {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        return action()
    }
    
    /// iOS 표준 카드 스타일 적용
    func nativeCardStyle(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 2
    ) -> some View {
        self
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.adaptiveShadow, radius: shadowRadius, x: 0, y: 1)
    }
    
    /// iOS 표준 리스트 행 스타일 적용
    func nativeListRowStyle() -> some View {
        self
            .padding(.vertical, AppSpacing.small)
            .padding(.horizontal, AppSpacing.medium)
            .background(Color.cardBackground)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
} 