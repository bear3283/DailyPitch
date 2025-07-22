import XCTest
import AVFoundation
@testable import DailyPitch

final class SynthesizedAudioTests: XCTestCase {
    
    var testNote: MusicNote!
    var testAudioData: [Float]!
    var testSampleRate: Double!
    
    override func setUp() {
        super.setUp()
        
        // Given: 테스트용 A4 음계와 오디오 데이터
        testNote = MusicNote.from(frequency: 440.0, duration: 1.0, amplitude: 0.5)!
        testSampleRate = 44100.0
        
        // 1초간의 간단한 사인파 생성
        let sampleCount = Int(testSampleRate)
        testAudioData = []
        
        for i in 0..<sampleCount {
            let phase = 2.0 * .pi * 440.0 * Double(i) / testSampleRate
            let sample = Float(sin(phase) * 0.5)
            testAudioData.append(sample)
        }
    }
    
    override func tearDown() {
        testNote = nil
        testAudioData = nil
        testSampleRate = nil
        super.tearDown()
    }
    
    // MARK: - 초기화 테스트
    
    func testBasicInitialization() {
        // When: SynthesizedAudio 생성
        let synthesizedAudio = SynthesizedAudio(
            musicNotes: [testNote],
            audioData: testAudioData,
            sampleRate: testSampleRate
        )
        
        // Then: 모든 속성이 올바르게 설정되어야 함
        XCTAssertEqual(synthesizedAudio.musicNotes.count, 1)
        XCTAssertEqual(synthesizedAudio.musicNotes.first?.name, "A4")
        XCTAssertEqual(synthesizedAudio.audioData.count, testAudioData.count)
        XCTAssertEqual(synthesizedAudio.sampleRate, testSampleRate)
        XCTAssertEqual(synthesizedAudio.duration, 1.0, accuracy: 0.01)
        XCTAssertEqual(synthesizedAudio.channelCount, 1)
        XCTAssertEqual(synthesizedAudio.synthesisMethod, .sineWave)
        XCTAssertNotNil(synthesizedAudio.id)
        XCTAssertNotNil(synthesizedAudio.synthesizedAt)
    }
    
    func testSilenceCreation() {
        // Given: 3초간의 무음
        let duration: TimeInterval = 3.0
        
        // When: 무음 생성
        let silence = SynthesizedAudio.silence(duration: duration, sampleRate: testSampleRate)
        
        // Then: 올바른 무음이 생성되어야 함
        XCTAssertEqual(silence.duration, duration, accuracy: 0.01)
        XCTAssertEqual(silence.musicNotes.count, 0)
        XCTAssertEqual(silence.audioData.count, Int(duration * testSampleRate))
        XCTAssertTrue(silence.audioData.allSatisfy { $0 == 0.0 })
        XCTAssertEqual(silence.peakAmplitude, 0.0)
        XCTAssertEqual(silence.rmsAmplitude, 0.0)
    }
    
    // MARK: - 단일 음계 생성 테스트
    
    func testSingleNoteGeneration() {
        // Given: A4 음계 (440Hz, 1초)
        let note = MusicNote.from(frequency: 440.0, duration: 1.0, amplitude: 0.8)!
        
        // When: 사인파로 오디오 생성
        let synthesizedAudio = SynthesizedAudio.from(
            note: note,
            sampleRate: testSampleRate,
            method: .sineWave
        )
        
        // Then: 올바른 오디오가 생성되어야 함
        XCTAssertEqual(synthesizedAudio.musicNotes.count, 1)
        XCTAssertEqual(synthesizedAudio.musicNotes.first?.frequency, 440.0, accuracy: 0.01)
        XCTAssertEqual(synthesizedAudio.duration, 1.0, accuracy: 0.01)
        XCTAssertTrue(synthesizedAudio.isValid)
        XCTAssertGreaterThan(synthesizedAudio.peakAmplitude, 0.0)
        XCTAssertGreaterThan(synthesizedAudio.rmsAmplitude, 0.0)
    }
    
