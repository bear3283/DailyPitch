import Foundation
import Combine
import AVFoundation

/// AudioAnalysisRepository의 구현체
/// FFTAnalyzer를 사용하여 실제 오디오 분석 기능을 제공
class AudioAnalysisRepositoryImpl: AudioAnalysisRepository {
    
    // MARK: - Properties
    
    private let fftAnalyzer: FFTAnalyzer
    private let audioEngine: AVAudioEngine
    private let inputNode: AVAudioInputNode
    private var realtimeSubject: PassthroughSubject<FrequencyData, AudioAnalysisError>?
    private var isCurrentlyAnalyzing = false
    
    // MARK: - Initialization
    
    init(fftSize: Int = 1024) {
        self.fftAnalyzer = FFTAnalyzer(fftSize: fftSize)
        self.audioEngine = AVAudioEngine()
        self.inputNode = audioEngine.inputNode
    }
    
    deinit {
        stopRealtimeAnalysis()
    }
    
    // MARK: - Singleton Pattern
    
    static func shared() -> AudioAnalysisRepositoryImpl {
        return AudioAnalysisRepositoryImpl()
    }
    
    // MARK: - AudioAnalysisRepository Implementation
    
    func analyzeAudio(from audioSession: AudioSession) -> AnyPublisher<AudioAnalysisResult, AudioAnalysisError> {
        return Future<AudioAnalysisResult, AudioAnalysisError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.fftProcessingFailed))
                return
            }
            
            guard let audioURL = audioSession.audioFileURL else {
                promise(.failure(.fileReadError))
                return
            }
            
            let startTime = Date()
            
            self.fftAnalyzer.analyzeAudioFile(at: audioURL) { result in
                switch result {
                case .success(let frequencyDataArray):
                    let analysisResult = AudioAnalysisResult(
                        audioSession: audioSession,
                        frequencyDataSequence: frequencyDataArray,
                        status: .completed,
                        analysisStartTime: startTime,
                        analysisEndTime: Date(),
                        error: nil
                    )
                    promise(.success(analysisResult))
                    
                case .failure(let error):
                    let analysisError: AudioAnalysisError
                    if error is AudioAnalysisError {
                        analysisError = error as! AudioAnalysisError
                    } else {
                        analysisError = .fftProcessingFailed
                    }
                    
                    let failedResult = AudioAnalysisResult(
                        audioSession: audioSession,
                        frequencyDataSequence: [],
                        status: .failed,
                        analysisStartTime: startTime,
                        analysisEndTime: Date(),
                        error: analysisError
                    )
                    
                    promise(.success(failedResult))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func analyzeAudioData(_ audioData: [Float], sampleRate: Double) -> AnyPublisher<FrequencyData, AudioAnalysisError> {
        return Future<FrequencyData, AudioAnalysisError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.fftProcessingFailed))
                return
            }
            
            // 백그라운드 큐에서 분석 수행
            DispatchQueue.global(qos: .userInitiated).async {
                let frequencyData = self.fftAnalyzer.analyze(audioData: audioData, sampleRate: sampleRate)
                
                DispatchQueue.main.async {
                    promise(.success(frequencyData))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func startRealtimeAnalysis(sampleRate: Double) -> AnyPublisher<FrequencyData, AudioAnalysisError> {
        // 이미 분석 중인 경우 기존 스트림 반환
        if isCurrentlyAnalyzing, let subject = realtimeSubject {
            return subject.eraseToAnyPublisher()
        }
        
        let subject = PassthroughSubject<FrequencyData, AudioAnalysisError>()
        self.realtimeSubject = subject
        
        // 백그라운드에서 권한 확인 및 오디오 엔진 설정
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    subject.send(completion: .failure(.fftProcessingFailed))
                }
                return
            }
            
            do {
                // 1. 권한 확인
                let permissionGranted = self.checkMicrophonePermission()
                if !permissionGranted {
                    throw AudioAnalysisError.invalidAudioData
                }
                
                // 2. 오디오 세션 설정 (단계적으로)
                try self.configureAudioSessionSafely(sampleRate: sampleRate)
                
                // 3. 오디오 엔진 설정 및 시작
                DispatchQueue.main.async {
                    self.setupAudioEngine(sampleRate: sampleRate, subject: subject)
                    
                    // 오디오 엔진 시작
                    do {
                        if !self.audioEngine.isRunning {
                            try self.audioEngine.start()
                        }
                        self.isCurrentlyAnalyzing = true
                        print("✅ 실시간 분석 시작됨 - 샘플레이트: \(sampleRate)Hz")
                    } catch {
                        print("❌ 오디오 엔진 시작 실패: \(error)")
                        self.isCurrentlyAnalyzing = false
                        self.deactivateAudioSession()
                        subject.send(completion: .failure(.fftProcessingFailed))
                    }
                }
                
            } catch {
                print("❌ 오디오 세션 설정 실패: \(error)")
                DispatchQueue.main.async {
                    self.isCurrentlyAnalyzing = false
                    self.deactivateAudioSession()
                    subject.send(completion: .failure(.fftProcessingFailed))
                }
            }
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    func stopRealtimeAnalysis() {
        isCurrentlyAnalyzing = false
        
        // 오디오 엔진 정리
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // 탭 제거 (안전하게)
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 오디오 세션 해제
        deactivateAudioSession()
        
        // Subject 정리
        realtimeSubject?.send(completion: .finished)
        realtimeSubject = nil
    }
    
    var isAnalyzing: Bool {
        return isCurrentlyAnalyzing
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine(sampleRate: Double, subject: PassthroughSubject<FrequencyData, AudioAnalysisError>) {
        _ = inputNode.outputFormat(forBus: 0)
        
        // 원하는 포맷으로 변환 (모노, Float32)
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            subject.send(completion: .failure(.invalidAudioData))
            return
        }
        
        // 버퍼 크기 설정 (1024 샘플)
        let bufferSize: AVAudioFrameCount = 1024
        
        // 입력 노드에 탭 설치
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self, self.isCurrentlyAnalyzing else { return }
            
            // FFT 분석 수행 (검증된 데이터만 전송)
            if let frequencyData = self.fftAnalyzer.analyzeBuffer(buffer, sampleRate: sampleRate) {
                // 유효한 피크 주파수가 있는 경우만 전송
                if let peakFreq = frequencyData.peakFrequency, 
                   peakFreq >= 20.0 && peakFreq <= 20000.0 { // 사람이 들을 수 있는 주파수 범위
                    DispatchQueue.main.async {
                        subject.send(frequencyData)
                    }
                } else {
                    // 유효하지 않은 데이터는 로그만 출력
                    let peakFreqString = frequencyData.peakFrequency.map { String(format: "%.2f", $0) } ?? "없음"
                    print("⚠️ 실시간 분석: 유효하지 않은 주파수 데이터 무시 (피크: \(peakFreqString)Hz)")
                }
            }
        }
    }
}

