//
//  ContentView.swift
//  DailyPitch
//
//  Created by bear on 7/9/25.
//

import SwiftUI

/// DailyPitch 앱의 메인 콘텐츠 뷰
/// 간단하고 직관적인 인터페이스
struct ContentView: View {
    
    var body: some View {
        TabView {
            // 메인 녹음 탭
            SimpleRecordingView()
                .tabItem {
                    Image(systemName: "mic.circle.fill")
                    Text("녹음")
                }
            
            // 간단한 히스토리 탭  
            SimpleHistoryView()
                .tabItem {
                    Image(systemName: "clock.circle.fill")
                    Text("기록")
                }
            
            // 간단한 설정 탭
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.circle.fill")
                    Text("설정")
                }
        }
        .accentColor(.blue)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // 선택된 아이템 색상
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        
        // 선택되지 않은 아이템 색상
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Simple History View

struct SimpleHistoryView: View {
    @StateObject private var historyViewModel = HistoryViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                if historyViewModel.recordingSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue.opacity(0.6))
                        
                        Text("아직 녹음 기록이 없습니다")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("첫 번째 음성을 녹음해보세요!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(historyViewModel.recordingSessions, id: \.id) { session in
                        HistoryRowView(session: session)
                    }
                    .onDelete(perform: historyViewModel.deleteSession)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("기록")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !historyViewModel.recordingSessions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .onAppear {
                historyViewModel.loadSessions()
            }
        }
    }
}

// MARK: - History Row View

struct HistoryRowView: View {
    let session: AudioSession
    
    var body: some View {
        HStack(spacing: 16) {
            // 세션 아이콘
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .font(.system(size: 22, weight: .medium))
            }
            
            // 세션 정보
            VStack(alignment: .leading, spacing: 6) {
                Text(DateFormatter.localizedString(from: session.timestamp, dateStyle: .medium, timeStyle: .short))
                    .fontWeight(.medium)
                    .font(.system(size: 16))
                
                Text("길이: \(String(format: "%.1f", session.duration))초")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let audioFileURL = session.audioFileURL {
                    Text("파일 크기: \(formatFileSize(url: audioFileURL))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 재생 버튼
            Button(action: {
                // 재생 기능 (다음 단계에서 구현)
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "play.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func formatFileSize(url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return "알 수 없음"
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                // 기본 설정 섹션
                Section {
                    SettingRow(
                        icon: "waveform.circle.fill",
                        title: "높은 품질 녹음",
                        description: "더 정확한 분석을 위한 고품질 녹음"
                    ) {
                        Toggle("", isOn: $settingsViewModel.highQualityRecording)
                            .labelsHidden()
                    }
                    
                    SettingRow(
                        icon: "timer.circle.fill", 
                        title: "최대 녹음 시간",
                        description: "녹음할 수 있는 최대 시간"
                    ) {
                        Text("\(Int(settingsViewModel.maxRecordingDuration))초")
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .rounded))
                    }
                    
                    SettingRow(
                        icon: "gear.circle.fill",
                        title: "자동 분석",
                        description: "녹음 완료 후 자동으로 분석 시작"
                    ) {
                        Toggle("", isOn: $settingsViewModel.autoAnalysis)
                            .labelsHidden()
                    }
                    
                    SettingRow(
                        icon: "iphone.radiowaves.left.and.right.circle.fill",
                        title: "햅틱 피드백",
                        description: "버튼 터치 시 진동 알림"
                    ) {
                        Toggle("", isOn: $settingsViewModel.hapticFeedbackEnabled)
                            .labelsHidden()
                    }
                } header: {
                    Text("오디오 설정")
                } footer: {
                    Text("설정 변경 시 다음 녹음부터 적용됩니다.")
                }
                
                // 앱 정보 섹션
                Section {
                    SettingRow(
                        icon: "info.circle.fill",
                        title: "버전",
                        description: "현재 앱 버전"
                    ) {
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .rounded))
                    }
                    
                    Button(action: {
                        // 피드백 기능
                    }) {
                        SettingRow(
                            icon: "envelope.circle.fill",
                            title: "피드백 보내기",
                            description: "개발팀에게 의견을 보내주세요"
                        ) {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("앱 정보")
                }
                
                // 개발자 모드 (선택사항)
                if settingsViewModel.developerModeEnabled {
                    Section {
                        Button("모든 데이터 삭제") {
                            settingsViewModel.clearAllData()
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .medium))
                    } header: {
                        Text("개발자 옵션")
                    } footer: {
                        Text("이 작업은 되돌릴 수 없습니다.")
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Setting Row Component

struct SettingRow<Content: View>: View {
    let icon: String
    let title: String
    let description: String?
    let content: () -> Content
    
    init(
        icon: String,
        title: String,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.content = content
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting ViewModels

class HistoryViewModel: ObservableObject {
    @Published var recordingSessions: [AudioSession] = []
    
    func loadSessions() {
        // 실제로는 CoreData나 다른 저장소에서 로드
        // 임시로 빈 배열로 초기화
        recordingSessions = []
    }
    
    func deleteSession(at offsets: IndexSet) {
        recordingSessions.remove(atOffsets: offsets)
    }
}

class SettingsViewModel: ObservableObject {
    @Published var highQualityRecording = true
    @Published var maxRecordingDuration: Double = 60.0
    @Published var autoAnalysis = true
    @Published var hapticFeedbackEnabled = true
    @Published var developerModeEnabled = false
    
    func clearAllData() {
        // 모든 데이터 삭제 구현
        print("모든 데이터가 삭제되었습니다.")
    }
}

#Preview {
    ContentView()
}
