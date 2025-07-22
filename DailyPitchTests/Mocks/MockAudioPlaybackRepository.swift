import Foundation
import Combine
@testable import DailyPitch

/// 테스트용 AudioPlaybackRepository Mock 구현체
class MockAudioPlaybackRepository: AudioPlaybackRepository {
    
    // MARK: - Mock 설정 프로퍼티들
    
    var shouldReturnError = false
    var errorToReturn: AudioPlaybackError = .playbackFailed
    var delayInSeconds: TimeInterval = 0.0
    var mockPlaybackState: PlaybackState = .stopped
    var mockSeekResult = true
    
    // MARK: - 호출 추적 프로퍼티들
    
    var playOriginalAudioCallCount = 0
    var playSynthesizedAudioCallCount = 0
    var playMixedAudioCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0
    var stopCallCount = 0
    var seekCallCount = 0
    var setVolumeCallCount = 0
    
    var lastPlayedAudioSession: AudioSession?
    var lastPlayedSynthesizedAudio: SynthesizedAudio?
    var lastMixedAudioParameters: (AudioSession, SynthesizedAudio, Float, Float)?
    var lastSeekTime: TimeInterval?
    var lastVolumeSet: Float?
    
    // MARK: - Repository 프로퍼티들
    
    private var _currentTime: TimeInterval = 0.0
    private var _duration: TimeInterval = 0.0
    private var _currentState: PlaybackState = .stopped
    private var _currentVolume: Float = 1.0
    
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
    
    // Publishers
    private let stateSubject = CurrentValueSubject<PlaybackState, Never>(.stopped)
    private let timeSubject = CurrentValueSubject<TimeInterval, Never>(0.0)
    
    var statePublisher: AnyPublisher<PlaybackState, Never> {
        return stateSubject.eraseToAnyPublisher()
    }
    
    var timePublisher: AnyPublisher<TimeInterval, Never> {
        return timeSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Mock 설정 메소드들
    
    func reset() {
        shouldReturnError = false
        errorToReturn = .playbackFailed
        delayInSeconds = 0.0
        mockPlaybackState = .stopped
        mockSeekResult = true
        
        playOriginalAudioCallCount = 0
        playSynthesizedAudioCallCount = 0
        playMixedAudioCallCount = 0
        pauseCallCount = 0
        resumeCallCount = 0
        stopCallCount = 0
        seekCallCount = 0
        setVolumeCallCount = 0
        
        lastPlayedAudioSession = nil
        lastPlayedSynthesizedAudio = nil
        lastMixedAudioParameters = nil
        lastSeekTime = nil
        lastVolumeSet = nil
        
        _currentTime = 0.0
        _duration = 0.0
        _currentState = .stopped
        _currentVolume = 1.0
        
        stateSubject.send(.stopped)
        timeSubject.send(0.0)
    }
    
    func setError(_ error: AudioPlaybackError) {
        shouldReturnError = true
        errorToReturn = error
    }
    
    func setDelay(_ delay: TimeInterval) {
        delayInSeconds = delay
    }
    
    func setMockDuration(_ duration: TimeInterval) {
        _duration = duration
    }
    
    func setMockCurrentTime(_ time: TimeInterval) {
        _currentTime = time
        timeSubject.send(time)
    }
    
    func setMockState(_ state: PlaybackState) {
        _currentState = state
        mockPlaybackState = state
        stateSubject.send(state)
    }
    
    // MARK: - Repository 메소드 구현
    
    func playOriginalAudio(_ audioSession: AudioSession) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        playOriginalAudioCallCount += 1
        lastPlayedAudioSession = audioSession
        
        // Duration 설정
        _duration = audioSession.duration
        
        return createMockPlaybackPublisher()
    }
    
    func playSynthesizedAudio(_ synthesizedAudio: SynthesizedAudio) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        playSynthesizedAudioCallCount += 1
        lastPlayedSynthesizedAudio = synthesizedAudio
        
        // Duration 설정
        _duration = synthesizedAudio.duration
        
