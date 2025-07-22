import XCTest
import Combine
@testable import DailyPitch

final class SynthesizeAudioUseCaseTests: XCTestCase {
    
    var useCase: SynthesizeAudioUseCase!
    var mockRepository: MockAudioSynthesisRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        mockRepository = MockAudioSynthesisRepository()
        useCase = SynthesizeAudioUseCase(audioSynthesisRepository: mockRepository)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        useCase = nil
        mockRepository = nil
        cancellables = nil
        
        super.tearDown()
    }
    
    // MARK: - 분석 결과로부터 합성 테스트
    
    func testSynthesizeFromAnalysis_Success() {
        // Given: 성공적인 분석 결과
        let mockResult = createMockAnalysisResult(isSuccessful: true, peakFrequency: 440.0)
        let expectation = XCTestExpectation(description: "합성 완료")
        
        // When: 분석 결과로부터 합성
        useCase.synthesizeFromAnalysis(mockResult, method: .sineWave, segmentDuration: 0.5)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("예상치 못한 에러 발생: \(error)")
                    }
                },
                receiveValue: { synthesizedAudio in
                    // Then: 성공적으로 합성되어야 함
                    XCTAssertTrue(synthesizedAudio.isValid)
                    XCTAssertEqual(self.mockRepository.synthesizeFromAnalysisCallCount, 1)
                    XCTAssertEqual(self.mockRepository.lastAnalysisResult?.peakFrequency, 440.0)
                    XCTAssertEqual(self.mockRepository.lastSynthesisMethod, .sineWave)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSynthesizeFromAnalysis_FailedAnalysis() {
        // Given: 실패한 분석 결과
        let mockResult = createMockAnalysisResult(isSuccessful: false)
        let expectation = XCTestExpectation(description: "에러 발생")
        
        // When: 실패한 분석 결과로부터 합성
        useCase.synthesizeFromAnalysis(mockResult)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then: 적절한 에러가 발생해야 함
                        XCTAssertEqual(error, .synthesisProcessingFailed)
                        XCTAssertEqual(self.mockRepository.synthesizeFromAnalysisCallCount, 0)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("실패한 분석 결과에서 성공이 반환되면 안됩니다.")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSynthesizeFromAnalysis_PostProcessing() {
        // Given: 높은 볼륨의 Mock 오디오 (후처리 필요)
        let highVolumeAudio = createHighVolumeAudio()
        mockRepository.setMockResult(highVolumeAudio)
        
        let mockResult = createMockAnalysisResult(isSuccessful: true, peakFrequency: 440.0)
        let expectation = XCTestExpectation(description: "후처리 완료")
        
        // When: 합성 (후처리 포함)
        useCase.synthesizeFromAnalysis(mockResult)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { synthesizedAudio in
                    // Then: 볼륨이 정규화되어야 함
                    XCTAssertLessThanOrEqual(synthesizedAudio.peakAmplitude, 0.95)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 주파수로부터 합성 테스트
    
    func testSynthesizeFromFrequency_Success() {
        // Given: 유효한 주파수
        let frequency: Double = 440.0
        let expectation = XCTestExpectation(description: "합성 완료")
        
        // When: 주파수로부터 합성
        useCase.synthesizeFromFrequency(frequency: frequency, duration: 1.0, amplitude: 0.5, method: .squareWave)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("예상치 못한 에러 발생: \(error)")
                    }
                },
                receiveValue: { synthesizedAudio in
                    // Then: 성공적으로 합성되어야 함
                    XCTAssertEqual(self.mockRepository.synthesizeCallCount, 1)
                    XCTAssertEqual(self.mockRepository.lastSynthesizedNote?.frequency, 440.0, accuracy: 0.01)
                    XCTAssertEqual(self.mockRepository.lastSynthesisMethod, .squareWave)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSynthesizeFromFrequency_InvalidFrequency() {
        // Given: 유효하지 않은 주파수
        let invalidFrequency: Double = -100.0
        let expectation = XCTestExpectation(description: "에러 발생")
        
        // When: 유효하지 않은 주파수로 합성
        useCase.synthesizeFromFrequency(frequency: invalidFrequency)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then: 적절한 에러가 발생해야 함
                        XCTAssertEqual(error, .invalidMusicNote)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("유효하지 않은 주파수에서 성공이 반환되면 안됩니다.")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 시퀀스 합성 테스트
    
    func testSynthesizeSequenceFromFrequencies_Success() {
        // Given: 유효한 주파수 배열
        let frequencies = [261.63, 329.63, 392.0] // C-E-G
        let expectation = XCTestExpectation(description: "시퀀스 합성 완료")
        
        // When: 주파수 시퀀스로부터 합성
        useCase.synthesizeSequenceFromFrequencies(
            frequencies: frequencies,
            segmentDuration: 0.5,
            amplitude: 0.6,
            method: .triangleWave
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("예상치 못한 에러 발생: \(error)")
                }
            },
            receiveValue: { synthesizedAudio in
                // Then: 성공적으로 합성되어야 함
                XCTAssertEqual(self.mockRepository.synthesizeSequenceCallCount, 1)
                XCTAssertEqual(self.mockRepository.lastSynthesizedNotes?.count, 3)
                XCTAssertEqual(self.mockRepository.lastSynthesisMethod, .triangleWave)
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSynthesizeSequenceFromFrequencies_EmptyArray() {
        // Given: 빈 주파수 배열
        let emptyFrequencies: [Double] = []
        let expectation = XCTestExpectation(description: "에러 발생")
        
        // When: 빈 배열로 합성
        useCase.synthesizeSequenceFromFrequencies(frequencies: emptyFrequencies)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then: 적절한 에러가 발생해야 함
                        XCTAssertEqual(error, .invalidMusicNote)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("빈 배열에서 성공이 반환되면 안됩니다.")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSynthesizeSequenceFromFrequencies_InvalidFrequencies() {
        // Given: 일부 유효하지 않은 주파수들 포함
        let mixedFrequencies = [440.0, -100.0, 880.0, 0.0, 220.0]
        let expectation = XCTestExpectation(description: "부분 성공")
        
        // When: 혼합 주파수로 합성
        useCase.synthesizeSequenceFromFrequencies(frequencies: mixedFrequencies)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("부분적으로 유효한 주파수에서 실패하면 안됩니다: \(error)")
                    }
                },
                receiveValue: { synthesizedAudio in
                    // Then: 유효한 주파수들만 처리되어야 함
                    XCTAssertEqual(self.mockRepository.lastSynthesizedNotes?.count, 3) // 440, 880, 220만 유효
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 화음 합성 테스트
    
    func testSynthesizeChordFromNoteNames_Success() {
        // Given: 유효한 음계명들
        let noteNames = ["C4", "E4", "G4"]
        let expectation = XCTestExpectation(description: "화음 합성 완료")
        
        // When: 음계명으로부터 화음 합성
        useCase.synthesizeChordFromNoteNames(
            noteNames: noteNames,
            duration: 2.0,
            amplitude: 0.3,
            method: .sawtoothWave
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("예상치 못한 에러 발생: \(error)")
                }
            },
            receiveValue: { synthesizedAudio in
                // Then: 성공적으로 합성되어야 함
                XCTAssertEqual(self.mockRepository.synthesizeChordCallCount, 1)
                XCTAssertEqual(self.mockRepository.lastSynthesizedNotes?.count, 3)
                XCTAssertEqual(self.mockRepository.lastSynthesisMethod, .sawtoothWave)
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSynthesizeChordFromNoteNames_InvalidNotes() {
        // Given: 유효하지 않은 음계명들
        let invalidNoteNames = ["X4", "Z9", "Invalid"]
        let expectation = XCTestExpectation(description: "에러 발생")
        
        // When: 유효하지 않은 음계명으로 화음 합성
        useCase.synthesizeChordFromNoteNames(noteNames: invalidNoteNames)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then: 적절한 에러가 발생해야 함
                        XCTAssertEqual(error, .invalidMusicNote)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("유효하지 않은 음계명에서 성공이 반환되면 안됩니다.")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 믹싱 테스트
    
    func testMixWithOriginalAudio_Success() {
        // Given: 원본 오디오와 합성 오디오
        let originalAudio = createMockAudioSession()
        let synthesizedAudio = createMockSynthesizedAudio()
        let expectation = XCTestExpectation(description: "믹싱 완료")
        
        // When: 원본과 합성 오디오 믹싱
        useCase.mixWithOriginalAudio(
            originalAudio: originalAudio,
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
            receiveValue: { mixedAudio in
                // Then: 성공적으로 믹싱되어야 함
                XCTAssertEqual(self.mockRepository.mixAudioCallCount, 1)
                
                let mixParams = self.mockRepository.lastMixParameters!
                XCTAssertEqual(mixParams.2, 0.8, accuracy: 0.01) // originalVolume
                XCTAssertEqual(mixParams.3, 0.6, accuracy: 0.01) // synthesizedVolume
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMixWithOriginalAudio_VolumeNormalization() {
        // Given: 범위를 벗어난 볼륨 값들
        let originalAudio = createMockAudioSession()
        let synthesizedAudio = createMockSynthesizedAudio()
        let expectation = XCTestExpectation(description: "볼륨 정규화 완료")
        
        // When: 범위를 벗어난 볼륨으로 믹싱
        useCase.mixWithOriginalAudio(
            originalAudio: originalAudio,
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
            receiveValue: { mixedAudio in
                // Then: 볼륨이 정규화되어야 함
                let mixParams = self.mockRepository.lastMixParameters!
                XCTAssertEqual(mixParams.2, 1.0, accuracy: 0.01) // originalVolume 정규화
                XCTAssertEqual(mixParams.3, 0.0, accuracy: 0.01) // synthesizedVolume 정규화
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 저장 테스트
    
    func testSaveAudio_Success() {
        // Given: 유효한 합성 오디오
        let synthesizedAudio = createMockSynthesizedAudio()
        let fileName = "test_audio"
        let expectation = XCTestExpectation(description: "저장 완료")
        
        // When: 오디오 저장
        useCase.saveAudio(synthesizedAudio, fileName: fileName)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("예상치 못한 에러 발생: \(error)")
                    }
                },
                receiveValue: { savedURL in
                    // Then: 성공적으로 저장되어야 함
                    XCTAssertEqual(self.mockRepository.saveAudioCallCount, 1)
                    XCTAssertTrue(savedURL.lastPathComponent.contains(fileName))
                    XCTAssertTrue(savedURL.pathExtension == "wav")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSaveAudio_Failure() {
        // Given: 저장 실패 설정
        mockRepository.mockSaveResult = false
        let synthesizedAudio = createMockSynthesizedAudio()
        let expectation = XCTestExpectation(description: "저장 실패")
        
        // When: 오디오 저장 (실패)
        useCase.saveAudio(synthesizedAudio)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Then: 적절한 에러가 발생해야 함
                        XCTAssertEqual(error, .fileWriteError)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("저장 실패 시 성공이 반환되면 안됩니다.")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - 유틸리티 메소드 테스트
    
    func testFilterFrequencies() {
        // Given: 다양한 주파수들
        let frequencies = [50.0, 100.0, 440.0, 880.0, 3000.0, 5000.0]
        
        // When: 주파수 필터링
        let filteredFreqs = useCase.filterFrequencies(frequencies, minFreq: 80.0, maxFreq: 2000.0)
        
        // Then: 범위 내의 주파수만 남아야 함
        let expectedFreqs = [100.0, 440.0, 880.0]
        XCTAssertEqual(filteredFreqs, expectedFreqs)
    }
    
    func testRecommendChordProgression() {
        // Given: C4 루트 음계
        let rootNote = MusicNote.from(noteName: "C4")!
        
        // When: 코드 진행 추천
        let chordProgression = useCase.recommendChordProgression(from: rootNote)
        
        // Then: C Major triad가 추천되어야 함
        let expectedChord = ["C4", "E4", "G4"]
        XCTAssertEqual(chordProgression, expectedChord)
    }
    
    func testAvailableSynthesisMethods() {
        // When: 지원되는 합성 방식 조회
        let methods = useCase.availableSynthesisMethods
        
        // Then: 모든 방식이 지원되어야 함
        XCTAssertEqual(methods.count, 4)
        XCTAssertTrue(methods.contains(.sineWave))
        XCTAssertTrue(methods.contains(.squareWave))
        XCTAssertTrue(methods.contains(.sawtoothWave))
        XCTAssertTrue(methods.contains(.triangleWave))
    }
    
    func testIsCurrentlySynthesizing() {
        // Given: 지연이 있는 Mock Repository
        mockRepository.setDelay(0.1)
        
        // When: 합성 시작
        let expectation = XCTestExpectation(description: "합성 상태 확인")
        
        useCase.synthesizeFromFrequency(frequency: 440.0)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                // Then: 완료 후에는 합성 중이 아니어야 함
                XCTAssertFalse(self.useCase.isCurrentlySynthesizing)
                expectation.fulfill()
            })
            .store(in: &cancellables)
        
        // 시작 직후에는 합성 중이어야 함
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertTrue(self.useCase.isCurrentlySynthesizing)
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockAnalysisResult(isSuccessful: Bool, peakFrequency: Double? = nil) -> AudioAnalysisResult {
        let frequencies = isSuccessful ? [FrequencyData(frequency: peakFrequency ?? 440.0, magnitude: 0.8)] : []
        return AudioAnalysisResult(
            frequencies: frequencies,
            peakFrequency: peakFrequency,
            analysisTimestamp: Date(),
            isSuccessful: isSuccessful,
            dataPointCount: frequencies.count,
            sampleRate: 44100.0,
            duration: 1.0
        )
    }
    
    private func createMockAudioSession() -> AudioSession {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")
        return AudioSession(
            audioFileURL: tempURL,
            duration: 2.0,
            sampleRate: 44100.0,
            channelCount: 1,
            recordedAt: Date()
        )
    }
    
    private func createMockSynthesizedAudio() -> SynthesizedAudio {
        let note = MusicNote.from(frequency: 440.0, duration: 1.0, amplitude: 0.5)!
        return SynthesizedAudio.from(note: note)
    }
    
    private func createHighVolumeAudio() -> SynthesizedAudio {
        let note = MusicNote.from(frequency: 440.0, duration: 1.0, amplitude: 1.0)!
        let audioData = Array(repeating: Float(1.2), count: 1000) // 클리핑 유발
        
        return SynthesizedAudio(
            musicNotes: [note],
            audioData: audioData,
            sampleRate: 44100.0,
            synthesisMethod: .sineWave
        )
    }
} 