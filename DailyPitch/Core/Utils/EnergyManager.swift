import Foundation
import UIKit
import Combine

/// 에너지 효율성 관리자 (배터리 최적화)
/// 앱의 전체 에너지 소비를 모니터링하고 최적화
/// 
/// 최적화 사항:
/// - 배터리 레벨 기반 적응형 성능 조절
/// - 백그라운드/포그라운드 전환 최적화
/// - CPU 집약적 작업 스케줄링
/// - 열 상태 기반 자동 조절
/// - 저전력 모드 감지 및 대응
class EnergyManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = EnergyManager()
    
    // MARK: - Published Properties
    
    /// 현재 에너지 상태
    @Published private(set) var energyState: EnergyState = .normal
    
    /// 배터리 레벨 (0.0 ~ 1.0)
    @Published private(set) var batteryLevel: Double = 1.0
    
    /// 저전력 모드 활성화 여부
    @Published private(set) var isLowPowerModeEnabled = false
    
    /// 열 상태
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    
    /// 성능 제한 상태
    @Published private(set) var performanceLimitation: PerformanceLimitation = .none
    
    /// 에너지 사용 통계
    @Published private(set) var energyMetrics = EnergyMetrics()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 에너지 모니터링 타이머
    private var monitoringTimer: Timer?
    
    /// 백그라운드 작업 관리자
    private let backgroundTaskManager = BackgroundTaskManager()
    
    /// CPU 사용량 모니터
    private let cpuMonitor = CPUMonitor()
    
    /// 적응형 성능 컨트롤러
    private let adaptiveController = AdaptivePerformanceController()
    
    /// 작업 스케줄러
    private let taskScheduler = EnergyAwareTaskScheduler()
    
    /// 현재 활성 컴포넌트들
    private var activeComponents: [String: any EnergyConsumingComponent] = [:]
    
    /// 에너지 절약 모드 콜백들
    private var energySavingCallbacks: [String: () -> Void] = [:]
    
    // MARK: - Initialization
    
    private init() {
        setupMonitoring()
        setupNotifications()
        updateInitialState()
        
        print("🔋 에너지 관리자 초기화 완료")
    }
    
    deinit {
        cleanup()
        print("🧹 에너지 관리자 정리 완료")
    }
    
    // MARK: - Public Methods
    
    /// 에너지 소비 컴포넌트 등록
    func registerComponent(_ component: any EnergyConsumingComponent) {
        activeComponents[component.name] = component
        
        // 현재 상태에 맞게 컴포넌트 조정
        applyEnergyLimitations(to: component)
        
        print("🔋 컴포넌트 등록: \(component.name) (\(component.priority.rawValue) 우선순위)")
    }
    
    /// 에너지 소비 컴포넌트 해제
    func unregisterComponent(_ component: any EnergyConsumingComponent) {
        activeComponents.removeValue(forKey: component.name)
        
        print("🔋 컴포넌트 해제: \(component.name)")
    }
    
    /// 에너지 절약 모드 콜백 등록
    func registerEnergySavingCallback(id: String, callback: @escaping () -> Void) {
        energySavingCallbacks[id] = callback
    }
    
    /// 에너지 절약 모드 콜백 해제
    func unregisterEnergySavingCallback(id: String) {
        energySavingCallbacks.removeValue(forKey: id)
    }
    
    /// CPU 집약적 작업 예약
    func scheduleTask(_ task: EnergyAwareTask) {
        taskScheduler.schedule(task, energyState: energyState)
    }
    
    /// 즉시 에너지 절약 모드 활성화
    func enableEnergySavingMode() {
        guard energyState != .critical else { return }
        
        energyState = .saving
        applyEnergySavingMeasures()
        
        print("🔋 에너지 절약 모드 활성화")
    }
    
    /// 에너지 절약 모드 비활성화
    func disableEnergySavingMode() {
        guard energyState == .saving else { return }
        
        energyState = .normal
        restoreNormalPerformance()
        
        print("🔋 일반 모드 복원")
    }
    
    /// 현재 에너지 상태 요약
    var energyStatusSummary: String {
        return energyMetrics.summary
    }
    
    /// 배터리 수명 예상 (분 단위)
    var estimatedBatteryLife: Int {
        guard batteryLevel > 0 else { return 0 }
        
        let currentConsumption = energyMetrics.currentPowerConsumption
        guard currentConsumption > 0 else { return Int.max }
        
        // 배터리 용량을 기준으로 예상 시간 계산 (대략적)
        let remainingCapacity = batteryLevel * 100 // 퍼센트
        let hoursRemaining = remainingCapacity / currentConsumption
        
        return max(0, Int(hoursRemaining * 60))
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // 배터리 및 시스템 상태 모니터링 (5초마다)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateSystemState()
        }
        
        // CPU 모니터링 시작
        cpuMonitor.startMonitoring { [weak self] usage in
            self?.handleCPUUsageChange(usage)
        }
        
        // 적응형 성능 컨트롤러 시작
        adaptiveController.startAdaptation { [weak self] recommendation in
            self?.applyPerformanceRecommendation(recommendation)
        }
    }
    
    private func setupNotifications() {
        // 배터리 상태 변화 감지
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryState()
            }
            .store(in: &cancellables)
        
        // 저전력 모드 변화 감지
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.updatePowerState()
            }
            .store(in: &cancellables)
        
        // 열 상태 변화 감지
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)
        
        // 앱 백그라운드 진입
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        // 앱 포그라운드 복귀
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func updateInitialState() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        updateBatteryState()
        updatePowerState()
        updateThermalState()
        updateEnergyState()
    }
    
    private func updateSystemState() {
        updateBatteryState()
        updatePowerState()
        updateThermalState()
        updateEnergyMetrics()
        updateEnergyState()
    }
    
    private func updateBatteryState() {
        let newLevel = Double(UIDevice.current.batteryLevel)
        
        // 유효한 배터리 레벨인 경우만 업데이트
        if newLevel >= 0 {
            batteryLevel = newLevel
        }
    }
    
    private func updatePowerState() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    private func updateThermalState() {
        thermalState = ProcessInfo.processInfo.thermalState
    }
    
    private func updateEnergyMetrics() {
        energyMetrics.updateMetrics(
            batteryLevel: batteryLevel,
            cpuUsage: cpuMonitor.currentUsage,
            thermalState: thermalState,
            lowPowerMode: isLowPowerModeEnabled
        )
    }
    
    private func updateEnergyState() {
        let previousState = energyState
        
        // 에너지 상태 결정 로직
        if batteryLevel < 0.1 || thermalState == .critical {
            energyState = .critical
        } else if batteryLevel < 0.2 || isLowPowerModeEnabled || thermalState == .serious {
            energyState = .saving
        } else if batteryLevel < 0.5 || thermalState == .fair {
            energyState = .efficient
        } else {
            energyState = .normal
        }
        
        // 상태 변화 시 적절한 조치
        if previousState != energyState {
            handleEnergyStateChange(from: previousState, to: energyState)
        }
    }
    
    private func handleEnergyStateChange(from previous: EnergyState, to current: EnergyState) {
        print("🔋 에너지 상태 변화: \(previous.rawValue) → \(current.rawValue)")
        
        switch current {
        case .normal:
            restoreNormalPerformance()
        case .efficient:
            applyEfficientMode()
        case .saving:
            applyEnergySavingMeasures()
        case .critical:
            applyCriticalEnergySaving()
        }
        
        // 모든 활성 컴포넌트에 새로운 제한사항 적용
        for component in activeComponents.values {
            applyEnergyLimitations(to: component)
        }
    }
    
    private func handleCPUUsageChange(_ usage: Double) {
        // CPU 사용량이 높을 때 자동 조절
        if usage > 80.0 && energyState != .critical {
            print("⚠️ 높은 CPU 사용량 감지 (\(String(format: "%.1f", usage))%) - 자동 최적화")
            applyTemporaryPerformanceLimitation()
        }
    }
    
    private func applyPerformanceRecommendation(_ recommendation: PerformanceRecommendation) {
        switch recommendation {
        case .reduceProcessing:
            performanceLimitation = .reduceProcessing
        case .limitAnimations:
            performanceLimitation = .limitAnimations
        case .pauseNonEssential:
            performanceLimitation = .pauseNonEssential
        case .normal:
            performanceLimitation = .none
        }
        
        // 모든 컴포넌트에 적용
        for component in activeComponents.values {
            applyEnergyLimitations(to: component)
        }
    }
    
    private func restoreNormalPerformance() {
        performanceLimitation = .none
        
        // 정상 성능 복원
        taskScheduler.enableHighPerformanceMode()
        
        print("🔋 정상 성능 모드 복원")
    }
    
    private func applyEfficientMode() {
        performanceLimitation = .reduceProcessing
        
        // 효율적 모드 적용
        taskScheduler.enableEfficientMode()
        
        print("🔋 효율적 모드 적용")
    }
    
    private func applyEnergySavingMeasures() {
        performanceLimitation = .limitAnimations
        
        // 에너지 절약 조치들
        taskScheduler.enableEnergySavingMode()
        
        // 등록된 콜백들 실행
        for (id, callback) in energySavingCallbacks {
            callback()
            print("🔋 에너지 절약 콜백 실행: \(id)")
        }
        
        print("🔋 에너지 절약 모드 적용")
    }
    
    private func applyCriticalEnergySaving() {
        performanceLimitation = .pauseNonEssential
        
        // 극한 에너지 절약 모드
        taskScheduler.enableCriticalMode()
        
        // 비필수 기능 모두 중지
        for component in activeComponents.values {
            if component.priority == .low || component.priority == .medium {
                component.suspend()
            }
        }
        
        print("🔋 극한 에너지 절약 모드 적용")
    }
    
    private func applyTemporaryPerformanceLimitation() {
        // 일시적 성능 제한 (30초)
        performanceLimitation = .reduceProcessing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            if self?.energyState == .normal {
                self?.performanceLimitation = .none
            }
        }
    }
    
    private func applyEnergyLimitations(to component: any EnergyConsumingComponent) {
        let limitations = calculateLimitations(for: component)
        component.applyEnergyLimitations(limitations)
    }
    
    private func calculateLimitations(for component: any EnergyConsumingComponent) -> EnergyLimitations {
        var limitations = EnergyLimitations()
        
        // 에너지 상태에 따른 기본 제한
        switch energyState {
        case .normal:
            limitations.cpuThrottle = 1.0
            limitations.animationScale = 1.0
            limitations.updateFrequency = 1.0
            
        case .efficient:
            limitations.cpuThrottle = 0.8
            limitations.animationScale = 0.9
            limitations.updateFrequency = 0.8
            
        case .saving:
            limitations.cpuThrottle = 0.6
            limitations.animationScale = 0.7
            limitations.updateFrequency = 0.5
            
        case .critical:
            limitations.cpuThrottle = 0.3
            limitations.animationScale = 0.3
            limitations.updateFrequency = 0.2
        }
        
        // 성능 제한사항 추가 적용
        switch performanceLimitation {
        case .none:
            break
        case .reduceProcessing:
            limitations.cpuThrottle *= 0.7
        case .limitAnimations:
            limitations.animationScale *= 0.5
        case .pauseNonEssential:
            if component.priority != .high {
                limitations.cpuThrottle *= 0.1
                limitations.animationScale = 0.0
                limitations.updateFrequency *= 0.1
            }
        }
        
        // 컴포넌트 우선순위에 따른 조정
        switch component.priority {
        case .high:
            // 고우선순위는 제한 완화
            limitations.cpuThrottle = min(1.0, limitations.cpuThrottle * 1.2)
        case .medium:
            // 중간 우선순위는 기본 적용
            break
        case .low:
            // 저우선순위는 제한 강화
            limitations.cpuThrottle *= 0.8
            limitations.updateFrequency *= 0.7
        }
        
        return limitations
    }
    
    private func handleAppDidEnterBackground() {
        print("🔋 앱 백그라운드 진입 - 에너지 절약 모드")
        
        // 백그라운드 작업 시작
        backgroundTaskManager.startBackgroundTask()
        
        // 모든 저우선순위 컴포넌트 일시정지
        for component in activeComponents.values {
            if component.priority == .low {
                component.suspend()
            }
        }
        
        // 타이머 빈도 감소
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateSystemState()
        }
    }
    
    private func handleAppWillEnterForeground() {
        print("🔋 앱 포그라운드 복귀 - 성능 복원")
        
        // 백그라운드 작업 종료
        backgroundTaskManager.endBackgroundTask()
        
        // 일시정지된 컴포넌트 재개
        for component in activeComponents.values {
            component.resume()
        }
        
        // 정상 모니터링 빈도 복원
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateSystemState()
        }
        
        // 상태 즉시 업데이트
        updateSystemState()
    }
    
    private func cleanup() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        cpuMonitor.stopMonitoring()
        adaptiveController.stopAdaptation()
        backgroundTaskManager.endBackgroundTask()
        
        cancellables.removeAll()
        activeComponents.removeAll()
        energySavingCallbacks.removeAll()
        
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
}

