import Foundation
import Accelerate

/// 고급 음절 세그멘테이션 엔진
/// VAD 결과를 받아 더 정밀한 음절 경계를 검출하는 전문 시스템
class SyllableSegmentationEngine {
    
    // MARK: - Configuration
    
    /// 세그멘테이션 설정 구조체
    struct SegmentationConfiguration {
        /// 에너지 변화 임계값 (0.0 ~ 1.0)
        let energyChangeThreshold: Double
        
        /// 스펙트럼 중심 변화 임계값 (Hz)
        let spectralCentroidChangeThreshold: Double
        
        /// 최소 음절 지속시간 (초)
        let minSyllableDuration: TimeInterval
        
        /// 최대 음절 지속시간 (초)
        let maxSyllableDuration: TimeInterval
        
        /// 음절간 최소 간격 (초)
        let minInterSyllableGap: TimeInterval
        
        /// 스무딩 윈도우 크기 (프레임 수)
        let smoothingWindowSize: Int
        
        /// 한국어 특화 설정 사용 여부
        let useKoreanOptimization: Bool
        
        /// 적응적 임계값 사용 여부
        let useAdaptiveThresholds: Bool
        
        static let `default` = SegmentationConfiguration(
            energyChangeThreshold: 0.3,
            spectralCentroidChangeThreshold: 150.0,
            minSyllableDuration: 0.08,
            maxSyllableDuration: 0.6,
            minInterSyllableGap: 0.02,
            smoothingWindowSize: 3,
            useKoreanOptimization: true,
            useAdaptiveThresholds: true
        )
        
        static let korean = SegmentationConfiguration(
            energyChangeThreshold: 0.25,
            spectralCentroidChangeThreshold: 120.0,
            minSyllableDuration: 0.09,
            maxSyllableDuration: 0.5,
            minInterSyllableGap: 0.025,
            smoothingWindowSize: 5,
            useKoreanOptimization: true,
            useAdaptiveThresholds: true
        )
        
        /// 의미있는 음절 변화만 감지하는 엄격한 설정
        static let significantChangeOnly = SegmentationConfiguration(
            energyChangeThreshold: 0.6,           // 60% 이상 에너지 변화만 감지
            spectralCentroidChangeThreshold: 300.0, // 300Hz 이상 주파수 변화만 감지
            minSyllableDuration: 0.2,             // 최소 0.2초 지속되어야 음절로 인정
            maxSyllableDuration: 1.0,             // 더 긴 최대 지속시간
            minInterSyllableGap: 0.1,             // 음절간 최소 0.1초 간격
            smoothingWindowSize: 7,               // 더 강한 스무딩
            useKoreanOptimization: false,         // 일반적인 음성 변화 감지
            useAdaptiveThresholds: true
        )
        
        /// 일상 환경 최적화 설정
        static let dailyEnvironment = SegmentationConfiguration(
            energyChangeThreshold: 0.8,           // 80% 이상 에너지 변화 (매우 엄격)
            spectralCentroidChangeThreshold: 400.0, // 400Hz 이상 주파수 변화
            minSyllableDuration: 0.25,            // 최소 0.25초
            maxSyllableDuration: 1.2,
            minInterSyllableGap: 0.15,            // 음절간 최소 0.15초 간격
            smoothingWindowSize: 9,               // 매우 강한 스무딩
            useKoreanOptimization: false,
            useAdaptiveThresholds: true
        )
    }
    
    /// 세그멘테이션 결과
    struct SegmentationResult {
        let originalSegment: VoiceActivityDetector.VADSegment
        let syllableBoundaries: [TimeInterval]
        let energyProfile: [Double]
        let spectralCentroidProfile: [Double]
        let confidence: Double
        let method: SegmentationMethod
    }
    
