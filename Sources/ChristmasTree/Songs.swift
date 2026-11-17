import Foundation

/// 퍼블릭 도메인 캐럴들. 모두 C장조로 적고 `transpose`로 옥타브를 올린다.
/// 표기: "음이름+옥타브:박" (예: E4:1, F#4:0.5, R:2 는 쉼표). "|" 는 마디 구분용(무시됨).
struct Song {
    enum Style { case oompah, pad }

    let title: String
    let bpm: Double
    let beatsPerBar: Double
    let pickup: Double
    let chordBeats: Double
    let transpose: Int
    let style: Style
    let jingle: Bool
    let melody: String
    /// 화음 구간마다 하나씩. nil 이면 멜로디로부터 자동 반주
    let chords: String?
}

enum Songs {
    static let all: [Song] = [jingleBells, weWishYou, deckTheHalls, silentNight, joyToTheWorld]

    static let jingleBells = Song(
        title: "Jingle Bells", bpm: 138, beatsPerBar: 4, pickup: 0, chordBeats: 2, transpose: 12,
        style: .oompah, jingle: true,
        melody: """
        G3:1 E4:1 D4:1 C4:1 | G3:3 G3:0.5 G3:0.5 | G3:1 E4:1 D4:1 C4:1 | A3:4 |
        A3:1 F4:1 E4:1 D4:1 | B3:4 | G4:1 G4:1 F4:1 D4:1 | E4:4 |
        G3:1 E4:1 D4:1 C4:1 | G3:4 | G3:1 E4:1 D4:1 C4:1 | A3:3 A3:1 |
        A3:1 F4:1 E4:1 D4:1 | G4:1 G4:1 G4:1 G4:1 | A4:1 G4:1 F4:1 D4:1 | C4:2 R:2 |
        E4:1 E4:1 E4:2 | E4:1 E4:1 E4:2 | E4:1 G4:1 C4:1.5 D4:0.5 | E4:4 |
        F4:1 F4:1 F4:1.5 F4:0.5 | F4:1 E4:1 E4:1 E4:0.5 E4:0.5 | E4:1 D4:1 D4:1 E4:1 | D4:2 G4:2 |
        E4:1 E4:1 E4:2 | E4:1 E4:1 E4:2 | E4:1 G4:1 C4:1.5 D4:0.5 | E4:4 |
        F4:1 F4:1 F4:1.5 F4:0.5 | F4:1 E4:1 E4:1 E4:0.5 E4:0.5 | G4:1 G4:1 F4:1 D4:1 | C4:4
        """,
        chords: """
        C C C C C C F F | Dm Dm G G G G C C | C C C C C C F F | Dm Dm G G G G C C |
        C C C C C C C C | F F C C D7 D7 G G | C C C C C C C C | F F C C G G C C
        """)

    static let weWishYou = Song(
        title: "We Wish You a Merry Christmas", bpm: 168, beatsPerBar: 3, pickup: 1, chordBeats: 3, transpose: 12,
        style: .oompah, jingle: false,
        melody: """
        G3:1 |
        C4:1 C4:0.5 D4:0.5 C4:0.5 B3:0.5 | A3:1 A3:1 A3:1 | D4:1 D4:0.5 E4:0.5 D4:0.5 C4:0.5 | B3:1 G3:1 G3:1 |
        E4:1 E4:0.5 F4:0.5 E4:0.5 D4:0.5 | C4:1 A3:1 G3:0.5 G3:0.5 | A3:1 D4:1 B3:1 | C4:2 G3:1 |
        C4:1 C4:1 C4:1 | B3:2 B3:1 | C4:1 B3:1 A3:1 | G3:2 D4:1 |
        E4:1 D4:1 C4:1 | G4:1 G3:1 G3:0.5 G3:0.5 | A3:1 D4:1 B3:1 | C4:3
        """,
        chords: "C F D7 G E7 Am G7 C | C G Am G C C G7 C")

