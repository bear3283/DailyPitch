import Foundation
import Accelerate

/// 음성 활동 검출(Voice Activity Detection) 클래스
/// 에너지, 제로 크로싱 레이트, 스펙트럼 특성을 종합하여 음성/무음 구간 분리
class VoiceActivityDetector {
    
    // MARK: - Configuration
    
    /// VAD 설정 구조체
    struct VADConfiguration {
        /// 에너지 임계값 (0.0 ~ 1.0)
        let energyThreshold: Double
        
        /// ZCR 임계값 (Hz)
        let zcrThreshold: Double
        
        /// 스펙트럼 플럭스 임계값
        let spectralFluxThreshold: Double
        
        /// 최소 음성 지속시간 (초)
        let minSpeechDuration: TimeInterval
        
        /// 최소 무음 지속시간 (초)
        let minSilenceDuration: TimeInterval
        
        /// 행아웃 시간 (음성 종료 후 추가 유지 시간, 초)
        let hangoverTime: TimeInterval
        
        /// 적응적 임계값 사용 여부
        let useAdaptiveThreshold: Bool
        
        /// 노이즈 추정 시간 (초)
        let noiseEstimationTime: TimeInterval
        
        static let `default` = VADConfiguration(
            energyThreshold: 0.01,
            zcrThreshold: 50.0,
            spectralFluxThreshold: 0.02,
            minSpeechDuration: 0.1,
            minSilenceDuration: 0.05,
            hangoverTime: 0.2,
            useAdaptiveThreshold: true,
            noiseEstimationTime: 0.5
        )
        
        /// 의미있는 음성 변화만 감지하는 엄격한 설정
        static let significantChangeOnly = VADConfiguration(
            energyThreshold: 0.08,          // 8% - 훨씬 높은 임계값
            zcrThreshold: 80.0,             // 더 높은 ZCR 임계값
            spectralFluxThreshold: 0.1,     // 5배 높은 스펙트럼 변화 임계값
            minSpeechDuration: 0.25,        // 최소 0.25초 지속되어야 음성으로 인정
            minSilenceDuration: 0.15,       // 최소 0.15초 무음이어야 구간 분리
            hangoverTime: 0.1,              // 짧은 행아웃 시간
            useAdaptiveThreshold: true,
            noiseEstimationTime: 1.0        // 더 긴 노이즈 추정 시간
        )
        
        /// 일상 소음 환경에 최적화된 설정
        static let dailyEnvironment = VADConfiguration(
            energyThreshold: 0.12,          // 12% - 매우 높은 임계값
            zcrThreshold: 100.0,
            spectralFluxThreshold: 0.15,
            minSpeechDuration: 0.3,         // 최소 0.3초
            minSilenceDuration: 0.2,        // 최소 0.2초
            hangoverTime: 0.05,
            useAdaptiveThreshold: true,
            noiseEstimationTime: 1.5        // 백그라운드 노이즈 충분히 학습
        )
    }
    
    /// VAD 결과 구조체
    struct VADResult {
        /// 음성 구간 여부
        let isSpeech: Bool
        
        /// 에너지 레벨 (0.0 ~ 1.0)
        let energyLevel: Double
        
        /// 제로 크로싱 레이트
        let zeroCrossingRate: Double
        
        /// 스펙트럼 플럭스
        let spectralFlux: Double
        
        /// 종합 신뢰도 (0.0 ~ 1.0)
        let confidence: Double
        
        /// 시간 위치 (초)
        let timestamp: TimeInterval
    }
    
    /// 연속된 VAD 구간
    struct VADSegment {
        let startTime: TimeInterval
        let endTime: TimeInterval
        let isSpeech: Bool
        let averageConfidence: Double
        let averageEnergy: Double
        
        var duration: TimeInterval {
            return endTime - startTime
        }
    }
    
    // MARK: - Properties
    
    private let configuration: VADConfiguration
    private let sampleRate: Double
    private let frameSize: Int
    private let hopSize: Int
    
    /// 적응적 임계값을 위한 노이즈 레벨 추정
    private var noiseEnergyLevel: Double = 0.0
    private var noiseZCRLevel: Double = 0.0
    private var isNoiseEstimated: Bool = false
    
    /// 이전 프레임의 스펙트럼 (스펙트럼 플럭스 계산용)
    private var previousSpectrum: [Double] = []
    
    /// 시간적 연속성을 위한 상태 추적
    private var consecutiveSpeechFrames: Int = 0
    private var consecutiveSilenceFrames: Int = 0
    private var hangoverFrames: Int = 0
    
    // MARK: - Initialization
    
