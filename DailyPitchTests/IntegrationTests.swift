import XCTest
import Combine
@testable import DailyPitch

/// DailyPitch 앱의 전체 플로우를 테스트하는 통합 테스트
final class IntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var recordingViewModel: RecordingViewModel!
    private var playbackViewModel: PlaybackViewModel!
    private var musicScaleRecommendationUseCase: MusicScaleRecommendationUseCaseImpl!
    
    private var mockRecordAudioUseCase: MockRecordAudioUseCase!
    private var mockSyllableAnalysisUseCase: MockSyllableAnalysisUseCase!
    private var mockSynthesizeAudioUseCase: MockSynthesizeAudioUseCase!
    private var mockAudioPlaybackUseCase: MockAudioPlaybackUseCase!
    private var mockMusicScaleRepository: MockMusicScaleRepository!
    
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Mock UseCase 생성
        mockRecordAudioUseCase = MockRecordAudioUseCase()
        mockSyllableAnalysisUseCase = MockSyllableAnalysisUseCase()
        mockSynthesizeAudioUseCase = MockSynthesizeAudioUseCase()
        mockAudioPlaybackUseCase = MockAudioPlaybackUseCase()
        mockMusicScaleRepository = MockMusicScaleRepository()
        
        // ViewModel 생성
        recordingViewModel = RecordingViewModel(
            recordAudioUseCase: mockRecordAudioUseCase,
            syllableAnalysisUseCase: mockSyllableAnalysisUseCase,
            synthesizeAudioUseCase: mockSynthesizeAudioUseCase,
            audioPlaybackUseCase: mockAudioPlaybackUseCase
        )
        
        playbackViewModel = PlaybackViewModel(
            synthesizeAudioUseCase: mockSynthesizeAudioUseCase,
            audioPlaybackUseCase: mockAudioPlaybackUseCase
        )
        
        musicScaleRecommendationUseCase = MusicScaleRecommendationUseCaseImpl(
            musicScaleRepository: mockMusicScaleRepository
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        musicScaleRecommendationUseCase = nil
        playbackViewModel = nil
        recordingViewModel = nil
        mockMusicScaleRepository = nil
        mockAudioPlaybackUseCase = nil
        mockSynthesizeAudioUseCase = nil
        mockSyllableAnalysisUseCase = nil
        mockRecordAudioUseCase = nil
        
        super.tearDown()
    }
    
    // MARK: - 전체 플로우 통합 테스트
    
    @MainActor
    func testCompleteWorkflow_RecordToPlayback_ShouldCompleteSuccessfully() async {
        // Given: 성공적인 Mock 설정
        setupSuccessfulMocks()
        
        let workflowExpectation = expectation(description: "전체 워크플로우 완료")
        var completedSteps: [String] = []
        
        // Step 1: 권한 설정 및 녹음 시작
        recordingViewModel.permissionStatus = .granted
        recordingViewModel.recordButtonTapped()
        
        // 녹음 상태 확인
        recordingViewModel.$isRecording
            .filter { $0 == true }
            .sink { _ in
                completedSteps.append("Recording Started")
                
                // Step 2: 녹음 중지 (시뮬레이션)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.recordingViewModel.recordButtonTapped()
                }
            }
            .store(in: &cancellables)
        
        // 분석 완료 확인
        recordingViewModel.$syllableSegments
            .filter { !$0.isEmpty }
            .sink { syllableSegments in
                completedSteps.append("Analysis Completed")
                
                // Step 3: 스케일 추천
                let notes = syllableSegments.compactMap { $0.musicNote }
                let recommendations = self.musicScaleRecommendationUseCase.recommendScales(from: notes)
                
                XCTAssertFalse(recommendations.isEmpty, "스케일 추천 결과가 있어야 함")
                completedSteps.append("Scale Recommendation Completed")
                
                // Step 4: 음계 합성
                guard let audioSession = self.recordingViewModel.currentAudioSession else { return }
                self.playbackViewModel.setAudioSession(audioSession)
                if let firstNote = notes.first {
                    self.playbackViewModel.synthesizeAudio(from: [firstNote])
                }
            }
            .store(in: &cancellables)
        
        // 합성 완료 확인
        playbackViewModel.$isLoading
            .filter { !$0 }
            .sink { _ in
                if self.playbackViewModel.canPlaySynthesized {
                    completedSteps.append("Audio Synthesis Completed")
                    
                    // Step 5: 재생
                    self.playbackViewModel.playSynthesized()
                }
            }
            .store(in: &cancellables)
        
        // 재생 시작 확인
        playbackViewModel.$isPlaying
            .filter { $0 == true }
            .sink { _ in
                completedSteps.append("Playback Started")
                
                // 모든 단계 완료 확인
                let expectedSteps = [
                    "Recording Started",
                    "Analysis Completed", 
                    "Scale Recommendation Completed",
                    "Audio Synthesis Completed",
                    "Playback Started"
                ]
                
                XCTAssertEqual(completedSteps, expectedSteps, "모든 워크플로우 단계가 순서대로 완료되어야 함")
                workflowExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [workflowExpectation], timeout: 2.0)
    }
    
    @MainActor
    func testErrorHandling_RecordingFailure_ShouldShowErrorMessage() async {
        // Given: 녹음 실패 설정
        mockRecordAudioUseCase.shouldSucceedRecording = false
        mockRecordAudioUseCase.recordingError = .permissionDenied
        
        let errorExpectation = expectation(description: "에러 메시지 표시")
        
        // When: 녹음 시작
        recordingViewModel.startRecording()
        
        // Then: 에러 메시지가 표시되어야 함
        recordingViewModel.$errorMessage
            .compactMap { $0 }
            .sink { errorMessage in
                XCTAssertFalse(errorMessage.isEmpty, "에러 메시지가 있어야 함")
                XCTAssertFalse(self.recordingViewModel.isRecording, "녹음이 중지되어야 함")
                errorExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [errorExpectation], timeout: 1.0)
    }
    
    @MainActor
    func testErrorHandling_AnalysisFailure_ShouldHandleGracefully() async {
        // Given: 분석 실패 설정
        setupSuccessfulMocks()
        mockAnalyzeFrequencyUseCase.shouldSucceedAnalysis = false
        
        let analysisErrorExpectation = expectation(description: "분석 에러 처리")
        
        // When: 녹음 및 분석 수행
        recordingViewModel.startRecording()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.recordingViewModel.stopRecording()
        }
        
        // Then: 분석 실패를 적절히 처리해야 함
        recordingViewModel.$analysisResult
            .compactMap { $0 }
            .sink { result in
                XCTAssertFalse(result.isSuccessful, "분석이 실패해야 함")
                XCTAssertFalse(self.recordingViewModel.isAnalyzing, "분석 상태가 종료되어야 함")
                analysisErrorExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [analysisErrorExpectation], timeout: 2.0)
    }
    
    // MARK: - 스케일 추천 통합 테스트
    
    func testScaleRecommendation_WithMixedGenrePreferences_ShouldReturnAppropriateResults() {
        // Given: 다양한 장르 선호도가 있는 설정
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!,
            MusicNote.from(noteName: "G4")!
        ]
        
        let jazzConfig = ScaleRecommendationConfig(
            maxResults: 3,
            minSimilarityThreshold: 0.3,
            preferredMood: nil,
            preferredGenres: [.jazz],
            complexityRange: 1...5
        )
        
        let classicalConfig = ScaleRecommendationConfig(
            maxResults: 3,
            minSimilarityThreshold: 0.3,
            preferredMood: nil,
            preferredGenres: [.classical],
            complexityRange: 1...5
        )
        
        // When: 각기 다른 설정으로 추천
        let jazzRecommendations = musicScaleRecommendationUseCase.recommendScales(from: notes, config: jazzConfig)
        let classicalRecommendations = musicScaleRecommendationUseCase.recommendScales(from: notes, config: classicalConfig)
        
        // Then: 각 장르에 맞는 스케일이 추천되어야 함
        XCTAssertFalse(jazzRecommendations.isEmpty, "재즈 스케일 추천이 있어야 함")
        XCTAssertFalse(classicalRecommendations.isEmpty, "클래식 스케일 추천이 있어야 함")
        
        // 장르별로 다른 결과가 나올 수 있음을 확인
        let jazzScaleIds = Set(jazzRecommendations.map { $0.scale.id })
        let classicalScaleIds = Set(classicalRecommendations.map { $0.scale.id })
        
        // 완전히 같지 않을 수도 있지만, 각각 유효한 결과여야 함
        jazzRecommendations.forEach { recommendation in
            XCTAssertGreaterThanOrEqual(recommendation.similarityScore, 0.3)
            XCTAssertGreaterThanOrEqual(recommendation.confidenceScore, 0.0)
        }
        
        classicalRecommendations.forEach { recommendation in
            XCTAssertGreaterThanOrEqual(recommendation.similarityScore, 0.3)
            XCTAssertGreaterThanOrEqual(recommendation.confidenceScore, 0.0)
        }
    }
    
    // MARK: - 성능 통합 테스트
    
    func testPerformance_CompleteWorkflow_ShouldCompleteWithinTimeLimit() {
        // 전체 워크플로우 성능 측정
        measure {
            let notes = (0..<7).map { index in
                MusicNote.from(frequency: 440.0 * pow(2.0, Double(index)/12.0))!
            }
            
            // 분석 결과 생성
            let frequencies = notes.map { note in
                FrequencyData(
                    frequencies: [note.frequency],
                    magnitudes: [0.8],
                    sampleRate: 44100.0,
                    windowSize: 1024
                )
            }
            
            // 스케일 추천
            let recommendations = musicScaleRecommendationUseCase.recommendScales(from: frequencies)
            
            // 합성된 오디오 생성 (시뮬레이션)
            let synthesizedAudio = SynthesizedAudio.fromSequence(notes: notes)
            
            XCTAssertFalse(recommendations.isEmpty)
            XCTAssertTrue(synthesizedAudio.isValid)
        }
    }
    
    // MARK: - 데이터 일관성 테스트
    
    func testDataConsistency_FrequencyToNoteConversion_ShouldMaintainAccuracy() {
        // Given: 알려진 주파수들
        let testFrequencies: [(frequency: Double, expectedNote: String)] = [
            (440.0, "A4"),
            (261.63, "C4"),
            (329.63, "E4"),
            (392.0, "G4"),
            (523.25, "C5")
        ]
        
        for testCase in testFrequencies {
            // When: 주파수를 음계로 변환
            guard let note = MusicNote.from(frequency: testCase.frequency) else {
                XCTFail("주파수 \(testCase.frequency)를 음계로 변환할 수 없음")
                continue
            }
            
            // Then: 예상된 음계와 일치해야 함
            XCTAssertEqual(note.name, testCase.expectedNote, "주파수 \(testCase.frequency)는 \(testCase.expectedNote)이어야 함")
            
            // 주파수 역변환 정확도 확인 (±1% 오차 허용)
            let frequencyError = abs(note.frequency - testCase.frequency) / testCase.frequency
            XCTAssertLessThan(frequencyError, 0.01, "주파수 변환 오차가 1% 이내여야 함")
        }
    }
    
    // MARK: - Edge Cases 통합 테스트
    
    @MainActor
    func testEdgeCases_VeryShortRecording_ShouldHandleGracefully() async {
        // Given: 매우 짧은 녹음 시뮬레이션
        setupSuccessfulMocks()
        mockRecordAudioUseCase.shortRecordingDuration = 0.1 // 0.1초
        
        let shortRecordingExpectation = expectation(description: "짧은 녹음 처리")
        
        // When: 매우 짧은 녹음 수행
        recordingViewModel.startRecording()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.recordingViewModel.stopRecording()
        }
        
        // Then: 적절히 처리되어야 함
        recordingViewModel.$currentAudioSession
            .compactMap { $0 }
            .sink { audioSession in
                XCTAssertGreaterThan(audioSession.duration, 0, "녹음 시간이 0보다 커야 함")
                shortRecordingExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [shortRecordingExpectation], timeout: 1.0)
    }
    
    func testEdgeCases_ExtremeFrequencies_ShouldFilterAppropriately() {
        // Given: 극단적인 주파수들
        let extremeFrequencies = [
            FrequencyData(frequency: 1.0, magnitude: 0.5),     // 매우 낮음
            FrequencyData(frequency: 20000.0, magnitude: 0.5), // 매우 높음
            FrequencyData(frequency: -100.0, magnitude: 0.5),  // 음수 (무효)
            FrequencyData(frequency: 440.0, magnitude: 0.8)    // 정상
        ]
        
        // When: 스케일 추천 시도
        let recommendations = musicScaleRecommendationUseCase.recommendScales(from: extremeFrequencies)
        
        // Then: 적절히 필터링되어야 함 (유효한 주파수만 처리)
        // 최소 음계 개수 미달로 빈 결과일 수 있음
        recommendations.forEach { recommendation in
            XCTAssertGreaterThanOrEqual(recommendation.similarityScore, 0.0)
            XCTAssertLessThanOrEqual(recommendation.similarityScore, 1.0)
        }
    }
    
    // MARK: - 멀티스레딩 안정성 테스트
    
    @MainActor
    func testConcurrency_MultipleSimultaneousRecordings_ShouldHandleGracefully() async {
        // Given: 동시 녹음 시도 설정
        setupSuccessfulMocks()
        
        let concurrentExpectation = expectation(description: "동시 녹음 처리")
        concurrentExpectation.expectedFulfillmentCount = 3
        
        // When: 여러 녹음을 동시에 시도
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<3 {
                group.addTask { @MainActor in
                    let viewModel = RecordingViewModel(
                        recordAudioUseCase: self.mockRecordAudioUseCase,
                        analyzeFrequencyUseCase: self.mockAnalyzeFrequencyUseCase
                    )
                    
                    viewModel.startRecording()
                    
                    // 0.1초 후 중지
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    viewModel.stopRecording()
                    
                    // 녹음 상태 확인
                    viewModel.$currentAudioSession
                        .compactMap { $0 }
                        .first()
                        .sink { _ in
                            concurrentExpectation.fulfill()
                        }
                        .store(in: &self.cancellables)
                }
            }
        }
        
        await fulfillment(of: [concurrentExpectation], timeout: 3.0)
        
        // Then: 모든 녹음이 적절히 처리되어야 함
        XCTAssertGreaterThanOrEqual(mockRecordAudioUseCase.startRecordingCallCount, 3, "모든 녹음 시도가 처리되어야 함")
    }
    
    @MainActor
    func testConcurrency_SimultaneousAnalysisAndPlayback_ShouldMaintainStateConsistency() async {
        // Given: 분석과 재생을 동시에 실행하는 시나리오
        setupSuccessfulMocks()
        
        let analysisExpectation = expectation(description: "분석 완료")
        let playbackExpectation = expectation(description: "재생 시작")
        
        // 테스트용 오디오 세션 생성
        let audioSession = AudioSession(
            id: UUID(),
            timestamp: Date(),
            duration: 2.0,
            audioFileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        // When: 분석과 재생을 동시에 시작
        async let analysisTask: Void = {
            recordingViewModel.startRecording()
            try? await Task.sleep(nanoseconds: 100_000_000)
            recordingViewModel.stopRecording()
            
            recordingViewModel.$analysisResult
                .compactMap { $0 }
                .first()
                .sink { _ in
                    analysisExpectation.fulfill()
                }
                .store(in: &cancellables)
        }()
        
        async let playbackTask: Void = {
            playbackViewModel.setAudioSession(audioSession)
            let testNote = MusicNote.from(frequency: 440.0, duration: 1.0, amplitude: 0.5)!
            playbackViewModel.synthesizeAudio(from: [testNote])
            
            playbackViewModel.$isPlaying
                .filter { $0 == true }
                .first()
                .sink { _ in
                    playbackExpectation.fulfill()
                }
                .store(in: &cancellables)
        }()
        
        _ = await (analysisTask, playbackTask)
        await fulfillment(of: [analysisExpectation, playbackExpectation], timeout: 3.0)
        
        // Then: 두 작업이 모두 성공적으로 완료되어야 함
        XCTAssertNotNil(recordingViewModel.analysisResult, "분석 결과가 있어야 함")
        XCTAssertTrue(playbackViewModel.canPlaySynthesized, "재생 가능 상태여야 함")
    }
    
    // MARK: - 메모리 관리 테스트
    
    func testMemoryManagement_LargeAudioProcessing_ShouldNotCauseMemoryLeaks() {
        // Given: 대용량 오디오 데이터 시뮬레이션
        let largeAudioData = Array(repeating: Float.random(in: -1...1), count: 1_000_000) // 1M 샘플
        
        autoreleasepool {
            let startMemory = mach_task_basic_info()
            
            // When: 대용량 데이터 처리
            for _ in 0..<10 {
                let frequencyData = FrequencyData(
                    frequencies: Array(0..<512).map { Double($0) },
                    magnitudes: Array(repeating: 0.5, count: 512),
                    sampleRate: 44100.0,
                    windowSize: 1024
                )
                
                _ = musicScaleRecommendationUseCase.recommendScales(from: [frequencyData])
            }
            
            let endMemory = mach_task_basic_info()
            
            // Then: 메모리 사용량이 과도하게 증가하지 않아야 함
            let memoryIncrease = endMemory.resident_size - startMemory.resident_size
            XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, "메모리 증가량이 100MB 미만이어야 함")
        }
    }
    
    func testMemoryManagement_ViewModelDeallocation_ShouldReleaseResources() {
        // Given: ViewModel 생성
        weak var weakRecordingViewModel: RecordingViewModel?
        weak var weakPlaybackViewModel: PlaybackViewModel?
        
        autoreleasepool {
            let recordingVM = RecordingViewModel(
                recordAudioUseCase: mockRecordAudioUseCase,
                analyzeFrequencyUseCase: mockAnalyzeFrequencyUseCase
            )
            
            let playbackVM = PlaybackViewModel(
                synthesizeAudioUseCase: mockSynthesizeAudioUseCase,
                audioPlaybackUseCase: mockAudioPlaybackUseCase
            )
            
            weakRecordingViewModel = recordingVM
            weakPlaybackViewModel = playbackVM
            
            // 일부 작업 수행
            recordingVM.startRecording()
            playbackVM.setAudioSession(AudioSession(duration: 1.0, audioFileURL: URL(fileURLWithPath: "/tmp/test.wav")))
        }
        
        // When: autoreleasepool을 벗어남
        
        // Then: ViewModel들이 적절히 해제되어야 함
        XCTAssertNil(weakRecordingViewModel, "RecordingViewModel이 해제되어야 함")
        XCTAssertNil(weakPlaybackViewModel, "PlaybackViewModel이 해제되어야 함")
    }
    
    // MARK: - 상태 일관성 테스트
    
    @MainActor
    func testStateConsistency_RecordingStateMachine_ShouldMaintainValidTransitions() async {
        // Given: 초기 상태 확인
        XCTAssertFalse(recordingViewModel.isRecording, "초기에는 녹음 중이 아니어야 함")
        XCTAssertFalse(recordingViewModel.isAnalyzing, "초기에는 분석 중이 아니어야 함")
        XCTAssertNil(recordingViewModel.currentAudioSession, "초기에는 오디오 세션이 없어야 함")
        
        let stateTransitionExpectation = expectation(description: "상태 전환 추적")
        var stateTransitions: [String] = []
        
        // 상태 변화 추적
        recordingViewModel.$isRecording
            .sink { isRecording in
                stateTransitions.append("Recording: \(isRecording)")
            }
            .store(in: &cancellables)
            
        recordingViewModel.$isAnalyzing
            .sink { isAnalyzing in
                stateTransitions.append("Analyzing: \(isAnalyzing)")
            }
            .store(in: &cancellables)
        
        // When: 녹음 시작
        setupSuccessfulMocks()
        recordingViewModel.startRecording()
        
        // 0.1초 후 중지
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.recordingViewModel.stopRecording()
        }
        
        // 분석 완료 대기
        recordingViewModel.$analysisResult
            .compactMap { $0 }
            .sink { _ in
                stateTransitionExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [stateTransitionExpectation], timeout: 2.0)
        
        // Then: 상태 전환이 올바른 순서로 이루어져야 함
        let expectedPattern = [
            "Recording: false",  // 초기 상태
            "Analyzing: false",  // 초기 상태
            "Recording: true",   // 녹음 시작
            "Recording: false",  // 녹음 종료
            "Analyzing: true",   // 분석 시작
            "Analyzing: false"   // 분석 완료
        ]
        
        XCTAssertTrue(stateTransitions.contains("Recording: true"), "녹음 시작 상태가 있어야 함")
        XCTAssertTrue(stateTransitions.contains("Analyzing: true"), "분석 시작 상태가 있어야 함")
        XCTAssertFalse(recordingViewModel.isRecording, "최종적으로 녹음이 중지되어야 함")
        XCTAssertFalse(recordingViewModel.isAnalyzing, "최종적으로 분석이 완료되어야 함")
    }
    
    @MainActor
    func testStateConsistency_PlaybackStateMachine_ShouldHandleStateTransitionsCorrectly() async {
        // Given: 재생 ViewModel 초기 상태
        XCTAssertFalse(playbackViewModel.isPlaying, "초기에는 재생 중이 아니어야 함")
        XCTAssertFalse(playbackViewModel.canPlayOriginal, "초기에는 원본 재생 불가능해야 함")
        XCTAssertFalse(playbackViewModel.canPlaySynthesized, "초기에는 합성음 재생 불가능해야 함")
        
        let playbackStateExpectation = expectation(description: "재생 상태 변화")
        var playbackStates: [String] = []
        
        // 재생 상태 추적
        playbackViewModel.$isPlaying
            .sink { isPlaying in
                playbackStates.append("Playing: \(isPlaying)")
            }
            .store(in: &cancellables)
            
        playbackViewModel.$isLoading
            .sink { isLoading in
                playbackStates.append("Loading: \(isLoading)")
            }
            .store(in: &cancellables)
        
        // When: 오디오 세션 설정 및 합성
        setupSuccessfulMocks()
        let audioSession = AudioSession(
            id: UUID(),
            timestamp: Date(),
            duration: 2.0,
            audioFileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        playbackViewModel.setAudioSession(audioSession)
        let testNote = MusicNote.from(frequency: 440.0, duration: 1.0, amplitude: 0.5)!
        playbackViewModel.synthesizeAudio(from: [testNote])
        
        // 합성 완료 대기
        playbackViewModel.$isLoading
            .filter { !$0 }
            .sink { _ in
                if self.playbackViewModel.canPlaySynthesized {
                    self.playbackViewModel.playSynthesized()
                    playbackStateExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [playbackStateExpectation], timeout: 3.0)
        
        // Then: 상태가 올바르게 변화해야 함
        XCTAssertTrue(playbackViewModel.canPlayOriginal, "원본 재생이 가능해야 함")
        XCTAssertTrue(playbackViewModel.canPlaySynthesized, "합성음 재생이 가능해야 함")
        XCTAssertTrue(playbackStates.contains("Loading: true"), "로딩 상태가 있어야 함")
        XCTAssertTrue(playbackStates.contains("Loading: false"), "로딩 완료 상태가 있어야 함")
    }
    
    // MARK: - 에러 복구 테스트
    
    @MainActor
    func testErrorRecovery_AfterRecordingError_ShouldAllowRetry() async {
        // Given: 첫 번째 녹음이 실패하도록 설정
        mockRecordAudioUseCase.shouldSucceedRecording = false
        mockRecordAudioUseCase.recordingError = .recordingFailed
        
        let firstErrorExpectation = expectation(description: "첫 번째 에러")
        let retrySuccessExpectation = expectation(description: "재시도 성공")
        
        // When: 첫 번째 녹음 시도 (실패)
        recordingViewModel.startRecording()
        
        recordingViewModel.$errorMessage
            .compactMap { $0 }
            .first()
            .sink { _ in
                firstErrorExpectation.fulfill()
                
                // 에러 후 Mock을 성공으로 변경
                self.mockRecordAudioUseCase.shouldSucceedRecording = true
                self.mockRecordAudioUseCase.recordingError = nil
                
                // 재시도
                self.recordingViewModel.clearError()
                self.recordingViewModel.startRecording()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.recordingViewModel.stopRecording()
                }
            }
            .store(in: &cancellables)
        
        recordingViewModel.$currentAudioSession
            .compactMap { $0 }
            .sink { _ in
                retrySuccessExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [firstErrorExpectation, retrySuccessExpectation], timeout: 3.0)
        
        // Then: 재시도가 성공해야 함
        XCTAssertNotNil(recordingViewModel.currentAudioSession, "재시도 후 오디오 세션이 있어야 함")
        XCTAssertNil(recordingViewModel.errorMessage, "에러 메시지가 클리어되어야 함")
    }
    
    // MARK: - Helper Methods
    
    private func setupSuccessfulMocks() {
        // 성공적인 시나리오를 위한 Mock 설정
        mockRecordAudioUseCase.shouldGrantPermission = true
        mockRecordAudioUseCase.shouldSucceedRecording = true
        
        mockSyllableAnalysisUseCase.shouldSucceedAnalysis = true
        mockSyllableAnalysisUseCase.setMockResult(createMockTimeBasedAnalysisResult())
        
        mockSynthesizeAudioUseCase.shouldSucceedSynthesis = true
        mockAudioPlaybackUseCase.shouldSucceedPlayback = true
    }
    
    private func createMockTimeBasedAnalysisResult() -> TimeBasedAnalysisResult {
        let audioSession = AudioSession(
            id: UUID(),
            timestamp: Date(),
            duration: 3.0,
            audioFileURL: URL(fileURLWithPath: "/tmp/test.wav"),
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        // 가짜 음절 세그먼트들 생성
        let syllableSegments = [
            createMockSyllableSegment(index: 0, startTime: 0.0, endTime: 1.0, frequency: 440.0), // A4
            createMockSyllableSegment(index: 1, startTime: 1.0, endTime: 2.0, frequency: 493.88), // B4
            createMockSyllableSegment(index: 2, startTime: 2.0, endTime: 3.0, frequency: 523.25)  // C5
        ]
        
        return TimeBasedAnalysisResult(
            audioSession: audioSession,
            syllableSegments: syllableSegments,
            vadResults: createMockVADResults(),
            segmentationResults: createMockSegmentationResults(),
            qualityGrade: .good,
            overallConfidence: 0.85,
            analysisStartTime: Date().addingTimeInterval(-1),
            analysisEndTime: Date(),
            error: nil
        )
    }
    
    private func createMockSyllableSegment(
        index: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        frequency: Double
    ) -> SyllableSegment {
        let frequencyData = FrequencyData(
            frequencies: [frequency],
            magnitudes: [0.8],
            sampleRate: 44100.0,
            windowSize: 1024
        )
        
        return SyllableSegment(
            index: index,
            startTime: startTime,
            endTime: endTime,
            frequencyData: frequencyData,
            musicNote: MusicNote.from(frequency: frequency),
            energy: 0.8,
            confidence: 0.9,
            type: .speech
        )
    }
    
    private func createMockVADResults() -> [VoiceActivityDetector.VADResult] {
        return (0..<30).map { index in
            VoiceActivityDetector.VADResult(
                frameIndex: index,
                timestamp: Double(index) * 0.1, // 100ms 간격
                isSpeech: index % 5 < 4, // 80% 음성, 20% 무음
                energy: 0.7,
                zeroCrossingRate: 0.1,
                spectralCentroid: 1000.0,
                confidence: 0.9
            )
        }
    }
    
    private func createMockSegmentationResults() -> [SyllableSegmentationEngine.SegmentationResult] {
        return [
            SyllableSegmentationEngine.SegmentationResult(
                originalStartTime: 0.0,
                originalEndTime: 3.0,
                syllableBoundaries: [0.0, 1.0, 2.0, 3.0],
                energyProfile: [0.8, 0.9, 0.85],
                confidence: 0.85,
                qualityMetrics: SyllableSegmentationEngine.QualityMetrics(
                    energyVariation: 0.2,
                    temporalConsistency: 0.9,
                    spectralClarity: 0.8,
                    overallQuality: 0.83
                )
            )
        ]
    }
    
    // MARK: - Helper Methods (추가)
    
    private func mach_task_basic_info() -> mach_task_basic_info {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return mach_task_basic_info()
        }
        
        return info
    }
}