        return createMockPlaybackPublisher()
    }
    
    func playMixedAudio(
        originalAudio: AudioSession,
        synthesizedAudio: SynthesizedAudio,
        originalVolume: Float,
        synthesizedVolume: Float
    ) -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        playMixedAudioCallCount += 1
        lastMixedAudioParameters = (originalAudio, synthesizedAudio, originalVolume, synthesizedVolume)
        
        // Duration은 둘 중 긴 것으로 설정
        _duration = max(originalAudio.duration, synthesizedAudio.duration)
        
        return createMockPlaybackPublisher()
    }
    
    func pause() {
        pauseCallCount += 1
        _currentState = .paused
        stateSubject.send(.paused)
    }
    
    func resume() {
        resumeCallCount += 1
        _currentState = .playing
        stateSubject.send(.playing)
    }
    
    func stop() {
        stopCallCount += 1
        _currentState = .stopped
        _currentTime = 0.0
        stateSubject.send(.stopped)
        timeSubject.send(0.0)
    }
    
    func seek(to time: TimeInterval) -> AnyPublisher<Bool, AudioPlaybackError> {
        seekCallCount += 1
        lastSeekTime = time
        
        return Future<Bool, AudioPlaybackError> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + self.delayInSeconds) {
                if self.shouldReturnError {
                    promise(.failure(self.errorToReturn))
                } else {
                    if self.mockSeekResult {
                        self._currentTime = time
                        self.timeSubject.send(time)
                    }
                    promise(.success(self.mockSeekResult))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func setVolume(_ volume: Float) {
        setVolumeCallCount += 1
        lastVolumeSet = volume
        _currentVolume = volume
    }
    
    // MARK: - Private Helper Methods
    
    private func createMockPlaybackPublisher() -> AnyPublisher<PlaybackState, AudioPlaybackError> {
        return Future<PlaybackState, AudioPlaybackError> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + self.delayInSeconds) {
                if self.shouldReturnError {
                    promise(.failure(self.errorToReturn))
                } else {
                    self._currentState = self.mockPlaybackState
                    self.stateSubject.send(self.mockPlaybackState)
                    
                    // 재생 시작 시 시간 진행 시뮬레이션
                    if self.mockPlaybackState == .playing {
                        self.simulateTimeProgress()
                    }
                    
                    promise(.success(self.mockPlaybackState))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func simulateTimeProgress() {
        // 0.1초마다 시간 진행 시뮬레이션
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard self._currentState == .playing else {
                timer.invalidate()
                return
            }
            
            self._currentTime += 0.1
            self.timeSubject.send(self._currentTime)
            
            // 재생 완료 체크
            if self._currentTime >= self._duration {
                self._currentState = .finished
                self.stateSubject.send(.finished)
                timer.invalidate()
            }
        }
    }
}

// MARK: - Mock Factory 메소드들

extension MockAudioPlaybackRepository {
    
    /// 성공적인 재생을 시뮬레이션하는 Mock
    static func successMock() -> MockAudioPlaybackRepository {
        let mock = MockAudioPlaybackRepository()
        mock.shouldReturnError = false
        mock.setMockState(.playing)
        mock.setMockDuration(3.0)
        return mock
    }
    
    /// 실패를 시뮬레이션하는 Mock
    static func failureMock(error: AudioPlaybackError = .playbackFailed) -> MockAudioPlaybackRepository {
        let mock = MockAudioPlaybackRepository()
        mock.setError(error)
        return mock
    }
    
    /// 지연을 시뮬레이션하는 Mock
    static func delayedMock(delay: TimeInterval) -> MockAudioPlaybackRepository {
        let mock = MockAudioPlaybackRepository.successMock()
        mock.setDelay(delay)
        return mock
    }
    
    /// 일시정지 상태의 Mock
    static func pausedMock() -> MockAudioPlaybackRepository {
        let mock = MockAudioPlaybackRepository()
        mock.setMockState(.paused)
        mock.setMockDuration(5.0)
        mock.setMockCurrentTime(2.5)
        return mock
    }
    
    /// 완료된 상태의 Mock
    static func finishedMock() -> MockAudioPlaybackRepository {
        let mock = MockAudioPlaybackRepository()
        mock.setMockState(.finished)
        mock.setMockDuration(3.0)
        mock.setMockCurrentTime(3.0)
        return mock
    }
    
    /// 버퍼링 상태의 Mock
    static func bufferingMock() -> MockAudioPlaybackRepository {
        let mock = MockAudioPlaybackRepository()
        mock.setMockState(.buffering)
        mock.setMockDuration(10.0)
        return mock
    }
} 