    init(
        configuration: VADConfiguration = .default,
        sampleRate: Double = 44100.0,
        frameSize: Int = 1024
    ) {
        self.configuration = configuration
        self.sampleRate = sampleRate
        self.frameSize = frameSize
        self.hopSize = frameSize / 2 // 50% overlap
        
        reset()
    }
    
    // MARK: - Public Methods
    
    /// VAD 상태 초기화
    func reset() {
        noiseEnergyLevel = 0.0
        noiseZCRLevel = 0.0
        isNoiseEstimated = false
        previousSpectrum.removeAll()
        consecutiveSpeechFrames = 0
        consecutiveSilenceFrames = 0
        hangoverFrames = 0
    }
    
    /// 오디오 데이터에서 음성 활동 검출
    /// - Parameters:
    ///   - audioData: 입력 오디오 데이터
    ///   - startTime: 시작 시간 (초)
    /// - Returns: VAD 결과 배열
    func detectVoiceActivity(in audioData: [Float], startTime: TimeInterval = 0.0) -> [VADResult] {
        guard audioData.count >= frameSize else {
            print("⚠️ VAD: 오디오 데이터가 너무 짧습니다 (\(audioData.count) < \(frameSize))")
            return []
        }
        
        var results: [VADResult] = []
        var frameIndex = 0
        
        // 프레임별 분석
        while frameIndex + frameSize <= audioData.count {
            let frameData = Array(audioData[frameIndex..<frameIndex + frameSize])
            let timestamp = startTime + Double(frameIndex) / sampleRate
            
            let vadResult = analyzeFrame(frameData, timestamp: timestamp)
            results.append(vadResult)
            
            frameIndex += hopSize
        }
        
        // 노이즈 레벨 추정 (처음 몇 프레임)
        if !isNoiseEstimated && results.count > 10 {
            estimateNoiseLevel(from: results)
        }
        
        // 시간적 연속성 적용
        let smoothedResults = applySmoothingAndHangover(results)
        
        print("🔍 VAD 분석 완료: \(results.count)개 프레임, 음성 비율: \(String(format: "%.1f%%", Double(smoothedResults.filter { $0.isSpeech }.count) / Double(smoothedResults.count) * 100))")
        
        return smoothedResults
    }
    
    /// VAD 결과를 연속된 세그먼트로 변환
    /// - Parameter vadResults: VAD 결과 배열
    /// - Returns: 연속된 VAD 세그먼트 배열
    func createSegments(from vadResults: [VADResult]) -> [VADSegment] {
        guard !vadResults.isEmpty else { return [] }
        
        var segments: [VADSegment] = []
        var currentSegmentStart: TimeInterval?
        var currentIsSpeech: Bool?
        var currentConfidences: [Double] = []
        var currentEnergies: [Double] = []
        
        for result in vadResults {
            if currentIsSpeech == nil {
                // 첫 번째 세그먼트 시작
                currentSegmentStart = result.timestamp
                currentIsSpeech = result.isSpeech
                currentConfidences = [result.confidence]
                currentEnergies = [result.energyLevel]
            } else if currentIsSpeech != result.isSpeech {
                // 세그먼트 변경 - 이전 세그먼트 완료
                if let startTime = currentSegmentStart,
                   let isSpeech = currentIsSpeech {
                    
                    let avgConfidence = currentConfidences.reduce(0, +) / Double(currentConfidences.count)
                    let avgEnergy = currentEnergies.reduce(0, +) / Double(currentEnergies.count)
                    
                    let segment = VADSegment(
                        startTime: startTime,
                        endTime: result.timestamp,
                        isSpeech: isSpeech,
                        averageConfidence: avgConfidence,
                        averageEnergy: avgEnergy
                    )
                    
                    // 최소 지속시간 조건 확인
                    let minDuration = isSpeech ? configuration.minSpeechDuration : configuration.minSilenceDuration
                    if segment.duration >= minDuration {
                        segments.append(segment)
                    }
                }
                
                // 새 세그먼트 시작
                currentSegmentStart = result.timestamp
                currentIsSpeech = result.isSpeech
                currentConfidences = [result.confidence]
                currentEnergies = [result.energyLevel]
            } else {
                // 같은 세그먼트 계속
                currentConfidences.append(result.confidence)
                currentEnergies.append(result.energyLevel)
            }
        }
        
        // 마지막 세그먼트 처리
        if let startTime = currentSegmentStart,
           let isSpeech = currentIsSpeech,
           let lastResult = vadResults.last {
            
            let avgConfidence = currentConfidences.reduce(0, +) / Double(currentConfidences.count)
            let avgEnergy = currentEnergies.reduce(0, +) / Double(currentEnergies.count)
            
            let segment = VADSegment(
                startTime: startTime,
                endTime: lastResult.timestamp + (Double(hopSize) / sampleRate),
                isSpeech: isSpeech,
                averageConfidence: avgConfidence,
                averageEnergy: avgEnergy
            )
            
            let minDuration = isSpeech ? configuration.minSpeechDuration : configuration.minSilenceDuration
            if segment.duration >= minDuration {
                segments.append(segment)
            }
        }
        
        let speechSegments = segments.filter { $0.isSpeech }
        print("📊 VAD 세그먼트 생성: 총 \(segments.count)개, 음성 \(speechSegments.count)개")
        
        return segments
    }
    