    func testDifferentWaveforms() {
        // Given: 같은 음계, 다른 파형들
        let note = MusicNote.from(frequency: 440.0, duration: 0.5, amplitude: 0.5)!
        let waveforms: [SynthesizedAudio.SynthesisMethod] = [.sineWave, .squareWave, .sawtoothWave, .triangleWave]
        
        for waveform in waveforms {
            // When: 각 파형으로 오디오 생성
            let synthesizedAudio = SynthesizedAudio.from(
                note: note,
                sampleRate: testSampleRate,
                method: waveform
            )
            
            // Then: 유효한 오디오가 생성되어야 함
            XCTAssertTrue(synthesizedAudio.isValid, "\(waveform) 파형이 유효하지 않습니다.")
            XCTAssertEqual(synthesizedAudio.synthesisMethod, waveform)
            XCTAssertGreaterThan(synthesizedAudio.peakAmplitude, 0.0, "\(waveform) 파형의 진폭이 0입니다.")
        }
    }
    
    // MARK: - 시퀀스 생성 테스트
    
    func testSequenceGeneration() {
        // Given: C-E-G 아르페지오
        let notes = [
            MusicNote.from(noteName: "C4", duration: 0.5, amplitude: 0.5)!,
            MusicNote.from(noteName: "E4", duration: 0.5, amplitude: 0.5)!,
            MusicNote.from(noteName: "G4", duration: 0.5, amplitude: 0.5)!
        ]
        
        // When: 순차적으로 연결하여 시퀀스 생성
        let sequence = SynthesizedAudio.fromSequence(
            notes: notes,
            sampleRate: testSampleRate,
            method: .sineWave
        )
        
        // Then: 올바른 시퀀스가 생성되어야 함
        XCTAssertEqual(sequence.musicNotes.count, 3)
        XCTAssertEqual(sequence.duration, 1.5, accuracy: 0.01) // 0.5 * 3
        XCTAssertTrue(sequence.isValid)
        XCTAssertEqual(sequence.frequencies, [261.63, 329.63, 392.0], accuracy: 0.1)
    }
    
    func testEmptySequence() {
        // Given: 빈 음계 배열
        let emptyNotes: [MusicNote] = []
        
        // When: 빈 시퀀스로 오디오 생성
        let sequence = SynthesizedAudio.fromSequence(
            notes: emptyNotes,
            sampleRate: testSampleRate,
            method: .sineWave
        )
        
        // Then: 빈 오디오가 생성되어야 함
        XCTAssertEqual(sequence.musicNotes.count, 0)
        XCTAssertEqual(sequence.audioData.count, 0)
        XCTAssertEqual(sequence.duration, 0.0)
        XCTAssertFalse(sequence.isValid)
    }
    
    // MARK: - 화음 생성 테스트
    
    func testChordGeneration() {
        // Given: C Major 코드 (C-E-G)
        let notes = [
            MusicNote.from(noteName: "C4", duration: 2.0, amplitude: 0.3)!,
            MusicNote.from(noteName: "E4", duration: 2.0, amplitude: 0.3)!,
            MusicNote.from(noteName: "G4", duration: 2.0, amplitude: 0.3)!
        ]
        
        // When: 화음 생성
        let chord = SynthesizedAudio.fromChord(
            notes: notes,
            sampleRate: testSampleRate,
            method: .sineWave
        )
        
        // Then: 올바른 화음이 생성되어야 함
        XCTAssertEqual(chord.musicNotes.count, 3)
        XCTAssertEqual(chord.duration, 2.0, accuracy: 0.01)
        XCTAssertTrue(chord.isValid)
        XCTAssertLessThanOrEqual(chord.peakAmplitude, 1.0) // 정규화 확인
        
        // 화음의 RMS는 단일 음보다 클 수 있음
        let singleNote = SynthesizedAudio.from(note: notes[0], sampleRate: testSampleRate, method: .sineWave)
        XCTAssertGreaterThanOrEqual(chord.rmsAmplitude, singleNote.rmsAmplitude)
    }
    
