import Foundation
import AVFoundation
import Combine

/// 중앙화된 오디오 관리자 (메모리 최적화 버전)
/// 모든 오디오 관련 작업(녹음, 재생, 분석)을 하나의 엔진으로 통합 관리
/// 
/// 최적화 사항:
/// - 오디오 버퍼 풀링으로 메모리 할당 최소화
/// - 스마트 캐싱 시스템으로 반복 작업 최적화
/// - 메모리 압박 상황 자동 감지 및 정리
/// - 백그라운드/포그라운드 전환 최적화
class CentralAudioManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CentralAudioManager()
    
    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    
    // 노드들
    let inputNode: AVAudioInputNode
    private let outputNode: AVAudioOutputNode
    private let mixerNode = AVAudioMixerNode()
    private let playerNode = AVAudioPlayerNode()
    
    // 상태 관리
    @Published var isEngineRunning = false
    @Published var currentEngineState: AudioEngineState = .stopped
    @Published var memoryUsage: MemoryUsageInfo = MemoryUsageInfo()
    
    // 에러 관리
    @Published var lastError: Error?
    
    // MARK: - Memory Optimization
    
    /// 오디오 버퍼 풀 (재사용)
    private let bufferPool = AudioBufferPool()
    
    /// 스마트 캐시 관리자
    private let cacheManager = SmartCacheManager()
    
    /// 메모리 모니터
    private let memoryMonitor = MemoryMonitor()
    
    /// 백그라운드 처리 큐
    private let backgroundQueue = DispatchQueue(label: "com.dailypitch.audio.background", 
                                               qos: .utility, 
                                               attributes: .concurrent)
    
    /// 메모리 정리 타이머
    private var cleanupTimer: Timer?
    
    /// 현재 활성 탭들
    private var activeTaps: Set<Int> = []
    
    // MARK: - Initialization
    
    private init() {
        self.inputNode = audioEngine.inputNode
        self.outputNode = audioEngine.outputNode
        
        setupAudioEngine()
        setupNotifications()
        setupMemoryMonitoring()
        
        print("🚀 최적화된 CentralAudioManager 초기화 완료")
    }
    
    deinit {
        cleanup()
        cleanupTimer?.invalidate()
        
        print("🧹 CentralAudioManager 정리 완료")
    }
    
    // MARK: - Public Methods (메모리 최적화)
    
    /// 오디오 엔진 시작 (메모리 효율적)
    func startEngine(for purpose: AudioPurpose) throws {
        print("🔧 메모리 최적화된 오디오 엔진 시작: \(purpose)")
        
        // 메모리 상태 체크
        memoryMonitor.checkMemoryPressure()
        if memoryMonitor.isUnderMemoryPressure {
            print("⚠️ 메모리 압박 상황 - 정리 수행")
            performMemoryCleanup()
        }
        
        // 세션 설정
        try configureAudioSession(for: purpose)
        
        // 엔진이 이미 실행 중이면 정지
        if audioEngine.isRunning {
            audioEngine.stop()
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // 엔진 시작
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isEngineRunning = true
            self.currentEngineState = .running(purpose)
        }
        
        // 주기적 메모리 정리 시작
        startPeriodicCleanup()
        
        print("✅ 메모리 최적화된 오디오 엔진 시작 완료")
    }
    
    /// 오디오 엔진 정지 (메모리 정리 포함)
    func stopEngine() {
        print("🔧 오디오 엔진 정지 및 메모리 정리")
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // 모든 탭 정리
        cleanupAllTaps()
        
        // 플레이어 정지
        if playerNode.isPlaying {
            playerNode.stop()
        }
        
        // 버퍼 풀 정리
        bufferPool.cleanup()
        
        // 캐시 정리 (일부)
        cacheManager.performPartialCleanup()
        
        // 주기적 정리 중지
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        DispatchQueue.main.async {
            self.isEngineRunning = false
            self.currentEngineState = .stopped
            self.updateMemoryUsage()
        }
        
        print("✅ 오디오 엔진 정지 및 메모리 정리 완료")
    }
    
    /// 입력 노드에 탭 설치 (메모리 효율적)
    func installInputTap(
        bufferSize: AVAudioFrameCount = 1024,
        format: AVAudioFormat? = nil,
        tapId: Int = 0,
        block: @escaping AVAudioNodeTapBlock
    ) throws {
        let tapFormat = format ?? inputNode.outputFormat(forBus: 0)
        
        // 기존 탭 제거 (해당 ID)
        if activeTaps.contains(tapId) {
            removeTap(tapId: tapId)
        }
        
        // 메모리 효율적인 탭 블록 생성
        let optimizedBlock: AVAudioNodeTapBlock = { [weak self] (buffer, time) in
            guard let self = self else { return }
            
            // 버퍼 풀에서 재사용 버퍼 가져오기
            let reusableBuffer = self.bufferPool.getBuffer(
                format: buffer.format,
                frameCapacity: buffer.frameCapacity
            )
            
            // 데이터 복사 (필요한 경우만)
            if let reusableBuffer = reusableBuffer {
                self.copyBufferData(from: buffer, to: reusableBuffer)
                block(reusableBuffer, time)
                
                // 버퍼 반환
                self.bufferPool.returnBuffer(reusableBuffer)
            } else {
                // 풀에서 버퍼를 가져올 수 없는 경우 원본 사용
                block(buffer, time)
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: tapFormat, block: optimizedBlock)
        activeTaps.insert(tapId)
        
        print("✅ 메모리 최적화된 입력 탭 설치 완료 - ID: \(tapId), 버퍼 크기: \(bufferSize)")
    }
    
    /// 특정 탭 제거
    func removeTap(tapId: Int) {
        if activeTaps.contains(tapId) {
            inputNode.removeTap(onBus: 0)
            activeTaps.remove(tapId)
            print("🗑️ 탭 제거 완료 - ID: \(tapId)")
        }
    }
    
    /// 오디오 재생 (메모리 효율적)
    func playAudio(file: AVAudioFile, completion: @escaping () -> Void) throws {
        // 캐시 확인
        let cacheKey = file.url.absoluteString
        if let cachedBuffer = cacheManager.getCachedBuffer(key: cacheKey) {
            print("📦 캐시된 버퍼 사용: \(cacheKey)")
            try playAudio(buffer: cachedBuffer, completion: completion)
            return
        }
        
        // 새로운 버퍼 생성 (백그라운드에서)
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let buffer = self.createOptimizedBuffer(from: file) {
                // 캐시에 저장
                self.cacheManager.cacheBuffer(buffer, forKey: cacheKey)
                
                DispatchQueue.main.async {
                    do {
                        try self.playAudio(buffer: buffer, completion: completion)
                    } catch {
                        self.lastError = error
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.lastError = AudioManagerError.playbackFailed
                }
            }
        }
    }
    
    /// 오디오 재생 (AVAudioPCMBuffer)
    func playAudio(buffer: AVAudioPCMBuffer, completion: @escaping () -> Void) throws {
        // 재생 준비
        try prepareForPlayback()
        
        // 기존 재생 정지
        if playerNode.isPlaying {
            playerNode.stop()
        }
        
        // 새로운 버퍼 스케줄링
        playerNode.scheduleBuffer(buffer) {
            DispatchQueue.main.async {
                completion()
            }
        }
        
        playerNode.play()
        print("✅ 메모리 최적화된 오디오 재생 시작")
    }
    
    /// 재생 정지
    func stopPlayback() {
        if playerNode.isPlaying {
            playerNode.stop()
        }
    }
    
    /// 메모리 사용량 정보 반환
    var currentMemoryUsage: MemoryUsageInfo {
        updateMemoryUsage()
        return memoryUsage
    }
    
    /// 강제 메모리 정리
    func forceMemoryCleanup() {
        print("🧹 강제 메모리 정리 시작")
        
        performMemoryCleanup()
        
        DispatchQueue.main.async {
            self.updateMemoryUsage()
        }
        
        print("✅ 강제 메모리 정리 완료")
    }
    
    // MARK: - Private Methods (메모리 최적화)
    
    private func setupAudioEngine() {
        // 노드 연결
        audioEngine.attach(mixerNode)
        audioEngine.attach(playerNode)
        
        // 연결 설정 (모노 44.1kHz로 통일) - 메모리 효율적
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        audioEngine.connect(playerNode, to: mixerNode, format: format)
        audioEngine.connect(mixerNode, to: outputNode, format: format)
        
        print("✅ 메모리 최적화된 오디오 엔진 노드 연결 완료")
    }
    
    private func configureAudioSession(for purpose: AudioPurpose) throws {
        print("🔧 메모리 효율적인 오디오 세션 설정: \(purpose)")
        
        // 기존 세션 비활성화 (메모리 해제)
        if audioSession.isOtherAudioPlaying {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // 목적에 따른 세션 설정
        switch purpose {
        case .recording, .analysis:
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetooth])
        case .playback:
            try audioSession.setCategory(.playback, 
                                       mode: .default)
        }
        
        // 메모리 효율적인 오디오 설정
        try audioSession.setPreferredSampleRate(44100.0)
        try audioSession.setPreferredIOBufferDuration(1024.0 / 44100.0) // 작은 버퍼
        
        // 세션 활성화
        try audioSession.setActive(true)
        
        print("✅ 메모리 효율적인 오디오 세션 설정 완료")
    }
    
    private func setupNotifications() {
        // 오디오 세션 인터럽션 처리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        
        // 오디오 경로 변경 처리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
        
        // 메모리 경고 처리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 앱 백그라운드 진입 처리
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    private func setupMemoryMonitoring() {
        // 메모리 모니터링 시작
        memoryMonitor.startMonitoring { [weak self] pressure in
            if pressure {
                print("⚠️ 메모리 압박 감지 - 자동 정리 시작")
                self?.performMemoryCleanup()
            }
        }
        
        updateMemoryUsage()
    }
    
    private func startPeriodicCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performPeriodicCleanup()
        }
    }
    
    private func performPeriodicCleanup() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 버퍼 풀 부분 정리
            self.bufferPool.performPeriodicCleanup()
            
            // 캐시 부분 정리
            self.cacheManager.performPeriodicCleanup()
            
            DispatchQueue.main.async {
                self.updateMemoryUsage()
            }
        }
    }
    
    private func performMemoryCleanup() {
        // 버퍼 풀 정리
        bufferPool.cleanup()
        
        // 캐시 정리
        cacheManager.performAggressiveCleanup()
        
        // 시스템 메모리 정리 권장
        if #available(iOS 13.0, *) {
            // iOS 13+ 메모리 정리 API 사용 가능시
        }
        
        updateMemoryUsage()
    }
    
    private func cleanupAllTaps() {
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }
        activeTaps.removeAll()
    }
    
    private func createOptimizedBuffer(from audioFile: AVAudioFile) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        // 버퍼 풀에서 재사용 버퍼 시도
        if let reusableBuffer = bufferPool.getBuffer(
            format: audioFile.processingFormat,
            frameCapacity: frameCount
        ) {
            do {
                try audioFile.read(into: reusableBuffer)
                return reusableBuffer
            } catch {
                bufferPool.returnBuffer(reusableBuffer)
                print("❌ 재사용 버퍼 읽기 실패: \(error)")
            }
        }
        
        // 새로운 버퍼 생성
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
            print("❌ 새 버퍼 읽기 실패: \(error)")
            return nil
        }
    }
    
    private func copyBufferData(from source: AVAudioPCMBuffer, to destination: AVAudioPCMBuffer) {
        guard source.format.isEqual(destination.format),
              source.frameLength <= destination.frameCapacity else {
            return
        }
        
        destination.frameLength = source.frameLength
        
        // 채널별 데이터 복사
        for channel in 0..<Int(source.format.channelCount) {
            guard let sourceData = source.floatChannelData?[channel],
                  let destData = destination.floatChannelData?[channel] else {
                continue
            }
            
            memcpy(destData, sourceData, Int(source.frameLength) * MemoryLayout<Float>.size)
        }
    }
    
    private func updateMemoryUsage() {
        let usage = memoryMonitor.getCurrentMemoryUsage()
        memoryUsage = MemoryUsageInfo(
            totalMemory: usage.total,
            usedMemory: usage.used,
            audioBuffersMemory: bufferPool.totalMemoryUsage,
            cacheMemory: cacheManager.totalMemoryUsage,
            isUnderPressure: memoryMonitor.isUnderMemoryPressure
        )
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        DispatchQueue.main.async {
            switch type {
            case .began:
                print("🔊 오디오 세션 인터럽션 시작 - 메모리 정리")
                self.stopEngine()
                self.performMemoryCleanup()
            case .ended:
                print("🔊 오디오 세션 인터럽션 종료")
                // 사용자가 명시적으로 재시작해야 함
            @unknown default:
                break
            }
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        DispatchQueue.main.async {
            switch reason {
            case .newDeviceAvailable, .oldDeviceUnavailable:
                print("🔊 오디오 경로 변경: \(reason.rawValue)")
                // 필요시 재설정 및 메모리 최적화
            default:
                break
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        print("⚠️ 시스템 메모리 경고 - 적극적 정리 수행")
        performMemoryCleanup()
    }
    
    @objc private func handleAppDidEnterBackground() {
        print("📱 앱 백그라운드 진입 - 메모리 최적화")
        performMemoryCleanup()
    }
    
    private func cleanup() {
        stopEngine()
        
        NotificationCenter.default.removeObserver(self)
        
        memoryMonitor.stopMonitoring()
        bufferPool.cleanup()
        cacheManager.cleanup()
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ 오디오 세션 정리 실패: \(error)")
        }
    }
    
    // MARK: - Convenience Methods
    
    func prepareForRecording() throws {
        try startEngine(for: .recording)
    }
    
    func prepareForPlayback() throws {
        try startEngine(for: .playback)
    }
    
    func prepareForAnalysis() throws {
        try startEngine(for: .analysis)
    }
}

// MARK: - Supporting Types (메모리 최적화)

/// 오디오 버퍼 풀 (메모리 재사용)
private class AudioBufferPool {
    private var buffers: [String: [AVAudioPCMBuffer]] = [:]
    private let accessQueue = DispatchQueue(label: "com.dailypitch.bufferpool", attributes: .concurrent)
    private let maxBuffersPerFormat = 5
    private let maxTotalBuffers = 20
    
    var totalMemoryUsage: Int {
        return accessQueue.sync {
            buffers.values.flatMap { $0 }.reduce(0) { total, buffer in
                total + Int(buffer.frameCapacity) * Int(buffer.format.channelCount) * MemoryLayout<Float>.size
            }
        }
    }
    
    func getBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        let key = formatKey(format: format, frameCapacity: frameCapacity)
        
        return accessQueue.sync(flags: .barrier) {
            if var formatBuffers = buffers[key], !formatBuffers.isEmpty {
                let buffer = formatBuffers.removeLast()
                buffers[key] = formatBuffers
                buffer.frameLength = 0 // 리셋
                return buffer
            }
            
            // 새로운 버퍼 생성
            return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
        }
    }
    
    func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        let key = formatKey(format: buffer.format, frameCapacity: buffer.frameCapacity)
        
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if var formatBuffers = self.buffers[key] {
                if formatBuffers.count < self.maxBuffersPerFormat {
                    buffer.frameLength = 0
                    formatBuffers.append(buffer)
                    self.buffers[key] = formatBuffers
                }
            } else {
                self.buffers[key] = [buffer]
            }
            
            // 전체 버퍼 수 제한
            self.limitTotalBuffers()
        }
    }
    
    func performPeriodicCleanup() {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // 사용량이 적은 포맷의 버퍼 일부 제거
            for key in self.buffers.keys {
                if var formatBuffers = self.buffers[key], formatBuffers.count > 2 {
                    formatBuffers.removeFirst() // 가장 오래된 버퍼 제거
                    self.buffers[key] = formatBuffers
                }
            }
        }
    }
    
    func cleanup() {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.buffers.removeAll()
        }
    }
    
    private func formatKey(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> String {
        return "\(format.sampleRate)_\(format.channelCount)_\(frameCapacity)"
    }
    
    private func limitTotalBuffers() {
        let totalBuffers = buffers.values.reduce(0) { $0 + $1.count }
        
        if totalBuffers > maxTotalBuffers {
            // 가장 적게 사용되는 포맷부터 제거
            let sortedKeys = buffers.keys.sorted { key1, key2 in
                (buffers[key1]?.count ?? 0) < (buffers[key2]?.count ?? 0)
            }
            
            for key in sortedKeys {
                if let formatBuffers = buffers[key], !formatBuffers.isEmpty {
                    var mutableBuffers = formatBuffers
                    mutableBuffers.removeFirst()
                    
                    if mutableBuffers.isEmpty {
                        buffers.removeValue(forKey: key)
                    } else {
                        buffers[key] = mutableBuffers
                    }
                    
                    if buffers.values.reduce(0, { $0 + $1.count }) <= maxTotalBuffers {
                        break
                    }
                }
            }
        }
    }
}

