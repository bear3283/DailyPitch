//
//  AnalysisResultsSection.swift
//  DailyPitch
//
//  Created by bear on 7/10/25.
//

import SwiftUI

/// 분석 결과 표시 섹션 - 간단한 버전
struct AnalysisResultsSection: View {
    
    // MARK: - Properties
    @ObservedObject var recordingViewModel: RecordingViewModel
    @ObservedObject var playbackViewModel: PlaybackViewModel
    @Binding var showingResults: Bool
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // 섹션 헤더
            sectionHeader
            
            if showingResults {
                VStack(spacing: 12) {
                    // 메시지 표시 (에러 및 정보)
                    if let errorInfo = recordingViewModel.errorInfo {
                        errorMessageView(errorInfo.error.localizedDescription)
                    }
                    
                    // 추천된 음악 스케일 표시
                    if !recordingViewModel.recommendedScales.isEmpty {
                        recommendedScalesCard()
                    }
                    
                    // 음절별 분석 결과 표시
                    if !recordingViewModel.syllables.isEmpty {
                        syllableAnalysisCard()
                    }
                    
                    // 재생 컨트롤
                    if recordingViewModel.playingAudioType != nil {
                        playbackControlsCard()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .onAppear {
            showingResults = true
        }
    }
    
    // MARK: - Section Header
    
    private var sectionHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .foregroundColor(.blue)
                    .font(.system(size: 20, weight: .medium))
                
                Text("분석 결과")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingResults.toggle()
                }
            }) {
                Image(systemName: showingResults ? "chevron.up" : "chevron.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
            }
        }
    }
    
    // MARK: - Error Message View
    
    private func errorMessageView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Recommended Scales Card
    
    private func recommendedScalesCard() -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("추천 음악 스케일")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(recordingViewModel.recommendedScales.enumerated()), id: \.offset) { index, scale in
                        musicScaleView(scale, index: index)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private func musicScaleView(_ scale: MusicScale, index: Int) -> some View {
        VStack(spacing: 6) {
            Text(scale.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(scale.type.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let mood = scale.mood {
                Text(mood.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Syllable Analysis Card
    
    private func syllableAnalysisCard() -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("음절별 분석")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(recordingViewModel.syllables.enumerated()), id: \.offset) { index, syllable in
                        syllableResultView(syllable, index: index)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private func syllableResultView(_ syllable: SyllableResult, index: Int) -> some View {
        VStack(spacing: 4) {
            Text("음절 \(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(syllable.note)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(String(format: "%.0f Hz", syllable.frequency))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(String(format: "신뢰도: %.0f%%", syllable.confidence * 100))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
    
    // MARK: - Playback Controls Card
    
    private func playbackControlsCard() -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("재생 컨트롤")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 16) {
                // 원본 재생 버튼
                Button(action: {
                    recordingViewModel.playAudio(type: .original)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: (recordingViewModel.playingAudioType == .original) ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        Text("원본")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // 합성음 재생 버튼
                Button(action: {
                    recordingViewModel.playAudio(type: .synthesized)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: (recordingViewModel.playingAudioType == .synthesized) ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                        Text("변환음")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                // 비교 재생 버튼
                Button(action: {
                    recordingViewModel.playAudio(type: .mixed)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: (recordingViewModel.playingAudioType == .mixed) ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text("비교")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }

} 