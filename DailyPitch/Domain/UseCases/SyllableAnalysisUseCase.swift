import Foundation
import AVFoundation

/// 오디오를 음절별로 분석하여 개별 음계를 추출하는 유스케이스
/// "안녕하세요" → ["안": F4, "녕": G4, "하": A4, "세": B4, "요": C5] 형태로 분석
protocol SyllableAnalysisUseCase {
    /// 오디오 세션을 음절별로 분석
    /// - Parameter audioSession: 분석할 오디오 세션
    /// - Returns: 시간 기반 분석 결과
    func analyzeSyllables(from audioSession: AudioSession) async throws -> TimeBasedAnalysisResult
    
    /// 실시간 오디오 버퍼를 음절별로 분석
    /// - Parameter buffer: 오디오 버퍼
    /// - Returns: 개별 음절 세그먼트 (옵셔널)
    func analyzeRealtimeBuffer(_ buffer: AVAudioPCMBuffer) async -> SyllableSegment?
    
    /// 오디오 파일을 음절별로 분석
    /// - Parameter fileURL: 오디오 파일 URL
    /// - Returns: 시간 기반 분석 결과
    func analyzeSyllables(from fileURL: URL) async throws -> TimeBasedAnalysisResult
}

/// SyllableAnalysisUseCase의 구현체
class SyllableAnalysisUseCaseImpl: SyllableAnalysisUseCase {
    
    // MARK: - Dependencies
    
    private let audioAnalysisRepository: AudioAnalysisRepository
    private let fftAnalyzer: FFTAnalyzer
    private let voiceActivityDetector: VoiceActivityDetector
    private let syllableSegmentationEngine: SyllableSegmentationEngine
    
    // MARK: - Configuration
    
    /// FFT 설정
    private let fftSize: Int
    private let overlapRatio: Double
    
    /// 음성 활동 감지 설정
    private let minSpeechDuration: TimeInterval
    private let minSilenceBetweenSyllables: TimeInterval
    
    // MARK: - Initialization
    
    init(
        audioAnalysisRepository: AudioAnalysisRepository,
        fftSize: Int = 1024,
        overlapRatio: Double = 0.75,  // 75% 겹침으로 더 세밀한 분석
        minSpeechDuration: TimeInterval = 0.2,  // 최소 200ms 음성 (더 엄격)
        minSilenceBetweenSyllables: TimeInterval = 0.1,  // 음절 간 최소 100ms 무음 (더 엄격)
        vadConfiguration: VoiceActivityDetector.VADConfiguration = .significantChangeOnly  // 의미있는 변화만 감지
    ) {
        self.audioAnalysisRepository = audioAnalysisRepository
        self.fftSize = fftSize
        self.overlapRatio = overlapRatio
        self.minSpeechDuration = minSpeechDuration
        self.minSilenceBetweenSyllables = minSilenceBetweenSyllables
        
        // FFT 분석기 초기화
        self.fftAnalyzer = FFTAnalyzer(fftSize: fftSize, overlapRatio: overlapRatio)
        
        // VAD 초기화 - 의미있는 변화만 감지하는 엄격한 설정 사용
        self.voiceActivityDetector = VoiceActivityDetector(
            configuration: vadConfiguration,
            frameSize: fftSize
        )
        
        // 음절 세그멘테이션 엔진 초기화 - 의미있는 변화만 감지하는 설정 사용
        self.syllableSegmentationEngine = SyllableSegmentationEngine(
            configuration: .significantChangeOnly,  // 엄격한 음절 분리 설정
            frameSize: fftSize
        )
    }
    
    // MARK: - Public Methods
    
    func analyzeSyllables(from audioSession: AudioSession) async throws -> TimeBasedAnalysisResult {
        guard let audioFileURL = audioSession.audioFileURL else {
            throw AudioAnalysisError.fileReadError
        }
        
        return try await analyzeSyllables(from: audioFileURL)
    }
    