    /// 음성 세그먼트만 필터링
    /// - Parameter segments: 전체 세그먼트 배열
    /// - Returns: 음성 세그먼트만 포함된 배열
    func speechSegments(from segments: [VADSegment]) -> [VADSegment] {
        return segments.filter { $0.isSpeech && $0.averageConfidence > 0.3 }
    }
    
    // MARK: - Private Methods
    
    /// 개별 프레임 분석
    /// - Parameters:
    ///   - frameData: 프레임 오디오 데이터
    ///   - timestamp: 시간 정보
    /// - Returns: VAD 결과
    private func analyzeFrame(_ frameData: [Float], timestamp: TimeInterval) -> VADResult {
        // 1. 에너지 계산
        let energy = calculateEnergy(frameData)
        
        // 2. 제로 크로싱 레이트 계산
        let zcr = calculateZeroCrossingRate(frameData)
        
        // 3. 스펙트럼 플럭스 계산
        let spectralFlux = calculateSpectralFlux(frameData)
        
        // 4. 종합 판단
        let (isSpeech, confidence) = makeVADDecision(
            energy: energy,
            zcr: zcr,
            spectralFlux: spectralFlux
        )
        
        return VADResult(
            isSpeech: isSpeech,
            energyLevel: energy,
            zeroCrossingRate: zcr,
            spectralFlux: spectralFlux,
            confidence: confidence,
            timestamp: timestamp
        )
    }
    
    /// 에너지 계산 (RMS)
    /// - Parameter frameData: 프레임 데이터
    /// - Returns: 정규화된 에너지 (0.0 ~ 1.0)
    private func calculateEnergy(_ frameData: [Float]) -> Double {
        let sumOfSquares = frameData.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(frameData.count))
        
        // 로그 스케일로 변환하여 정규화
        let energyDB = 20.0 * log10(max(Double(rms), 1e-10))
        let normalizedEnergy = max(0.0, min(1.0, (energyDB + 60.0) / 60.0)) // -60dB ~ 0dB 범위를 0~1로
        