/// 스마트 캐시 관리자
private class SmartCacheManager {
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var accessTimes: [String: Date] = [:]
    private let accessQueue = DispatchQueue(label: "com.dailypitch.cache", attributes: .concurrent)
    private let maxCacheSize = 10
    private let maxCacheAge: TimeInterval = 300 // 5분
    
    var totalMemoryUsage: Int {
        return accessQueue.sync {
            cache.values.reduce(0) { total, buffer in
                total + Int(buffer.frameCapacity) * Int(buffer.format.channelCount) * MemoryLayout<Float>.size
            }
        }
    }
    
    func getCachedBuffer(key: String) -> AVAudioPCMBuffer? {
        return accessQueue.sync {
            if let buffer = cache[key] {
                accessTimes[key] = Date() // 접근 시간 업데이트
                return buffer
            }
            return nil
        }
    }
    
    func cacheBuffer(_ buffer: AVAudioPCMBuffer, forKey key: String) {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.cache[key] = buffer
            self.accessTimes[key] = Date()
            
            self.limitCacheSize()
        }
    }
    
    func performPeriodicCleanup() {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.removeExpiredItems()
        }
    }
    
    func performPartialCleanup() {
        accessQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let targetSize = self.maxCacheSize / 2
            while self.cache.count > targetSize {
                self.removeOldestItem()
            }
        }
    }
    
    func performAggressiveCleanup() {
        accessQueue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
            self?.accessTimes.removeAll()
        }
    }
    
    func cleanup() {
        performAggressiveCleanup()
    }
    
    private func limitCacheSize() {
        while cache.count > maxCacheSize {
            removeOldestItem()
        }
    }
    
    private func removeOldestItem() {
        guard let oldestKey = accessTimes.min(by: { $0.value < $1.value })?.key else {
            return
        }
        
        cache.removeValue(forKey: oldestKey)
        accessTimes.removeValue(forKey: oldestKey)
    }
    
    private func removeExpiredItems() {
        let now = Date()
        let expiredKeys = accessTimes.compactMap { key, date in
            now.timeIntervalSince(date) > maxCacheAge ? key : nil
        }
        
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            accessTimes.removeValue(forKey: key)
        }
    }
}