// MARK: - Supporting Types

/// 에너지 상태
enum EnergyState: String, CaseIterable {
    case normal = "정상"
    case efficient = "효율적"
    case saving = "절약"
    case critical = "극한절약"
}

/// 성능 제한 상태
enum PerformanceLimitation: String, CaseIterable {
    case none = "제한없음"
    case reduceProcessing = "처리량감소"
    case limitAnimations = "애니메이션제한"
    case pauseNonEssential = "비필수기능정지"
}

/// 성능 권장사항
enum PerformanceRecommendation {
    case normal
    case reduceProcessing
    case limitAnimations
    case pauseNonEssential
}

/// 에너지 소비 컴포넌트 우선순위
enum ComponentPriority: String, CaseIterable {
    case high = "높음"
    case medium = "중간"
    case low = "낮음"
}

/// 에너지 제한사항
struct EnergyLimitations {
    var cpuThrottle: Double = 1.0        // CPU 사용량 제한 (0.0 ~ 1.0)
    var animationScale: Double = 1.0     // 애니메이션 스케일 (0.0 ~ 1.0)
    var updateFrequency: Double = 1.0    // 업데이트 빈도 (0.0 ~ 1.0)
}

/// 에너지 소비 컴포넌트 프로토콜
protocol EnergyConsumingComponent: Hashable {
    var name: String { get }
    var priority: ComponentPriority { get }
    
