import Foundation
import Accelerate
import AVFoundation

/// FFT 분석을 수행하는 클래스
/// Accelerate 프레임워크를 사용하여 오디오 신호를 주파수 도메인으로 변환
/// 시간별 개별 분석을 통해 음절별 주파수 추출
class FFTAnalyzer {
    
    // MARK: - Properties
    
    /// FFT 창 크기 (2의 거듭제곱이어야 함)
    private let fftSize: Int
    
    /// FFT 설정 객체
    private let fftSetup: vDSP.FFT<DSPSplitComplex>
    
    /// 입력 버퍼 (실수 부분)
    private var inputReal: [Float]
    
    /// 입력 버퍼 (허수 부분)
    private var inputImag: [Float]
    
    /// 출력 버퍼 (실수 부분)
    private var outputReal: [Float]
    
    /// 출력 버퍼 (허수 부분)
    private var outputImag: [Float]
    
    /// 윈도우 함수 (해밍 윈도우)
    private let window: [Float]
    
    /// 로그값 (FFT 크기)
    private let log2Size: vDSP_Length
    
    /// 겹침 비율 (기본 50%)
    private let overlapRatio: Double
    
    // MARK: - Initialization
    
    /// FFTAnalyzer 초기화
    /// - Parameters:
    ///   - fftSize: FFT 창 크기 (기본값: 1024, 2의 거듭제곱이어야 함)
    ///   - overlapRatio: 창 겹침 비율 (0.0~1.0, 기본값: 0.5)
    init(fftSize: Int = 1024, overlapRatio: Double = 0.5) {
        // FFT 크기가 2의 거듭제곱인지 확인
        guard fftSize > 0 && (fftSize & (fftSize - 1)) == 0 else {
            fatalError("FFT size must be a power of 2")
        }
        
        self.fftSize = fftSize
        self.overlapRatio = max(0.0, min(1.0, overlapRatio))
        self.log2Size = vDSP_Length(log2(Float(fftSize)))
        
        // FFT 설정 초기화
        guard let setup = vDSP.FFT(log2n: log2Size, radix: .radix2, ofType: DSPSplitComplex.self) else {
            fatalError("Failed to create FFT setup")
        }
        self.fftSetup = setup
        
        // 버퍼 초기화
        self.inputReal = Array(repeating: 0.0, count: fftSize)
        self.inputImag = Array(repeating: 0.0, count: fftSize)
        self.outputReal = Array(repeating: 0.0, count: fftSize / 2)
        self.outputImag = Array(repeating: 0.0, count: fftSize / 2)
        
        // 해밍 윈도우 생성
        self.window = Self.createHammingWindow(size: fftSize)
    }
    
    // MARK: - Public Methods
    
    /// 오디오 데이터를 시간별로 분석하여 개별 FrequencyData 배열 생성
    /// - Parameters:
    ///   - audioData: 입력 오디오 데이터 (Float 배열)
    ///   - sampleRate: 샘플 레이트
    /// - Returns: 시간순 개별 주파수 데이터 배열
    func analyzeTimeSegments(audioData: [Float], sampleRate: Double) -> [FrequencyData] {
        guard audioData.count >= fftSize else {
            print("⚠️ FFT: 오디오 데이터가 너무 짧습니다 (\(audioData.count) < \(fftSize))")
            return []
        }
        
        let hopSize = Int(Double(fftSize) * (1.0 - overlapRatio))
        var results: [FrequencyData] = []
        
        var startIndex = 0
        while startIndex + fftSize <= audioData.count {
            let windowData = Array(audioData[startIndex..<startIndex + fftSize])
            
            // 시간 정보 계산
            let timePosition = Double(startIndex) / sampleRate
            
            // 해당 창의 FFT 분석 수행
            let frequencyData = performFFT(
                on: windowData, 
                sampleRate: sampleRate,
                timePosition: timePosition
            )
            
            // 유효한 신호가 있는 경우에만 추가
            if isValidSignal(frequencyData) {
                results.append(frequencyData)
                print("🎵 음절 \(results.count): \(String(format: "%.3f", timePosition))초 - \(String(format: "%.1f", frequencyData.peakFrequency ?? 0))Hz")
            }
            
            startIndex += hopSize
        }
        
        print("🎵 총 \(results.count)개의 음절 세그먼트 분석 완료")
        return results
    }
    