/// 메모리 모니터
private class MemoryMonitor {
    private var monitoringTimer: Timer?
    private var pressureCallback: ((Bool) -> Void)?
    
    private(set) var isUnderMemoryPressure = false
    
    func startMonitoring(pressureCallback: @escaping (Bool) -> Void) {
        self.pressureCallback = pressureCallback
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        pressureCallback = nil
    }
    
    func checkMemoryPressure() {
        let usage = getCurrentMemoryUsage()
        let pressureThreshold: Double = 0.8 // 80%
        let currentPressure = Double(usage.used) / Double(usage.total) > pressureThreshold
        
        if currentPressure != isUnderMemoryPressure {
            isUnderMemoryPressure = currentPressure
            pressureCallback?(currentPressure)
        }
    }
    
    func getCurrentMemoryUsage() -> (total: Int, used: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let used = Int(info.resident_size)
            let total = Int(ProcessInfo.processInfo.physicalMemory)
            return (total, used)
        } else {
            return (0, 0)
        }
    }
}

/// 메모리 사용량 정보
struct MemoryUsageInfo {
    let totalMemory: Int
    let usedMemory: Int
    let audioBuffersMemory: Int
    let cacheMemory: Int
    let isUnderPressure: Bool
    
    init(
        totalMemory: Int = 0,
        usedMemory: Int = 0,
        audioBuffersMemory: Int = 0,
        cacheMemory: Int = 0,
        isUnderPressure: Bool = false
    ) {
        self.totalMemory = totalMemory
        self.usedMemory = usedMemory
        self.audioBuffersMemory = audioBuffersMemory
        self.cacheMemory = cacheMemory
        self.isUnderPressure = isUnderPressure
    }
    
