//
//  SessionInfoSection.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI

/// 세션 정보 표시 섹션
/// iOS 네이티브 컴포넌트와 접근성 최적화를 완전히 적용한 세션 정보 인터페이스
struct SessionInfoSection: View {
    
    // MARK: - Properties
    let audioSession: AudioSession
    let analysisResult: TimeBasedAnalysisResult?
    @StateObject private var accessibilityManager = AccessibilityManager()
    @State private var showingDetailedInfo = false
    @State private var showingTechnicalSpecs = false
    
    // MARK: - Body
    
    var body: some View {
        NativeCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                // 섹션 헤더
                sectionHeader
                
                // 기본 세션 정보
                basicSessionInfo
                
                // 오디오 품질 정보
                audioQualityInfo
                
                // 분석 결과 요약 (있는 경우)
                if let result = analysisResult {
                    analysisResultSummary(result: result)
                }
                
                // 확장된 상세 정보
                if showingDetailedInfo {
                    detailedSessionInfo
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // 기술적 세부사항
                if showingTechnicalSpecs {
                    technicalSpecifications
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // 액션 버튼들
                actionButtons
            }
            .padding(AppSpacing.medium)
        }
        .padding(.horizontal, AppSpacing.medium)
        .accessibilityOptimized(
            label: "세션 정보",
            hint: "현재 녹음 세션의 상세 정보를 확인할 수 있습니다"
        )
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        HStack {
            HStack(spacing: AppSpacing.small) {
                AccessibleImage(
                    systemName: "info.circle.fill",
                    size: 20,
                    color: Color.interactive,
                    label: "세션 정보"
                )
                
                AccessibleText(
                    "세션 정보",
                    style: .headline,
                    weight: .semibold
                )
            }
            
            Spacer()
            
            // 상세 정보 토글
            AccessibleButton(
                action: {
                    withAnimation(Animations.Transition.slide) {
                        showingDetailedInfo.toggle()
                    }
                },
                label: showingDetailedInfo ? "상세 정보 접기" : "상세 정보 펼치기",
                hint: showingDetailedInfo ? "상세 세션 정보를 숨깁니다" : "상세 세션 정보를 표시합니다"
            ) {
                AccessibleImage(
                    systemName: showingDetailedInfo ? "chevron.up" : "chevron.down",
                    size: 16,
                    color: Color.interactive,
                    label: showingDetailedInfo ? "접기" : "펼치기"
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHeading(.h2)
    }
    
    // MARK: - Basic Session Info
    
    private var basicSessionInfo: some View {
        VStack(spacing: AppSpacing.small) {
            SessionInfoRow(
                icon: "clock.fill",
                title: "녹음 시간",
                value: "\(String(format: "%.1f", audioSession.duration))초",
                iconColor: Color.interactive
            )
            
            SessionInfoRow(
                icon: "calendar",
                title: "녹음 일시",
                value: DateFormatter.localizedString(
                    from: audioSession.timestamp,
                    dateStyle: .medium,
                    timeStyle: .short
                ),
                iconColor: Color.interactive
            )
            
            if let fileURL = audioSession.audioFileURL {
                SessionInfoRow(
                    icon: "doc.fill",
                    title: "파일명",
                    value: fileURL.lastPathComponent,
                    iconColor: Color.interactive
                )
            }
            
            SessionInfoRow(
                icon: "waveform",
                title: "세션 ID",
                value: String(audioSession.id.uuidString.prefix(8)),
                iconColor: Color.interactive
            )
        }
    }
    
    // MARK: - Audio Quality Info
    
    private var audioQualityInfo: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AccessibleText(
                "오디오 품질",
                style: .subheadline,
                weight: .semibold
            )
            .accessibilityHeading(.h3)
            
            VStack(spacing: AppSpacing.small) {
                SessionInfoRow(
                    icon: "speaker.wave.2.fill",
                    title: "샘플 레이트",
                    value: "\(String(format: "%.0f", audioSession.sampleRate)) Hz",
                    iconColor: Color.dpSuccess
                )
                
                SessionInfoRow(
                    icon: "music.mic",
                    title: "채널 수",
                    value: "\(audioSession.channelCount)개",
                    iconColor: Color.dpSuccess
                )
                
                // 품질 등급 표시
                qualityGradeIndicator
                
                // 파일 크기 (있는 경우)
                if let fileURL = audioSession.audioFileURL {
                    fileSizeInfo(for: fileURL)
                }
            }
        }
    }
    
    // MARK: - Quality Grade Indicator
    
    private var qualityGradeIndicator: some View {
        let grade = calculateQualityGrade()
        
        return HStack {
            AccessibleImage(
                systemName: "star.fill",
                size: 16,
                color: colorFromString(grade.color),
                label: "품질 등급"
            )
            
            AccessibleText(
                "품질 등급",
                style: .body
            )
            .foregroundColor(Color.textSecondary)
            
            Spacer()
            
            HStack(spacing: AppSpacing.xsmall) {
                ForEach(0..<5, id: \.self) { index in
                    AccessibleImage(
                        systemName: index < grade.stars ? "star.fill" : "star",
                        size: 12,
                        color: colorFromString(grade.color),
                        label: index < grade.stars ? "채워진 별" : "빈 별",
                        decorative: true
                    )
                }
                
                AccessibleText(
                    grade.description,
                    style: .caption,
                    weight: .medium
                )
                .foregroundColor(colorFromString(grade.color))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("오디오 품질: \(grade.description), 5점 만점에 \(grade.stars)점")
    }
    
    // MARK: - Analysis Result Summary
    
    private func analysisResultSummary(result: TimeBasedAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            AccessibleText(
                "분석 결과 요약",
                style: .subheadline,
                weight: .semibold
            )
            .accessibilityHeading(.h3)
            
            VStack(spacing: AppSpacing.small) {
                SessionInfoRow(
                    icon: result.isSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill",
                    title: "분석 상태",
                    value: result.isSuccessful ? "성공" : "실패",
                    iconColor: result.isSuccessful ? Color.dpSuccess : Color.dpError
                )
                
                SessionInfoRow(
                    icon: "waveform.path.ecg",
                    title: "처리된 세그먼트",
                    value: "\(result.validSpeechSegments.count)개",
                    iconColor: Color.interactive
                )
                
                if result.isSuccessful {
                    SessionInfoRow(
                        icon: "percent",
                        title: "평균 신뢰도",
                        value: "\(String(format: "%.1f", result.overallConfidence * 100))%",
                        iconColor: confidenceColor(result.overallConfidence * 100)
                    )
                    
                    SessionInfoRow(
                        icon: "timer",
                        title: "처리 시간",
                        value: "\(String(format: "%.2f", result.processingDuration ?? 0.0))초",
                        iconColor: Color.interactive
                    )
                }
            }
        }
    }
    
    // MARK: - Detailed Session Info
    
    private var detailedSessionInfo: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Divider()
            
            AccessibleText(
                "상세 정보",
                style: .subheadline,
                weight: .semibold
            )
            .accessibilityHeading(.h3)
            
            VStack(spacing: AppSpacing.small) {
                SessionInfoRow(
                    icon: "memories",
                    title: "메모리 사용량",
                    value: "\(String(format: "%.1f", Double(getCurrentMemoryUsage()) / 1024 / 1024)) MB",
                    iconColor: Color.dpWarning
                )
                
                SessionInfoRow(
                    icon: "cpu",
                    title: "처리 코어",
                    value: "\(ProcessInfo.processInfo.processorCount)개",
                    iconColor: Color.interactive
                )
                
                SessionInfoRow(
                    icon: "battery.100",
                    title: "배터리 상태",
                    value: batteryStatusDescription,
                    iconColor: batteryStatusColor
                )
                
                // 기술적 세부사항 토글
                AccessibleButton(
                    action: {
                        withAnimation(Animations.Transition.slide) {
                            showingTechnicalSpecs.toggle()
                        }
                    },
                    label: showingTechnicalSpecs ? "기술 정보 접기" : "기술 정보 펼치기",
                    hint: showingTechnicalSpecs ? "기술적 세부사항을 숨깁니다" : "기술적 세부사항을 표시합니다"
                ) {
                    HStack {
                        AccessibleImage(
                            systemName: "gearshape.2",
                            size: 16,
                            color: Color.interactive,
                            label: "기술 정보"
                        )
                        
                        AccessibleText(
                            showingTechnicalSpecs ? "기술 정보 접기" : "기술 정보 보기",
                            style: .body,
                            weight: .medium
                        )
                        .foregroundColor(Color.interactive)
                        
                        Spacer()
                        
                        AccessibleImage(
                            systemName: showingTechnicalSpecs ? "chevron.up" : "chevron.down",
                            size: 12,
                            color: Color.interactive,
                            label: showingTechnicalSpecs ? "접기" : "펼치기",
                            decorative: true
                        )
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }
    
    // MARK: - Technical Specifications
    
    private var technicalSpecifications: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Divider()
            
            AccessibleText(
                "기술적 세부사항",
                style: .subheadline,
                weight: .semibold
            )
            .accessibilityHeading(.h3)
            
            VStack(spacing: AppSpacing.small) {
                SessionInfoRow(
                    icon: "waveform.path",
                    title: "비트 깊이",
                    value: "16 bit",
                    iconColor: Color.interactive
                )
                
                SessionInfoRow(
                    icon: "speedometer",
                    title: "비트레이트",
                    value: "\(String(format: "%.0f", (audioSession.sampleRate * Double(audioSession.channelCount) * 16.0) / 1000)) kbps",
                    iconColor: Color.interactive
                )
                
                SessionInfoRow(
                    icon: "square.grid.3x3",
                    title: "FFT 윈도우 크기",
                    value: "2048 samples",
                    iconColor: Color.interactive
                )
                
                SessionInfoRow(
                    icon: "arrow.up.and.down",
                    title: "오버랩",
                    value: "50%",
                    iconColor: Color.interactive
                )
                
                SessionInfoRow(
                    icon: "function",
                    title: "윈도우 함수",
                    value: "Hamming",
                    iconColor: Color.interactive
                )
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: AppSpacing.small) {
            Divider()
            
            HStack(spacing: AppSpacing.medium) {
                // 세션 내보내기
                AccessibleButton(
                    action: {
                        exportSession()
                    },
                    label: "세션 내보내기",
                    hint: "세션 정보와 오디오 파일을 내보냅니다"
                ) {
                    HStack(spacing: AppSpacing.small) {
                        AccessibleImage(
                            systemName: "square.and.arrow.up",
                            size: 16,
                            color: Color.interactive,
                            label: "내보내기"
                        )
                        AccessibleText("내보내기", style: .body, weight: .medium)
                    }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                
                // 세션 삭제
                AccessibleButton(
                    action: {
                        deleteSession()
                    },
                    label: "세션 삭제",
                    hint: "이 세션을 영구적으로 삭제합니다"
                ) {
                    HStack(spacing: AppSpacing.small) {
                        AccessibleImage(
                            systemName: "trash",
                            size: 16,
                            color: Color.dpError,
                            label: "삭제"
                        )
                        AccessibleText("삭제", style: .body, weight: .medium)
                    }
                }

            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateQualityGrade() -> QualityGrade {
        let sampleRate = audioSession.sampleRate
        let channelCount = audioSession.channelCount
        let bitDepth = 16 // 기본값으로 16 bit 사용
        
        // 품질 점수 계산 (0-5점)
        var score = 0
        
        // 샘플 레이트 평가
        if sampleRate >= 48000 { score += 2 }
        else if sampleRate >= 44100 { score += 1 }
        
        // 비트 깊이 평가
        if bitDepth >= 24 { score += 2 }
        else if bitDepth >= 16 { score += 1 }
        
        // 채널 수 평가 (모노는 감점)
        if channelCount >= 2 { score += 1 }
        
        switch score {
        case 5: return .excellent
        case 3...4: return .good
        case 2: return .fair
        default: return .poor
        }
    }
    
    private func fileSizeInfo(for url: URL) -> some View {
        let fileSize = getFileSize(for: url)
        
        return SessionInfoRow(
            icon: "externaldrive.fill",
            title: "파일 크기",
            value: ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file),
            iconColor: Color.interactive
        )
    }
    
    private func getFileSize(for url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 80 { return Color.dpSuccess }
        else if confidence >= 60 { return Color.dpWarning }
        else { return Color.dpError }
    }
    
    private var batteryStatusDescription: String {
        let level = UIDevice.current.batteryLevel
        if level < 0 { return "알 수 없음" }
        return "\(Int(level * 100))%"
    }
    
    private var batteryStatusColor: Color {
        let level = UIDevice.current.batteryLevel
        if level < 0 { return Color.textSecondary }
        if level < 0.2 { return Color.dpError }
        if level < 0.5 { return Color.dpWarning }
        return Color.dpSuccess
    }
    
    private func exportSession() {
        // 세션 내보내기 로직
        print("Exporting session: \(audioSession.id)")
    }
    
    private func deleteSession() {
        // 세션 삭제 로직
        print("Deleting session: \(audioSession.id)")
    }
    
    // MARK: - Helper Methods
    
    /// 문자열 색상을 SwiftUI Color로 변환
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "green": return Color.dpSuccess
        case "blue": return Color.interactive
        case "orange": return Color.dpWarning
        case "red": return Color.dpError
        default: return Color.textSecondary
        }
    }
    
    /// 현재 메모리 사용량 가져오기 (바이트 단위)
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        return 0
    }
}

// MARK: - Supporting Components

struct SessionInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            AccessibleImage(
                systemName: icon,
                size: 16,
                color: iconColor,
                label: title
            )
            .frame(width: 20)
            
            AccessibleText(
                title,
                style: .body
            )
            .foregroundColor(Color.textSecondary)
            
            Spacer()
            
            AccessibleText(
                value,
                style: .body,
                weight: .medium
            )
            .foregroundColor(Color.textPrimary)
            .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Supporting Types (QualityGrade는 SyllableSegment.swift에서 정의됨)