// MARK: - AudioAnalysisRepositoryImpl Extensions

extension AudioAnalysisRepositoryImpl {
    
    /// 마이크 권한 확인
    private func checkMicrophonePermission() -> Bool {
        // iOS 17.0 이상에서는 AVAudioApplication 사용
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }
    
    /// 안전한 오디오 세션 설정
    /// - Parameter sampleRate: 원하는 샘플 레이트
    private func configureAudioSessionSafely(sampleRate: Double) throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        print("🔧 오디오 세션 설정 시작...")
        
        // 1. 기존 세션 정리
        if audioSession.isOtherAudioPlaying {
            print("🔧 다른 오디오 세션 비활성화 중...")
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            // 잠시 대기하여 세션 전환 완료
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // 2. 카테고리 설정 (단계별)
        print("🔧 카테고리 설정: .playAndRecord")
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        
        // 3. 샘플 레이트 설정
        print("🔧 샘플 레이트 설정: \(sampleRate)Hz")
        try audioSession.setPreferredSampleRate(sampleRate)
        
        // 4. 버퍼 지속 시간 설정
        let bufferDuration = 1024.0 / sampleRate // 동적 계산
        print("🔧 버퍼 지속 시간 설정: \(bufferDuration)초")
        try audioSession.setPreferredIOBufferDuration(bufferDuration)
        
        // 5. 세션 활성화
        print("🔧 오디오 세션 활성화 중...")
        try audioSession.setActive(true, options: [])
        
        print("✅ 오디오 세션 설정 완료")
    }
    