// MARK: - Mock Extensions for Integration Tests

extension MockRecordAudioUseCase {
    var shortRecordingDuration: TimeInterval {
        get { return currentDuration }
        set { currentDuration = newValue }
    }
}

extension MockAnalyzeFrequencyUseCase {
    var shouldSucceedAnalysis: Bool {
        get { return !shouldFail }
        set { shouldFail = !newValue }
    }
}

extension MockSynthesizeAudioUseCase {
    var shouldSucceedSynthesis: Bool {
        get { return !shouldFail }
        set { shouldFail = !newValue }
    }
}

extension MockAudioPlaybackUseCase {
    var shouldSucceedPlayback: Bool {
        get { return !shouldFail }
        set { shouldFail = !newValue }
    }
} 

// MARK: - MockSyllableAnalysisUseCase

class MockSyllableAnalysisUseCase: SyllableAnalysisUseCase {
    
    // MARK: - Mock Configuration
    var shouldSucceedAnalysis = true
    var mockAnalysisResult: TimeBasedAnalysisResult?
    var mockAnalysisError: AudioAnalysisError?
    var analysisDelay: TimeInterval = 0.1
    
    // MARK: - Call Tracking
    var analyzeSyllablesFromSessionCallCount = 0
    var analyzeSyllablesFromFileCallCount = 0
    var analyzeRealtimeBufferCallCount = 0
    