    static let deckTheHalls = Song(
        title: "Deck the Halls", bpm: 126, beatsPerBar: 4, pickup: 0, chordBeats: 2, transpose: 12,
        style: .oompah, jingle: false,
        melody: """
        G4:1.5 F4:0.5 E4:1 D4:1 | C4:1 D4:1 E4:1 C4:1 | D4:0.5 E4:0.5 F4:0.5 D4:0.5 E4:1.5 D4:0.5 | C4:1 B3:1 C4:2 |
        G4:1.5 F4:0.5 E4:1 D4:1 | C4:1 D4:1 E4:1 C4:1 | D4:0.5 E4:0.5 F4:0.5 D4:0.5 E4:1.5 D4:0.5 | C4:1 B3:1 C4:2 |
        D4:1.5 E4:0.5 F4:1 D4:1 | E4:1.5 F4:0.5 G4:1 D4:1 | E4:0.5 F4:0.5 G4:1 A4:0.5 B4:0.5 C5:1 | B4:1 A4:1 G4:2 |
        G4:1.5 F4:0.5 E4:1 D4:1 | C4:1 D4:1 E4:1 C4:1 | A4:0.5 A4:0.5 A4:0.5 A4:0.5 G4:1.5 F4:0.5 | E4:1 D4:1 C4:2
        """,
        chords: """
        C C C C G C G C | C C C C G C G C |
        G G C G C F G G | C C C C F C G C
        """)

    static let silentNight = Song(
        title: "Silent Night", bpm: 96, beatsPerBar: 3, pickup: 0, chordBeats: 3, transpose: 12,
        style: .pad, jingle: false,
        melody: """
        G4:1.5 A4:0.5 G4:1 | E4:3 | G4:1.5 A4:0.5 G4:1 | E4:3 |
        D5:2 D5:1 | B4:3 | C5:2 C5:1 | G4:3 |
        A4:2 A4:1 | C5:1.5 B4:0.5 A4:1 | G4:1.5 A4:0.5 G4:1 | E4:3 |
        A4:2 A4:1 | C5:1.5 B4:0.5 A4:1 | G4:1.5 A4:0.5 G4:1 | E4:3 |
        D5:2 D5:1 | F5:1.5 D5:0.5 B4:1 | C5:3 | E5:3 |
        C5:1 G4:1 E4:1 | G4:1.5 F4:0.5 D4:1 | C4:3 | R:3
        """,
        chords: "C C C C G G C C F F C C F F C C G G7 C C C G7 C C")

    static let joyToTheWorld = Song(
        title: "Joy to the World", bpm: 108, beatsPerBar: 2, pickup: 0, chordBeats: 2, transpose: 12,
        style: .oompah, jingle: false,
        melody: """
        C5:1 B4:0.75 A4:0.25 | G4:1.5 F4:0.5 | E4:1 D4:1 | C4:1.5 G4:0.5 |
        A4:1.5 A4:0.5 | B4:1.5 B4:0.5 | C5:1.5 C5:0.5 |
        C5:0.5 B4:0.5 A4:0.5 G4:0.5 | G4:0.75 F4:0.25 E4:0.5 C5:0.5 |
        C5:0.5 B4:0.5 A4:0.5 G4:0.5 | G4:0.75 F4:0.25 E4:0.5 E4:0.5 |
        E4:0.5 E4:0.5 E4:0.5 E4:0.25 F4:0.25 | G4:1.5 F4:0.25 E4:0.25 |
        D4:0.5 D4:0.5 D4:0.5 D4:0.25 E4:0.25 | F4:1.5 E4:0.25 D4:0.25 |
        C4:0.5 C5:1 A4:0.5 | G4:0.75 F4:0.25 E4:0.5 F4:0.5 | E4:1 D4:1 | C4:2
        """,
        chords: "C G7 C C F G7 C C C C C C C G7 G7 F C G7 C")
}