    var usagePercentage: Double {
        return totalMemory > 0 ? Double(usedMemory) / Double(totalMemory) * 100 : 0
    }
    
    var audioMemoryMB: Double {
        return Double(audioBuffersMemory + cacheMemory) / (1024 * 1024)
    }
    
    var summary: String {
        return """
        📊 메모리 사용량:
        - 전체: \(String(format: "%.1f", Double(totalMemory) / (1024 * 1024 * 1024)))GB
        - 사용중: \(String(format: "%.1f", Double(usedMemory) / (1024 * 1024)))MB (\(String(format: "%.1f", usagePercentage))%)
        - 오디오: \(String(format: "%.1f", audioMemoryMB))MB
        - 압박상태: \(isUnderPressure ? "예" : "아니오")
        """
    }
}

// MARK: - Legacy Support

enum AudioPurpose: String, CaseIterable {
    case recording = "녹음"
    case playback = "재생"  
    case analysis = "분석"
}

enum AudioEngineState {
    case stopped
    case running(AudioPurpose)
}

enum AudioManagerError: Error, LocalizedError {
    case engineNotRunning
    case playbackFailed
    case configurationFailed
    
    var errorDescription: String? {
        switch self {
        case .engineNotRunning:
            return "오디오 엔진이 실행되지 않았습니다"
        case .playbackFailed:
            return "오디오 재생에 실패했습니다"
        case .configurationFailed:
            return "오디오 설정에 실패했습니다"
        }
    }
} 