    func testChordNormalization() {
        // Given: 높은 진폭을 가진 음계들 (클리핑 유발)
        let notes = [
            MusicNote.from(noteName: "C4", duration: 1.0, amplitude: 0.8)!,
            MusicNote.from(noteName: "E4", duration: 1.0, amplitude: 0.8)!,
            MusicNote.from(noteName: "G4", duration: 1.0, amplitude: 0.8)!,
            MusicNote.from(noteName: "C5", duration: 1.0, amplitude: 0.8)!
        ]
        
        // When: 화음 생성
        let chord = SynthesizedAudio.fromChord(
            notes: notes,
            sampleRate: testSampleRate,
            method: .sineWave
        )
        
        // Then: 정규화가 적용되어야 함
        XCTAssertLessThanOrEqual(chord.peakAmplitude, 1.0)
        XCTAssertGreaterThan(chord.peakAmplitude, 0.0)
    }
    
    // MARK: - AVAudioPCMBuffer 변환 테스트
    
    func testAVAudioPCMBufferConversion() {
        // Given: 유효한 합성 오디오
        let synthesizedAudio = SynthesizedAudio.from(
            note: testNote,
            sampleRate: testSampleRate,
            method: .sineWave
        )
        
        // When: AVAudioPCMBuffer로 변환
        let buffer = synthesizedAudio.toAVAudioPCMBuffer()
        
        // Then: 유효한 버퍼가 생성되어야 함
        XCTAssertNotNil(buffer)
        XCTAssertEqual(buffer?.format.sampleRate, testSampleRate)
        XCTAssertEqual(buffer?.format.channelCount, 1)
        XCTAssertEqual(buffer?.frameLength, AVAudioFrameCount(synthesizedAudio.audioData.count))
    }
    
    func testInvalidBufferConversion() {
        // Given: 빈 오디오 데이터
        let invalidAudio = SynthesizedAudio(
            musicNotes: [],
            audioData: [],
            sampleRate: testSampleRate
        )
        
        // When: AVAudioPCMBuffer로 변환 시도
        let buffer = invalidAudio.toAVAudioPCMBuffer()
        
        // Then: 버퍼 생성에 실패할 수 있음 (빈 데이터)
        if let buffer = buffer {
            XCTAssertEqual(buffer.frameLength, 0)
        }
    }
    
    // MARK: - 웨이브 함수 테스트
    
    func testWaveFunctions() {
        let testPhases: [Double] = [0, .pi/4, .pi/2, .pi, 3*.pi/2, 2*.pi]
        
        for method in SynthesizedAudio.SynthesisMethod.allCases {
            for phase in testPhases {
                // When: 각 위상에서 웨이브 함수 계산
                let value = method.waveFunction(phase: phase)
                
                // Then: 유한한 값이어야 함
                XCTAssertTrue(value.isFinite, "\(method) 웨이브 함수가 \(phase) 위상에서 무한값을 반환했습니다.")
                XCTAssertTrue(abs(value) <= 1.1, "\(method) 웨이브 함수가 예상 범위를 벗어났습니다: \(value)")
            }
        }
    }
    
    // MARK: - 속성 계산 테스트
    
