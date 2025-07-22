//
//  ErrorRecoveryView.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI
import UIKit

/// Jakob 휴리스틱 9번 "Help Users Recognize, Diagnose, and Recover from Errors"를 구현하는 에러 복구 UI

// MARK: - Enhanced Error Recovery View

struct ErrorRecoveryView: View {
    @ObservedObject var errorManager: ErrorRecoveryManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accessibilityManager = AccessibilityManager()
    
    var body: some View {
        if let error = errorManager.currentError {
            errorContent(for: error)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        }
    }
    
    private func errorContent(for error: UserFriendlyError) -> some View {
        ZStack {
            // 배경 딤 효과
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    errorManager.resolveError()
                }
            
            // 에러 카드
            VStack(spacing: 0) {
                errorCard(for: error)
            }
            .background(Color.dpSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, AppSpacing.large)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
    
    private func errorCard(for error: UserFriendlyError) -> some View {
        VStack(spacing: AppSpacing.medium) {
            // 헤더 섹션
            errorHeader(for: error)
            
            // 진단 섹션
            diagnosisSection(for: error)
            
            // 복구 액션 섹션
            if !error.recoveryActions.isEmpty {
                recoveryActionsSection(for: error)
            }
            
            // 하단 버튼 섹션
            bottomButtonSection
        }
        .padding(AppSpacing.large)
    }
    
    // MARK: - Header Section (인식 - Recognition)
    
    private func errorHeader(for error: UserFriendlyError) -> some View {
        VStack(spacing: AppSpacing.small) {
            // 에러 아이콘
            ZStack {
                Circle()
                    .fill(severityColor(error.severity).opacity(0.1))
                    .frame(width: 60, height: 60)
                
                AccessibleImage(
                    systemName: error.severity.systemImage,
                    size: 28,
                    color: severityColor(error.severity),
                    label: severityAccessibilityLabel(error.severity)
                )
            }
            .accessibilityElement(children: .combine)
            
            // 에러 제목
            AccessibleText(
                error.title,
                style: .title2,
                weight: .semibold
            )
            .foregroundColor(Color.dpTextPrimary)
            .multilineTextAlignment(.center)
            .accessibilityHeading(.h1)
            
            // 에러 메시지
            AccessibleText(
                error.message,
                style: .body
            )
            .foregroundColor(Color.dpTextSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Diagnosis Section (진단 - Diagnosis)
    
    private func diagnosisSection(for error: UserFriendlyError) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                AccessibleImage(
                    systemName: "stethoscope",
                    size: 16,
                    color: Color.dpTextSecondary,
                    label: "진단"
                )
                
                AccessibleText(
                    "원인 분석",
                    style: .headline,
                    weight: .medium
                )
                .foregroundColor(Color.dpTextPrimary)
                
                Spacer()
            }
            
            AccessibleText(
                error.diagnosis,
                style: .callout
            )
            .foregroundColor(Color.dpTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.medium)
        .background(Color.dpBackgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("원인 분석: \(error.diagnosis)")
    }
    
    // MARK: - Recovery Actions Section (복구 - Recovery)
    
    private func recoveryActionsSection(for error: UserFriendlyError) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                AccessibleImage(
                    systemName: "wrench.and.screwdriver",
                    size: 16,
                    color: Color.dpTextSecondary,
                    label: "해결책"
                )
                
                AccessibleText(
                    "해결 방법",
                    style: .headline,
                    weight: .medium
                )
                .foregroundColor(Color.dpTextPrimary)
                
                Spacer()
            }
            
            LazyVStack(spacing: AppSpacing.small) {
                ForEach(error.recoveryActions.sorted(by: { $0.priority > $1.priority }), id: \.id) { action in
                    recoveryActionButton(action)
                }
            }
        }
    }
    
