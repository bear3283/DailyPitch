import SwiftUI
import Combine
import AVFoundation

/// 간단하고 실용적인 녹음 화면
/// 핵심 기능에만 집중: 녹음 → 분석 → 재생
struct SimpleRecordingView: View {
    
    // MARK: - Properties
    @StateObject private var viewModel = SimpleRecordingViewModel()
    @State private var showingPermissionAlert = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer(minLength: 20)
                
                // 앱 로고 및 제목 (더 컴팩트하게)
                headerSection
                
                // 녹음 상태 표시
                statusSection
                
                // 메인 녹음 버튼
                recordingButton
                
                // 결과 섹션 (녹음 완료 후)
                if viewModel.hasResult {
                    resultSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .background(Color(.systemBackground))
            .navigationTitle("DailyPitch")
            .navigationBarTitleDisplayMode(.large)
            .alert("마이크 권한 필요", isPresented: $showingPermissionAlert) {
                Button("설정으로 이동") {
                    openAppSettings()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("음성을 녹음하려면 마이크 사용 권한이 필요합니다.")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasResult)
        .onReceive(viewModel.$permissionDenied) { denied in
            showingPermissionAlert = denied
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // 앱 아이콘 (더 작게)
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 35))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text("DailyPitch")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("일상의 소리를 음계로 변환하세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(spacing: 16) {
            // 상태 아이콘
            ZStack {
                Circle()
                    .fill(statusBackgroundColor)
                    .frame(width: 110, height: 110)
                
                Image(systemName: statusIconName)
                    .font(.system(size: 45))
                    .foregroundColor(statusIconColor)
                    .symbolEffect(.pulse, isActive: viewModel.isRecording)
            }
            
            // 상태 텍스트
            VStack(spacing: 6) {
                Text(statusTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // 녹음 시간 표시
                if viewModel.isRecording {
                    Text(viewModel.recordingTimeString)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .monospacedDigit()
                        .padding(.top, 4)
                }
                
                // 분석 진행률
                if viewModel.isAnalyzing {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.analysisProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 180)
                        
                        Text("\(Int(viewModel.analysisProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Recording Button
    
    private var recordingButton: some View {
        Button(action: viewModel.toggleRecording) {
            ZStack {
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 90, height: 90)
                    .shadow(color: buttonBackgroundColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: buttonIconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
        }
        .disabled(viewModel.isAnalyzing)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Result Section
    
    private var resultSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, -20)
            
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.blue)
                        .font(.system(size: 18, weight: .medium))
                    Text("분석 결과")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                if let detectedNote = viewModel.detectedNote {
                    VStack(spacing: 10) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("감지된 음계")
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
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                
                // 재생 버튼들 (더 컴팩트하게)
                playbackButtons
            }
        }
        .padding(.horizontal, -20)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Playback Buttons
    
    private var playbackButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 원본 재생
                Button(action: viewModel.playOriginal) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                        Text("원본")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
                .disabled(viewModel.isPlaying)
                
                // 음계 재생
                Button(action: viewModel.playSynthesized) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 16))
                        Text("음계")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(20)
                }
                .disabled(viewModel.isPlaying || viewModel.synthesizedAudio == nil)
            }
            
