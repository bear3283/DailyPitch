import Foundation

/// FFT 분석 결과를 나타내는 주파수 데이터 엔터티
struct FrequencyData {
    /// 주파수 값들 (Hz 단위)
    let frequencies: [Double]
    
    /// 각 주파수에 대응하는 진폭(magnitude) 값들
    let magnitudes: [Double]
    
    /// 샘플 레이트 (Hz)
    let sampleRate: Double
    
    /// FFT 창 크기
    let windowSize: Int
    
    /// 분석 시간(타임스탬프)
    let timestamp: Date
    
    /// 가장 강한 주파수 (peak frequency)
    var peakFrequency: Double? {
        guard !magnitudes.isEmpty else { return nil }
        
        // 0Hz 근처의 DC 성분만 제외하고 탐색 (5Hz 이상부터 허용)
        let startIndex = max(1, frequencies.firstIndex(where: { $0 > 5.0 }) ?? 1)
        let endIndex = frequencies.lastIndex(where: { $0 < 20000.0 }) ?? magnitudes.count - 1
        
        guard startIndex < endIndex, startIndex < magnitudes.count else { return nil }
        
        let validRange = startIndex..<min(endIndex + 1, magnitudes.count)
        let validMagnitudes = Array(magnitudes[validRange])
        
        guard let maxIndex = validMagnitudes.firstIndex(of: validMagnitudes.max() ?? 0) else {
            return nil
        }
        
        let actualIndex = startIndex + maxIndex
        return actualIndex < frequencies.count ? frequencies[actualIndex] : nil
    }
    
    /// 가장 강한 주파수의 진폭
    var peakMagnitude: Double? {
        guard let peak = peakFrequency,
              let peakIndex = frequencies.firstIndex(where: { abs($0 - peak) < 1.0 }) else {
            return nil
        }
        
        return peakIndex < magnitudes.count ? magnitudes[peakIndex] : nil
    }
    
    /// 특정 주파수 범위의 평균 진폭을 계산
    /// - Parameters:
    ///   - minFreq: 최소 주파수 (Hz)
    ///   - maxFreq: 최대 주파수 (Hz)
    /// - Returns: 해당 범위의 평균 진폭
    func averageMagnitude(in range: ClosedRange<Double>) -> Double {
        let indices = frequencies.enumerated().compactMap { index, freq in
            range.contains(freq) ? index : nil
        }
        
        guard !indices.isEmpty else { return 0.0 }
        
        let sum = indices.reduce(0.0) { result, index in
            result + (index < magnitudes.count ? magnitudes[index] : 0.0)
        }
        
        return sum / Double(indices.count)
    }
    
    /// 주파수 데이터가 유효한지 확인
    var isValid: Bool {
        return frequencies.count == magnitudes.count &&
               !frequencies.isEmpty &&
               sampleRate > 0 &&
               windowSize > 0
    }
    
    init(
        frequencies: [Double],
        magnitudes: [Double],
        sampleRate: Double,
        windowSize: Int,
        timestamp: Date = Date()
    ) {
        self.frequencies = frequencies
        self.magnitudes = magnitudes
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.timestamp = timestamp
    }
}

extension FrequencyData: Equatable {
    static func == (lhs: FrequencyData, rhs: FrequencyData) -> Bool {
        return lhs.frequencies == rhs.frequencies &&
               lhs.magnitudes == rhs.magnitudes &&
               lhs.sampleRate == rhs.sampleRate &&
               lhs.windowSize == rhs.windowSize &&
               lhs.timestamp == rhs.timestamp
    }
} 