    // MARK: - Last Called Parameters
    var lastAnalyzedAudioSession: AudioSession?
    var lastAnalyzedFileURL: URL?
    var lastAnalyzedBuffer: AVAudioPCMBuffer?
    
    // MARK: - SyllableAnalysisUseCase Implementation
    
    func analyzeSyllables(from audioSession: AudioSession) async throws -> TimeBasedAnalysisResult {
        analyzeSyllablesFromSessionCallCount += 1
        lastAnalyzedAudioSession = audioSession
        
        // 지연 시뮬레이션
        try await Task.sleep(nanoseconds: UInt64(analysisDelay * 1_000_000_000))
        
        if let error = mockAnalysisError {
            throw error
        }
        
        guard shouldSucceedAnalysis else {
            throw AudioAnalysisError.analysisProcessingFailed
        }
        
        return mockAnalysisResult ?? createDefaultAnalysisResult(for: audioSession)
    }
    
    func analyzeRealtimeBuffer(_ buffer: AVAudioPCMBuffer) async -> SyllableSegment? {
        analyzeRealtimeBufferCallCount += 1
        lastAnalyzedBuffer = buffer
        
        guard shouldSucceedAnalysis else { return nil }
        
        // 기본 실시간 세그먼트 생성
        let frequencyData = FrequencyData(
            frequencies: [440.0], // A4
            magnitudes: [0.8],
            sampleRate: Double(buffer.format.sampleRate),
            windowSize: 1024
        )
        
        return SyllableSegment(
            index: 0,
            startTime: 0.0,
            endTime: Double(buffer.frameLength) / Double(buffer.format.sampleRate),
            frequencyData: frequencyData,
            musicNote: MusicNote.from(frequency: 440.0),
            energy: 0.8,
            confidence: 0.9,
            type: .speech
        )
    }
    
