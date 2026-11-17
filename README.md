<p align="center"><img src="Assets/icon-1024.png" width="160" alt=""></p>

# 🎄 Christmas Tree

macOS 화면 최상단에 항상 떠 있는 작은 크리스마스 트리 앱 (Swift / AppKit + SwiftUI Canvas).

## 기능

- **항상 위에 표시** — 투명한 테두리 없는 창으로, 모든 데스크탑(Space)과 전체화면 앱 위에도 표시
- **드래그로 이동** — 트리를 끌어서 원하는 곳에 두면 위치를 기억
- **눈 내리기 on/off** — 트리 주변으로 눈이 내림
- **트리 디자인 14종** — 클래식 레드 & 골드, 눈 덮인 전나무, 샴페인 골드, 버건디 벨벳, 실버 & 블루, 화이트 플로킹, 노르딕 우드, 웜 라이트, 빈티지 전구, 에메랄드 & 골드, 선물 한가득, 블루 스프루스, 회전 조명, 골드 와이어
  - 3D 원뿔 위에 1천여 개의 전나무 가지를 바늘잎 단위로 그려 입체감을 내고, 오너먼트·리본·가랜드는 깊이 순서대로 가지 사이에 끼워 넣음
  - 잎과 장식은 한 번만 그려 이미지로 캐시하고, 전구·별·눈만 매 프레임 애니메이션
- **크리스마스 음악 on/off** — 오르골 음색으로 실시간 합성 (오디오 파일 없음, 모두 퍼블릭 도메인 곡)
  - Jingle Bells · We Wish You a Merry Christmas · Deck the Halls · Silent Night · Joy to the World
  - 전체 연속 재생 또는 한 곡 반복, 음량 3단계
- 크기 4단계, 로그인 시 자동 실행, 크리스마스 D-day 표시
- **영어 / 한국어** — macOS 언어 설정을 따름 (그 외 언어는 영어)
- **자동 업데이트** — Sparkle, 메뉴의 **업데이트 확인…**

## 조작

| 동작 | 기능 |
| --- | --- |
| 드래그 | 트리 이동 |
| 더블클릭 | 다음 디자인 |
| 우클릭 (또는 ⌃클릭) | 설정 메뉴 |
| 메뉴 막대의 🌲 아이콘 | 같은 설정 메뉴 |

Dock 아이콘 없이 메뉴 막대에서만 동작합니다. 종료는 메뉴의 **종료**.

## 빌드

macOS 26 이상, Xcode 26 이상(macOS 26 SDK)에서:

```bash
Scripts/bundle.sh            # build/ChristmasTree.app 생성
open build/ChristmasTree.app

Scripts/bundle.sh --install  # /Applications 에 설치하고 실행
```

> "로그인 시 자동 실행"은 앱이 `/Applications`에 있을 때 가장 잘 동작합니다.

`CODESIGN_IDENTITY="Developer ID Application"`을 주면 배포용(hardened runtime) 서명, 없으면 ad-hoc 서명입니다.

## 앱 아이콘

`Assets/AppIcon.icon`은 Icon Composer 문서입니다 (Liquid Glass). 손으로 고치지 말고 스크립트로 다시 만듭니다:

```bash
swift Scripts/make-assets.swift   # 레이어 PNG + icon.json + Assets/icon-1024.png(시스템 렌더)
```

별·오너먼트·트리(잎+기둥)·눈을 각각 그룹으로 나눠 그룹마다 유리 재질·스펙큘러·그림자를 줍니다. `bundle.sh`가 actool로 `Assets.car`(+ 폴백 `AppIcon.icns`)로 컴파일합니다.

## 릴리스

`CHANGELOG.md`와 `CHANGELOG.ko.md`에 `## <버전>` 섹션을 쓰고 `v<버전>` 태그를 push하면 `.github/workflows/release.yml`이 빌드 → 서명·공증 → GitHub 릴리스 → `appcast.xml` 갱신까지 합니다. 업데이트 피드는 `Scripts/Info.plist`의 `SUFeedURL`(`jhaemin/christmas-tree`의 main 브랜치 `appcast.xml`)입니다.

필요한 repo 시크릿: `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD`, `NOTARY_KEY_P8`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`, `SPARKLE_ED_PRIVATE_KEY`(Domus 공유 키 — `SUPublicEDKey`의 짝).

## 구조

```
Sources/ChristmasTree/
├── main.swift          진입점 (+ 개발용 렌더링 옵션)
├── AppDelegate.swift   메뉴 막대 아이콘, 메뉴, 상태 바인딩
├── UpdaterController.swift  Sparkle 자동 업데이트
├── Localization.swift  L("English") → 현지화 문자열
├── Resources/ko.lproj/Localizable.strings  한국어 번역 (영어 원문이 키)
├── TreePanel.swift     항상 위에 뜨는 투명 패널, 드래그/클릭 처리
├── AppState.swift      설정 상태 (UserDefaults 저장)
├── Scene.swift         눈 + 트리 합성, 디자인 전환 크로스페이드
├── DrawingKit.swift    색 보간, 난수 등 공용 도구
├── TreeEngine.swift    트리 생성/렌더링 엔진 (가지, 오너먼트, 리본, 별, 받침, 캐시)
├── TreeDesigns.swift   14가지 디자인 레시피
├── Songs.swift         캐럴 악보 (멜로디 + 코드)
├── MusicPlayer.swift   신시사이저 + AVAudioEngine 재생
└── DevTools.swift      미리보기/오디오 렌더링
Scripts/
├── bundle.sh           .app 번들 (리소스·Sparkle·아이콘·서명)
├── make-assets.swift   Icon Composer 아이콘 생성
├── Info.plist
├── appcast-add.sh, changelog-extract.sh  릴리스 워크플로용
```

UI 문자열은 모두 `L("English text")`로 감싸고, 한국어는 `Localizable.strings`에 추가합니다.

### 새 트리 디자인 추가하기

`TreeDesign`에 case 와 이름(`L("…")` + 한국어 번역)을 추가하고 `recipe`에서 조합을 정하면 됩니다.
잎 색(`Foliage`), 오너먼트 종류/개수, 리본, 비즈 가랜드, 전구 스타일, 별, 받침(스커트·바구니·황동·나무상자·양동이)을 골라 조합합니다.

### 새 곡 추가하기

`Songs.swift`에 `Song`을 추가하고 `all` 배열에 넣으면 됩니다. 멜로디는 `E4:1 F#4:0.5 R:2` 형식(음이름+옥타브:박), 코드는 화음 구간(`chordBeats`)마다 하나씩 적습니다.

### 개발용 명령

```bash
swift build
.build/debug/ChristmasTree --render-previews /tmp/previews   # 모든 디자인 PNG
.build/debug/ChristmasTree --render-audio /tmp/audio         # 모든 곡 WAV
```