    /// 세그멘테이션 방법
    enum SegmentationMethod: String, CaseIterable {
        case energyBased = "에너지 기반"
        case spectralBased = "스펙트럼 기반"
        case hybrid = "하이브리드"
        case durationBased = "지속시간 기반"
        case adaptive = "적응적"
        
        var koreanName: String { return self.rawValue }
    }
    
    // MARK: - Properties
    
    private let configuration: SegmentationConfiguration
    private let sampleRate: Double
    private let frameSize: Int
    private let hopSize: Int
    
    /// 적응적 임계값을 위한 통계
    private var energyStatistics: (mean: Double, stdDev: Double) = (0.0, 0.0)
    private var spectralCentroidStatistics: (mean: Double, stdDev: Double) = (0.0, 0.0)
    
    // MARK: - Initialization
    
    init(
        configuration: SegmentationConfiguration = .korean,
        sampleRate: Double = 44100.0,
        frameSize: Int = 1024
    ) {
        self.configuration = configuration
        self.sampleRate = sampleRate
        self.frameSize = frameSize
        self.hopSize = frameSize / 2
    }
    
    // MARK: - Public Methods
    
    /// VAD 세그먼트를 음절로 세분화
    /// - Parameters:
    ///   - vadSegment: VAD로 검출된 음성 구간
    ///   - audioData: 해당 구간의 오디오 데이터
    /// - Returns: 세그멘테이션 결과
    func segmentIntoSyllables(
        vadSegment: VoiceActivityDetector.VADSegment,
        audioData: [Float]
    ) -> SegmentationResult {
        
        print("🔪 음절 세그멘테이션 시작: \(String(format: "%.3f", vadSegment.startTime))~\(String(format: "%.3f", vadSegment.endTime))초")
        
        // 1단계: 프레임별 특성 추출
        let frameFeatures = extractFrameFeatures(from: audioData)
        
        // 2단계: 통계 계산 (적응적 임계값용)
        if configuration.useAdaptiveThresholds {
            updateStatistics(from: frameFeatures)
        }
        
        // 3단계: 음절 경계 후보 검출
        let energyBoundaries = detectEnergyBasedBoundaries(features: frameFeatures)
        let spectralBoundaries = detectSpectralBasedBoundaries(features: frameFeatures)
        
        // 4단계: 하이브리드 경계 결정
        let finalBoundaries = combineAndRefineBoundaries(
            energyBoundaries: energyBoundaries,
            spectralBoundaries: spectralBoundaries,
            vadSegment: vadSegment,
            audioLength: audioData.count
        )
        
        // 5단계: 한국어 특화 후처리
        let optimizedBoundaries = configuration.useKoreanOptimization ? 
            applyKoreanOptimization(boundaries: finalBoundaries, features: frameFeatures) :
            finalBoundaries
        
        let confidence = calculateSegmentationConfidence(
            boundaries: optimizedBoundaries,
            features: frameFeatures
        )
        
        let result = SegmentationResult(
            originalSegment: vadSegment,
            syllableBoundaries: optimizedBoundaries,
            energyProfile: frameFeatures.map { $0.energy },
            spectralCentroidProfile: frameFeatures.map { $0.spectralCentroid },
            confidence: confidence,
            method: .hybrid
        )
        
        print("🔪 세그멘테이션 완료: \(optimizedBoundaries.count)개 경계, 신뢰도: \(String(format: "%.1f%%", confidence * 100))")
        
        return result
    }
    
