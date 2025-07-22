import Foundation
import AVFoundation

/// 오디오 녹음 세션을 나타내는 도메인 엔터티
struct AudioSession {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let audioFileURL: URL?
    let sampleRate: Double
    let channelCount: Int
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        audioFileURL: URL? = nil,
        sampleRate: Double = 44100,
        channelCount: Int = 1
    ) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

extension AudioSession: Equatable {
    static func == (lhs: AudioSession, rhs: AudioSession) -> Bool {
        return lhs.id == rhs.id &&
               lhs.timestamp == rhs.timestamp &&
               lhs.duration == rhs.duration &&
               lhs.audioFileURL == rhs.audioFileURL &&
               lhs.sampleRate == rhs.sampleRate &&
               lhs.channelCount == rhs.channelCount
    }
} 