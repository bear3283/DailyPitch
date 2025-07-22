import Foundation

/// 음계를 나타내는 엔터티
struct MusicNote {
    /// 음계명 (예: "A4", "C#5")
    let name: String
    
    /// 정확한 주파수 (Hz)
    let frequency: Double
    
    /// 미디 노트 번호 (0-127)
    let midiNumber: Int
    
    /// 옥타브 번호
    let octave: Int
    
    /// 음계 인덱스 (C=0, C#=1, D=2, ..., B=11)
    let noteIndex: Int
    
    /// 원본 주파수와의 오차 (cents)
    let deviationCents: Double
    
    /// 지속 시간 (초)
    let duration: TimeInterval
    
    /// 진폭 (0.0 ~ 1.0)
    let amplitude: Double
    
    /// 음계 생성 시간
    let timestamp: Date
    
    /// 기본 음계명 배열
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    /// A4 기준 주파수 (440Hz)
    static let A4Frequency: Double = 440.0
    static let A4MidiNumber: Int = 69
    
    /// 주파수로부터 음계 생성
    /// - Parameters:
    ///   - frequency: 원본 주파수 (Hz)
    ///   - duration: 지속 시간 (초)
    ///   - amplitude: 진폭 (0.0 ~ 1.0)
    /// - Returns: 가장 가까운 음계
    static func from(frequency: Double, duration: TimeInterval = 1.0, amplitude: Double = 0.5) -> MusicNote? {
        guard frequency > 0 else { return nil }
        
        // 주파수를 미디 노트 번호로 변환
        let midiNote = A4MidiNumber + Int(round(12 * log2(frequency / A4Frequency)))
        guard midiNote >= 0 && midiNote <= 127 else { return nil }
        
        // 정확한 주파수 계산
        let exactFrequency = A4Frequency * pow(2, Double(midiNote - A4MidiNumber) / 12)
        
        // 오차를 센트 단위로 계산
        let deviationCents = 1200 * log2(frequency / exactFrequency)
        
        // 옥타브와 음계 인덱스 계산
        let octave = (midiNote / 12) - 1
        let noteIndex = midiNote % 12
        let noteName = "\(noteNames[noteIndex])\(octave)"
        
        return MusicNote(
            name: noteName,
            frequency: exactFrequency,
            midiNumber: midiNote,
            octave: octave,
            noteIndex: noteIndex,
            deviationCents: deviationCents,
            duration: duration,
            amplitude: amplitude,
            timestamp: Date()
        )
    }
    
    /// 미디 노트 번호로부터 음계 생성
    /// - Parameters:
    ///   - midiNumber: 미디 노트 번호 (0-127)
    ///   - duration: 지속 시간 (초)
    ///   - amplitude: 진폭 (0.0 ~ 1.0)
    /// - Returns: 음계 (옵셔널)
    static func from(midiNumber: Int, duration: TimeInterval = 1.0, amplitude: Double = 0.5) -> MusicNote? {
        guard midiNumber >= 0 && midiNumber <= 127 else { return nil }
        
        let frequency = A4Frequency * pow(2, Double(midiNumber - A4MidiNumber) / 12)
        let octave = (midiNumber / 12) - 1
        let noteIndex = midiNumber % 12
        let noteName = "\(noteNames[noteIndex])\(octave)"
        
        return MusicNote(
            name: noteName,
            frequency: frequency,
            midiNumber: midiNumber,
            octave: octave,
            noteIndex: noteIndex,
            deviationCents: 0.0, // MIDI 노트는 정확한 주파수
            duration: duration,
            amplitude: amplitude,
            timestamp: Date()
        )
    }
    
    /// 음계명으로부터 음계 생성 (예: "A4", "C#5")
    /// - Parameters:
    ///   - noteName: 음계명
    ///   - duration: 지속 시간 (초)
    ///   - amplitude: 진폭 (0.0 ~ 1.0)
    /// - Returns: 음계 (옵셔널)
    static func from(noteName: String, duration: TimeInterval = 1.0, amplitude: Double = 0.5) -> MusicNote? {
        // 음계명 파싱 (예: "A4" -> note: "A", octave: 4)
        let notePattern = "([A-G][#b]?)([0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: notePattern),
              let match = regex.firstMatch(in: noteName, range: NSRange(noteName.startIndex..., in: noteName)) else {
            return nil
        }
        
        let noteString = String(noteName[Range(match.range(at: 1), in: noteName)!])
        let octaveString = String(noteName[Range(match.range(at: 2), in: noteName)!])
        
        guard let octave = Int(octaveString) else { return nil }
        
        // 음계 인덱스 찾기
        let normalizedNote = noteString.replacingOccurrences(of: "b", with: "#") // 플랫을 샵으로 변환
        guard let noteIndex = noteNames.firstIndex(of: normalizedNote) else { return nil }
        
        let midiNumber = (octave + 1) * 12 + noteIndex
        
        return from(midiNumber: midiNumber, duration: duration, amplitude: amplitude)
    }
    
    /// 반음 위로 올리기
    var sharpened: MusicNote? {
        return MusicNote.from(midiNumber: midiNumber + 1, duration: duration, amplitude: amplitude)
    }
    
    /// 반음 아래로 내리기
    var flattened: MusicNote? {
        return MusicNote.from(midiNumber: midiNumber - 1, duration: duration, amplitude: amplitude)
    }
    
    /// 옥타브 올리기
    var octaveUp: MusicNote? {
        return MusicNote.from(midiNumber: midiNumber + 12, duration: duration, amplitude: amplitude)
    }
    
    /// 옥타브 내리기
    var octaveDown: MusicNote? {
        return MusicNote.from(midiNumber: midiNumber - 12, duration: duration, amplitude: amplitude)
    }
    
    /// 음계가 정확한지 확인 (±10 cents 이내)
    var isAccurate: Bool {
        return abs(deviationCents) <= 10.0
    }
    
    /// 음계 정확도 등급
    var accuracyGrade: AccuracyGrade {
        let absDeviation = abs(deviationCents)
        
        if absDeviation <= 5.0 {
            return .excellent
        } else if absDeviation <= 15.0 {
            return .good
        } else if absDeviation <= 30.0 {
            return .fair
        } else {
            return .poor
        }
    }
    
    /// 정확도 등급
    enum AccuracyGrade: String, CaseIterable {
        case excellent = "매우 정확"
        case good = "정확"
        case fair = "보통"
        case poor = "부정확"
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }
}

extension MusicNote: Equatable {
    static func == (lhs: MusicNote, rhs: MusicNote) -> Bool {
        return lhs.midiNumber == rhs.midiNumber &&
               abs(lhs.duration - rhs.duration) < 0.001 &&
               abs(lhs.amplitude - rhs.amplitude) < 0.001
    }
}

extension MusicNote: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(midiNumber)
        hasher.combine(Int(duration * 1000)) // 밀리초 단위로 해싱
        hasher.combine(Int(amplitude * 1000))
    }
}

extension MusicNote: CustomStringConvertible {
    var description: String {
        return "\(name) (\(String(format: "%.1f", frequency))Hz, \(String(format: "%.1f", deviationCents)) cents)"
    }
} 