    /// 다중 VAD 세그먼트들을 일괄 처리
    /// - Parameters:
    ///   - vadSegments: VAD 세그먼트 배열
    ///   - audioData: 전체 오디오 데이터
    /// - Returns: 세그멘테이션 결과 배열
    func segmentMultipleSpeechSegments(
        vadSegments: [VoiceActivityDetector.VADSegment],
        audioData: [Float]
    ) -> [SegmentationResult] {
        
        var results: [SegmentationResult] = []
        
        for vadSegment in vadSegments {
            let startSample = Int(vadSegment.startTime * sampleRate)
            let endSample = Int(vadSegment.endTime * sampleRate)
            
            guard startSample >= 0 && endSample <= audioData.count && startSample < endSample else {
                print("⚠️ 잘못된 세그먼트 범위: \(startSample)~\(endSample)")
                continue
            }
            
            let segmentAudioData = Array(audioData[startSample..<endSample])
            let segmentationResult = segmentIntoSyllables(
                vadSegment: vadSegment,
                audioData: segmentAudioData
            )
            
            results.append(segmentationResult)
        }
        
        print("🔪 일괄 세그멘테이션 완료: \(vadSegments.count)개 구간 → \(results.reduce(0) { $0 + $1.syllableBoundaries.count })개 음절 경계")
        
        return results
    }
    
    // MARK: - Private Methods
    
    /// 프레임별 특성 추출
    /// - Parameter audioData: 오디오 데이터
    /// - Returns: 프레임 특성 배열
    private func extractFrameFeatures(from audioData: [Float]) -> [FrameFeatures] {
        var features: [FrameFeatures] = []
        var frameIndex = 0
        
        while frameIndex + frameSize <= audioData.count {
            let frameData = Array(audioData[frameIndex..<frameIndex + frameSize])
            let feature = FrameFeatures(from: frameData, sampleRate: sampleRate)
            features.append(feature)
            
            frameIndex += hopSize
        }
        
        // 스무딩 적용
        return applySmoothing(to: features)
    }
    
    /// 에너지 기반 경계 검출
    /// - Parameter features: 프레임 특성들
    /// - Returns: 경계 시간 배열
    private func detectEnergyBasedBoundaries(features: [FrameFeatures]) -> [TimeInterval] {
        guard features.count > 1 else { return [] }
        
        var boundaries: [TimeInterval] = []
        let threshold = configuration.useAdaptiveThresholds ? 
            energyStatistics.mean + (energyStatistics.stdDev * configuration.energyChangeThreshold) :
            configuration.energyChangeThreshold
        
        for i in 1..<features.count {
            let energyChange = abs(features[i].energy - features[i-1].energy)
            let normalizedChange = energyChange / max(features[i-1].energy, 0.01)
            
            if normalizedChange > threshold {
                let boundaryTime = Double(i) * Double(hopSize) / sampleRate
                boundaries.append(boundaryTime)
            }
        }
        
        return boundaries
    }
    
    /// 스펙트럼 기반 경계 검출
    /// - Parameter features: 프레임 특성들
    /// - Returns: 경계 시간 배열
    private func detectSpectralBasedBoundaries(features: [FrameFeatures]) -> [TimeInterval] {
        guard features.count > 1 else { return [] }
        
        var boundaries: [TimeInterval] = []
        let threshold = configuration.useAdaptiveThresholds ?
            spectralCentroidStatistics.mean + (spectralCentroidStatistics.stdDev * 0.5) :
            configuration.spectralCentroidChangeThreshold
        
        for i in 1..<features.count {
            let centroidChange = abs(features[i].spectralCentroid - features[i-1].spectralCentroid)
            
            if centroidChange > threshold {
                let boundaryTime = Double(i) * Double(hopSize) / sampleRate
                boundaries.append(boundaryTime)
            }
        }
        
        return boundaries
    }
    
