import XCTest
import Combine
@testable import DailyPitch

final class AudioPlaybackUseCaseTests: XCTestCase {
    
    var useCase: AudioPlaybackUseCase!
    var mockRepository: MockAudioPlaybackRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        mockRepository = MockAudioPlaybackRepository()
        useCase = AudioPlaybackUseCase(audioPlaybackRepository: mockRepository)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        useCase = nil
        mockRepository = nil
        cancellables = nil
        
        super.tearDown()
    }
    
    // MARK: - 원본 오디오 재생 테스트
    
    func testPlayOriginalAudio_Success() {
        // Given: 유효한 오디오 세션
        let audioSession = createMockAudioSession()
        mockRepository.setMockState(.playing)
        
        let expectation = XCTestExpectation(description: "원본 오디오 재생 완료")
        
        // When: 원본 오디오 재생
        useCase.playOriginalAudio(audioSession)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("예상치 못한 에러 발생: \(error)")
                    }
                },
                receiveValue: { playbackState in
                    // Then: 성공적으로 재생되어야 함
                    XCTAssertEqual(playbackState, .playing)
                    XCTAssertEqual(self.mockRepository.playOriginalAudioCallCount, 1)
                    XCTAssertEqual(self.mockRepository.lastPlayedAudioSession?.duration, audioSession.duration)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlayOriginalAudio_FileNotFound() {
        // Given: 존재하지 않는 파일을 가진 오디오 세션
        let invalidAudioSession = createMockAudioSession(withValidFile: false)
        
        let expectation = XCTestExpectation(description: "파일 없음 에러")
        
        // When: 존재하지 않는 파일로 재생 시도
        useCase.playOriginalAudio(invalidAudioSession)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then: 적절한 에러가 발생해야 함
                        XCTAssertEqual(error, .audioFileNotFound)
                        XCTAssertEqual(self.mockRepository.playOriginalAudioCallCount, 0)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("존재하지 않는 파일에서 성공이 반환되면 안됩니다.")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 합성 오디오 재생 테스트
    
    func testPlaySynthesizedAudio_Success() {
        // Given: 유효한 합성 오디오
        let synthesizedAudio = createMockSynthesizedAudio()
        mockRepository.setMockState(.playing)
        
        let expectation = XCTestExpectation(description: "합성 오디오 재생 완료")
        
        // When: 합성 오디오 재생
        useCase.playSynthesizedAudio(synthesizedAudio)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("예상치 못한 에러 발생: \(error)")
                    }
                },
                receiveValue: { playbackState in
                    // Then: 성공적으로 재생되어야 함
                    XCTAssertEqual(playbackState, .playing)
                    XCTAssertEqual(self.mockRepository.playSynthesizedAudioCallCount, 1)
                    XCTAssertEqual(self.mockRepository.lastPlayedSynthesizedAudio?.duration, synthesizedAudio.duration)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlaySynthesizedAudio_InvalidAudio() {
        // Given: 유효하지 않은 합성 오디오
        let invalidAudio = createInvalidSynthesizedAudio()
        
        let expectation = XCTestExpectation(description: "유효하지 않은 오디오 에러")
        
        // When: 유효하지 않은 오디오로 재생 시도
        useCase.playSynthesizedAudio(invalidAudio)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then: 적절한 에러가 발생해야 함
                        XCTAssertEqual(error, .unsupportedAudioFormat)
                        XCTAssertEqual(self.mockRepository.playSynthesizedAudioCallCount, 0)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("유효하지 않은 오디오에서 성공이 반환되면 안됩니다.")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 믹싱 오디오 재생 테스트
    
    func testPlayMixedAudio_Success() {
        // Given: 유효한 원본과 합성 오디오
        let audioSession = createMockAudioSession()
        let synthesizedAudio = createMockSynthesizedAudio()
        mockRepository.setMockState(.playing)
        
        let expectation = XCTestExpectation(description: "믹싱 오디오 재생 완료")
        
        // When: 믹싱 오디오 재생
        useCase.playMixedAudio(
            originalAudio: audioSession,
            synthesizedAudio: synthesizedAudio,
            originalVolume: 0.8,
            synthesizedVolume: 0.6
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("예상치 못한 에러 발생: \(error)")
                }
            },
            receiveValue: { playbackState in
                // Then: 성공적으로 재생되어야 함
                XCTAssertEqual(playbackState, .playing)
                XCTAssertEqual(self.mockRepository.playMixedAudioCallCount, 1)
                
                let mixParams = self.mockRepository.lastMixedAudioParameters!
                XCTAssertEqual(mixParams.2, 0.8, accuracy: 0.01) // originalVolume
                XCTAssertEqual(mixParams.3, 0.6, accuracy: 0.01) // synthesizedVolume
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlayMixedAudio_VolumeNormalization() {
        // Given: 범위를 벗어난 볼륨 값들
        let audioSession = createMockAudioSession()
        let synthesizedAudio = createMockSynthesizedAudio()
        mockRepository.setMockState(.playing)
        
        let expectation = XCTestExpectation(description: "볼륨 정규화 완료")
        
        // When: 범위를 벗어난 볼륨으로 재생
        useCase.playMixedAudio(
            originalAudio: audioSession,
            synthesizedAudio: synthesizedAudio,
            originalVolume: 1.5, // > 1.0
            synthesizedVolume: -0.2 // < 0.0
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("예상치 못한 에러 발생: \(error)")
                }
            },
            receiveValue: { playbackState in
                // Then: 볼륨이 정규화되어야 함
                let mixParams = self.mockRepository.lastMixedAudioParameters!
                XCTAssertEqual(mixParams.2, 1.0, accuracy: 0.01) // originalVolume 정규화
                XCTAssertEqual(mixParams.3, 0.0, accuracy: 0.01) // synthesizedVolume 정규화
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 재생 모드별 테스트
    
    func testPlayWithMode_OriginalOnly() {
        // Given: 원본 재생 모드
        let audioSession = createMockAudioSession()
        let synthesizedAudio = createMockSynthesizedAudio()
        mockRepository.setMockState(.playing)
        
        let expectation = XCTestExpectation(description: "원본 재생 모드 완료")
        
        // When: 원본 재생 모드로 재생
        useCase.playWithMode(
            mode: .originalOnly,
            audioSession: audioSession,
            synthesizedAudio: synthesizedAudio
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("예상치 못한 에러 발생: \(error)")
                }
            },
            receiveValue: { playbackState in
                // Then: 원본 오디오만 재생되어야 함
                XCTAssertEqual(self.mockRepository.playOriginalAudioCallCount, 1)
                XCTAssertEqual(self.mockRepository.playSynthesizedAudioCallCount, 0)
                XCTAssertEqual(self.mockRepository.playMixedAudioCallCount, 0)
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlayWithMode_SynthesizedOnly() {
        // Given: 합성 재생 모드
        let audioSession = createMockAudioSession()
        let synthesizedAudio = createMockSynthesizedAudio()
        mockRepository.setMockState(.playing)
        
        let expectation = XCTestExpectation(description: "합성 재생 모드 완료")
        
        // When: 합성 재생 모드로 재생
        useCase.playWithMode(
            mode: .synthesizedOnly,
            audioSession: audioSession,
            synthesizedAudio: synthesizedAudio
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("예상치 못한 에러 발생: \(error)")
                }
            },
            receiveValue: { playbackState in
                // Then: 합성 오디오만 재생되어야 함
                XCTAssertEqual(self.mockRepository.playOriginalAudioCallCount, 0)
                XCTAssertEqual(self.mockRepository.playSynthesizedAudioCallCount, 1)
                XCTAssertEqual(self.mockRepository.playMixedAudioCallCount, 0)
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlayWithMode_Mixed() {
        // Given: 믹싱 재생 모드
        let audioSession = createMockAudioSession()
        let synthesizedAudio = createMockSynthesizedAudio()
        mockRepository.setMockState(.playing)
        
        let expectation = XCTestExpectation(description: "믹싱 재생 모드 완료")
        
        // When: 믹싱 재생 모드로 재생
        useCase.playWithMode(
            mode: .mixed,
            audioSession: audioSession,
            synthesizedAudio: synthesizedAudio
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("예상치 못한 에러 발생: \(error)")
                }
            },
            receiveValue: { playbackState in
                // Then: 믹싱 오디오가 재생되어야 함
                XCTAssertEqual(self.mockRepository.playOriginalAudioCallCount, 0)
                XCTAssertEqual(self.mockRepository.playSynthesizedAudioCallCount, 0)
                XCTAssertEqual(self.mockRepository.playMixedAudioCallCount, 1)
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPlayWithMode_MissingSynthesizedAudio() {
        // Given: 합성 오디오가 없는 상태에서 합성 모드
        let audioSession = createMockAudioSession()
        
        let expectation = XCTestExpectation(description: "합성 오디오 없음 에러")
        
        // When: 합성 오디오 없이 합성 모드로 재생
        useCase.playWithMode(
            mode: .synthesizedOnly,
            audioSession: audioSession,
            synthesizedAudio: nil
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    // Then: 적절한 에러가 발생해야 함
                    XCTAssertEqual(error, .unsupportedAudioFormat)
                    expectation.fulfill()
                }
            },
            receiveValue: { _ in
                XCTFail("합성 오디오 없이 성공이 반환되면 안됩니다.")
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 재생 제어 테스트
    
    func testPlaybackControl() {
        // When: 재생 제어 메소드들 호출
        useCase.pause()
        useCase.resume()
        useCase.stop()
        useCase.setVolume(0.5)
        
        // Then: Repository의 메소드들이 호출되어야 함
        XCTAssertEqual(mockRepository.pauseCallCount, 1)
        XCTAssertEqual(mockRepository.resumeCallCount, 1)
        XCTAssertEqual(mockRepository.stopCallCount, 1)
        XCTAssertEqual(mockRepository.setVolumeCallCount, 1)
        XCTAssertEqual(mockRepository.lastVolumeSet, 0.5)
    }
    
    func testVolumeNormalization() {
        // When: 범위를 벗어난 볼륨 설정
        useCase.setVolume(1.5) // > 1.0
        useCase.setVolume(-0.5) // < 0.0
        
        // Then: 볼륨이 정규화되어 설정되어야 함
        XCTAssertEqual(mockRepository.setVolumeCallCount, 2)
        // 마지막 호출된 볼륨이 정규화된 값이어야 함 (0.0)
        XCTAssertEqual(mockRepository.lastVolumeSet, 0.0)
    }
    
    func testSeek_Success() {
        // Given: 유효한 시간
        let seekTime: TimeInterval = 2.5
        mockRepository.setMockDuration(5.0)
        
        let expectation = XCTestExpectation(description: "시크 성공")
        
        // When: 시크 실행
        useCase.seek(to: seekTime)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("예상치 못한 에러 발생: \(error)")
                    }
                },
                receiveValue: { success in
                    // Then: 성공적으로 시크되어야 함
                    XCTAssertTrue(success)
                    XCTAssertEqual(self.mockRepository.seekCallCount, 1)
                    XCTAssertEqual(self.mockRepository.lastSeekTime, seekTime)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSeek_OutOfRange() {
        // Given: 범위를 벗어난 시간
        mockRepository.setMockDuration(5.0)
        
        let expectation = XCTestExpectation(description: "시크 실패")
        
        // When: 범위를 벗어난 시간으로 시크
        useCase.seek(to: 10.0) // > duration
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then: 적절한 에러가 발생해야 함
                        XCTAssertEqual(error, .seekFailed)
                        XCTAssertEqual(self.mockRepository.seekCallCount, 0)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("범위를 벗어난 시크에서 성공이 반환되면 안됩니다.")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 재생 정보 테스트
    
    func testPlaybackInfo() {
        // Given: Mock 상태 설정
        mockRepository.setMockDuration(10.0)
        mockRepository.setMockCurrentTime(3.5)
        mockRepository.setMockState(.playing)
        mockRepository._currentVolume = 0.8
        
        // Then: 올바른 정보가 반환되어야 함
        XCTAssertEqual(useCase.currentTime, 3.5)
        XCTAssertEqual(useCase.duration, 10.0)
        XCTAssertEqual(useCase.currentState, .playing)
        XCTAssertEqual(useCase.currentVolume, 0.8)
        XCTAssertTrue(useCase.isPlaying)
        XCTAssertEqual(useCase.progress, 0.35, accuracy: 0.01) // 3.5 / 10.0
        XCTAssertEqual(useCase.remainingTime, 6.5, accuracy: 0.01) // 10.0 - 3.5
    }
    
    func testProgressCalculation() {
        // Given: 다양한 시간 상태
        let testCases: [(currentTime: TimeInterval, duration: TimeInterval, expectedProgress: Double)] = [
            (0.0, 10.0, 0.0),
            (5.0, 10.0, 0.5),
            (10.0, 10.0, 1.0),
            (0.0, 0.0, 0.0) // 지속시간이 0인 경우
        ]
        
        for testCase in testCases {
            // When: Mock 상태 설정
            mockRepository.setMockCurrentTime(testCase.currentTime)
            mockRepository.setMockDuration(testCase.duration)
            
            // Then: 올바른 진행률이 계산되어야 함
            XCTAssertEqual(useCase.progress, testCase.expectedProgress, accuracy: 0.01)
        }
    }
    
    // MARK: - Publisher 테스트
    
    func testStatePublisher() {
        let expectation = XCTestExpectation(description: "상태 변화 감지")
        var receivedStates: [PlaybackState] = []
        
        // When: 상태 Publisher 구독
        useCase.statePublisher
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 상태 변화 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockRepository.setMockState(.playing)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.mockRepository.setMockState(.paused)
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then: 상태 변화가 감지되어야 함
        XCTAssertTrue(receivedStates.contains(.stopped))
        XCTAssertTrue(receivedStates.contains(.playing))
        XCTAssertTrue(receivedStates.contains(.paused))
    }
    
    func testTimePublisher() {
        let expectation = XCTestExpectation(description: "시간 변화 감지")
        var receivedTimes: [TimeInterval] = []
        
        // When: 시간 Publisher 구독
        useCase.timePublisher
            .sink { time in
                receivedTimes.append(time)
                if receivedTimes.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 시간 변화 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockRepository.setMockCurrentTime(1.0)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.mockRepository.setMockCurrentTime(2.0)
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then: 시간 변화가 감지되어야 함
        XCTAssertTrue(receivedTimes.contains(0.0))
        XCTAssertTrue(receivedTimes.contains(1.0))
        XCTAssertTrue(receivedTimes.contains(2.0))
    }
    
    func testProgressPublisher() {
        let expectation = XCTestExpectation(description: "진행률 변화 감지")
        var receivedProgress: [Double] = []
        
        // Given: 지속시간 설정
        mockRepository.setMockDuration(10.0)
        
        // When: 진행률 Publisher 구독
        useCase.progressPublisher
            .sink { progress in
                receivedProgress.append(progress)
                if receivedProgress.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 시간 변화로 진행률 변화 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.mockRepository.setMockCurrentTime(2.5) // 25%
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.mockRepository.setMockCurrentTime(5.0) // 50%
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Then: 진행률 변화가 감지되어야 함
        XCTAssertTrue(receivedProgress.contains(0.0))
        XCTAssertTrue(receivedProgress.contains(0.25))
        XCTAssertTrue(receivedProgress.contains(0.5))
    }
    
    // MARK: - 재생 가능성 확인 테스트
    
    func testCanPlay_ValidAudio() {
        // Given: 유효한 오디오 세션과 합성 오디오
        let audioSession = createMockAudioSession()
        let synthesizedAudio = createMockSynthesizedAudio()
        
        // When: 재생 가능성 확인
        let result = useCase.canPlay(audioSession: audioSession, synthesizedAudio: synthesizedAudio)
        
        // Then: 재생 가능해야 함
        XCTAssertTrue(result.canPlay)
        XCTAssertNil(result.reason)
    }
    
    func testCanPlay_InvalidAudio() {
        // Given: 유효하지 않은 오디오들
        let invalidAudioSession = createMockAudioSession(withValidFile: false)
        let invalidSynthesizedAudio = createInvalidSynthesizedAudio()
        
        // When: 재생 가능성 확인
        let result = useCase.canPlay(audioSession: invalidAudioSession, synthesizedAudio: invalidSynthesizedAudio)
        
        // Then: 재생 불가능해야 함
        XCTAssertFalse(result.canPlay)
        XCTAssertNotNil(result.reason)
    }
    
    // MARK: - 재생 품질 확인 테스트
    
    func testCheckPlaybackQuality() {
        // Given: 다양한 품질의 합성 오디오들
        let excellentAudio = createMockSynthesizedAudio(rms: 0.2, peak: 0.7, noteCount: 5)
        let poorAudio = createMockSynthesizedAudio(rms: 0.005, peak: 0.98, noteCount: 0)
        
        // When: 품질 확인
        let excellentResult = useCase.checkPlaybackQuality(excellentAudio)
        let poorResult = useCase.checkPlaybackQuality(poorAudio)
        
        // Then: 올바른 품질 등급이 반환되어야 함
        XCTAssertEqual(excellentResult.quality, .excellent)
        XCTAssertEqual(poorResult.quality, .poor)
    }
    
    // MARK: - Helper Methods
    
    private func createMockAudioSession(withValidFile: Bool = true) -> AudioSession {
        let fileName = withValidFile ? "DailyPitch/ContentView.swift" : "non_existent_file.wav"
        let fileURL = URL(fileURLWithPath: fileName)
        
        return AudioSession(
            audioFileURL: fileURL,
            duration: 3.0,
            sampleRate: 44100.0,
            channelCount: 1,
            recordedAt: Date()
        )
    }
    
    private func createMockSynthesizedAudio(rms: Float = 0.1, peak: Float = 0.8, noteCount: Int = 3) -> SynthesizedAudio {
        let notes = (0..<noteCount).compactMap { i in
            MusicNote.from(midiNumber: 60 + i, duration: 1.0, amplitude: 0.5)
        }
        
        // 특정 RMS와 Peak 값을 가진 오디오 데이터 생성
        let sampleCount = 1000
        var audioData: [Float] = []
        
        for i in 0..<sampleCount {
            let sample = peak * sin(2.0 * .pi * Double(i) / 100.0) // 단순한 사인파
            audioData.append(Float(sample))
        }
        
        return SynthesizedAudio(
            musicNotes: notes,
            audioData: audioData,
            sampleRate: 44100.0,
            synthesisMethod: .sineWave
        )
    }
    
    private func createInvalidSynthesizedAudio() -> SynthesizedAudio {
        return SynthesizedAudio(
            musicNotes: [],
            audioData: [],
            sampleRate: 0.0,
            synthesisMethod: .sineWave
        )
    }
} 