import SwiftUI

/// 오디오 재생 컨트롤 뷰
struct PlaybackControlsView: View {
    @ObservedObject var playbackViewModel: PlaybackViewModel
    let audioSession: AudioSession
    let detectedNote: String?
    let peakFrequency: Double?
    
    @State private var showingSynthesisOptions = false
    @State private var selectedSynthesisMethod: SynthesizedAudio.SynthesisMethod = .harmonic
    
    var body: some View {
        VStack(spacing: 16) {
            
            // MARK: - 음계 합성 섹션
            VStack(spacing: 12) {
                HStack {
                    Text("🎼 음계 합성")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if playbackViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if let note = detectedNote, let frequency = peakFrequency {
                    // 합성 방법 선택
                    Picker("합성 방법", selection: $selectedSynthesisMethod) {
                        ForEach([SynthesizedAudio.SynthesisMethod.sineWave, .harmonic, .squareWave], id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // 합성 버튼
                    Button(action: synthesizeAudio) {
                        HStack {
                            Image(systemName: "waveform.and.magnifyingglass")
                            Text("음계 합성")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(playbackViewModel.isLoading)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // MARK: - 재생 컨트롤 섹션
            if playbackViewModel.canPlay {
                VStack(spacing: 12) {
                    // 재생 모드 선택
                    Picker("재생 모드", selection: $playbackViewModel.playbackMode) {
                        ForEach(SynthesizedAudio.PlaybackMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.description)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // 재생 진행률 바
                    if playbackViewModel.duration > 0 {
                        VStack(spacing: 4) {
                            ProgressView(value: playbackViewModel.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let newProgress = Double(value.location.x / UIScreen.main.bounds.width)
                                            playbackViewModel.seek(toProgress: max(0, min(1, newProgress)))
                                        }
                                )
                            
                            HStack {
                                Text(playbackViewModel.formattedCurrentTime)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(playbackViewModel.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 재생 버튼들
                    HStack(spacing: 20) {
                        // 이전/되감기 버튼
                        Button(action: { playbackViewModel.seek(to: max(0, playbackViewModel.currentTime - 10)) }) {
                            Image(systemName: "gobackward.10")
                                .font(.title2)
                        }
                        .disabled(!playbackViewModel.canPlay)
                        
                        // 메인 재생/일시정지 버튼
                        Button(action: togglePlayback) {
                            Image(systemName: playbackButtonIcon)
                                .font(.title)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.blue))
                                .foregroundColor(.white)
                        }
                        .disabled(!canPlayCurrentMode)
                        
                        // 다음/빨리감기 버튼
                        Button(action: { playbackViewModel.seek(to: min(playbackViewModel.duration, playbackViewModel.currentTime + 10)) }) {
                            Image(systemName: "goforward.10")
                                .font(.title2)
                        }
                        .disabled(!playbackViewModel.canPlay)
                        
                        Spacer()
                        
                        // 정지 버튼
                        Button(action: { playbackViewModel.stop() }) {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                        }
                        .disabled(!playbackViewModel.isPlaying && !playbackViewModel.isPaused)
                    }
                    
                    // 볼륨 컨트롤
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                        
                        Slider(
                            value: Binding(
                                get: { Double(playbackViewModel.currentVolume) },
                                set: { playbackViewModel.setVolume(Float($0)) }
                            ),
                            in: 0...1
                        )
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            // MARK: - 재생 품질 정보
            if let quality = playbackViewModel.playbackQuality {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("재생 품질:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(quality.description)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(quality.color)
                    }
                    
                    HStack {
                        Text("RMS: \(String(format: "%.3f", quality.rms))")
                        Spacer()
                        Text("Peak: \(String(format: "%.3f", quality.peak))")
                        Spacer()
                        Text("Range: \(String(format: "%.1f", quality.dynamicRange)) dB")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            // MARK: - 에러 메시지
            if let errorMessage = playbackViewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("닫기") {
                        playbackViewModel.clearError()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .onAppear {
            setupAudioSession()
        }
    }
    
    // MARK: - Private Methods
    
    private var playbackButtonIcon: String {
        if playbackViewModel.isLoading {
            return "hourglass"
        } else if playbackViewModel.isPlaying {
            return "pause.fill"
        } else {
            return "play.fill"
        }
    }
    
    private var canPlayCurrentMode: Bool {
        switch playbackViewModel.playbackMode {
        case .originalOnly:
            return playbackViewModel.canPlay
        case .synthesizedOnly:
            return playbackViewModel.canPlaySynthesized
        case .mixed:
            return playbackViewModel.canPlayMixed
        }
    }
    
    private func togglePlayback() {
        if playbackViewModel.isPlaying {
            playbackViewModel.pause()
        } else if playbackViewModel.isPaused {
            playbackViewModel.resume()
        } else {
            playbackViewModel.playWithCurrentMode()
        }
    }
    
    private func synthesizeAudio() {
        guard let note = detectedNote, let frequency = peakFrequency else { return }
        
        // 감지된 주파수를 기반으로 MusicNote 생성
        let musicNote = MusicNote.from(
            frequency: frequency,
            duration: min(audioSession.duration, 3.0), // 최대 3초
            amplitude: 0.7
        )
        
        guard let validNote = musicNote else {
            playbackViewModel.errorMessage = "유효한 음계를 생성할 수 없습니다."
            return
        }
        
        // 음계 합성
        playbackViewModel.synthesizeAudio(from: [validNote], method: selectedSynthesisMethod)
    }
    
    private func setupAudioSession() {
        playbackViewModel.setAudioSession(audioSession)
    }
}

// MARK: - Preview

struct PlaybackControlsView_Previews: PreviewProvider {
    static var previews: some View {
        let audioSynthesizer = AudioSynthesizer()
        let audioPlayer = AudioPlayer()
        
        let synthesizeUseCase = SynthesizeAudioUseCase(audioSynthesisRepository: audioSynthesizer)
        let playbackUseCase = AudioPlaybackUseCase(audioPlaybackRepository: audioPlayer)
        
        let playbackVM = PlaybackViewModel(
            synthesizeAudioUseCase: synthesizeUseCase,
            audioPlaybackUseCase: playbackUseCase
        )
        
        let audioSession = AudioSession(
            id: UUID(),
            timestamp: Date(),
            duration: 5.0,
            audioFileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        return PlaybackControlsView(
            playbackViewModel: playbackVM,
            audioSession: audioSession,
            detectedNote: "C4",
            peakFrequency: 261.63
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 