# DailyPitch 🎵

> **일상의 소리를 음계로 변환하여 음악적 영감을 제공하는 iOS 앱**

DailyPitch는 일상에서 들리는 다양한 소리(말소리, 새소리, 차소리, 에어컨 소리 등)를 실시간으로 분석하여 해당하는 음계로 변환하고, 이를 기반으로 음악 스케일을 추천해주는 혁신적인 iOS 애플리케이션입니다.

## 📱 주요 기능

### 🎤 실시간 오디오 녹음 및 분석
- AVFoundation을 이용한 고품질 오디오 녹음
- Accelerate 프레임워크 기반의 실시간 FFT 분석
- 주파수 스펙트럼 분석 및 주요 음계 감지

### 🎼 음계 변환 및 합성
- 감지된 주파수를 정확한 음계로 변환
- 다양한 파형(사인파, 사각파, 톱니파, 삼각파, 하모닉) 지원
- 원본 소리와 변환된 음계의 동시 재생 기능

### 🎯 지능형 스케일 추천
- 감지된 음계들을 기반으로 한 음악 스케일 추천
- 분위기별, 장르별 맞춤형 추천
- 복잡도 수준에 따른 필터링

### 🎵 음악적 도구
- 20개 이상의 미리 정의된 음악 스케일
- 장조, 단조, 펜타토닉, 블루스, 교회선법 등 지원
- 실시간 주파수 분석 및 시각화

## 🏗️ 시스템 아키텍처

DailyPitch는 클린 아키텍처 원칙을 따라 설계되었습니다:

```
📁 DailyPitch/
├── 🎨 Presentation/          # UI Layer
│   ├── Views/               # SwiftUI Views
│   └── ViewModels/          # MVVM ViewModels
├── 🔧 Domain/               # Business Logic Layer
│   ├── Entities/            # Core Business Objects
│   ├── UseCases/            # Business Use Cases
│   └── Repositories/        # Repository Interfaces
├── 📊 Data/                 # Data Layer
│   ├── Repositories/        # Repository Implementations
│   └── DataSources/         # External Data Sources
└── 🛠️ Core/                # Shared Utilities
    └── Utils/               # Helper Classes
```

### 🧩 주요 컴포넌트

#### Domain Layer
- **Entities**: `MusicNote`, `MusicScale`, `AudioSession`, `SynthesizedAudio`
- **Use Cases**: `RecordAudioUseCase`, `AnalyzeFrequencyUseCase`, `SynthesizeAudioUseCase`, `MusicScaleRecommendationUseCase`

#### Data Layer
- **FFTAnalyzer**: Accelerate 프레임워크를 이용한 고성능 FFT 분석
- **AVFoundationManager**: 오디오 녹음 및 재생 관리
- **AudioSynthesizer**: 다양한 파형을 이용한 오디오 합성

#### Presentation Layer
- **RecordingView**: 녹음 및 분석 화면
- **PlaybackControlsView**: 재생 컨트롤 인터페이스

## 🚀 기술 스택

### 📱 iOS 개발
- **Swift 5.0+**
- **SwiftUI** - 모던한 UI 프레임워크
- **Combine** - 반응형 프로그래밍
- **MVVM 아키텍처** - 관심사 분리

### 🔊 오디오 처리
- **AVFoundation** - 오디오 녹음, 재생, 처리
- **Accelerate** - 고성능 FFT 연산
- **AudioToolbox** - 로우레벨 오디오 처리

### 🧪 테스트
- **XCTest** - 단위 테스트 및 통합 테스트
- **TDD (Test-Driven Development)** - 테스트 주도 개발

### 📊 데이터 관리
- **Firebase** (선택사항) - 클라우드 데이터 저장
- **Core Data** - 로컬 데이터 저장

## 📋 시스템 요구사항

- **iOS 15.0 이상**
- **Xcode 14.0 이상**
- **마이크 접근 권한**
- **최소 1GB RAM 권장**

## 🛠️ 설치 및 설정 방법

### 1. 프로젝트 클론
```bash
git clone https://github.com/yourusername/DailyPitch.git
cd DailyPitch
```

### 2. Xcode에서 프로젝트 열기
```bash
open DailyPitch.xcodeproj
```

### 3. 빌드 대상 설정
- Target: iOS 15.0+
- Device: iPhone (실제 기기 권장 - 마이크 기능 필요)

### 4. 권한 설정 확인
`Info.plist`에서 마이크 권한 설정이 포함되어 있는지 확인:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>앱이 주변 소리를 분석하여 음계로 변환하기 위해 마이크 접근이 필요합니다.</string>
```

### 5. 빌드 및 실행
- **⌘ + R** 또는 Product → Run
- 실제 iOS 기기에서 테스트 권장

## 📖 사용법

### 🎤 기본 사용 흐름

1. **앱 실행 및 권한 허용**
   - 마이크 사용 권한 허용

2. **소리 녹음**
   - 🔴 녹음 버튼 탭
   - 일상의 소리 녹음 (말소리, 새소리, 차소리 등)
   - ⏹️ 정지 버튼으로 녹음 종료

3. **분석 및 결과 확인**
   - 자동 FFT 분석 진행
   - 감지된 주요 주파수 및 음계 표시
   - 정확도 및 신뢰도 점수 확인

4. **음계 합성 및 재생**
   - 합성 방법 선택 (사인파, 사각파 등)
   - 🎵 합성 버튼으로 음계 생성
   - 다양한 재생 모드:
     - 원본만 재생
     - 변환된 음계만 재생
     - 원본 + 변환 동시 재생

5. **스케일 추천 받기**
   - 감지된 음계 기반 스케일 자동 추천
   - 분위기별, 장르별 필터링 가능
   - 복잡도 수준 조절

### 🎛️ 고급 기능

#### 실시간 분석 모드
```swift
// 실시간 주파수 분석 시작
analyzeFrequencyUseCase.startRealtimeAnalysis()
    .sink { frequencyData in
        // 실시간 주파수 데이터 처리
    }