    /// 경계들을 결합하고 정제
    /// - Parameters:
    ///   - energyBoundaries: 에너지 기반 경계들
    ///   - spectralBoundaries: 스펙트럼 기반 경계들
    ///   - vadSegment: 원본 VAD 세그먼트
    ///   - audioLength: 오디오 길이
    /// - Returns: 최종 경계 배열
    private func combineAndRefineBoundaries(
        energyBoundaries: [TimeInterval],
        spectralBoundaries: [TimeInterval],
        vadSegment: VoiceActivityDetector.VADSegment,
        audioLength: Int
    ) -> [TimeInterval] {
        
        // 모든 후보 경계들을 결합
        let allBoundaries = Set(energyBoundaries + spectralBoundaries)
        var sortedBoundaries = Array(allBoundaries).sorted()
        
        // 절대 시간으로 변환
        sortedBoundaries = sortedBoundaries.map { vadSegment.startTime + $0 }
        
        // 최소 간격 필터링
        var filteredBoundaries: [TimeInterval] = []
        var lastBoundary: TimeInterval = vadSegment.startTime
        
        for boundary in sortedBoundaries {
            if boundary - lastBoundary >= configuration.minInterSyllableGap {
                filteredBoundaries.append(boundary)
                lastBoundary = boundary
            }
        }
        
        // 지속시간 기반 추가 분할
        filteredBoundaries = applyDurationBasedSplitting(
            boundaries: filteredBoundaries,
            vadSegment: vadSegment
        )
        
        // 시작과 끝 경계 추가
        var finalBoundaries = [vadSegment.startTime] + filteredBoundaries
        if finalBoundaries.last != vadSegment.endTime {
            finalBoundaries.append(vadSegment.endTime)
        }
        
        return finalBoundaries.sorted()
    }
    
    /// 지속시간 기반 분할
    /// - Parameters:
    ///   - boundaries: 현재 경계들
    ///   - vadSegment: VAD 세그먼트
    /// - Returns: 분할 적용된 경계들
    private func applyDurationBasedSplitting(
        boundaries: [TimeInterval],
        vadSegment: VoiceActivityDetector.VADSegment
    ) -> [TimeInterval] {
        
        var newBoundaries = boundaries
        let tempBoundaries = [vadSegment.startTime] + boundaries + [vadSegment.endTime]
        
        for i in 0..<tempBoundaries.count - 1 {
            let segmentDuration = tempBoundaries[i + 1] - tempBoundaries[i]
            
            if segmentDuration > configuration.maxSyllableDuration {
                // 긴 세그먼트를 균등 분할
                let numberOfSplits = Int(ceil(segmentDuration / configuration.maxSyllableDuration))
                let splitDuration = segmentDuration / Double(numberOfSplits)
                
                for j in 1..<numberOfSplits {
                    let newBoundary = tempBoundaries[i] + (Double(j) * splitDuration)
                    newBoundaries.append(newBoundary)
                }
            }
        }
        
        return newBoundaries.sorted()
    }
    
    /// 한국어 특화 최적화
    /// - Parameters:
    ///   - boundaries: 현재 경계들
    ///   - features: 프레임 특성들
    /// - Returns: 최적화된 경계들
    private func applyKoreanOptimization(
        boundaries: [TimeInterval],
        features: [FrameFeatures]
    ) -> [TimeInterval] {
        
        // 한국어 음성학적 특성:
        // 1. 평균 음절 지속시간: 0.15~0.35초
        // 2. 모음 중심의 에너지 분포
        // 3. 자음-모음 전이 패턴
        
        var optimizedBoundaries = boundaries
        
        // 너무 짧은 음절 병합
        var filteredBoundaries: [TimeInterval] = [optimizedBoundaries[0]]
        
        for i in 1..<optimizedBoundaries.count {
            let prevBoundary = filteredBoundaries.last!
            let currentBoundary = optimizedBoundaries[i]
            let syllableDuration = currentBoundary - prevBoundary
            
            if syllableDuration >= configuration.minSyllableDuration {
                filteredBoundaries.append(currentBoundary)
            }
            // 짧은 경우 이전 경계를 현재 위치로 조정
            else if i == optimizedBoundaries.count - 1 {
                filteredBoundaries[filteredBoundaries.count - 1] = currentBoundary
            }
        }
        
        return filteredBoundaries
    }
    
