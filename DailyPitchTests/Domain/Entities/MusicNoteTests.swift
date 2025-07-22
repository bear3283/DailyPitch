import XCTest
@testable import DailyPitch

final class MusicNoteTests: XCTestCase {
    
    // MARK: - 주파수로부터 음계 생성 테스트
    
    func testCreateNoteFromA4Frequency() {
        // Given: A4 표준 주파수 (440Hz)
        let frequency: Double = 440.0
        
        // When: 주파수로부터 음계 생성
        let note = MusicNote.from(frequency: frequency)
        
        // Then: A4 음계가 정확히 생성되어야 함
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.name, "A4")
        XCTAssertEqual(note?.frequency, 440.0, accuracy: 0.01)
        XCTAssertEqual(note?.midiNumber, 69)
        XCTAssertEqual(note?.octave, 4)
        XCTAssertEqual(note?.noteIndex, 9) // A는 인덱스 9
        XCTAssertEqual(note?.deviationCents, 0.0, accuracy: 0.01)
    }
    
    func testCreateNoteFromC4Frequency() {
        // Given: C4 주파수 (약 261.63Hz)
        let frequency: Double = 261.63
        
        // When: 주파수로부터 음계 생성
        let note = MusicNote.from(frequency: frequency)
        
        // Then: C4 음계가 생성되어야 함
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.name, "C4")
        XCTAssertEqual(note?.octave, 4)
        XCTAssertEqual(note?.noteIndex, 0) // C는 인덱스 0
        XCTAssertEqual(note?.midiNumber, 60)
    }
    
    func testCreateNoteFromSlightlyOffPitchFrequency() {
        // Given: A4보다 약간 높은 주파수 (442Hz, +7.8 cents)
        let frequency: Double = 442.0
        
        // When: 주파수로부터 음계 생성
        let note = MusicNote.from(frequency: frequency)
        
        // Then: A4로 감지되고 편차가 계산되어야 함
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.name, "A4")
        XCTAssertEqual(note?.frequency, 440.0, accuracy: 0.01) // 정확한 A4 주파수
        XCTAssertTrue(note!.deviationCents > 0) // 양의 편차
        XCTAssertEqual(note?.deviationCents, 7.82, accuracy: 0.1)
    }
    
    func testCreateNoteFromInvalidFrequency() {
        // Given: 유효하지 않은 주파수들
        let invalidFrequencies: [Double] = [-1.0, 0.0, 20000.0]
        
        for frequency in invalidFrequencies {
            // When: 유효하지 않은 주파수로 음계 생성 시도
            let note = MusicNote.from(frequency: frequency)
            
            // Then: nil이 반환되어야 함
            XCTAssertNil(note, "주파수 \(frequency)는 유효하지 않으므로 nil을 반환해야 합니다.")
        }
    }
    
    // MARK: - MIDI 번호로부터 음계 생성 테스트
    
    func testCreateNoteFromMidiNumber() {
        // Given: A4의 MIDI 번호 (69)
        let midiNumber = 69
        
        // When: MIDI 번호로부터 음계 생성
        let note = MusicNote.from(midiNumber: midiNumber)
        
        // Then: 정확한 A4 음계가 생성되어야 함
        XCTAssertNotNil(note)
        XCTAssertEqual(note?.name, "A4")
        XCTAssertEqual(note?.frequency, 440.0, accuracy: 0.01)
        XCTAssertEqual(note?.midiNumber, 69)
        XCTAssertEqual(note?.deviationCents, 0.0) // MIDI는 정확한 주파수
    }
    
    func testCreateNoteFromInvalidMidiNumber() {
        // Given: 유효하지 않은 MIDI 번호들
        let invalidMidiNumbers = [-1, 128, 200]
        
        for midiNumber in invalidMidiNumbers {
            // When: 유효하지 않은 MIDI 번호로 음계 생성 시도
            let note = MusicNote.from(midiNumber: midiNumber)
            
            // Then: nil이 반환되어야 함
            XCTAssertNil(note, "MIDI 번호 \(midiNumber)는 유효하지 않으므로 nil을 반환해야 합니다.")
        }
    }
    
    // MARK: - 음계명으로부터 음계 생성 테스트
    
    func testCreateNoteFromNoteName() {
        // Given: 유효한 음계명들
        let testCases: [(name: String, expectedMidi: Int)] = [
            ("A4", 69),
            ("C4", 60),
            ("C#4", 61),
            ("Db4", 61), // 플랫 표기
            ("G5", 79),
            ("A0", 21)
        ]
        
        for testCase in testCases {
            // When: 음계명으로부터 음계 생성
            let note = MusicNote.from(noteName: testCase.name)
            
            // Then: 올바른 음계가 생성되어야 함
            XCTAssertNotNil(note, "\(testCase.name)에서 음계가 생성되어야 합니다.")
            XCTAssertEqual(note?.midiNumber, testCase.expectedMidi, "\(testCase.name)의 MIDI 번호가 \(testCase.expectedMidi)이어야 합니다.")
        }
    }
    
    func testCreateNoteFromInvalidNoteName() {
        // Given: 유효하지 않은 음계명들
        let invalidNames = ["H4", "A", "C#", "X4", "A99", ""]
        
        for invalidName in invalidNames {
            // When: 유효하지 않은 음계명으로 음계 생성 시도
            let note = MusicNote.from(noteName: invalidName)
            
            // Then: nil이 반환되어야 함
            XCTAssertNil(note, "\(invalidName)는 유효하지 않은 음계명이므로 nil을 반환해야 합니다.")
        }
    }
    
    // MARK: - 음계 조작 테스트
    
    func testSharpAndFlat() {
        // Given: C4 음계
        let note = MusicNote.from(noteName: "C4")!
        
        // When: 반음 올리기
        let sharpened = note.sharpened
        
        // Then: C#4가 되어야 함
        XCTAssertNotNil(sharpened)
        XCTAssertEqual(sharpened?.name, "C#4")
        XCTAssertEqual(sharpened?.midiNumber, 61)
        
        // When: 반음 내리기
        let flattened = sharpened!.flattened
        
        // Then: 다시 C4가 되어야 함
        XCTAssertNotNil(flattened)
        XCTAssertEqual(flattened?.name, "C4")
        XCTAssertEqual(flattened?.midiNumber, 60)
    }
    
    func testOctaveTransposition() {
        // Given: A4 음계
        let note = MusicNote.from(noteName: "A4")!
        
        // When: 옥타브 올리기
        let octaveUp = note.octaveUp
        
        // Then: A5가 되어야 함
        XCTAssertNotNil(octaveUp)
        XCTAssertEqual(octaveUp?.name, "A5")
        XCTAssertEqual(octaveUp?.midiNumber, 81)
        XCTAssertEqual(octaveUp?.frequency, 880.0, accuracy: 0.01)
        
        // When: 옥타브 내리기
        let octaveDown = note.octaveDown
        
        // Then: A3가 되어야 함
        XCTAssertNotNil(octaveDown)
        XCTAssertEqual(octaveDown?.name, "A3")
        XCTAssertEqual(octaveDown?.midiNumber, 57)
        XCTAssertEqual(octaveDown?.frequency, 220.0, accuracy: 0.01)
    }
    
    // MARK: - 정확도 테스트
    
    func testAccuracyGrades() {
        // Given: 다양한 편차를 가진 음계들
        let testCases: [(cents: Double, expectedGrade: MusicNote.AccuracyGrade)] = [
            (0.0, .excellent),
            (3.0, .excellent),
            (8.0, .good),
            (12.0, .good),
            (20.0, .fair),
            (25.0, .fair),
            (40.0, .poor),
            (100.0, .poor)
        ]
        
        for testCase in testCases {
            // When: 특정 편차를 가진 음계 생성 (시뮬레이션)
            let frequency = 440.0 * pow(2, testCase.cents / 1200.0) // cents만큼 벗어난 주파수
            let note = MusicNote.from(frequency: frequency)!
            
            // Then: 올바른 정확도 등급이 계산되어야 함
            XCTAssertEqual(note.accuracyGrade, testCase.expectedGrade, 
                          "\(testCase.cents) cents 편차는 \(testCase.expectedGrade) 등급이어야 합니다.")
        }
    }
    
    func testIsAccurate() {
        // Given: 정확한 A4 주파수
        let accurateNote = MusicNote.from(frequency: 440.0)!
        // Given: 부정확한 주파수 (20 cents 벗어남)
        let inaccurateNote = MusicNote.from(frequency: 446.0)!
        
        // Then: 정확도 판정이 올바르게 되어야 함
        XCTAssertTrue(accurateNote.isAccurate)
        XCTAssertFalse(inaccurateNote.isAccurate)
    }
    
    // MARK: - Equatable & Hashable 테스트
    
    func testEquatable() {
        // Given: 동일한 MIDI 번호, 지속시간, 진폭을 가진 두 음계
        let note1 = MusicNote.from(midiNumber: 69, duration: 1.0, amplitude: 0.5)!
        let note2 = MusicNote.from(midiNumber: 69, duration: 1.0, amplitude: 0.5)!
        let note3 = MusicNote.from(midiNumber: 70, duration: 1.0, amplitude: 0.5)! // 다른 음계
        
        // Then: 동등성 비교가 올바르게 작동해야 함
        XCTAssertEqual(note1, note2)
        XCTAssertNotEqual(note1, note3)
    }
    
    func testHashable() {
        // Given: 동일한 음계들
        let note1 = MusicNote.from(midiNumber: 69, duration: 1.0, amplitude: 0.5)!
        let note2 = MusicNote.from(midiNumber: 69, duration: 1.0, amplitude: 0.5)!
        
        // When: Set에 추가
        let noteSet = Set([note1, note2])
        
        // Then: 중복이 제거되어야 함
        XCTAssertEqual(noteSet.count, 1)
    }
    
    // MARK: - CustomStringConvertible 테스트
    
    func testDescription() {
        // Given: A4 음계
        let note = MusicNote.from(frequency: 442.0)! // 약간 높은 주파수
        
        // When: description 접근
        let description = note.description
        
        // Then: 적절한 형식의 문자열이 반환되어야 함
        XCTAssertTrue(description.contains("A4"))
        XCTAssertTrue(description.contains("440.0"))
        XCTAssertTrue(description.contains("Hz"))
        XCTAssertTrue(description.contains("cents"))
    }
    
    // MARK: - 성능 테스트
    
    func testPerformanceFrequencyToNoteConversion() {
        // Given: 다양한 주파수들
        let frequencies = stride(from: 80.0, through: 2000.0, by: 10.0).map { $0 }
        
        // When: 성능 측정
        measure {
            for frequency in frequencies {
                _ = MusicNote.from(frequency: frequency)
            }
        }
    }
} 