    private func recoveryActionButton(_ action: RecoveryAction) -> some View {
        Button(action: {
            performRecoveryAction(action)
        }) {
            HStack(spacing: AppSpacing.small) {
                // 아이콘
                AccessibleImage(
                    systemName: action.systemImage,
                    size: 20,
                    color: actionTypeColor(action.type),
                    label: action.title,
                    decorative: true
                )
                
                // 텍스트 정보
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    AccessibleText(
                        action.title,
                        style: .body,
                        weight: .medium
                    )
                    .foregroundColor(Color.dpTextPrimary)
                    
                    AccessibleText(
                        action.description,
                        style: .caption
                    )
                    .foregroundColor(Color.dpTextSecondary)
                }
                
                Spacer()
                
                // 우선순위 배지 (고우선순위만 표시)
                if action.priority >= 8 {
                    Text("권장")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(actionTypeColor(action.type).opacity(0.1))
                        .foregroundColor(actionTypeColor(action.type))
                        .clipShape(Capsule())
                }
                
                // 외부 링크 표시
                if action.destination != .inApp {
                    AccessibleImage(
                        systemName: "arrow.up.right.square",
                        size: 14,
                        color: Color.dpTextSecondary,
                        label: "외부 링크"
                    )
                }
            }
            .padding(AppSpacing.medium)
            .background(Color.dpBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(actionTypeColor(action.type).opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(InteractiveButtonStyle())
        .accessibilityLabel("\(action.title): \(action.description)")
        .accessibilityHint(accessibilityHint(for: action))
    }
    
    // MARK: - Bottom Section
    
    private var bottomButtonSection: some View {
        HStack(spacing: AppSpacing.medium) {
            // 취소/닫기 버튼
            Button("닫기") {
                errorManager.resolveError()
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityLabel("에러 창 닫기")
            .accessibilityHint("에러 정보를 닫고 이전 화면으로 돌아갑니다")
            
            // 자동 복구 진행 중일 때 표시
            if errorManager.autoRecoveryInProgress {
                HStack(spacing: AppSpacing.xsmall) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    AccessibleText(
                        "자동 복구 중...",
                        style: .caption,
                        weight: .medium
                    )
                    .foregroundColor(Color.dpTextSecondary)
                }
                .accessibilityLabel("자동 복구가 진행 중입니다")
            }
            
            Spacer()
            
            // 에러 기록 보기 버튼 (고급 사용자용)
            if !errorManager.errorHistory.isEmpty {
                Button("기록") {
                    // 에러 기록 화면 표시
                }
                .buttonStyle(TertiaryActionButtonStyle())
                .accessibilityLabel("에러 기록 보기")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performRecoveryAction(_ action: RecoveryAction) {
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 액션 실행
        action.action()
        
        // 접근성 안내
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(action.title) 실행됨"
        )
        
        // 특정 액션들은 자동으로 에러 해결 처리
        if action.type == .retry || action.type == .alternative {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                errorManager.resolveError()
            }
        }
    }
    
    private func severityColor(_ severity: ErrorSeverity) -> Color {
        switch severity {
        case .low: return Color.dpInfo
        case .medium: return Color.dpWarning
        case .high: return Color.dpError
        case .critical: return Color.purple
        }
    }
    
    private func severityAccessibilityLabel(_ severity: ErrorSeverity) -> String {
        switch severity {
        case .low: return "정보"
        case .medium: return "경고"
        case .high: return "오류"
        case .critical: return "심각한 오류"
        }
    }
    
    private func actionTypeColor(_ type: RecoveryActionType) -> Color {
        switch type {
        case .retry: return Color.dpSuccess
        case .skipStep: return Color.dpInfo
        case .alternative: return Color.dpWarning
        case .settings: return Color.dpSecondary
        case .help: return Color.dpPrimary
        case .contact: return Color.dpError
        case .reset: return Color.dpError
        }
    }
    
    private func accessibilityHint(for action: RecoveryAction) -> String {
        switch action.destination {
        case .inApp:
            return "앱 내에서 \(action.title)을 실행합니다"
        case .systemSettings:
            return "시스템 설정으로 이동하여 \(action.title)을 실행합니다"
        case .external:
            return "외부 앱에서 \(action.title)을 실행합니다"
        }
    }
}

// MARK: - Error History View

struct ErrorHistoryView: View {
    @ObservedObject var errorManager: ErrorRecoveryManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(errorManager.errorHistory, id: \.id) { error in
                    ErrorHistoryRow(error: error)
                }
                .onDelete(perform: deleteErrorHistory)
            }
            .navigationTitle("에러 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("전체 삭제") {
                        clearAllErrorHistory()
                    }
                    .disabled(errorManager.errorHistory.isEmpty)
                }
            }
        }
    }
    
    private func deleteErrorHistory(at offsets: IndexSet) {
        errorManager.errorHistory.remove(atOffsets: offsets)
    }
    
    private func clearAllErrorHistory() {
        errorManager.errorHistory.removeAll()
    }
}

