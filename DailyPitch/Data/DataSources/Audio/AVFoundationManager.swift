import Foundation
import AVFoundation
import Combine

/// AVFoundation을 사용한 오디오 녹음 관리 클래스
class AVFoundationManager: NSObject {
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var maxRecordingDuration: TimeInterval = 60.0
    
    // Publishers
    private let recordingStateSubject = CurrentValueSubject<Bool, Never>(false)
    private let recordingDurationSubject = CurrentValueSubject<TimeInterval, Never>(0)
    
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupAudioSession()
    }
    
    deinit {
        _ = stopRecording()
        recordingTimer?.invalidate()
        
        // 오디오 세션 정리
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session in deinit: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// 녹음 시작
    func startRecording(maxDuration: TimeInterval) -> AnyPublisher<URL, AudioRecordingError> {
        return Future<URL, AudioRecordingError> { [weak self] promise in
            guard let self = self else {
                print("❌ self가 nil입니다.")
                promise(.failure(.recordingFailed))
                return
            }
            
            print("🎤 녹음 시작 요청 - 최대 시간: \(maxDuration)초")
            
            // 이미 녹음 중인지 확인
            if self.isRecording {
                print("❌ 이미 녹음 중입니다.")
                promise(.failure(.recordingInProgress))
                return
            }
            
            self.maxRecordingDuration = maxDuration
            
            do {
                // 오디오 세션 재설정 (권한 및 설정 확인)
                self.setupAudioSession()
                
                let audioURL = try self.createAudioFileURL()
                print("🎤 오디오 파일 생성: \(audioURL.lastPathComponent)")
                
                let recorder = try self.createAudioRecorder(at: audioURL)
                print("🎤 오디오 레코더 생성 완료")
                
                self.audioRecorder = recorder
                
                // 레코더 준비
                guard recorder.prepareToRecord() else {
                    print("❌ 레코더 준비 실패")
                    promise(.failure(.recordingFailed))
                    return
                }
                
                // 녹음 시작
                guard recorder.record() else {
                    print("❌ 녹음 시작 실패")
                    promise(.failure(.recordingFailed))
                    return
                }
                
                self.recordingStartTime = Date()
                self.recordingStateSubject.send(true)
                self.startRecordingTimer()
                
                print("✅ 녹음 시작 성공")
                promise(.success(audioURL))
                
            } catch {
                print("❌ 녹음 시작 중 오류: \(error)")
                promise(.failure(.recordingFailed))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 녹음 중지
    func stopRecording() -> AnyPublisher<TimeInterval, AudioRecordingError> {
        return Future<TimeInterval, AudioRecordingError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.recordingFailed))
                return
            }
            
            guard let recorder = self.audioRecorder, recorder.isRecording else {
                promise(.failure(.recordingFailed))
                return
            }
            
            recorder.stop()
            self.audioRecorder = nil
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            
            let duration = self.getCurrentRecordingDuration()
            self.recordingStateSubject.send(false)
            self.recordingDurationSubject.send(0)
            
            promise(.success(duration))
        }
        .eraseToAnyPublisher()
    }
    
    /// 현재 녹음 중인지 확인
    var isRecording: Bool {
        return recordingStateSubject.value
    }
    
    /// 현재 녹음 시간 (초)
    var currentRecordingDuration: TimeInterval {
        return recordingDurationSubject.value
    }
    
    /// 녹음 상태 Publisher
    var recordingStatePublisher: AnyPublisher<Bool, Never> {
        return recordingStateSubject.eraseToAnyPublisher()
    }
    
    /// 녹음 시간 Publisher
    var recordingDurationPublisher: AnyPublisher<TimeInterval, Never> {
        return recordingDurationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    /// 오디오 세션 설정
    private func setupAudioSession() {
        do {
            print("🔧 오디오 세션 설정 시작...")
            
            // 기존 세션이 활성화되어 있으면 먼저 비활성화
            if audioSession.isOtherAudioPlaying {
                print("🔧 다른 오디오 세션 비활성화 중...")
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                // 잠시 대기하여 세션 전환 완료
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // 오디오 세션 카테고리 설정 (녹음용)
            print("🔧 카테고리 설정: .playAndRecord")
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            
            // 샘플 레이트 및 버퍼 설정
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(1024.0 / 44100.0)
            
            print("🔧 오디오 세션 활성화 중...")
            try audioSession.setActive(true, options: [])
            
            print("✅ 오디오 세션 설정 완료")
        } catch {
            print("❌ 오디오 세션 설정 실패: \(error)")
        }
    }
    
    /// 오디오 파일 URL 생성
    private func createAudioFileURL() throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    /// 오디오 레코더 생성
    private func createAudioRecorder(at url: URL) throws -> AVAudioRecorder {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        return try AVAudioRecorder(url: url, settings: settings)
    }
    
    /// 녹음 타이머 시작
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentDuration = self.getCurrentRecordingDuration()
            self.recordingDurationSubject.send(currentDuration)
            
            // 최대 녹음 시간 체크
            if currentDuration >= self.maxRecordingDuration {
                self.stopRecording()
                    .sink(
                        receiveCompletion: { _ in },
                        receiveValue: { _ in }
                    )
                    .store(in: &self.cancellables)
            }
        }
    }
    
    /// 현재 녹음 시간 계산
    private func getCurrentRecordingDuration() -> TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    private var cancellables = Set<AnyCancellable>()
} 