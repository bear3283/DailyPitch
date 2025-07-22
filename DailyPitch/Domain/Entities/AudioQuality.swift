import Foundation

/// 오디오 품질 정보
struct AudioQuality {
    /// RMS (Root Mean Square) 값
    let rms: Float
    
    /// 피크 값
    let peak: Float
    
    /// 다이나믹 레인지 (dB)
    let dynamicRange: Float
    
    /// Signal to Noise Ratio (dB)
    let signalToNoiseRatio: Float
    
    /// Total Harmonic Distortion (0.0 ~ 1.0)
    let totalHarmonicDistortion: Float
    
    /// 초기화
    init(
        rms: Float,
        peak: Float,
        dynamicRange: Float,
        signalToNoiseRatio: Float,
        totalHarmonicDistortion: Float
    ) {
        self.rms = rms
        self.peak = peak
        self.dynamicRange = dynamicRange
        self.signalToNoiseRatio = signalToNoiseRatio
        self.totalHarmonicDistortion = totalHarmonicDistortion
    }
    
    /// 품질 등급 계산
    var qualityLevel: AudioQualityLevel {
        // 품질 기준
        if rms < 0.001 || peak < 0.01 {
            return .failed
        } else if rms > 0.1 && peak > 0.5 && dynamicRange > 20.0 {
            return .excellent
        } else if rms > 0.05 && peak > 0.3 && dynamicRange > 15.0 {
            return .good
        } else if rms > 0.02 && peak > 0.1 && dynamicRange > 10.0 {
            return .fair
        } else {
            return .poor
        }
    }
    
    /// 전체 점수 계산 (0.0 ~ 1.0)
    var overallScore: Float {
        let rmsScore = min(1.0, rms * 10.0) // RMS 점수
        let peakScore = min(1.0, peak) // Peak 점수
        let dynamicScore = min(1.0, dynamicRange / 40.0) // Dynamic Range 점수 (40dB 기준)
        let snrScore = min(1.0, signalToNoiseRatio / 60.0) // SNR 점수 (60dB 기준)
        let thdScore = 1.0 - totalHarmonicDistortion // THD 점수 (낮을수록 좋음)
        
        return (rmsScore + peakScore + dynamicScore + snrScore + thdScore) / 5.0
    }
}

/// 오디오 품질 등급
enum AudioQualityLevel: String, CaseIterable {
    case excellent = "우수"
    case good = "양호"
    case fair = "보통"
    case poor = "낮음"
    case failed = "실패"
    
    /// 품질 설명
    var description: String {
        switch self {
        case .excellent:
            return "매우 좋은 음질입니다"
        case .good:
            return "좋은 음질입니다"
        case .fair:
            return "보통 음질입니다"
        case .poor:
            return "음질이 좋지 않습니다"
        case .failed:
            return "음질이 너무 낮습니다"
        }
    }
    
    /// 개선 제안
    var improvementSuggestion: String {
        switch self {
        case .excellent:
            return "현재 최적의 음질입니다"
        case .good:
            return "더 나은 음질을 위해 Harmonic 방법을 시도해보세요"
        case .fair:
            return "다른 합성 방법을 시도하거나 노이즈를 줄여보세요"
        case .poor:
            return "원본 오디오의 품질을 확인하거나 합성 방법을 변경해보세요"
        case .failed:
            return "오디오를 다시 녹음하거나 다른 합성 방법을 사용해보세요"
        }
    }
} 