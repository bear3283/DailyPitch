import Foundation
import SwiftUI
import Combine

/// 오디오 재생 기능을 관리하는 ViewModel
@MainActor
class PlaybackViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var progress: Double = 0.0
    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentVolume: Float = 1.0
    @Published var playbackMode: SynthesizedAudio.PlaybackMode = .originalOnly
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var playbackQuality: PlaybackQuality?
    
    // MARK: - Private Properties
    
    private let synthesizeAudioUseCase: SynthesizeAudioUseCase
    private let audioPlaybackUseCase: AudioPlaybackUseCase
    private var cancellables = Set<AnyCancellable>()
    
    private var currentAudioSession: AudioSession?
    private var currentSynthesizedAudio: SynthesizedAudio?
    
    // MARK: - Computed Properties
    
    var remainingTime: TimeInterval {
        return max(0, duration - currentTime)
    }
    
    var formattedCurrentTime: String {
        return formatTime(currentTime)
    }
    
    var formattedDuration: String {
        return formatTime(duration)
    }
    
    var formattedRemainingTime: String {
        return formatTime(remainingTime)
    }
    
    var canPlay: Bool {
        return currentAudioSession != nil && !isLoading
    }
    
    var canPlaySynthesized: Bool {
        return currentSynthesizedAudio != nil && !isLoading
    }
    
    var canPlayMixed: Bool {
        return canPlay && canPlaySynthesized
    }
    
    // MARK: - Initialization
    
    init(
        synthesizeAudioUseCase: SynthesizeAudioUseCase,
        audioPlaybackUseCase: AudioPlaybackUseCase
    ) {
        self.synthesizeAudioUseCase = synthesizeAudioUseCase
        self.audioPlaybackUseCase = audioPlaybackUseCase
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// 오디오 세션 설정
    func setAudioSession(_ audioSession: AudioSession) {
        self.currentAudioSession = audioSession
        self.duration = audioSession.duration
        
        // 기존 합성 오디오 초기화
        self.currentSynthesizedAudio = nil
        self.playbackQuality = nil
    }
    
    /// 분석된 음계들로부터 합성 오디오 생성
    func synthesizeAudio(from notes: [MusicNote], method: SynthesizedAudio.SynthesisMethod = .harmonic) {
        guard !notes.isEmpty else {
            errorMessage = "합성할 음계 정보가 없습니다."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let frequencies = notes.map { $0.frequency }
        synthesizeAudioUseCase.synthesizeSequenceFromFrequencies(
            frequencies: frequencies,
            segmentDuration: 0.5,
            amplitude: 0.5,
            method: method
        )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.handleSynthesisError(error)
                    }
                },
                receiveValue: { [weak self] synthesizedAudio in
                    self?.currentSynthesizedAudio = synthesizedAudio
                    self?.checkPlaybackQuality(synthesizedAudio)
                }
            )
            .store(in: &cancellables)
    }
    
    /// 원본 오디오 재생
    func playOriginal() {
        guard let audioSession = currentAudioSession else {
            errorMessage = "재생할 오디오가 없습니다."
            return
        }
        
        playAudio(mode: .originalOnly, audioSession: audioSession)
    }
    
    /// 합성 오디오 재생
    func playSynthesized() {
        guard let audioSession = currentAudioSession,
              let synthesizedAudio = currentSynthesizedAudio else {
            errorMessage = "합성된 오디오가 없습니다."
            return
        }
        
        playAudio(mode: .synthesizedOnly, audioSession: audioSession, synthesizedAudio: synthesizedAudio)
    }
    
    /// 믹싱된 오디오 재생
    func playMixed(originalVolume: Float = 0.7, synthesizedVolume: Float = 0.8) {
        guard let audioSession = currentAudioSession,
              let synthesizedAudio = currentSynthesizedAudio else {
            errorMessage = "원본 및 합성 오디오가 모두 필요합니다."
            return
        }
        
        playAudio(
            mode: .mixed,
            audioSession: audioSession,
            synthesizedAudio: synthesizedAudio,
            originalVolume: originalVolume,
            synthesizedVolume: synthesizedVolume
        )
    }
    
    /// 재생 모드에 따른 재생
    func playWithCurrentMode() {
        switch playbackMode {
        case .originalOnly:
            playOriginal()
        case .synthesizedOnly:
            playSynthesized()
        case .mixed:
            playMixed()
        }
    }
    
    /// 재생 일시정지
    func pause() {
        audioPlaybackUseCase.pause()
    }
    
    /// 재생 재개
    func resume() {
        audioPlaybackUseCase.resume()
    }
    
    /// 재생 정지
    func stop() {
        audioPlaybackUseCase.stop()
    }
    
    /// 특정 시간으로 이동
    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        
        audioPlaybackUseCase.seek(to: clampedTime)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "시크 실패: \(error.localizedDescription)"
                    }
                },
                receiveValue: { _ in
                    // 시크 완료
                }
            )
            .store(in: &cancellables)
    }
    
    /// 진행률로 이동 (0.0 ~ 1.0)
    func seek(toProgress progress: Double) {
        let clampedProgress = max(0.0, min(1.0, progress))
        let targetTime = duration * clampedProgress
        seek(to: targetTime)
    }
    
    /// 볼륨 설정
    func setVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        audioPlaybackUseCase.setVolume(clampedVolume)
        currentVolume = clampedVolume
    }
    
    /// 재생 모드 변경
    func setPlaybackMode(_ mode: SynthesizedAudio.PlaybackMode) {
        playbackMode = mode
    }
    
    /// 에러 메시지 제거
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 재생 상태 구독
        audioPlaybackUseCase.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updatePlaybackState(state)
            }
            .store(in: &cancellables)
        
        // 재생 시간 구독
        audioPlaybackUseCase.timePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
                self?.updateProgress()
            }
            .store(in: &cancellables)
        
        // 재생 진행률 구독
        audioPlaybackUseCase.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progressValue in
                self?.progress = progressValue
            }
            .store(in: &cancellables)
    }
    
    private func playAudio(
        mode: SynthesizedAudio.PlaybackMode,
        audioSession: AudioSession,
        synthesizedAudio: SynthesizedAudio? = nil,
        originalVolume: Float = 1.0,
        synthesizedVolume: Float = 1.0
    ) {
        isLoading = true
        errorMessage = nil
        
        audioPlaybackUseCase.playWithMode(
            mode: mode,
            audioSession: audioSession,
            synthesizedAudio: synthesizedAudio
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                
                if case .failure(let error) = completion {
                    self?.handlePlaybackError(error)
                }
            },
            receiveValue: { [weak self] state in
                self?.updatePlaybackState(state)
            }
        )
        .store(in: &cancellables)
    }
    
    private func updatePlaybackState(_ state: PlaybackState) {
        switch state {
        case .playing:
            isPlaying = true
            isPaused = false
        case .paused:
            isPlaying = false
            isPaused = true
        case .stopped, .finished:
            isPlaying = false
            isPaused = false
        case .buffering:
            // 버퍼링 상태 처리
            break
        }
        
        // 재생 완료 시 처리
        if state == .finished {
            handlePlaybackCompletion()
        }
    }
    
    private func updateProgress() {
        guard duration > 0 else {
            progress = 0.0
            return
        }
        
        progress = currentTime / duration
    }
    
    private func handlePlaybackCompletion() {
        // 재생 완료 시 자동으로 다음 동작 수행 (선택사항)
        // 예: 다시 처음부터 재생, 다음 모드로 전환 등
    }
    
    private func checkPlaybackQuality(_ synthesizedAudio: SynthesizedAudio) {
        let qualityResult = audioPlaybackUseCase.checkPlaybackQuality(synthesizedAudio)
        
        // AudioPlaybackUseCase에서 반환된 tuple을 PlaybackQuality 구조체로 변환
        playbackQuality = PlaybackQuality(
            quality: mapToAudioQualityLevel(qualityResult.quality),
            rms: synthesizedAudio.rmsAmplitude,
            peak: synthesizedAudio.peakAmplitude,
            dynamicRange: 20.0 * log10(synthesizedAudio.peakAmplitude / max(synthesizedAudio.rmsAmplitude, 0.001))
        )
    }
    
    private func mapToAudioQualityLevel(_ playbackQuality: AudioPlaybackUseCase.PlaybackQuality) -> AudioQualityLevel {
        switch playbackQuality {
        case .excellent:
            return .excellent
        case .good:
            return .good
        case .fair:
            return .fair
        case .poor:
            return .poor
        }
    }
    
    private func handleSynthesisError(_ error: AudioSynthesisError) {
        switch error {
        case .invalidMusicNote:
            errorMessage = "유효하지 않은 음계입니다."
        case .synthesisTimedOut:
            errorMessage = "합성 시간이 초과되었습니다."
        case .insufficientMemory:
            errorMessage = "메모리가 부족합니다."
        case .synthesisProcessingFailed:
            errorMessage = "합성 과정에서 오류가 발생했습니다."
        case .unsupportedSynthesisMethod:
            errorMessage = "지원하지 않는 합성 방법입니다."
        case .audioFormatError:
            errorMessage = "오디오 형식 오류입니다."
        case .fileWriteError:
            errorMessage = "파일 저장에 실패했습니다."
        }
    }
    
    private func handlePlaybackError(_ error: AudioPlaybackError) {
        switch error {
        case .audioFileNotFound:
            errorMessage = "오디오 파일을 찾을 수 없습니다."
        case .unsupportedAudioFormat:
            errorMessage = "지원하지 않는 오디오 형식입니다."
        case .playbackFailed:
            errorMessage = "재생에 실패했습니다."
        case .seekFailed:
            errorMessage = "시간 이동에 실패했습니다."
        case .playerInitializationFailed:
            errorMessage = "플레이어 초기화에 실패했습니다."
        case .volumeAdjustmentFailed:
            errorMessage = "볼륨 조정에 실패했습니다."
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types

struct PlaybackQuality {
    let quality: AudioQualityLevel
    let rms: Float
    let peak: Float
    let dynamicRange: Float
    
    var description: String {
        switch quality {
        case .excellent:
            return "우수"
        case .good:
            return "양호"
        case .fair:
            return "보통"
        case .poor:
            return "낮음"
        case .failed:
            return "실패"
        }
    }
    
    var color: Color {
        switch quality {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .red
        case .failed:
            return .gray
        }
    }
} 