    /// 세그멘테이션 신뢰도 계산
    /// - Parameters:
    ///   - boundaries: 경계들
    ///   - features: 프레임 특성들
    /// - Returns: 신뢰도 (0.0~1.0)
    private func calculateSegmentationConfidence(
        boundaries: [TimeInterval],
        features: [FrameFeatures]
    ) -> Double {
        
        guard boundaries.count >= 2 else { return 0.0 }
        
        // 여러 신뢰도 지표들의 가중 평균
        let energyConsistency = calculateEnergyConsistency(boundaries: boundaries, features: features)
        let durationReasonableness = calculateDurationReasonableness(boundaries: boundaries)
        let spectralStability = calculateSpectralStability(boundaries: boundaries, features: features)
        
        let confidence = energyConsistency * 0.4 + durationReasonableness * 0.3 + spectralStability * 0.3
        
        return max(0.0, min(1.0, confidence))
    }
    
    /// 에너지 일관성 계산
    private func calculateEnergyConsistency(boundaries: [TimeInterval], features: [FrameFeatures]) -> Double {
        // 각 음절 내의 에너지 일관성 측정
        var consistencySum = 0.0
        
        for i in 0..<boundaries.count - 1 {
            let startFrame = Int(boundaries[i] * sampleRate / Double(hopSize))
            let endFrame = Int(boundaries[i + 1] * sampleRate / Double(hopSize))
            
            guard startFrame < endFrame && endFrame <= features.count else { continue }
            
            let syllableFeatures = Array(features[startFrame..<endFrame])
            let energyVariance = calculateVariance(syllableFeatures.map { $0.energy })
            consistencySum += exp(-energyVariance * 10) // 낮은 분산 = 높은 일관성
        }
        
        return consistencySum / Double(max(1, boundaries.count - 1))
    }
    
    /// 지속시간 합리성 계산
    private func calculateDurationReasonableness(boundaries: [TimeInterval]) -> Double {
        var reasonablenessSum = 0.0
        
        for i in 0..<boundaries.count - 1 {
            let duration = boundaries[i + 1] - boundaries[i]
            let idealDuration = 0.2 // 한국어 평균 음절 지속시간
            let deviation = abs(duration - idealDuration) / idealDuration
            reasonablenessSum += exp(-deviation * 2) // 이상적 지속시간에 가까울수록 높은 점수
        }
        
        return reasonablenessSum / Double(max(1, boundaries.count - 1))
    }
    
    /// 스펙트럼 안정성 계산
    private func calculateSpectralStability(boundaries: [TimeInterval], features: [FrameFeatures]) -> Double {
        // 음절 내 스펙트럼 중심의 안정성 측정
        var stabilitySum = 0.0
        
        for i in 0..<boundaries.count - 1 {
            let startFrame = Int(boundaries[i] * sampleRate / Double(hopSize))
            let endFrame = Int(boundaries[i + 1] * sampleRate / Double(hopSize))
            
            guard startFrame < endFrame && endFrame <= features.count else { continue }
            
            let syllableFeatures = Array(features[startFrame..<endFrame])
            let centroidVariance = calculateVariance(syllableFeatures.map { $0.spectralCentroid })
            stabilitySum += exp(-centroidVariance / 10000) // 안정적인 스펙트럼 = 높은 점수
        }
        
        return stabilitySum / Double(max(1, boundaries.count - 1))
    }
    
