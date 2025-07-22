import Foundation
import Combine
import SwiftUI

/// 음절별 오디오 녹음 및 분석 화면의 ViewModel
/// "안녕하세요" → ["안": F4, "녕": G4, "하": A4, "세": B4, "요": C5] 형태로 분석
@MainActor
class RecordingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 녹음 상태
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var permissionStatus: AudioPermissionStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var currentAudioSession: AudioSession?
    @Published var showingPermissionAlert = false
    
    /// 음절별 분석 결과
    @Published var isAnalyzing = false
    @Published var analysisResult: TimeBasedAnalysisResult?
    @Published var syllableSegments: [SyllableSegment] = []
    @Published var analysisProgress: Double = 0.0
    @Published var selectedSyllableIndex: Int?
    
    /// 개별 음절 재생
    @Published var playingSyllableIndex: Int?
    @Published var synthesizedAudios: [Int: SynthesizedAudio] = [:]
    @Published var isGeneratingAudio = false
    
    /// 전체 분석 결과에서 추출한 대표 음계 정보 (ContentView UI에서 사용)
    @Published var detectedNote: String?
    @Published var peakFrequency: Double?
    @Published var frequencyAccuracy: Double?
    
    // MARK: - Private Properties
    
    private let recordAudioUseCase: RecordAudioUseCase
    private let syllableAnalysisUseCase: SyllableAnalysisUseCase
    private let synthesizeAudioUseCase: SynthesizeAudioUseCase
    private let audioPlaybackUseCase: AudioPlaybackUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var recordingTimeString: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var canStartRecording: Bool {
        return permissionStatus == .granted && !isRecording && !isAnalyzing
    }
    
    var recordButtonTitle: String {
        if isAnalyzing {
            return "분석 중..."
        } else if isRecording {
            return "녹음 중지"
        } else if permissionStatus == .granted {
            return "녹음 시작"
        } else {
            return "권한 필요"
        }
    }
    
    var statusMessage: String {
        if isAnalyzing {
            return "주파수 분석 중... \(String(format: "%.0f", analysisProgress * 100))%"
        } else if let result = analysisResult, result.isSuccessful {
            if let note = detectedNote, let freq = peakFrequency {
                return "감지된 음계: \(note) (\(String(format: "%.1f", freq))Hz)"
            } else {
                return "분석 완료"
            }
        } else if isRecording {
            return "녹음 중... (최대 60초)"
        } else {
            return "녹음 버튼을 눌러 시작하세요"
        }
    }
    
    var hasAnalysisResult: Bool {
        return analysisResult?.isSuccessful == true && !syllableSegments.isEmpty
    }
    
    var syllableNotes: [String] {
        return syllableSegments.compactMap { $0.noteName }
    }
    
    var analysisQuality: String {
        guard let result = analysisResult else { return "분석 안됨" }
        return result.qualityGrade.koreanName
    }
    
    var analysisConfidence: Double {
        return analysisResult?.overallConfidence ?? 0.0
    }
    
    // MARK: - Initialization
    
    init(
        recordAudioUseCase: RecordAudioUseCase = RecordAudioUseCase(
            audioRepository: AudioRecordingRepositoryImpl()
        ),
        syllableAnalysisUseCase: SyllableAnalysisUseCase = SyllableAnalysisUseCaseImpl(
            audioAnalysisRepository: AudioAnalysisRepositoryImpl.shared()
        ),
        synthesizeAudioUseCase: SynthesizeAudioUseCase = SynthesizeAudioUseCase(
            audioSynthesisRepository: AudioSynthesizer()
        ),
        audioPlaybackUseCase: AudioPlaybackUseCase = AudioPlaybackUseCase(
            audioPlaybackRepository: AudioPlayer()
        )
    ) {
        self.recordAudioUseCase = recordAudioUseCase
        self.syllableAnalysisUseCase = syllableAnalysisUseCase
        self.synthesizeAudioUseCase = synthesizeAudioUseCase
        self.audioPlaybackUseCase = audioPlaybackUseCase
        setupBindings()
        checkInitialPermissionStatus()
    }
    
    // MARK: - Public Methods
    
    /// 녹음 버튼 액션
    func recordButtonTapped() {
        print("🎤 녹음 버튼 클릭 - 현재 상태: \(isRecording ? "녹음 중" : "중지됨"), 권한: \(permissionStatus)")
        
        guard permissionStatus == .granted else {
            print("❌ 권한이 필요합니다. 권한 알림 표시...")
            showingPermissionAlert = true
            return
        }
        
        if isRecording {
            print("🎤 녹음 중지 시도...")
            stopRecording()
        } else {
            print("🎤 녹음 시작 시도...")
            startRecording()
        }
    }
    
    /// 권한 요청
    func requestPermission() {
        print("🔐 권한 요청 시작...")
        
        recordAudioUseCase.checkRecordingReadiness()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("❌ 권한 요청 실패: \(error)")
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] granted in
                    if granted {
                        print("✅ 권한 승인됨")
                        self?.permissionStatus = .granted
                    } else {
                        print("❌ 권한 거부됨")
                        self?.permissionStatus = .denied
                        self?.showingPermissionAlert = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// 음절별 분석 시작
    func startSyllableAnalysis() {
        guard let audioSession = currentAudioSession else {
            errorMessage = "분석할 오디오가 없습니다."
            return
        }
        
        clearAnalysisResults()
        isAnalyzing = true
        analysisProgress = 0.0
        
        // 진행률 시뮬레이션
        startProgressSimulation()
        
        Task {
            do {
                let result = try await syllableAnalysisUseCase.analyzeSyllables(from: audioSession)
                
                await MainActor.run {
                    self.processAnalysisResult(result)
                    self.isAnalyzing = false
                    self.analysisProgress = 1.0
                }
                
            } catch {
                await MainActor.run {
                    self.handleAnalysisError(error)
                    self.isAnalyzing = false
                    self.analysisProgress = 1.0
                }
            }
        }
    }
    
    /// 개별 음절 선택
    func selectSyllable(at index: Int) {
        guard index >= 0 && index < syllableSegments.count else { return }
        selectedSyllableIndex = index
        print("🔍 음절 선택: \(index) - \(syllableSegments[index].noteName ?? "N/A")")
    }
    
    /// 개별 음절 재생
    func playSyllable(at index: Int) {
        guard index >= 0 && index < syllableSegments.count else { return }
        
        let segment = syllableSegments[index]
        guard let musicNote = segment.musicNote else {
            errorMessage = "재생할 음계가 없습니다."
            return
        }
        
        // 기존 재생 중지
        stopAllPlayback()
        
        // 합성 오디오가 없으면 생성
        if synthesizedAudios[index] == nil {
            generateSynthesizedAudio(for: index, musicNote: musicNote)
        } else {
            // 바로 재생
            playGeneratedAudio(at: index)
        }
    }
    
    /// 전체 음절 순차 재생
    func playAllSyllables() {
        guard !syllableSegments.isEmpty else {
            errorMessage = "재생할 음절이 없습니다."
            return
        }
        
        stopAllPlayback()
        
        // 모든 음절의 합성 오디오 생성 및 순차 재생
        generateAllSynthesizedAudios { [weak self] in
            self?.startSequentialPlayback()
        }
    }
    
    /// 원본 오디오 재생
    func playOriginalAudio() {
        guard let audioSession = currentAudioSession else {
            errorMessage = "재생할 원본 오디오가 없습니다."
            return
        }
        
        stopAllPlayback()
        
        audioPlaybackUseCase.playWithMode(
            mode: .originalOnly,
            audioSession: audioSession,
            synthesizedAudio: nil
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handlePlaybackError(error)
                }
            },
            receiveValue: { _ in
                // 재생 시작됨
                print("🎵 원본 오디오 재생 시작")
            }
        )
        .store(in: &cancellables)
    }
    
    /// 모든 재생 중지
    func stopAllPlayback() {
        audioPlaybackUseCase.stop()
        playingSyllableIndex = nil
    }
    
    /// 분석 결과 초기화
    func clearAnalysisResults() {
        analysisResult = nil
        syllableSegments = []
        selectedSyllableIndex = nil
        playingSyllableIndex = nil
        synthesizedAudios.removeAll()
        analysisProgress = 0.0
        detectedNote = nil
        peakFrequency = nil
        frequencyAccuracy = nil
    }
    
    /// 에러 메시지 제거
    func clearError() {
        errorMessage = nil
    }
    
    /// 녹음 시작
    func startRecording() {
        clearError()
        clearAnalysisResults()
        
        recordAudioUseCase.startRecording()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                        self?.isRecording = false
                    }
                },
                receiveValue: { [weak self] audioSession in
                    self?.currentAudioSession = audioSession
                    print("🎤 녹음 시작됨: \(audioSession.id)")
                }
            )
            .store(in: &cancellables)
    }
    
    /// 녹음 중지
    func stopRecording() {
        recordAudioUseCase.stopRecording()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                    self?.isRecording = false
                },
                receiveValue: { [weak self] audioSession in
                    self?.currentAudioSession = audioSession
                    self?.recordingDuration = 0
                    print("🎤 녹음 완료: \(audioSession.duration)초, 파일: \(audioSession.audioFileURL?.lastPathComponent ?? "없음")")
                    
                    // 녹음 완료 후 자동으로 음절별 분석 시작
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.startSyllableAnalysis()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// 녹음 토글 (시작/중지)
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    /// 세션 리셋
    func resetSession() {
        stopAllPlayback()
        clearAnalysisResults()
        clearError()
        currentAudioSession = nil
        recordingDuration = 0
        isRecording = false
        isAnalyzing = false
        print("🔄 세션 리셋됨")
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 녹음 상태 감지
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if self.recordAudioUseCase.isCurrentlyRecording {
                    self.isRecording = true
                    self.recordingDuration = self.recordAudioUseCase.currentDuration
                } else if self.isRecording {
                    // 녹음이 중지되었을 때
                    self.isRecording = false
                }
            }
            .store(in: &cancellables)
        
        // 재생 상태 감지
        audioPlaybackUseCase.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                if state == .finished || state == .stopped {
                    self?.playingSyllableIndex = nil
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkInitialPermissionStatus() {
        recordAudioUseCase.checkRecordingReadiness()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        switch error {
                        case .permissionDenied:
                            self?.permissionStatus = .denied
                        default:
                            self?.permissionStatus = .notDetermined
                        }
                    }
                },
                receiveValue: { [weak self] granted in
                    self?.permissionStatus = granted ? .granted : .denied
                }
            )
            .store(in: &cancellables)
    }
    
    private func processAnalysisResult(_ result: TimeBasedAnalysisResult) {
        analysisResult = result
        syllableSegments = result.validSpeechSegments
        
        // ContentView UI를 위한 대표 음계 정보 추출
        extractRepresentativeNote(from: result)
        
        print("🎵 음절별 분석 완료:")
        print("   - 총 세그먼트: \(result.syllableSegments.count)개")
        print("   - 유효 음절: \(syllableSegments.count)개") 
        print("   - 음계들: \(syllableNotes.joined(separator: " → "))")
        print("   - 품질: \(result.qualityGrade.koreanName)")
        print("   - 신뢰도: \(String(format: "%.1f%%", result.overallConfidence * 100))")
        
        if let note = detectedNote, let freq = peakFrequency {
            print("   - 대표 음계: \(note) (\(String(format: "%.1f", freq))Hz)")
        }
    }
    
    /// 분석 결과에서 가장 대표적인 음계 정보를 추출
    private func extractRepresentativeNote(from result: TimeBasedAnalysisResult) {
        let validSegments = result.validSpeechSegments
        
        guard !validSegments.isEmpty else {
            detectedNote = nil
            peakFrequency = nil
            frequencyAccuracy = nil
            return
        }
        
        // 모든 유효한 주파수들을 수집
        let allFrequencies = validSegments.compactMap { $0.primaryFrequency }
        
        guard !allFrequencies.isEmpty else {
            detectedNote = nil
            peakFrequency = nil
            frequencyAccuracy = nil
            return
        }
        
        // 평균 주파수 계산
        let averageFrequency = allFrequencies.reduce(0.0, +) / Double(allFrequencies.count)
        
        // 가장 가까운 음계 찾기
        if let representativeNote = MusicNote.from(frequency: averageFrequency) {
            detectedNote = representativeNote.name
            peakFrequency = averageFrequency
            
            // 정확도 계산 (실제 주파수와 표준 음계 주파수의 차이)
            let standardFrequency = representativeNote.frequency
            let accuracyPercentage = max(0.0, 1.0 - abs(averageFrequency - standardFrequency) / standardFrequency)
            frequencyAccuracy = accuracyPercentage
        } else {
            detectedNote = nil
            peakFrequency = averageFrequency
            frequencyAccuracy = nil
        }
    }
    
    private func generateSynthesizedAudio(for index: Int, musicNote: MusicNote) {
        isGeneratingAudio = true
        
        synthesizeAudioUseCase.synthesizeFromFrequency(
            frequency: musicNote.frequency,
            duration: 1.0,
            amplitude: 0.7,
            method: .harmonic
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] (completion: Subscribers.Completion<AudioSynthesisError>) in
                self?.isGeneratingAudio = false
                
                if case .failure(let error) = completion {
                    print("❌ 음절 \(index) 합성 실패: \(error)")
                    self?.errorMessage = "음성 합성에 실패했습니다."
                }
            },
            receiveValue: { [weak self] (synthesizedAudio: SynthesizedAudio) in
                self?.synthesizedAudios[index] = synthesizedAudio
                self?.playGeneratedAudio(at: index)
                print("✅ 음절 \(index) 합성 완료: \(musicNote.name)")
            }
        )
        .store(in: &cancellables)
    }
    
    private func playGeneratedAudio(at index: Int) {
        guard let synthesizedAudio = synthesizedAudios[index] else { return }
        
        playingSyllableIndex = index
        
        // 임시 오디오 세션 생성
        let tempSession = AudioSession(
            duration: synthesizedAudio.duration,
            sampleRate: synthesizedAudio.sampleRate
        )
        
        audioPlaybackUseCase.playWithMode(
            mode: .synthesizedOnly,
            audioSession: tempSession,
            synthesizedAudio: synthesizedAudio
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handlePlaybackError(error)
                    self?.playingSyllableIndex = nil
                }
            },
            receiveValue: { _ in
                print("🎵 음절 \(index) 재생 시작")
            }
        )
        .store(in: &cancellables)
    }
    
    private func generateAllSynthesizedAudios(completion: @escaping () -> Void) {
        let musicNotes = syllableSegments.compactMap { $0.musicNote }
        guard !musicNotes.isEmpty else {
            completion()
            return
        }
        
        isGeneratingAudio = true
        
        // 모든 음절을 하나의 시퀀스로 합성
        let frequencies = musicNotes.map { $0.frequency }
        synthesizeAudioUseCase.synthesizeSequenceFromFrequencies(
            frequencies: frequencies,
            segmentDuration: 0.8,
            amplitude: 0.7,
            method: .harmonic
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] (completionResult: Subscribers.Completion<AudioSynthesisError>) in
                self?.isGeneratingAudio = false
                
                if case .failure(let error) = completionResult {
                    print("❌ 전체 시퀀스 합성 실패: \(error)")
                    self?.errorMessage = "음성 합성에 실패했습니다."
                }
            },
            receiveValue: { [weak self] (synthesizedAudio: SynthesizedAudio) in
                // 전체 시퀀스를 인덱스 -1에 저장
                self?.synthesizedAudios[-1] = synthesizedAudio
                completion()
                print("✅ 전체 시퀀스 합성 완료")
            }
        )
        .store(in: &cancellables)
    }
    
    private func startSequentialPlayback() {
        guard let sequenceAudio = synthesizedAudios[-1] else { return }
        
        let tempSession = AudioSession(
            duration: sequenceAudio.duration,
            sampleRate: sequenceAudio.sampleRate
        )
        
        audioPlaybackUseCase.playWithMode(
            mode: .synthesizedOnly,
            audioSession: tempSession,
            synthesizedAudio: sequenceAudio
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.handlePlaybackError(error)
                }
            },
            receiveValue: { _ in
                print("🎵 전체 시퀀스 재생 시작")
            }
        )
        .store(in: &cancellables)
    }
    
    private func startProgressSimulation() {
        // 분석 진행률 시뮬레이션
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .prefix(while: { [weak self] _ in
                self?.isAnalyzing == true && self?.analysisProgress ?? 1.0 < 0.9
            })
            .sink { [weak self] _ in
                self?.analysisProgress += 0.03
            }
            .store(in: &cancellables)
    }
    
    private func handleError(_ error: AudioRecordingError) {
        switch error {
        case .permissionDenied:
            errorMessage = "마이크 사용 권한이 필요합니다."
            permissionStatus = .denied
            showingPermissionAlert = true
        case .recordingFailed:
            errorMessage = "녹음에 실패했습니다."
        case .recordingInProgress:
            errorMessage = "이미 녹음 중입니다."
        case .maxDurationExceeded:
            errorMessage = "최대 녹음 시간을 초과했습니다."
        case .invalidAudioFormat:
            errorMessage = "지원하지 않는 오디오 형식입니다."
        case .fileSystemError:
            errorMessage = "파일 저장에 실패했습니다."
        }
    }
    
    private func handleAnalysisError(_ error: Error) {
        if let audioError = error as? AudioAnalysisError {
            switch audioError {
            case .invalidAudioData:
                errorMessage = "오디오 데이터가 유효하지 않습니다."
            case .analysisTimeout:
                errorMessage = "분석 시간이 초과되었습니다."
            case .insufficientData:
                errorMessage = "분석하기에 충분한 데이터가 없습니다."
            case .fftProcessingFailed:
                errorMessage = "주파수 분석에 실패했습니다."
            case .fileReadError:
                errorMessage = "오디오 파일을 읽을 수 없습니다."
            }
        } else {
            errorMessage = "분석 중 오류가 발생했습니다: \(error.localizedDescription)"
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
}

// MARK: - Extensions

extension RecordingViewModel {
    
    /// 음악 스케일 추천을 위한 데이터 준비
    func prepareScaleRecommendationData() -> [Int] {
        guard let result = analysisResult else { return [] }
        return result.getScaleAnalysisData()
    }
    
    /// 특정 품질 이상의 음절만 필터링
    func getHighQualitySyllables() -> [SyllableSegment] {
        return syllableSegments.filter { $0.qualityGrade != .poor }
    }
    
    /// 분석 통계 정보
    var analysisStatistics: String {
        guard let result = analysisResult else { return "분석 데이터 없음" }
        
        let totalSegments = result.syllableSegments.count
        let validSegments = result.validSpeechSegments.count
        let avgConfidence = result.overallConfidence * 100
        
        return """
        총 세그먼트: \(totalSegments)개
        유효 음절: \(validSegments)개
        평균 신뢰도: \(String(format: "%.1f", avgConfidence))%
        분석 품질: \(result.qualityGrade.koreanName)
        """
    }
    
    /// 선택된 스케일 설정
    func setSelectedScale(_ scale: MusicScale) {
        // 선택된 스케일을 현재 세션에 연결
        print("🎼 스케일 선택됨: \(scale.name)")
        
        // 사용자에게 피드백 제공
        if scale.notes.count > 0 {
            let noteNames = scale.notes.prefix(3).map { $0.name }.joined(separator: ", ")
            infoMessage = "\(scale.name) 스케일이 선택되었습니다 (\(noteNames)...)"
            
            // 3초 후 메시지 자동 제거
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.infoMessage = nil
            }
        }
    }
    
    /// 에러 메시지 설정
    func setErrorMessage(_ message: String) {
        errorMessage = message
        
        // 5초 후 자동으로 에러 메시지 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if self.errorMessage == message {
                self.errorMessage = nil
            }
        }
    }
    
    /// 정보 메시지 설정
    func setInfoMessage(_ message: String) {
        infoMessage = message
        
        // 3초 후 자동으로 정보 메시지 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.infoMessage == message {
                self.infoMessage = nil
            }
        }
    }
    
    /// 에러 메시지 제거
    func clearErrorMessage() {
        errorMessage = nil
    }
    
    /// 정보 메시지 제거
    func clearInfoMessage() {
        infoMessage = nil
    }
} 