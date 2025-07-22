import XCTest
import AVFoundation
import Combine
@testable import DailyPitch

final class AudioPermissionManagerTests: XCTestCase {
    
    private var sut: AudioPermissionManager!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = AudioPermissionManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - 권한 상태 변환 테스트
    
    func test_convertAVPermissionStatus_shouldConvertCorrectly() {
        // Given & When & Then
        XCTAssertEqual(sut.convertPermissionStatus(.notDetermined), .notDetermined)
        XCTAssertEqual(sut.convertPermissionStatus(.granted), .granted)
        XCTAssertEqual(sut.convertPermissionStatus(.denied), .denied)
    }
    
    // MARK: - 권한 요청 테스트
    
    func test_requestPermission_shouldReturnPublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Permission request should complete")
        var permissionResult: Bool?
        
        // When
        sut.requestPermission()
            .sink { granted in
                permissionResult = granted
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // 실제 결과는 시뮬레이터/디바이스 환경에 따라 다를 수 있음
        XCTAssertNotNil(permissionResult)
    }
    
    // MARK: - 현재 권한 상태 확인 테스트
    
    func test_currentPermissionStatus_shouldReturnCurrentStatus() {
        // Given & When
        let status = sut.currentPermissionStatus()
        
        // Then
        // 실제 상태는 시뮬레이터/디바이스 설정에 따라 다름
        XCTAssertTrue([
            AudioPermissionStatus.notDetermined,
            AudioPermissionStatus.granted,
            AudioPermissionStatus.denied
        ].contains(status))
    }
    
    // MARK: - 권한 상태 변화 감지 테스트
    
    func test_permissionStatusPublisher_shouldEmitCurrentStatus() {
        // Given
        let expectation = XCTestExpectation(description: "Should emit current permission status")
        var receivedStatus: AudioPermissionStatus?
        
        // When
        sut.permissionStatusPublisher
            .first()
            .sink { status in
                receivedStatus = status
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedStatus)
    }
} 