    /// 기존 오디오 세션 설정 (호환성 유지)
    /// - Parameter sampleRate: 원하는 샘플 레이트
    private func configureAudioSession(sampleRate: Double) throws {
        try configureAudioSessionSafely(sampleRate: sampleRate)
    }
    
    /// 오디오 세션 해제
    private func deactivateAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    /// 실시간 분석을 위한 고급 설정
    /// - Parameters:
    ///   - sampleRate: 샘플 레이트
    ///   - bufferSize: 버퍼 크기
    ///   - windowOverlap: 윈도우 겹침 비율 (0.0 ~ 1.0)
    func startAdvancedRealtimeAnalysis(
        sampleRate: Double,
        bufferSize: AVAudioFrameCount = 1024,
        windowOverlap: Float = 0.5
    ) -> AnyPublisher<FrequencyData, AudioAnalysisError> {
        
        let subject = PassthroughSubject<FrequencyData, AudioAnalysisError>()
        self.realtimeSubject = subject
        self.isCurrentlyAnalyzing = true
        
        // 오디오 세션 설정 시도
        do {
            try configureAudioSession(sampleRate: sampleRate)
        } catch {
            subject.send(completion: .failure(.invalidAudioData))
            return subject.eraseToAnyPublisher()
        }
        
        // 고급 오디오 엔진 설정
        setupAdvancedAudioEngine(
            sampleRate: sampleRate,
            bufferSize: bufferSize,
            windowOverlap: windowOverlap,
            subject: subject
        )
        
        // 오디오 엔진 시작
        do {
            try audioEngine.start()
        } catch {
            isCurrentlyAnalyzing = false
            deactivateAudioSession()
            subject.send(completion: .failure(.fftProcessingFailed))
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    private func setupAdvancedAudioEngine(
        sampleRate: Double,
        bufferSize: AVAudioFrameCount,
        windowOverlap: Float,
        subject: PassthroughSubject<FrequencyData, AudioAnalysisError>
    ) {
        _ = inputNode.outputFormat(forBus: 0)
        
        // 원하는 포맷으로 변환
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            subject.send(completion: .failure(.invalidAudioData))
            return
        }
        
        // 겹치는 윈도우를 위한 버퍼 관리
        var previousBuffer: [Float] = []
        let hopSize = Int(Float(bufferSize) * (1.0 - windowOverlap))
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self, self.isCurrentlyAnalyzing else { return }
            
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            let currentBuffer = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
            
            // 겹치는 윈도우 처리
            let combinedBuffer = previousBuffer + currentBuffer
            
            if combinedBuffer.count >= Int(bufferSize) {
                // 분석을 위한 버퍼 준비 (현재는 원본 buffer 사용)
                
                if let frequencyData = self.fftAnalyzer.analyzeBuffer(buffer, sampleRate: sampleRate) {
                    DispatchQueue.main.async {
                        subject.send(frequencyData)
                    }
                }
                
                // 다음 윈도우를 위해 일부 데이터 보존
                if combinedBuffer.count > hopSize {
                    previousBuffer = Array(combinedBuffer.suffix(combinedBuffer.count - hopSize))
                } else {
                    previousBuffer = []
                }
            } else {
                previousBuffer = combinedBuffer
            }
        }
    }
}

// MARK: - Convenience Factory Methods

extension AudioAnalysisRepositoryImpl {
    
    /// 기본 설정으로 AudioAnalysisRepository 생성
    static func standard() -> AudioAnalysisRepositoryImpl {
        return AudioAnalysisRepositoryImpl(fftSize: 1024)
    }
    
    /// 고해상도 분석을 위한 설정
    static func highResolution() -> AudioAnalysisRepositoryImpl {
        return AudioAnalysisRepositoryImpl(fftSize: 2048)
    }
    
    /// 실시간 최적화 설정
    static func realtimeOptimized() -> AudioAnalysisRepositoryImpl {
        return AudioAnalysisRepositoryImpl(fftSize: 512)
    }
} 