    /// 분산 계산 헬퍼
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDeviations = values.map { pow($0 - mean, 2) }
        return squaredDeviations.reduce(0, +) / Double(values.count)
    }
    
    /// 통계 업데이트 (적응적 임계값용)
    private func updateStatistics(from features: [FrameFeatures]) {
        let energyValues = features.map { $0.energy }
        let centroidValues = features.map { $0.spectralCentroid }
        
        energyStatistics = calculateStatistics(energyValues)
        spectralCentroidStatistics = calculateStatistics(centroidValues)
    }
    
    /// 통계 계산 헬퍼
    private func calculateStatistics(_ values: [Double]) -> (mean: Double, stdDev: Double) {
        guard !values.isEmpty else { return (0.0, 0.0) }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        
        return (mean, stdDev)
    }
    
    /// 스무딩 적용
    private func applySmoothing(to features: [FrameFeatures]) -> [FrameFeatures] {
        guard features.count >= configuration.smoothingWindowSize else { return features }
        
        var smoothedFeatures = features
        let windowSize = configuration.smoothingWindowSize
        let halfWindow = windowSize / 2
        
        for i in halfWindow..<features.count - halfWindow {
            let windowFeatures = Array(features[i - halfWindow...i + halfWindow])
            
            let smoothedEnergy = windowFeatures.map { $0.energy }.reduce(0, +) / Double(windowSize)
            let smoothedCentroid = windowFeatures.map { $0.spectralCentroid }.reduce(0, +) / Double(windowSize)
            
            smoothedFeatures[i] = FrameFeatures(
                energy: smoothedEnergy,
                spectralCentroid: smoothedCentroid,
                zeroCrossingRate: features[i].zeroCrossingRate,
                spectralFlux: features[i].spectralFlux
            )
        }
        
        return smoothedFeatures
    }
}

// MARK: - Supporting Types

/// 프레임 특성 구조체
struct FrameFeatures {
    let energy: Double
    let spectralCentroid: Double
    let zeroCrossingRate: Double
    let spectralFlux: Double
    
    init(energy: Double, spectralCentroid: Double, zeroCrossingRate: Double, spectralFlux: Double) {
        self.energy = energy
        self.spectralCentroid = spectralCentroid
        self.zeroCrossingRate = zeroCrossingRate
        self.spectralFlux = spectralFlux
    }
    
    /// 오디오 프레임으로부터 특성 추출
    init(from frameData: [Float], sampleRate: Double) {
        self.energy = Self.calculateEnergy(frameData)
        self.spectralCentroid = Self.calculateSpectralCentroid(frameData, sampleRate: sampleRate)
        self.zeroCrossingRate = Self.calculateZeroCrossingRate(frameData, sampleRate: sampleRate)
        self.spectralFlux = 0.0 // 이전 프레임과의 비교가 필요하므로 별도 계산
    }
    
    /// 에너지 계산
    private static func calculateEnergy(_ frameData: [Float]) -> Double {
        let sumOfSquares = frameData.reduce(0) { $0 + $1 * $1 }
        return Double(sqrt(sumOfSquares / Float(frameData.count)))
    }
    
    /// 스펙트럼 중심 계산
    private static func calculateSpectralCentroid(_ frameData: [Float], sampleRate: Double) -> Double {
        let fftSize = frameData.count
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        
        guard let fftSetup = vDSP.FFT(log2n: log2Size, radix: .radix2, ofType: DSPSplitComplex.self) else {
            return 0.0
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
        
        // 스펙트럼 중심 계산
        let totalMagnitude = magnitudes.reduce(0, +)
        guard totalMagnitude > 0 else { return 0.0 }
        
        var weightedSum = 0.0
        for i in 0..<magnitudes.count {
            let frequency = Double(i) * sampleRate / Double(fftSize)
            weightedSum += frequency * magnitudes[i]
        }
        
        return weightedSum / totalMagnitude
    }
    
    /// 제로 크로싱 레이트 계산
    private static func calculateZeroCrossingRate(_ frameData: [Float], sampleRate: Double) -> Double {
        guard frameData.count > 1 else { return 0.0 }
        
        var crossings = 0
        for i in 1..<frameData.count {
            if (frameData[i-1] >= 0 && frameData[i] < 0) || (frameData[i-1] < 0 && frameData[i] >= 0) {
                crossings += 1
            }
        }
        
        return Double(crossings) * sampleRate / (2.0 * Double(frameData.count))
    }
} 