struct ErrorHistoryRow: View {
    let error: UserFriendlyError
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                AccessibleImage(
                    systemName: error.severity.systemImage,
                    size: 16,
                    color: severityColor(error.severity),
                    label: severityLabel(error.severity)
                )
                
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    AccessibleText(
                        error.title,
                        style: .body,
                        weight: .medium
                    )
                    .foregroundColor(Color.dpTextPrimary)
                    
                    AccessibleText(
                        DateFormatter.relativeFormatter.localizedString(for: error.timestamp, relativeTo: Date()),
                        style: .caption
                    )
                    .foregroundColor(Color.dpTextSecondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    AccessibleImage(
                        systemName: isExpanded ? "chevron.up" : "chevron.down",
                        size: 12,
                        color: Color.dpTextSecondary,
                        label: isExpanded ? "접기" : "펼치기"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    AccessibleText(
                        error.message,
                        style: .callout
                    )
                    .foregroundColor(Color.dpTextSecondary)
                    
                    AccessibleText(
                        error.diagnosis,
                        style: .caption
                    )
                    .foregroundColor(Color.dpTextHint)
                }
                .padding(.top, AppSpacing.xsmall)
                .transition(.slide)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private func severityColor(_ severity: ErrorSeverity) -> Color {
        switch severity {
        case .low: return Color.dpInfo
        case .medium: return Color.dpWarning
        case .high: return Color.dpError
        case .critical: return Color.purple
        }
    }
    
    private func severityLabel(_ severity: ErrorSeverity) -> String {
        switch severity {
        case .low: return "정보"
        case .medium: return "경고"
        case .high: return "오류"
        case .critical: return "심각한 오류"
        }
    }
}

// MARK: - Error Toast View (가벼운 에러 표시용)

struct ErrorToastView: View {
    let error: UserFriendlyError
    @Binding var isShowing: Bool
    
    var body: some View {
        if isShowing {
            HStack(spacing: AppSpacing.small) {
                AccessibleImage(
                    systemName: error.severity.systemImage,
                    size: 16,
                    color: severityColor(error.severity),
                    label: severityLabel(error.severity)
                )
                
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    AccessibleText(
                        error.title,
                        style: .body,
                        weight: .medium
                    )
                    .foregroundColor(Color.dpTextPrimary)
                    
                    if error.severity == .low {
                        AccessibleText(
                            error.message,
                            style: .caption
                        )
                        .foregroundColor(Color.dpTextSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: { isShowing = false }) {
                    AccessibleImage(
                        systemName: "xmark",
                        size: 12,
                        color: Color.dpTextSecondary,
                        label: "닫기"
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(AppSpacing.medium)
            .background(Color.dpSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal, AppSpacing.medium)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onAppear {
                // 가벼운 에러는 3초 후 자동 사라짐
                if error.severity == .low {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        isShowing = false
                    }
                }
                
                // 접근성 안내
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "\(severityLabel(error.severity)): \(error.title)"
                )
            }
        }
    }
    
    private func severityColor(_ severity: ErrorSeverity) -> Color {
        switch severity {
        case .low: return Color.dpInfo
        case .medium: return Color.dpWarning
        case .high: return Color.dpError
        case .critical: return Color.purple
        }
    }
    
    private func severityLabel(_ severity: ErrorSeverity) -> String {
        switch severity {
        case .low: return "정보"
        case .medium: return "경고"
        case .high: return "오류"
        case .critical: return "심각한 오류"
        }
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
}