            // 함께 재생 (전체 너비)
            Button(action: viewModel.playMixed) {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                    Text("원본 + 음계 함께 재생")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(20)
            }
            .disabled(viewModel.isPlaying || viewModel.synthesizedAudio == nil)
        }
    }
    
    // MARK: - Helper Properties
    
    private var statusIconName: String {
        if viewModel.isRecording {
            return "mic.fill"
        } else if viewModel.isAnalyzing {
            return "waveform.path"
        } else if viewModel.hasResult {
            return "music.note"
        } else {
            return "mic"
        }
    }
    
    private var statusIconColor: Color {
        if viewModel.isRecording {
            return .white
        } else if viewModel.isAnalyzing {
            return .white
        } else if viewModel.hasResult {
            return .white
        } else {
            return .blue
        }
    }
    
    private var statusBackgroundColor: Color {
        if viewModel.isRecording {
            return .red
        } else if viewModel.isAnalyzing {
            return .orange
        } else if viewModel.hasResult {
            return .green
        } else {
            return Color(.systemGray5)
        }
    }
    
    private var statusTitle: String {
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
    
    private var statusDescription: String {
        if viewModel.isRecording {
            return "소리를 내어 주세요"
        } else if viewModel.isAnalyzing {
            return "음계를 분석하고 있습니다"
        } else if viewModel.hasResult {
            return "결과를 확인하고 재생해보세요"
        } else {
            return "버튼을 눌러 녹음을 시작하세요"
        }
    }
    
    private var buttonIconName: String {
        return viewModel.isRecording ? "stop.fill" : "mic.fill"
    }
    
    private var buttonBackgroundColor: Color {
        return viewModel.isRecording ? .red : .blue
    }
    
    // MARK: - Helper Methods
    
    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Simple Recording ViewModel

@MainActor
class SimpleRecordingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isAnalyzing = false
    @Published var isPlaying = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var analysisProgress: Double = 0.0
    @Published var permissionDenied = false
    
    // 결과
    @Published var detectedNote: String?
    @Published var peakFrequency: Double?
    @Published var currentAudioSession: AudioSession?
    @Published var synthesizedAudio: SynthesizedAudio?
    
    // MARK: - Dependencies
    private let audioManager = CentralAudioManager.shared
    private let permissionManager = AudioPermissionManager()
    private let recordAudioUseCase: RecordAudioUseCase
    private let analyzeFrequencyUseCase: AnalyzeFrequencyUseCase
    private let synthesizeAudioUseCase: SynthesizeAudioUseCase
    
    private var cancellables = Set<AnyCancellable>()
    private var recordingTimer: Timer?
    
    // MARK: - Computed Properties
    
    var recordingTimeString: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var hasResult: Bool {
        return detectedNote != nil
    }
    
    // MARK: - Initialization
    
    init() {
        let audioRecordingRepository = AudioRecordingRepositoryImpl()
        let audioAnalysisRepository = AudioAnalysisRepositoryImpl()
        let audioSynthesisRepository: AudioSynthesisRepository = AudioSynthesizer()
        
        self.recordAudioUseCase = RecordAudioUseCase(audioRepository: audioRecordingRepository)
        self.analyzeFrequencyUseCase = AnalyzeFrequencyUseCase(audioAnalysisRepository: audioAnalysisRepository)
        self.synthesizeAudioUseCase = SynthesizeAudioUseCase(audioSynthesisRepository: audioSynthesisRepository)
    }
    
    // MARK: - Public Methods
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func playOriginal() {
        guard let audioSession = currentAudioSession,
              let audioURL = audioSession.audioFileURL else { return }
        
        playAudioFile(url: audioURL)
    }
    
    func playSynthesized() {
        guard let synthesizedAudio = synthesizedAudio else { 
            print("❌ 합성 오디오가 없습니다")
            return 
        }
        
        do {
            // AVAudioPCMBuffer 생성
            let buffer = try createAudioBuffer(from: synthesizedAudio)
            
            isPlaying = true
            try audioManager.playAudio(buffer: buffer) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            }
            print("🎵 합성 오디오 재생 시작: \(synthesizedAudio.musicNotes.count)개 음계")
        } catch {
            print("❌ 합성 오디오 재생 실패: \(error)")
            isPlaying = false
        }
    }
    
    func playMixed() {
        guard let currentAudioSession = currentAudioSession,
              let synthesizedAudio = synthesizedAudio,
              let audioURL = currentAudioSession.audioFileURL else {
            print("❌ 믹스 재생을 위한 데이터가 부족합니다")
            return
        }
        
        do {
            // 원본 오디오 파일 로드
            let audioFile = try AVAudioFile(forReading: audioURL)
            let originalBuffer = try createBuffer(from: audioFile)
            
            // 합성 오디오 버퍼 생성
            let synthesizedBuffer = try createAudioBuffer(from: synthesizedAudio)
            
            // 믹싱된 버퍼 생성
            let mixedBuffer = try mixAudioBuffers(
                originalBuffer: originalBuffer,
                synthesizedBuffer: synthesizedBuffer,
                originalVolume: 0.7,
                synthesizedVolume: 0.5
            )
            
            isPlaying = true
            try audioManager.playAudio(buffer: mixedBuffer) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            }
            print("🎵 믹스 재생 시작 (원본 + 합성)")
        } catch {
            print("❌ 믹스 재생 실패: \(error)")
            isPlaying = false
        }
    }
    
    // MARK: - Private Methods
    
    private func startRecording() {
        // 권한 확인
        permissionManager.requestPermission()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                if granted {
                    self?.performRecording()
                } else {
                    self?.permissionDenied = true
                }
            }
            .store(in: &cancellables)
    }
    
    private func performRecording() {
        clearResults()
        
        recordAudioUseCase.startRecording()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ 녹음 실패: \(error)")
                    }
                    self?.isRecording = false
                    self?.stopRecordingTimer()
                },
                receiveValue: { [weak self] audioSession in
                    self?.isRecording = true
                    self?.currentAudioSession = audioSession
                    self?.startRecordingTimer()
                }
            )
            .store(in: &cancellables)
    }
    
    private func stopRecording() {
        recordAudioUseCase.stopRecording()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isRecording = false
                    self?.stopRecordingTimer()
                    
                    if case .failure(let error) = completion {
                        print("❌ 녹음 중지 실패: \(error)")
                    }
                },
                receiveValue: { [weak self] audioSession in
                    self?.currentAudioSession = audioSession
                    self?.startAnalysis(audioSession: audioSession)
                }
            )
            .store(in: &cancellables)
    }
    
    private func startAnalysis(audioSession: AudioSession) {
        isAnalyzing = true
        analysisProgress = 0.0
        
        // 진행률 시뮬레이션
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.isAnalyzing else {
                timer.invalidate()
                return
            }
            self.analysisProgress = min(self.analysisProgress + 0.05, 0.9)
        }
        
        analyzeFrequencyUseCase.analyzeAudioSession(audioSession)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    progressTimer.invalidate()
                    self?.isAnalyzing = false
                    self?.analysisProgress = 1.0
                    
                    if case .failure(let error) = completion {
                        print("❌ 분석 실패: \(error)")
                    }
                },
                receiveValue: { [weak self] result in
                    self?.processAnalysisResult(result)
                }
            )
            .store(in: &cancellables)
    }
    
    private func processAnalysisResult(_ result: AudioAnalysisResult) {
        // 대표 음계 정보 추출
        if let peakFrequency = result.averagePeakFrequency,
           let musicNote = MusicNote.from(frequency: peakFrequency, duration: 1.0, amplitude: 0.7) {
            
            self.detectedNote = musicNote.name
            self.peakFrequency = peakFrequency
            
            // 합성 오디오 생성
            synthesizeAudio(note: musicNote)
        }
    }
    
    private func synthesizeAudio(note: MusicNote) {
        synthesizeAudioUseCase.synthesizeFromFrequency(frequency: note.frequency, duration: note.duration, amplitude: note.amplitude, method: .sineWave)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ 합성 실패: \(error)")
                    }
                },
                receiveValue: { [weak self] synthesizedAudio in
                    self?.synthesizedAudio = synthesizedAudio
                }
            )
            .store(in: &cancellables)
    }
    
    private func playAudioFile(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ 오디오 파일이 존재하지 않습니다: \(url.path)")
            return
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: url)
            isPlaying = true
            
            try audioManager.playAudio(file: audioFile) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                }
            }
        } catch {
            print("❌ 오디오 재생 실패: \(error)")
        }
    }
    
    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func clearResults() {
        detectedNote = nil
        peakFrequency = nil
        synthesizedAudio = nil
        recordingDuration = 0
        analysisProgress = 0.0
    }
    
    // MARK: - Audio Buffer Helper Methods
    
    private func createAudioBuffer(from synthesizedAudio: SynthesizedAudio) throws -> AVAudioPCMBuffer {
        let sampleRate = synthesizedAudio.sampleRate
        let frameCount = AVAudioFrameCount(synthesizedAudio.audioData.count)
        
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            throw AudioManagerError.configurationFailed
        }
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            throw AudioManagerError.playbackFailed
        }
        
        // 오디오 데이터 복사
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        
        for i in 0..<Int(frameCount) {
            channelData[i] = synthesizedAudio.audioData[i]
        }
        
        return buffer
    }
    
    private func createBuffer(from audioFile: AVAudioFile) throws -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: frameCount
        ) else {
            throw AudioManagerError.playbackFailed
        }
        
        try audioFile.read(into: buffer)
        return buffer
    }
    
    private func mixAudioBuffers(
        originalBuffer: AVAudioPCMBuffer,
        synthesizedBuffer: AVAudioPCMBuffer,
        originalVolume: Float,
        synthesizedVolume: Float
    ) throws -> AVAudioPCMBuffer {
        let originalFrameCount = originalBuffer.frameLength
        let synthesizedFrameCount = synthesizedBuffer.frameLength
        let maxFrameCount = max(originalFrameCount, synthesizedFrameCount)
        
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: 44100,
            channels: 1
        ) else {
            throw AudioManagerError.configurationFailed
        }
        
        guard let mixedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: maxFrameCount
        ) else {
            throw AudioManagerError.playbackFailed
        }
        
        // 믹싱 수행
        mixedBuffer.frameLength = maxFrameCount
        let mixedData = mixedBuffer.floatChannelData![0]
        let originalData = originalBuffer.floatChannelData![0]
        let synthesizedData = synthesizedBuffer.floatChannelData![0]
        
        for i in 0..<Int(maxFrameCount) {
            var sample: Float = 0.0
            
            // 원본 오디오 추가
            if i < Int(originalFrameCount) {
                sample += originalData[i] * originalVolume
            }
            
            // 합성 오디오 추가
            if i < Int(synthesizedFrameCount) {
                sample += synthesizedData[i] * synthesizedVolume
            }
            
            // 클리핑 방지
            mixedData[i] = max(-1.0, min(1.0, sample))
        }
        
        return mixedBuffer
    }
}

// Preview
#Preview {
    SimpleRecordingView()
} 