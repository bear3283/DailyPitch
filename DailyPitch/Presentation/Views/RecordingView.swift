import SwiftUI
import AVFoundation

/// 메인 녹음 화면 - 단순화된 버전
struct RecordingView: View {
    @StateObject private var viewModel = SimpleRecordingViewModel()
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 권한 상태 표시
                if viewModel.permissionDenied {
                    VStack {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.dpError)
                        
                        Text("마이크 권한이 필요합니다")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("일상 소리를 녹음하여 음계로 변환하기 위해 마이크 접근 권한이 필요합니다.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("권한 설정하기") {
                            showingPermissionAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    // 메인 녹음 인터페이스
                    mainRecordingInterface
                }
            }
            .navigationTitle("DailyPitch")
            .alert("마이크 권한 필요", isPresented: $showingPermissionAlert) {
                Button("설정으로 이동") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("설정 앱에서 DailyPitch의 마이크 권한을 활성화해주세요.")
            }
        }
    }
    
    private var mainRecordingInterface: some View {
        VStack(spacing: 30) {
            // 현재 상태 표시
            statusSection
            
            // 녹음 버튼
            recordingButton
            
            // 분석 결과 (있는 경우)
            if viewModel.hasResult {
                analysisResultsSection
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: statusIcon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                )
            
            Text(statusText)
                .font(.title2)
                .fontWeight(.semibold)
            
            if viewModel.isAnalyzing {
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }
    
    private var recordingButton: some View {
        Button(action: {
            viewModel.toggleRecording()
        }) {
            HStack {
                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                Text(viewModel.isRecording ? "녹음 중지" : "녹음 시작")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(viewModel.isRecording ? Color.dpError : Color.accentColor)
            .cornerRadius(25)
        }
        .disabled(viewModel.isAnalyzing)
        .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: viewModel.isRecording)
    }
    
    private var analysisResultsSection: some View {
        VStack(spacing: 16) {
            Text("분석 결과")
                .font(.headline)
            
            // 주요 음계들
            if let detectedNote = viewModel.detectedNote {
                VStack(alignment: .leading, spacing: 8) {
                    Text("감지된 음계:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("음계")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(detectedNote)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        if let frequency = viewModel.peakFrequency {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("주파수")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", frequency)) Hz")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // 재생 버튼들
            HStack(spacing: 16) {
                Button("원본 재생") {
                    viewModel.playOriginal()
                }
                .buttonStyle(.bordered)
                
                Button("변환음 재생") {
                    viewModel.playSynthesized()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.synthesizedAudio == nil)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        if viewModel.isRecording {
            return .dpError
        } else if viewModel.isAnalyzing {
            return .dpWarning
        } else {
            return .dpSuccess
        }
    }
    
    private var statusIcon: String {
        if viewModel.isRecording {
            return "waveform"
        } else if viewModel.isAnalyzing {
            return "gearshape.fill"
        } else {
            return "checkmark"
        }
    }
    
    private var statusText: String {
        if viewModel.isRecording {
            return "녹음 중..."
        } else if viewModel.isAnalyzing {
            return "분석 중..."
        } else if viewModel.hasResult {
            return "분석 완료"
        } else {
            return "녹음 준비"
        }
    }
}

#Preview {
    RecordingView()
} 