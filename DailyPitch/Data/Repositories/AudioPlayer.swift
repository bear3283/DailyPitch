import Foundation
import AVFoundation
import Combine

/// AVFoundation 기반 오디오 재생 구현체
class AudioPlayer: AudioPlaybackRepository {
    
    // MARK: - Private Properties
    
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixerNode = AVAudioMixerNode()
    private let audioSession = AVAudioSession.sharedInstance()
    
    private var currentAudioFile: AVAudioFile?
    private var currentSynthesizedAudio: SynthesizedAudio?
    private var playbackTimer: Timer?
    
    // State tracking
    private var _currentTime: TimeInterval = 0.0
    private var _duration: TimeInterval = 0.0
    private var _currentState: PlaybackState = .stopped
    private var _currentVolume: Float = 1.0
    
    // Publishers
    private let stateSubject = CurrentValueSubject<PlaybackState, Never>(.stopped)
    private let timeSubject = CurrentValueSubject<TimeInterval, Never>(0.0)
    
    // MARK: - Initialization
    
    init() {
        setupAudioEngine()
        setupAudioSession()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - AudioPlaybackRepository Implementation
    
    var currentTime: TimeInterval {
        return _currentTime
    }
    
    var duration: TimeInterval {
        return _duration
    }
    
    var currentState: PlaybackState {
        return _currentState
    }
    
    var currentVolume: Float {
        return _currentVolume
    }
    
    var isPlaying: Bool {
        return _currentState == .playing
    }
    
    var statePublisher: AnyPublisher<PlaybackState, Never> {
        return stateSubject.eraseToAnyPublisher()
    }
    
    var timePublisher: AnyPublisher<TimeInterval, Never> {
        return timeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Playback Methods
    
    func playOriginalAudio(_ audioSession: AudioSession) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        return Future<PlaybackState, AudioPlaybackError> { promise in
            DispatchQueue.main.async {
                do {
                    // 파일 존재 여부 확인
                    guard let audioFileURL = audioSession.audioFileURL,
                          FileManager.default.fileExists(atPath: audioFileURL.path) else {
                        promise(.failure(.audioFileNotFound))
                        return
                    }
                    
                    // 오디오 파일 로드
                    let audioFile = try AVAudioFile(forReading: audioFileURL)
                    
                    // 재생 준비
                    self.prepareForPlayback()
                    self.currentAudioFile = audioFile
                    self._duration = audioSession.duration
                    
                    // 재생 시작
                    self.startPlayback(audioFile: audioFile)
                    
                    promise(.success(.playing))
                    
                } catch {
                    promise(.failure(.playbackFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func playSynthesizedAudio(_ synthesizedAudio: SynthesizedAudio) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        return Future<PlaybackState, AudioPlaybackError> { promise in
            DispatchQueue.main.async {
                do {
                    // 합성 오디오 검증
                    guard self.validateSynthesizedAudio(synthesizedAudio) else {
                        promise(.failure(.unsupportedAudioFormat))
                        return
                    }
                    
                    // 오디오 버퍼 생성
                    let audioBuffer = try self.createAudioBuffer(from: synthesizedAudio)
                    
                    // 재생 준비
                    self.prepareForPlayback()
                    self.currentSynthesizedAudio = synthesizedAudio
                    self._duration = synthesizedAudio.duration
                    
                    // 재생 시작
                    self.startPlayback(audioBuffer: audioBuffer)
                    
                    promise(.success(.playing))
                    
                } catch {
                    promise(.failure(.playbackFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func playMixedAudio(
        originalAudio: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        originalVolume: Float,
        synthesizedVolume: Float
    ) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        return Future<PlaybackState, AudioPlaybackError> { promise in
            DispatchQueue.main.async {
                do {
                    // 입력 검증
                    guard let audioFileURL = originalAudio.audioFileURL,
                          FileManager.default.fileExists(atPath: audioFileURL.path),
                          self.validateSynthesizedAudio(synthesizedAudio) else {
                        promise(.failure(.audioFileNotFound))
                        return
                    }
                    
                    // 볼륨 정규화
                    let normalizedOriginalVolume = max(0.0, min(1.0, originalVolume))
                    let normalizedSynthesizedVolume = max(0.0, min(1.0, synthesizedVolume))
                    
                    // 오디오 파일 로드
                    let audioFile = try AVAudioFile(forReading: audioFileURL)
                    let synthesizedBuffer = try self.createAudioBuffer(from: synthesizedAudio)
                    
                    // 믹싱된 오디오 생성
                    let mixedBuffer = try self.mixAudioBuffers(
                        originalFile: audioFile,
                        synthesizedBuffer: synthesizedBuffer,
                        originalVolume: normalizedOriginalVolume,
                        synthesizedVolume: normalizedSynthesizedVolume
                    )
                    
                    // 재생 준비
                    self.prepareForPlayback()
                    self._duration = max(originalAudio.duration, synthesizedAudio.duration)
                    
                    // 재생 시작
                    self.startPlayback(audioBuffer: mixedBuffer)
                    
                    promise(.success(.playing))
                    
                } catch {
                    promise(.failure(.playbackFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func pause() {
        guard _currentState == .playing else { return }
        
        playerNode.pause()
        pauseTimer()
        
        _currentState = .paused
        stateSubject.send(.paused)
    }
    
    func resume() {
        guard _currentState == .paused else { return }
        
        playerNode.play()
        resumeTimer()
        
        _currentState = .playing
        stateSubject.send(.playing)
    }
    
    func stop() {
        playerNode.stop()
        stopTimer()
        
        _currentTime = 0.0
        _currentState = .stopped
        
        stateSubject.send(.stopped)
        timeSubject.send(0.0)
    }
    
    func seek(to time: TimeInterval) -> AnyPublisher<Bool, AudioPlaybackError> {
        return Future<Bool, AudioPlaybackError> { promise in
            DispatchQueue.main.async {
                // 시간 범위 검증
                guard time >= 0.0 && time <= self._duration else {
                    promise(.failure(.seekFailed))
                    return
                }
                
                // 현재 재생 상태 저장
                let wasPlaying = self.isPlaying
                
                // 재생 정지
                self.playerNode.stop()
                
                // 새로운 위치로 이동
                self._currentTime = time
                self.timeSubject.send(time)
                
                // 재생 재시작 (필요한 경우)
                if wasPlaying {
                    self.seekAndPlay(to: time)
                }
                
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func setVolume(_ volume: Float) {
        _currentVolume = max(0.0, min(1.0, volume))
        mixerNode.outputVolume = _currentVolume
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        // 노드 연결
        audioEngine.attach(playerNode)
        audioEngine.attach(mixerNode)
        
        // 모노 포맷으로 통일 (44.1kHz, 1채널)
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        
        audioEngine.connect(playerNode, to: mixerNode, format: monoFormat)
        audioEngine.connect(mixerNode, to: audioEngine.outputNode, format: monoFormat)
        
        // 엔진 시작
        do {
            try audioEngine.start()
        } catch {
            print("오디오 엔진 시작 실패: \(error)")
        }
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("오디오 세션 설정 실패: \(error)")
        }
    }
    
    private func validateSynthesizedAudio(_ synthesizedAudio: SynthesizedAudio) -> Bool {
        return !synthesizedAudio.audioData.isEmpty &&
               synthesizedAudio.sampleRate > 0 &&
               !synthesizedAudio.musicNotes.isEmpty
    }
    
    private func createAudioBuffer(from synthesizedAudio: SynthesizedAudio) throws -> AVAudioPCMBuffer {
        let sampleRate = synthesizedAudio.sampleRate
        let frameCount = AVAudioFrameCount(synthesizedAudio.audioData.count)
        
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            throw AudioPlaybackError.unsupportedAudioFormat
        }
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            throw AudioPlaybackError.playbackFailed
        }
        
        // 오디오 데이터 복사
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        
        for i in 0..<Int(frameCount) {
            channelData[i] = synthesizedAudio.audioData[i]
        }
        
        return buffer
    }
    
    private func mixAudioBuffers(
        originalFile: AVAudioFile,
        synthesizedBuffer: AVAudioPCMBuffer,
        originalVolume: Float,
        synthesizedVolume: Float
    ) throws -> AVAudioPCMBuffer {
        let sampleRate = originalFile.processingFormat.sampleRate
        let originalFrameCount = AVAudioFrameCount(originalFile.length)
        let synthesizedFrameCount = synthesizedBuffer.frameLength
        let maxFrameCount = max(originalFrameCount, synthesizedFrameCount)
        
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            throw AudioPlaybackError.unsupportedAudioFormat
        }
        
        guard let mixedBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: maxFrameCount
        ) else {
            throw AudioPlaybackError.playbackFailed
        }
        
        // 원본 오디오 읽기
        guard let originalBuffer = AVAudioPCMBuffer(
            pcmFormat: originalFile.processingFormat,
            frameCapacity: originalFrameCount
        ) else {
            throw AudioPlaybackError.playbackFailed
        }
        
        try originalFile.read(into: originalBuffer)
        
        // 믹싱 수행
        mixedBuffer.frameLength = maxFrameCount
        let mixedData = mixedBuffer.floatChannelData![0]
        let originalData = originalBuffer.floatChannelData![0]
        let synthesizedData = synthesizedBuffer.floatChannelData![0]
        
        for i in 0..<Int(maxFrameCount) {
            var sample: Float = 0.0
            
            // 원본 오디오 추가
            if i < Int(originalFrameCount) {
                sample += originalData[i] * originalVolume
            }
            
            // 합성 오디오 추가
            if i < Int(synthesizedFrameCount) {
                sample += synthesizedData[i] * synthesizedVolume
            }
            
            mixedData[i] = sample
        }
        
        return mixedBuffer
    }
    
    private func prepareForPlayback() {
        stop()
        _currentTime = 0.0
        timeSubject.send(0.0)
    }
    
    private func startPlayback(audioFile: AVAudioFile) {
        guard let buffer = createBuffer(from: audioFile) else { return }
        startPlayback(audioBuffer: buffer)
    }
    
    private func startPlayback(audioBuffer: AVAudioPCMBuffer) {
        playerNode.scheduleBuffer(audioBuffer) { [weak self] in
            DispatchQueue.main.async {
                self?.handlePlaybackCompletion()
            }
        }
        
        playerNode.play()
        startTimer()
        
        _currentState = .playing
        stateSubject.send(.playing)
    }
    
    private func createBuffer(from audioFile: AVAudioFile) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: frameCount
        ) else {
            return nil
        }
        
        do {
            try audioFile.read(into: buffer)
            return buffer
        } catch {
            print("오디오 파일 읽기 실패: \(error)")
            return nil
        }
    }
    
    private func seekAndPlay(to time: TimeInterval) {
        guard let audioFile = currentAudioFile else {
            // 합성 오디오의 경우 시크 기능 제한적
            if let synthesizedAudio = currentSynthesizedAudio {
                let buffer = try? createAudioBuffer(from: synthesizedAudio)
                if let buffer = buffer {
                    startPlayback(audioBuffer: buffer)
                }
            }
            return
        }
        
        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let frameCount = AVAudioFrameCount(audioFile.length - startFrame)
        
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: audioFile.processingFormat,
                  frameCapacity: frameCount
              ) else {
            return
        }
        
        do {
            audioFile.framePosition = startFrame
            try audioFile.read(into: buffer)
            startPlayback(audioBuffer: buffer)
        } catch {
            print("시크 재생 실패: \(error)")
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        stopTimer()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePlaybackTime()
        }
    }
    
    private func pauseTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func resumeTimer() {
        startTimer()
    }
    
    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updatePlaybackTime() {
        guard _currentState == .playing else { return }
        
        _currentTime += 0.1
        timeSubject.send(_currentTime)
        
        // 재생 완료 체크
        if _currentTime >= _duration {
            handlePlaybackCompletion()
        }
    }
    
    private func handlePlaybackCompletion() {
        stopTimer()
        _currentState = .finished
        stateSubject.send(.finished)
    }
    
    private func cleanup() {
        stop()
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        do {
            try audioSession.setActive(false)
        } catch {
            print("오디오 세션 비활성화 실패: \(error)")
        }
    }
} 