        return normalizedEnergy
    }
    
    /// 제로 크로싱 레이트 계산
    /// - Parameter frameData: 프레임 데이터
    /// - Returns: ZCR (Hz)
    private func calculateZeroCrossingRate(_ frameData: [Float]) -> Double {
        guard frameData.count > 1 else { return 0.0 }
        
        var crossings = 0
        for i in 1..<frameData.count {
            if (frameData[i-1] >= 0 && frameData[i] < 0) || (frameData[i-1] < 0 && frameData[i] >= 0) {
                crossings += 1
            }
        }
        
        // Hz로 변환
        let zcrRate = Double(crossings) * sampleRate / (2.0 * Double(frameData.count))
        return zcrRate
    }
    
    /// 스펙트럼 플럭스 계산
    /// - Parameter frameData: 프레임 데이터
    /// - Returns: 스펙트럼 플럭스 값
    private func calculateSpectralFlux(_ frameData: [Float]) -> Double {
        // FFT 계산
        let spectrum = performFFT(frameData)
        
        var spectralFlux = 0.0
        
        if !previousSpectrum.isEmpty && previousSpectrum.count == spectrum.count {
            // 이전 프레임과의 차이 계산
            for i in 0..<spectrum.count {
                let diff = spectrum[i] - previousSpectrum[i]
                spectralFlux += max(0.0, diff) // 증가분만 고려
            }
            spectralFlux /= Double(spectrum.count)
        }
        
        previousSpectrum = spectrum
        return spectralFlux
    }
    
    /// 간단한 FFT 계산 (magnitude spectrum)
    /// - Parameter frameData: 입력 데이터
    /// - Returns: 크기 스펙트럼
    private func performFFT(_ frameData: [Float]) -> [Double] {
        let fftSize = frameData.count
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        
        guard let fftSetup = vDSP.FFT(log2n: log2Size, radix: .radix2, ofType: DSPSplitComplex.self) else {
            return []
        }
        
        var realParts = frameData
        var imagParts = Array(repeating: Float(0.0), count: fftSize)
        var outputReal = Array(repeating: Float(0.0), count: fftSize / 2)
        var outputImag = Array(repeating: Float(0.0), count: fftSize / 2)
        
        realParts.withUnsafeMutableBufferPointer { realPtr in
            imagParts.withUnsafeMutableBufferPointer { imagPtr in
                outputReal.withUnsafeMutableBufferPointer { outRealPtr in
                    outputImag.withUnsafeMutableBufferPointer { outImagPtr in
                        let input = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                        var output = DSPSplitComplex(realp: outRealPtr.baseAddress!, imagp: outImagPtr.baseAddress!)
                        
                        fftSetup.forward(input: input, output: &output)
                    }
                }
            }
        }
        
        // 크기 스펙트럼 계산
        var magnitudes: [Double] = []
        for i in 0..<outputReal.count {
            let magnitude = sqrt(Double(outputReal[i] * outputReal[i] + outputImag[i] * outputImag[i]))
            magnitudes.append(magnitude)
        }
        
        return magnitudes
    }
    
    /// VAD 결정 로직
    /// - Parameters:
    ///   - energy: 에너지 레벨
    ///   - zcr: 제로 크로싱 레이트
    ///   - spectralFlux: 스펙트럼 플럭스
    /// - Returns: (음성 여부, 신뢰도)
    private func makeVADDecision(energy: Double, zcr: Double, spectralFlux: Double) -> (Bool, Double) {
        // 적응적 임계값 적용
        let energyThreshold = configuration.useAdaptiveThreshold ? 
            max(configuration.energyThreshold, noiseEnergyLevel * 2.0) : 
            configuration.energyThreshold
            
        let zcrThreshold = configuration.useAdaptiveThreshold ?
            max(configuration.zcrThreshold, noiseZCRLevel * 1.5) :
            configuration.zcrThreshold
        
        // 각 특성별 점수 계산
        let energyScore = energy > energyThreshold ? 1.0 : 0.0
        let zcrScore = zcr > zcrThreshold ? 1.0 : 0.0
        let fluxScore = spectralFlux > configuration.spectralFluxThreshold ? 1.0 : 0.0
        
        // 가중치 적용한 종합 점수
        let weightedScore = energyScore * 0.5 + zcrScore * 0.3 + fluxScore * 0.2
        
        // 음성 판단 및 신뢰도 계산
        let isSpeech = weightedScore > 0.5
        let confidence = isSpeech ? weightedScore : (1.0 - weightedScore)
        
        return (isSpeech, confidence)
    }
    
    /// 노이즈 레벨 추정
    /// - Parameter vadResults: 초기 VAD 결과들
    private func estimateNoiseLevel(from vadResults: [VADResult]) {
        let noiseEstimationFrames = Int(configuration.noiseEstimationTime * sampleRate / Double(hopSize))
        let estimationResults = Array(vadResults.prefix(min(noiseEstimationFrames, vadResults.count)))
        
        // 낮은 에너지 프레임들을 노이즈로 간주
        let lowEnergyResults = estimationResults.filter { $0.energyLevel < 0.1 }
        
        if !lowEnergyResults.isEmpty {
            noiseEnergyLevel = lowEnergyResults.reduce(0) { $0 + $1.energyLevel } / Double(lowEnergyResults.count)
            noiseZCRLevel = lowEnergyResults.reduce(0) { $0 + $1.zeroCrossingRate } / Double(lowEnergyResults.count)
            
            print("🔇 노이즈 레벨 추정 완료 - 에너지: \(String(format: "%.4f", noiseEnergyLevel)), ZCR: \(String(format: "%.1f", noiseZCRLevel))Hz")
        }
        
        isNoiseEstimated = true
    }
    
    /// 시간적 연속성 및 행아웃 적용
    /// - Parameter vadResults: 원본 VAD 결과
    /// - Returns: 스무딩 적용된 VAD 결과
    private func applySmoothingAndHangover(_ vadResults: [VADResult]) -> [VADResult] {
        guard !vadResults.isEmpty else { return [] }
        
        var smoothedResults = vadResults
        let hangoverFrames = Int(configuration.hangoverTime * sampleRate / Double(hopSize))
        
        // 행아웃 및 최소 지속시간 적용
        var speechEndFrame = -1
        
        for i in 0..<smoothedResults.count {
            let result = smoothedResults[i]
            
            if result.isSpeech {
                speechEndFrame = i
            } else if speechEndFrame >= 0 && (i - speechEndFrame) <= hangoverFrames {
                // 행아웃 기간 내의 무음을 음성으로 변경
                smoothedResults[i] = VADResult(
                    isSpeech: true,
                    energyLevel: result.energyLevel,
                    zeroCrossingRate: result.zeroCrossingRate,
                    spectralFlux: result.spectralFlux,
                    confidence: result.confidence * 0.5, // 신뢰도는 절반으로
                    timestamp: result.timestamp
                )
            }
        }
        
        return smoothedResults
    }
} 