    func testAudioProperties() {
        // Given: 알려진 특성을 가진 오디오
        let audioData: [Float] = [0.0, 0.5, 1.0, 0.5, 0.0, -0.5, -1.0, -0.5]
        let synthesizedAudio = SynthesizedAudio(
            musicNotes: [testNote],
            audioData: audioData,
            sampleRate: 8.0 // 8 샘플 = 1초
        )
        
        // Then: 올바른 속성이 계산되어야 함
        XCTAssertEqual(synthesizedAudio.peakAmplitude, 1.0)
        XCTAssertEqual(synthesizedAudio.noteCount, 1)
        XCTAssertEqual(synthesizedAudio.frequencies, [440.0])
        XCTAssertTrue(synthesizedAudio.isValid)
        
        // RMS 계산 확인
        let expectedRMS = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count))
        XCTAssertEqual(synthesizedAudio.rmsAmplitude, expectedRMS, accuracy: 0.001)
    }
    
    func testInvalidAudio() {
        // Given: 유효하지 않은 오디오들
        let invalidCases = [
            SynthesizedAudio(musicNotes: [], audioData: [], sampleRate: 44100.0),
            SynthesizedAudio(musicNotes: [testNote], audioData: [0.0], sampleRate: 0.0),
            SynthesizedAudio(musicNotes: [testNote], audioData: [0.0], sampleRate: -1.0)
        ]
        
        for invalidAudio in invalidCases {
            // Then: 유효하지 않다고 판정되어야 함
            XCTAssertFalse(invalidAudio.isValid)
        }
    }
    
    // MARK: - Equatable & Hashable 테스트
    
    func testEquatable() {
        // Given: 동일한 ID를 가진 두 오디오 (다른 내용이지만 ID가 같음)
        let audio1 = SynthesizedAudio(musicNotes: [testNote], audioData: testAudioData, sampleRate: testSampleRate)
        let audio2 = audio1 // 같은 인스턴스
        
        // When: 다른 오디오 생성
        let audio3 = SynthesizedAudio(musicNotes: [testNote], audioData: testAudioData, sampleRate: testSampleRate)
        
        // Then: ID 기반 동등성이 작동해야 함
        XCTAssertEqual(audio1, audio2)
        XCTAssertNotEqual(audio1, audio3) // 다른 ID
    }
    
    func testHashable() {
        // Given: 여러 오디오 인스턴스
        let audio1 = SynthesizedAudio(musicNotes: [testNote], audioData: testAudioData, sampleRate: testSampleRate)
        let audio2 = SynthesizedAudio(musicNotes: [testNote], audioData: testAudioData, sampleRate: testSampleRate)
        
        // When: Set에 추가
        let audioSet = Set([audio1, audio1, audio2]) // audio1 중복
        
        // Then: 고유한 ID별로 저장되어야 함
        XCTAssertEqual(audioSet.count, 2)
    }
    
    // MARK: - CustomStringConvertible 테스트
    
    func testDescription() {
        // Given: 여러 음계를 가진 오디오
        let notes = [
            MusicNote.from(noteName: "C4")!,
            MusicNote.from(noteName: "E4")!
        ]
        let audio = SynthesizedAudio.fromChord(notes: notes, sampleRate: testSampleRate, method: .squareWave)
        
        // When: description 접근
        let description = audio.description
        
        // Then: 적절한 정보가 포함되어야 함
        XCTAssertTrue(description.contains("C4"))
        XCTAssertTrue(description.contains("E4"))
        XCTAssertTrue(description.contains("사각파"))
        XCTAssertTrue(description.contains("duration"))
    }
    
    // MARK: - 성능 테스트
    
    func testPerformanceChordGeneration() {
        // Given: 복잡한 화음 (7개 음계)
        let notes = (0..<7).compactMap { i in
            MusicNote.from(midiNumber: 60 + i * 2, duration: 1.0, amplitude: 0.2) // C Major scale
        }
        
        // When: 성능 측정
        measure {
            _ = SynthesizedAudio.fromChord(notes: notes, sampleRate: testSampleRate, method: .sineWave)
        }
    }
    
    func testPerformanceLongSequence() {
        // Given: 긴 시퀀스 (50개 음계)
        let notes = (0..<50).compactMap { i in
            MusicNote.from(midiNumber: 60 + (i % 12), duration: 0.1, amplitude: 0.3)
        }
        
        // When: 성능 측정
        measure {
            _ = SynthesizedAudio.fromSequence(notes: notes, sampleRate: testSampleRate, method: .sineWave)
        }
    }
} 