    func applyEnergyLimitations(_ limitations: EnergyLimitations)
    func suspend()
    func resume()
}

/// 에너지 인식 작업
struct EnergyAwareTask {
    let id: String
    let priority: ComponentPriority
    let estimatedCPUUsage: Double // 0.0 ~ 1.0
    let estimatedDuration: TimeInterval
    let task: () -> Void
}

/// 에너지 메트릭스
struct EnergyMetrics {
    private(set) var currentPowerConsumption: Double = 0.0 // %/hour
    private(set) var averageCPUUsage: Double = 0.0
    private(set) var thermalEvents: Int = 0
    private(set) var backgroundTime: TimeInterval = 0.0
    
    mutating func updateMetrics(
        batteryLevel: Double,
        cpuUsage: Double,
        thermalState: ProcessInfo.ThermalState,
        lowPowerMode: Bool
    ) {
        // 단순한 전력 소비 추정
        var consumption = cpuUsage * 0.1 // 기본 CPU 소비
        
        if thermalState == .serious || thermalState == .critical {
            consumption *= 1.5
            thermalEvents += 1
        }
        
        if lowPowerMode {
            consumption *= 0.7
        }
        
        currentPowerConsumption = consumption
        averageCPUUsage = (averageCPUUsage + cpuUsage) / 2.0
    }
    