    func analyzeRealtimeBuffer(_ buffer: AVAudioPCMBuffer) async -> SyllableSegment? {
        // 실시간 버퍼 분석
        guard let frequencyData = fftAnalyzer.analyzeBuffer(buffer, sampleRate: buffer.format.sampleRate) else {
            return nil
        }
        
        // 윈도우 지속시간 계산
        let windowDuration = Double(buffer.frameLength) / buffer.format.sampleRate
        
        // SyllableSegment 생성
        let segment = SyllableSegment.from(
            frequencyData: frequencyData,
            index: 0, // 실시간에서는 인덱스 0
            windowDuration: windowDuration
        )
        
        // 유효한 음성 세그먼트인지 확인
        return segment.isValid ? segment : nil
    }
    
    func analyzeSyllables(from fileURL: URL) async throws -> TimeBasedAnalysisResult {
        return try await withCheckedThrowingContinuation { continuation in
            print("🎵 VAD 기반 음절별 분석 시작: \(fileURL.lastPathComponent)")
            
            // VAD 초기화
            self.voiceActivityDetector.reset()
            
            do {
                // 1단계: 오디오 파일 읽기
                let audioFile = try AVAudioFile(forReading: fileURL)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    continuation.resume(throwing: AudioAnalysisError.invalidAudioData)
                    return
                }
                
                try audioFile.read(into: buffer)
                
                guard let channelData = buffer.floatChannelData else {
                    continuation.resume(throwing: AudioAnalysisError.invalidAudioData)
                    return
                }
                
                let audioData = Array(UnsafeBufferPointer(start: channelData[0], count: Int(frameCount)))
                
                print("🔍 VAD 분석 시작 - 총 샘플: \(audioData.count), 길이: \(String(format: "%.2f", Double(audioData.count) / format.sampleRate))초")
                
                // 2단계: VAD를 통한 음성 활동 검출
                let vadResults = self.voiceActivityDetector.detectVoiceActivity(in: audioData)
                let vadSegments = self.voiceActivityDetector.createSegments(from: vadResults)
                let speechOnlySegments = self.voiceActivityDetector.speechSegments(from: vadSegments)
                
                print("🔍 VAD 결과: \(vadSegments.count)개 전체 구간, \(speechOnlySegments.count)개 음성 구간")
                
                // 3단계: 고급 음절 세그멘테이션 적용
                let segmentationResults = self.syllableSegmentationEngine.segmentMultipleSpeechSegments(
                    vadSegments: speechOnlySegments,
                    audioData: audioData
                )
                
                // 4단계: 세그멘테이션 결과를 기반으로 FFT 분석 및 SyllableSegment 생성
                var syllableSegments: [SyllableSegment] = []
                
                for (segmentIndex, segmentationResult) in segmentationResults.enumerated() {
                    let boundaries = segmentationResult.syllableBoundaries
                    
                    print("🔪 구간 \(segmentIndex + 1): \(boundaries.count-1)개 음절 검출")
                    
                    // 각 음절별로 FFT 분석 수행
                    for i in 0..<boundaries.count - 1 {
                        let syllableStart = boundaries[i]
                        let syllableEnd = boundaries[i + 1]
                        
                        let startSample = Int(syllableStart * format.sampleRate)
                        let endSample = Int(syllableEnd * format.sampleRate)
                        
                        guard startSample >= 0 && endSample <= audioData.count && startSample < endSample else {
                            print("⚠️ 음절 범위 오류: \(startSample)~\(endSample)")
                            continue
                        }
                        
                        let syllableAudioData = Array(audioData[startSample..<endSample])
                        
                        // 음절별 FFT 분석
                        let frequencyDataArray = self.fftAnalyzer.analyzeTimeSegments(
                            audioData: syllableAudioData,
                            sampleRate: format.sampleRate
                        )
                        
                        // 대표 주파수 데이터 선택 (가장 강한 신호)
                        let dominantFrequencyData = frequencyDataArray.max { first, second in
                            let firstPeak = first.peakMagnitude ?? 0.0
                            let secondPeak = second.peakMagnitude ?? 0.0
                            return firstPeak < secondPeak
                        }
                        
                        if let frequencyData = dominantFrequencyData {
                            let musicNote = frequencyData.peakFrequency.flatMap { MusicNote.from(frequency: $0) }
                            let syllableSegment = SyllableSegment(
                                index: syllableSegments.count,
                                startTime: syllableStart,
                                endTime: syllableEnd,
                                frequencyData: frequencyData,
                                musicNote: musicNote,
                                energy: segmentationResult.energyProfile.reduce(0, +) / Double(max(1, segmentationResult.energyProfile.count)),
                                confidence: segmentationResult.confidence,
                                type: .speech
                            )
                            
                            syllableSegments.append(syllableSegment)
                            
                            let noteString = syllableSegment.musicNote?.description ?? "Unknown"
                            print("🎵 음절 \(syllableSegments.count): \(String(format: "%.3f", syllableStart))~\(String(format: "%.3f", syllableEnd))초 → \(noteString)")
                        }
                    }
                }
                
                // 5단계: 최종 정제 및 품질 필터링 (세그멘테이션 엔진 기반)
                let refinedSegments = self.applyAdvancedQualityFiltering(syllableSegments)
                
                // 6단계: 오디오 세션 및 결과 생성
                let audioSession = AudioSession(
                    duration: Double(frameCount) / format.sampleRate,
                    audioFileURL: fileURL,
                    sampleRate: format.sampleRate,
                    channelCount: Int(format.channelCount)
                )
                
                let analysisResult = self.createAnalysisResult(
                    from: refinedSegments,
                    audioSession: audioSession
                )
                
                print("🎵 VAD 기반 음절별 분석 완료: \(analysisResult.syllableNotes.joined(separator: " → "))")
                print("🎵 분석 품질: \(analysisResult.qualityGrade.koreanName) (신뢰도: \(String(format: "%.1f%%", analysisResult.overallConfidence * 100)))")
                
                continuation.resume(returning: analysisResult)
                
            } catch {
                print("❌ VAD 기반 음절별 분석 실패: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Private Methods (VAD 기반)
    
    // MARK: - Deprecated Methods (Replaced by SyllableSegmentationEngine)
    
    @available(*, deprecated, message: "Use SyllableSegmentationEngine instead")
    private func convertToSyllableSegments(
        frequencyDataArray: [FrequencyData],
        vadSegment: VoiceActivityDetector.VADSegment,
        baseIndex: Int
    ) -> [SyllableSegment] {
        // Legacy implementation preserved for compatibility
        return []
    }
    
    /// 고급 품질 필터링 (세그멘테이션 엔진 결과 기반)
    /// - Parameter segments: 세그멘테이션 엔진으로 생성된 음절 세그먼트들
    /// - Returns: 고품질 세그먼트들
    private func applyAdvancedQualityFiltering(_ segments: [SyllableSegment]) -> [SyllableSegment] {
        // 1단계: 기본 품질 필터링 (더 엄격한 기준)
        let basicFiltered = segments.filter { segment in
            segment.confidence > 0.6 &&          // 신뢰도 60% 이상 (기존 40%에서 상향)
            segment.energy > 0.08 &&             // 에너지 8% 이상 (기존 3%에서 대폭 상향)
            segment.duration >= 0.2 &&           // 최소 0.2초 지속 (기존 0.08초에서 상향)
            segment.duration <= 1.0 &&           // 최대 1초
            segment.musicNote != nil
        }
        
        // 2단계: 에너지 변화 기반 필터링 (연속된 세그먼트 간 의미있는 변화만 유지)
        let energyChangeFiltered = applyEnergyChangeFiltering(basicFiltered)
        
        // 3단계: 주파수 변화 기반 필터링 (급격한 음계 변화만 유지)
        let frequencyChangeFiltered = applyFrequencyChangeFiltering(energyChangeFiltered)
        
        // 4단계: 백그라운드 노이즈 제거 (상대적으로 약한 신호 제거)
        let noiseFiltered = removeBackgroundNoise(frequencyChangeFiltered)
        
        // 인덱스 재정렬
        let reindexedSegments = noiseFiltered.enumerated().map { index, segment in
            SyllableSegment(
                index: index,
                startTime: segment.startTime,
                endTime: segment.endTime,
                frequencyData: segment.frequencyData,
                musicNote: segment.musicNote,
                energy: segment.energy,
                confidence: segment.confidence,
                type: segment.type
            )
        }
        
        print("🔍 고급 품질 필터링:")
        print("   - 세그멘테이션 엔진 결과: \(segments.count)개")
        print("   - 기본 품질 필터링 후: \(basicFiltered.count)개")
        print("   - 에너지 변화 필터링 후: \(energyChangeFiltered.count)개")
        print("   - 주파수 변화 필터링 후: \(frequencyChangeFiltered.count)개")
        print("   - 노이즈 제거 후: \(noiseFiltered.count)개")
        print("   - 최종 음절: \(reindexedSegments.count)개")
        
        return reindexedSegments
    }
    
    /// 에너지 변화 기반 필터링 (연속된 세그먼트 간 의미있는 변화만 유지)
    private func applyEnergyChangeFiltering(_ segments: [SyllableSegment]) -> [SyllableSegment] {
        guard segments.count > 1 else { return segments }
        
        var filtered: [SyllableSegment] = []
        let energyChangeThreshold = 0.5  // 50% 이상 에너지 변화만 유지
        
        // 첫 번째 세그먼트는 항상 포함
        if let first = segments.first {
            filtered.append(first)
        }
        
        for i in 1..<segments.count {
            let current = segments[i]
            let previous = segments[i-1]
            
            let energyChange = abs(current.energy - previous.energy) / max(previous.energy, 0.01)
            
            // 에너지 변화가 임계값 이상이거나, 음계가 크게 변한 경우 포함
            if energyChange >= energyChangeThreshold || hasSignificantPitchChange(previous, current) {
                filtered.append(current)
            }
        }
        
        return filtered
    }
    
    /// 주파수 변화 기반 필터링 (급격한 음계 변화만 유지)
    private func applyFrequencyChangeFiltering(_ segments: [SyllableSegment]) -> [SyllableSegment] {
        guard segments.count > 1 else { return segments }
        
        var filtered: [SyllableSegment] = []
        let frequencyChangeThreshold = 100.0  // 100Hz 이상 변화만 유지
        
        // 첫 번째 세그먼트는 항상 포함
        if let first = segments.first {
            filtered.append(first)
        }
        
        for i in 1..<segments.count {
            let current = segments[i]
            let previous = segments[i-1]
            
            guard let currentFreq = current.musicNote?.frequency,
                  let previousFreq = previous.musicNote?.frequency else {
                // 주파수 정보가 없으면 일단 포함
                filtered.append(current)
                continue
            }
            
            let frequencyChange = abs(currentFreq - previousFreq)
            
            // 주파수 변화가 임계값 이상인 경우만 포함
            if frequencyChange >= frequencyChangeThreshold {
                filtered.append(current)
            }
        }
        
        return filtered
    }
    
    /// 백그라운드 노이즈 제거 (상대적으로 약한 신호 제거)
    private func removeBackgroundNoise(_ segments: [SyllableSegment]) -> [SyllableSegment] {
        guard !segments.isEmpty else { return segments }
        
        // 전체 에너지의 평균과 표준편차 계산
        let energies = segments.map { $0.energy }
        let meanEnergy = energies.reduce(0, +) / Double(energies.count)
        let variance = energies.map { pow($0 - meanEnergy, 2) }.reduce(0, +) / Double(energies.count)
        let stdDeviation = sqrt(variance)
        
        // 평균 + 표준편차 이상의 에너지를 가진 세그먼트만 유지
        let energyThreshold = meanEnergy + stdDeviation
        
        let filtered = segments.filter { segment in
            segment.energy >= energyThreshold
        }
        
        print("🔇 노이즈 제거: 평균 에너지 \(String(format: "%.3f", meanEnergy)), 임계값 \(String(format: "%.3f", energyThreshold))")
        
        return filtered
    }
    
    /// 두 세그먼트 간 의미있는 음계 변화가 있는지 확인
    private func hasSignificantPitchChange(_ previous: SyllableSegment, _ current: SyllableSegment) -> Bool {
        guard let prevNote = previous.musicNote, let currNote = current.musicNote else {
            return false
        }
        
        // 3반음(minor third) 이상 변화가 있으면 의미있는 변화로 간주
        let semitoneDifference = abs(currNote.midiNumber - prevNote.midiNumber)
        return semitoneDifference >= 3
    }
    
    // MARK: - Legacy Methods (Deprecated)
    
    /// 품질 기반 세그먼트 필터링
    /// - Parameter segments: 필터링할 세그먼트들
    /// - Returns: 품질 기준을 만족하는 세그먼트들
    private func filterByQuality(_ segments: [SyllableSegment]) -> [SyllableSegment] {
        // 최소 품질 기준: Fair 이상
        return segments.filter { segment in
            segment.qualityGrade != .poor &&
            segment.confidence > 0.2 &&
            segment.energy > 0.03
        }
    }
    
    /// 오디오 파일 URL로부터 AudioSession 생성
    /// - Parameters:
    ///   - fileURL: 오디오 파일 URL
    ///   - frequencyDataArray: 주파수 데이터 배열
    /// - Returns: 생성된 오디오 세션
    private func createAudioSession(from fileURL: URL, frequencyDataArray: [FrequencyData]) -> AudioSession {
        let sampleRate = frequencyDataArray.first?.sampleRate ?? 44100.0
        let totalFrames = frequencyDataArray.count * fftSize
        let duration = Double(totalFrames) / sampleRate
        
        return AudioSession(
            duration: duration,
            audioFileURL: fileURL,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }
    
    /// 정제된 세그먼트들로부터 최종 분석 결과 생성
    /// - Parameters:
    ///   - syllableSegments: 정제된 음절 세그먼트들
    ///   - audioSession: 오디오 세션 정보
    /// - Returns: 시간 기반 분석 결과
    private func createAnalysisResult(
        from syllableSegments: [SyllableSegment],
        audioSession: AudioSession
    ) -> TimeBasedAnalysisResult {
        // 분석 메타데이터 생성
        let metadata = AnalysisMetadata(
            totalSegments: syllableSegments.count,
            validSegments: syllableSegments.speechSegments.count,
            averageEnergy: syllableSegments.speechSegments.isEmpty ? 0.0 :
                syllableSegments.speechSegments.reduce(0) { $0 + $1.energy } / Double(syllableSegments.speechSegments.count),
            frequencyRange: syllableSegments.frequencyRange,
            analysisMethod: .timeDomain,
            windowSize: Double(fftSize) / audioSession.sampleRate
        )
        
        return TimeBasedAnalysisResult(
            audioSession: audioSession,
            syllableSegments: syllableSegments,
            status: .completed,
            analysisStartTime: Date().addingTimeInterval(-1), // 1초 전에 시작했다고 가정
            analysisEndTime: Date(),
            error: nil,
            metadata: metadata
        )
    }
}

// MARK: - Extensions

extension SyllableAnalysisUseCaseImpl {
    
    /// 분석 결과를 음악 스케일 추천을 위한 형태로 변환
    /// - Parameter analysisResult: 시간 기반 분석 결과
    /// - Returns: 스케일 분석을 위한 음정 데이터
    func prepareForScaleRecommendation(_ analysisResult: TimeBasedAnalysisResult) -> [Int] {
        return analysisResult.getScaleAnalysisData()
    }
    
    /// 분석 설정 업데이트
    /// - Parameters:
    ///   - sensitivity: 감도 (0.0 ~ 1.0)
    ///   - minDuration: 최소 음성 지속시간
    func updateAnalysisSettings(sensitivity: Double, minDuration: TimeInterval) {
        // 런타임에서 설정 업데이트가 필요한 경우를 위한 확장 포인트
        print("🔧 분석 설정 업데이트: 감도=\(sensitivity), 최소지속시간=\(minDuration)s")
    }
} 