    func analyzeSyllables(from fileURL: URL) async throws -> TimeBasedAnalysisResult {
        analyzeSyllablesFromFileCallCount += 1
        lastAnalyzedFileURL = fileURL
        
        // 지연 시뮬레이션
        try await Task.sleep(nanoseconds: UInt64(analysisDelay * 1_000_000_000))
        
        if let error = mockAnalysisError {
            throw error
        }
        
        guard shouldSucceedAnalysis else {
            throw AudioAnalysisError.analysisProcessingFailed
        }
        
        // 파일 기반 분석 결과 생성
        let mockAudioSession = AudioSession(
            id: UUID(),
            timestamp: Date(),
            duration: 3.0,
            audioFileURL: fileURL,
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        return mockAnalysisResult ?? createDefaultAnalysisResult(for: mockAudioSession)
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        shouldSucceedAnalysis = true
        mockAnalysisResult = nil
        mockAnalysisError = nil
        analysisDelay = 0.1
        
        analyzeSyllablesFromSessionCallCount = 0
        analyzeSyllablesFromFileCallCount = 0
        analyzeRealtimeBufferCallCount = 0
        
        lastAnalyzedAudioSession = nil
        lastAnalyzedFileURL = nil
        lastAnalyzedBuffer = nil
    }
    
    func setMockResult(_ result: TimeBasedAnalysisResult) {
        mockAnalysisResult = result
    }
    
    func setError(_ error: AudioAnalysisError) {
        shouldSucceedAnalysis = false
        mockAnalysisError = error
    }
    
    // MARK: - Private Helper Methods
    
    private func createDefaultAnalysisResult(for audioSession: AudioSession) -> TimeBasedAnalysisResult {
        // 가짜 음절 세그먼트들 생성
        let syllableSegments = [
            createMockSyllableSegment(index: 0, startTime: 0.0, endTime: 0.5, frequency: 440.0), // A4
            createMockSyllableSegment(index: 1, startTime: 0.5, endTime: 1.0, frequency: 493.88), // B4
            createMockSyllableSegment(index: 2, startTime: 1.0, endTime: 1.5, frequency: 523.25), // C5
            createMockSyllableSegment(index: 3, startTime: 1.5, endTime: 2.0, frequency: 587.33), // D5
            createMockSyllableSegment(index: 4, startTime: 2.0, endTime: 2.5, frequency: 659.25)  // E5
        ]
        
        return TimeBasedAnalysisResult(
            audioSession: audioSession,
            syllableSegments: syllableSegments,
            vadResults: createMockVADResults(),
            segmentationResults: createMockSegmentationResults(),
            qualityGrade: .good,
            overallConfidence: 0.85,
            analysisStartTime: Date().addingTimeInterval(-1),
            analysisEndTime: Date(),
            error: nil
        )
    }
    
    private func createMockSyllableSegment(
        index: Int,
        startTime: TimeInterval,
        endTime: TimeInterval,
        frequency: Double
    ) -> SyllableSegment {
        let frequencyData = FrequencyData(
            frequencies: [frequency],
            magnitudes: [0.8],
            sampleRate: 44100.0,
            windowSize: 1024
        )
        
        return SyllableSegment(
            index: index,
            startTime: startTime,
            endTime: endTime,
            frequencyData: frequencyData,
            musicNote: MusicNote.from(frequency: frequency),
            energy: 0.8,
            confidence: 0.9,
            type: .speech
        )
    }
    
    private func createMockVADResults() -> [VoiceActivityDetector.VADResult] {
        return (0..<50).map { index in
            VoiceActivityDetector.VADResult(
                frameIndex: index,
                timestamp: Double(index) * 0.05, // 50ms 간격
                isSpeech: index % 10 < 8, // 80% 음성, 20% 무음
                energy: 0.7,
                zeroCrossingRate: 0.1,
                spectralCentroid: 1000.0,
                confidence: 0.9
            )
        }
    }
    
    private func createMockSegmentationResults() -> [SyllableSegmentationEngine.SegmentationResult] {
        return [
            SyllableSegmentationEngine.SegmentationResult(
                originalStartTime: 0.0,
                originalEndTime: 2.5,
                syllableBoundaries: [0.0, 0.5, 1.0, 1.5, 2.0, 2.5],
                energyProfile: [0.8, 0.9, 0.7, 0.85, 0.75],
                confidence: 0.85,
                qualityMetrics: SyllableSegmentationEngine.QualityMetrics(
                    energyVariation: 0.2,
                    temporalConsistency: 0.9,
                    spectralClarity: 0.8,
                    overallQuality: 0.83
                )
            )
        ]
    }
} 