    var summary: String {
        return """
        🔋 에너지 상태:
        - 예상 소비량: \(String(format: "%.1f", currentPowerConsumption))%/시간
        - 평균 CPU: \(String(format: "%.1f", averageCPUUsage))%
        - 열 이벤트: \(thermalEvents)회
        - 백그라운드 시간: \(String(format: "%.1f", backgroundTime))분
        """
    }
}

/// CPU 모니터
private class CPUMonitor {
    private var monitoringTimer: Timer?
    private var callback: ((Double) -> Void)?
    
    private(set) var currentUsage: Double = 0.0
    
    func startMonitoring(callback: @escaping (Double) -> Void) {
        self.callback = callback
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateCPUUsage()
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        callback = nil
    }
    
    private func updateCPUUsage() {
        // CPU 사용량 계산 (단순화된 버전)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // 간접적인 CPU 사용량 추정
            let usage = min(100.0, Double(info.resident_size) / (1024 * 1024) * 0.1) // MB 기반 추정
            currentUsage = usage
            callback?(usage)
        }
    }
}

/// 적응형 성능 컨트롤러
private class AdaptivePerformanceController {
    private var monitoringTimer: Timer?
    private var callback: ((PerformanceRecommendation) -> Void)?
    
    private var consecutiveHighUsage = 0
    private var consecutiveLowUsage = 0
    