    /// 실시간 오디오 버퍼 분석 (개별 창 분석)
    /// - Parameters:
    ///   - buffer: AVAudioPCMBuffer
    ///   - sampleRate: 샘플 레이트
    /// - Returns: 분석된 주파수 데이터 (옵셔널)
    func analyzeBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) -> FrequencyData? {
        guard let channelData = buffer.floatChannelData else { 
            print("❌ FFT: 채널 데이터가 없습니다")
            return nil 
        }
        
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { 
            print("❌ FFT: 프레임 카운트가 0입니다")
            return nil 
        }
        
        // 첫 번째 채널 데이터 사용 (모노로 처리)
        let audioData = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        
        // 버퍼가 FFT 크기보다 작으면 패딩 또는 분할 처리
        if frameCount < fftSize {
            let paddedData = audioData + Array(repeating: 0.0, count: fftSize - frameCount)
            let result = performFFT(on: paddedData, sampleRate: sampleRate, timePosition: 0.0)
            return isValidSignal(result) ? result : nil
        } else {
            // 첫 번째 창만 분석 (실시간이므로)
            let windowData = Array(audioData.prefix(fftSize))
            let result = performFFT(on: windowData, sampleRate: sampleRate, timePosition: 0.0)
            return isValidSignal(result) ? result : nil
        }
    }
    
    /// 주파수로부터 가장 가까운 음계 찾기
    /// - Parameter frequency: 주파수 (Hz)
    /// - Returns: 음계 정보 (튜플: 음계명, 정확한 주파수, 오차)
    func findClosestNote(frequency: Double) -> (note: String, exactFreq: Double, cents: Double)? {
        guard frequency > 0 else { return nil }
        
        // A4 = 440Hz를 기준으로 음계 계산
        let A4 = 440.0
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        // 주파수를 미디 노트 번호로 변환
        let midiNote = 69 + 12 * log2(frequency / A4)
        let roundedMidi = round(midiNote)
        
        // 음계명 계산
        let noteIndex = Int(roundedMidi.truncatingRemainder(dividingBy: 12))
        let octave = Int(roundedMidi / 12) - 1
        let noteName = "\(noteNames[noteIndex < 0 ? noteIndex + 12 : noteIndex])\(octave)"
        
        // 정확한 주파수 계산
        let exactFreq = A4 * pow(2, (roundedMidi - 69) / 12)
        
        // 오차를 센트 단위로 계산 (1센트 = 1/100 반음)
        let cents = 1200 * log2(frequency / exactFreq)
        
        return (noteName, exactFreq, cents)
    }
    
    // MARK: - Private Methods
    
    /// 단일 창에 대해 FFT 수행
    /// - Parameters:
    ///   - windowData: 창 크기만큼의 오디오 데이터
    ///   - sampleRate: 샘플 레이트
    ///   - timePosition: 시간 위치 (초)
    /// - Returns: 주파수 분석 결과
    private func performFFT(on windowData: [Float], sampleRate: Double, timePosition: TimeInterval) -> FrequencyData {
        // 입력 데이터에 윈도우 함수 적용
        var windowedData = Array(repeating: Float(0.0), count: fftSize)
        vDSP_vmul(windowData, 1, window, 1, &windowedData, 1, vDSP_Length(fftSize))
        
        // 실수 데이터를 복소수 형태로 변환 (허수 부분은 0)
        for i in 0..<fftSize {
            inputReal[i] = windowedData[i]
            inputImag[i] = 0.0
        }
        
        // FFT 실행
        inputReal.withUnsafeMutableBufferPointer { realPtr in
            inputImag.withUnsafeMutableBufferPointer { imagPtr in
                outputReal.withUnsafeMutableBufferPointer { outRealPtr in
                    outputImag.withUnsafeMutableBufferPointer { outImagPtr in
                        
                        let input = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                        var output = DSPSplitComplex(realp: outRealPtr.baseAddress!, imagp: outImagPtr.baseAddress!)
                        
                        fftSetup.forward(input: input, output: &output)
                    }
                }
            }
        }
        
        // 진폭 계산 (magnitude = sqrt(real^2 + imag^2))
        var magnitudes = Array(repeating: Double(0.0), count: fftSize / 2)
        for i in 0..<magnitudes.count {
            let real = Double(outputReal[i])
            let imag = Double(outputImag[i])
            magnitudes[i] = sqrt(real * real + imag * imag)
        }
        
        // 정규화 (FFT 크기로 나누기)
        let normalizationFactor = 1.0 / Double(fftSize)
        for i in 0..<magnitudes.count {
            magnitudes[i] *= normalizationFactor
        }
        
        let frequencies = generateFrequencyBins(sampleRate: sampleRate)
        
        // 시간 정보를 포함한 타임스탬프 생성
        let timestamp = Date().addingTimeInterval(timePosition)
        
        return FrequencyData(
            frequencies: frequencies,
            magnitudes: magnitudes,
            sampleRate: sampleRate,
            windowSize: fftSize,
            timestamp: timestamp
        )
    }
    
    /// 신호가 유효한지 확인 (음성 활동 감지)
    /// - Parameter frequencyData: 확인할 주파수 데이터
    /// - Returns: 유효한 신호 여부
    private func isValidSignal(_ frequencyData: FrequencyData) -> Bool {
        // 피크 주파수가 있고, 인간 음성 범위에 있는지 확인
        guard let peakFreq = frequencyData.peakFrequency,
              let peakMag = frequencyData.peakMagnitude else {
            return false
        }
        
        // 인간 음성 주파수 범위: 80Hz ~ 2000Hz (기본 범위)
        let isInVoiceRange = peakFreq >= 80.0 && peakFreq <= 2000.0
        
        // 충분한 진폭을 가지고 있는지 확인 (임계값 낮춤)
        let hasSignificantAmplitude = peakMag > 0.001
        
        // 전체 에너지 확인
        let totalEnergy = frequencyData.magnitudes.reduce(0, +)
        let hasEnoughEnergy = totalEnergy > 0.01
        
        return isInVoiceRange && hasSignificantAmplitude && hasEnoughEnergy
    }
    
    /// 주파수 빈 배열 생성
    /// - Parameter sampleRate: 샘플 레이트
    /// - Returns: 주파수 배열
    private func generateFrequencyBins(sampleRate: Double) -> [Double] {
        let binCount = fftSize / 2
        return (0..<binCount).map { i in
            Double(i) * sampleRate / Double(fftSize)
        }
    }
    
    /// 해밍 윈도우 함수 생성
    /// - Parameter size: 윈도우 크기
    /// - Returns: 해밍 윈도우 배열
    private static func createHammingWindow(size: Int) -> [Float] {
        return (0..<size).map { i in
            let angle = 2.0 * Float.pi * Float(i) / Float(size - 1)
            return 0.54 - 0.46 * cos(angle)
        }
    }
}