```

#### 커스텀 스케일 추천
```swift
let config = ScaleRecommendationConfig(
    maxResults: 5,
    minSimilarityThreshold: 0.4,
    preferredMood: .bright,
    preferredGenres: [.jazz, .blues],
    complexityRange: 2...4
)
```

## 🧪 테스트 실행 방법

### 단위 테스트
```bash
# Xcode에서
⌘ + U

# 또는 커맨드라인에서
xcodebuild test -scheme DailyPitch -destination 'platform=iOS Simulator,name=iPhone 14'
```

### 통합 테스트
```swift
// 전체 워크플로우 테스트
testCompleteWorkflow_RecordToPlayback_ShouldCompleteSuccessfully()

// 에러 처리 테스트
testErrorHandling_RecordingFailure_ShouldShowErrorMessage()
```

### 성능 테스트
```swift
// FFT 분석 성능
testPerformance_FFTAnalysis_ShouldCompleteWithinTimeLimit()

// 전체 워크플로우 성능
testPerformance_CompleteWorkflow_ShouldCompleteWithinTimeLimit()
```

## 📊 성능 최적화

### 🔊 오디오 처리 최적화
- **FFT 윈도우 크기**: 1024 샘플 (실시간 처리와 정확도의 균형)
- **샘플링 레이트**: 44.1kHz (CD 품질)
- **해밍 윈도우**: 주파수 누출 최소화
- **겹치는 윈도우**: 50% 오버랩으로 연속성 보장

### 💾 메모리 관리
- 순환 참조 방지를 위한 weak self 사용
- 오디오 버퍼의 효율적인 재사용
- 백그라운드 큐에서 무거운 연산 처리

### ⚡ 실시간 성능
- 평균 분석 시간: < 10ms
- UI 응답성: 메인 스레드 블로킹 방지
- 배터리 최적화: 필요시에만 분석 수행

## 🎯 핵심 알고리즘

### 🔬 FFT 분석
```swift
// 해밍 윈도우 적용
vDSP_vmul(inputData, 1, hammingWindow, 1, &windowedData, 1, length)

// FFT 변환
fftSetup.forward(input: input, output: &output)

// 진폭 계산
magnitude = sqrt(real² + imag²)
```

### 🎵 음계 감지
```swift
// 주파수 → MIDI 노트 변환
let midiNote = 69 + 12 * log2(frequency / 440.0)

// 가장 가까운 음계 계산
let noteIndex = round(midiNote) % 12
let noteName = noteNames[noteIndex]
```

### 📈 스케일 유사도 계산
```swift
// Jaccard 유사도
let intersection = Set(detectedNotes) ∩ Set(scaleNotes)
let union = Set(detectedNotes) ∪ Set(scaleNotes)
let similarity = Double(intersection.count) / Double(union.count)
```

## 🔧 문제 해결

### 일반적인 문제들

#### 마이크 권한 문제
```swift
// 권한 상태 확인
let status = AVAudioSession.sharedInstance().recordPermission
if status == .denied {
    // 설정 앱으로 유도
}
```

#### 오디오 세션 충돌
```swift
// 오디오 세션 올바른 설정
try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
try AVAudioSession.sharedInstance().setActive(true)
```

#### 메모리 부족
- 긴 녹음 시 메모리 사용량 모니터링
- 필요없는 오디오 데이터 즉시 해제
- 백그라운드에서 메모리 정리

## 🤝 기여하기

1. **Fork** 이 프로젝트
2. **Feature 브랜치** 생성 (`git checkout -b feature/AmazingFeature`)
3. **변경사항 커밋** (`git commit -m 'Add some AmazingFeature'`)
4. **브랜치에 Push** (`git push origin feature/AmazingFeature`)
5. **Pull Request** 생성

### 📝 커밋 컨벤션
```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포매팅
refactor: 코드 리팩토링
test: 테스트 추가/수정
chore: 빌드 관련 수정
```

## 📜 라이선스

이 프로젝트는 **MIT License** 하에 라이선스가 부여됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 👥 개발팀

- **Bear** - *Lead Developer* - [GitHub](https://github.com/bear)

## 🙏 감사의 말

- **Apple** - AVFoundation 및 Accelerate 프레임워크
- **Swift Community** - 오픈소스 생태계
- **음악 이론 전문가들** - 스케일 및 음계 체계 자문

## 📞 지원 및 문의

- **이슈 리포팅**: [GitHub Issues](https://github.com/yourusername/DailyPitch/issues)
- **기능 요청**: [GitHub Discussions](https://github.com/yourusername/DailyPitch/discussions)
- **이메일**: support@dailypitch.app

---

**DailyPitch와 함께 일상의 소리를 음악으로 만들어보세요! 🎵✨** 