    func startAdaptation(callback: @escaping (PerformanceRecommendation) -> Void) {
        self.callback = callback
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.evaluatePerformance()
        }
    }
    
    func stopAdaptation() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        callback = nil
    }
    
    private func evaluatePerformance() {
        let batteryLevel = UIDevice.current.batteryLevel
        let thermalState = ProcessInfo.processInfo.thermalState
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        var recommendation: PerformanceRecommendation = .normal
        
        // 배터리 레벨 기반 권장사항
        if batteryLevel < 0.1 {
            recommendation = .pauseNonEssential
        } else if batteryLevel < 0.2 || isLowPowerMode {
            recommendation = .limitAnimations
        } else if batteryLevel < 0.5 {
            recommendation = .reduceProcessing
        }
        
        // 열 상태 기반 권장사항 (우선순위 높음)
        switch thermalState {
        case .critical:
            recommendation = .pauseNonEssential
        case .serious:
            recommendation = .limitAnimations
        case .fair:
            if recommendation == .normal {
                recommendation = .reduceProcessing
            }
        default:
            break
        }
        
        callback?(recommendation)
    }
}

/// 에너지 인식 작업 스케줄러
private class EnergyAwareTaskScheduler {
    private var pendingTasks: [EnergyAwareTask] = []
    private var isHighPerformanceMode = true
    
    func schedule(_ task: EnergyAwareTask, energyState: EnergyState) {
        switch energyState {
        case .normal:
            // 즉시 실행
            DispatchQueue.global(qos: .userInitiated).async {
                task.task()
            }
            
        case .efficient:
            // 우선순위에 따라 지연 실행
            let delay = task.priority == .high ? 0.0 : 1.0
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                task.task()
            }
            
        case .saving:
            // 고우선순위만 즉시 실행, 나머지는 큐에 저장
            if task.priority == .high {
                DispatchQueue.global(qos: .utility).async {
                    task.task()
                }
            } else {
                pendingTasks.append(task)
            }
            
        case .critical:
            // 고우선순위만 실행
            if task.priority == .high {
                DispatchQueue.global(qos: .background).async {
                    task.task()
                }
            } else {
                // 나머지는 무시
                print("🔋 에너지 절약으로 인해 작업 스킵: \(task.id)")
            }
        }
    }
    
    func enableHighPerformanceMode() {
        isHighPerformanceMode = true
        executePendingTasks()
    }
    
    func enableEfficientMode() {
        isHighPerformanceMode = false
    }
    
    func enableEnergySavingMode() {
        isHighPerformanceMode = false
        // 저우선순위 작업들만 실행
        executePendingTasks(priorityFilter: .medium)
    }
    
    func enableCriticalMode() {
        isHighPerformanceMode = false
        pendingTasks.removeAll()
    }
    
    private func executePendingTasks(priorityFilter: ComponentPriority = .low) {
        let tasksToExecute = pendingTasks.filter { task in
            switch priorityFilter {
            case .high:
                return task.priority == .high
            case .medium:
                return task.priority == .high || task.priority == .medium
            case .low:
                return true
            }
        }
        
        for task in tasksToExecute {
            DispatchQueue.global(qos: .background).async {
                task.task()
            }
        }
        
        pendingTasks.removeAll { task in
            tasksToExecute.contains { $0.id == task.id }
        }
    }
}

/// 백그라운드 작업 관리자
private class BackgroundTaskManager {
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    func startBackgroundTask() {
        guard backgroundTaskId == .invalid else { return }
        
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    func endBackgroundTask() {
        guard backgroundTaskId != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }
} 