// MARK: - FFTAnalyzer Extension for Convenience

extension FFTAnalyzer {
    
    /// 오디오 파일에서 시간별 분석 수행
    /// - Parameters:
    ///   - url: 오디오 파일 URL
    ///   - completion: 완료 콜백 (성공시 FrequencyData 배열, 실패시 Error)
    func analyzeAudioFile(at url: URL, completion: @escaping (Result<[FrequencyData], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let audioFile = try AVAudioFile(forReading: url)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)
                
                print("🎵 파일 분석 시작 - 총 프레임: \(frameCount), 샘플레이트: \(format.sampleRate)")
                
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    completion(.failure(AudioAnalysisError.invalidAudioData))
                    return
                }
                
                try audioFile.read(into: buffer)
                
                guard let channelData = buffer.floatChannelData else {
                    completion(.failure(AudioAnalysisError.invalidAudioData))
                    return
                }
                
                // 첫 번째 채널 데이터 추출
                let audioData = Array(UnsafeBufferPointer(start: channelData[0], count: Int(frameCount)))
                
                // 시간별 분석 수행
                let results = self.analyzeTimeSegments(audioData: audioData, sampleRate: format.sampleRate)
                
                print("🎵 파일 분석 완료 - \(results.count)개의 음절 세그먼트")
                
                DispatchQueue.main.async {
                    completion(.success(results))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 레거시 지원을 위한 기존 analyze 메소드 (deprecated)
    @available(*, deprecated, message: "Use analyzeTimeSegments instead for individual syllable analysis")
    func analyze(audioData: [Float], sampleRate: Double) -> FrequencyData {
        let segments = analyzeTimeSegments(audioData: audioData, sampleRate: sampleRate)
        return segments.first ?? FrequencyData(
            frequencies: [],
            magnitudes: [],
            sampleRate: sampleRate,
            windowSize: fftSize
        )
    }
} 