import AVFoundation

/// 노트 데이터를 오르골 느낌의 소리로 직접 합성한다 (오디오 파일 없음).
enum Synth {
    struct Voice {
        var partials: [(ratio: Float, amp: Float, decay: Float)]
        var attack: Float
        var tau: Float
        var release: Float
        var gain: Float
    }

    static let musicBox = Voice(partials: [(1, 1, 0), (2, 0.32, 3), (3, 0.1, 7), (4.16, 0.07, 10)],
                                attack: 0.003, tau: 0.6, release: 0.12, gain: 0.32)
    static let celesta = Voice(partials: [(1, 1, 0), (2, 0.25, 2), (3, 0.07, 5), (4.16, 0.04, 8)],
                               attack: 0.004, tau: 1.3, release: 0.25, gain: 0.3)
    static let bass = Voice(partials: [(1, 1, 0), (2, 0.25, 2)], attack: 0.008, tau: 1.0, release: 0.08, gain: 0.2)
    static let pluck = Voice(partials: [(1, 1, 0), (2, 0.2, 4)], attack: 0.005, tau: 0.3, release: 0.06, gain: 0.065)
    static let pad = Voice(partials: [(1, 1, 0), (2, 0.12, 0), (3, 0.04, 0)], attack: 0.25, tau: 5, release: 0.35, gain: 0.05)

    static let chordTable: [String: (root: Int, tones: [Int])] = [
        "C": (0, [0, 4, 7]), "F": (5, [5, 9, 0]), "G": (7, [7, 11, 2]), "G7": (7, [7, 11, 2, 5]),
        "Am": (9, [9, 0, 4]), "Dm": (2, [2, 5, 9]), "Em": (4, [4, 7, 11]),
        "D7": (2, [2, 6, 9, 0]), "E7": (4, [4, 8, 11, 2]),
    ]

    struct Note { var start: Double; var beats: Double; var midi: Int? }

    static func parse(_ text: String) -> [Note] {
        var notes: [Note] = []
        var beat = 0.0
        for token in text.split(whereSeparator: { $0.isWhitespace || $0 == "|" }) {
            let parts = token.split(separator: ":")
            guard parts.count == 2, let len = Double(parts[1]) else { continue }
            notes.append(Note(start: beat, beats: len, midi: midi(String(parts[0]))))
            beat += len
        }
        return notes
    }

    static func midi(_ name: String) -> Int? {
        guard name != "R", let letter = name.first else { return nil }
        let base: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard var pc = base[letter] else { return nil }
        var rest = name.dropFirst()
        if rest.first == "#" { pc += 1; rest = rest.dropFirst() } else if rest.first == "b" { pc -= 1; rest = rest.dropFirst() }
        guard let octave = Int(rest) else { return nil }
        return 12 * (octave + 1) + pc
    }

    static func frequency(_ midi: Int) -> Float { 440 * powf(2, Float(midi - 69) / 12) }

    static func addTone(_ buf: inout [Float], sr: Float, start: Double, dur: Double, midi: Int, voice v: Voice, amp: Float = 1) {
        let f = frequency(midi)
        let total = Float(dur) + v.release
        let s0 = Int(start * Double(sr))
        let n = min(Int(total * sr), buf.count - s0)
        guard n > 0, s0 >= 0 else { return }
        let w = 2 * Float.pi * f / sr
        let d = Float(dur)
        let partials = v.partials.filter { $0.ratio * f < sr * 0.45 }
        for i in 0..<n {
            let t = Float(i) / sr
            var env = (t < v.attack ? t / v.attack : 1) * expf(-t / v.tau)
            if t > d { env *= max(0, 1 - (t - d) / v.release) }
            if env < 1e-5 { continue }
            var s: Float = 0
            for p in partials {
                s += p.amp * (p.decay > 0 ? expf(-t * p.decay) : 1) * sinf(w * p.ratio * Float(i))
            }
            buf[s0 + i] += s * env * v.gain * amp
        }
    }

    /// 썰매 방울 — 높은 대역의 짧은 노이즈
    static func addJingle(_ buf: inout [Float], sr: Float, start: Double, amp: Float, rng: inout SplitMix) {
        let s0 = Int(start * Double(sr))
        let n = min(Int(0.12 * sr), buf.count - s0)
        guard n > 0 else { return }
        var prev: Float = 0
        for i in 0..<n {
            let t = Float(i) / sr
            let x = Float(rng.next() * 2 - 1)
            let hp = x - prev
            prev = x
            let ring = 0.5 + 0.5 * sinf(2 * Float.pi * 5200 * t)
            buf[s0 + i] += hp * ring * expf(-t / 0.035) * amp
        }
    }

    static func render(_ song: Song, sampleRate sr: Double = 44100) -> AVAudioPCMBuffer? {
        let srf = Float(sr)
        let spb = 60 / song.bpm
        let melody = parse(song.melody)
        let totalBeats = melody.last.map { $0.start + $0.beats } ?? 0
        let tail = 2.2
        let frames = Int((totalBeats * spb + tail) * sr)
        var buf = [Float](repeating: 0, count: frames)

        let melodyVoice = song.style == .pad ? celesta : musicBox
        for note in melody {
            guard let m = note.midi else { continue }
            addTone(&buf, sr: srf, start: note.start * spb, dur: note.beats * spb, midi: m + song.transpose, voice: melodyVoice)
        }

        // 반주
        let names = (song.chords ?? "").split(whereSeparator: { $0.isWhitespace || $0 == "|" }).map(String.init)
        var segStart = song.pickup
        var idx = 0
        var prevRoot: Int?
        while segStart < totalBeats - 0.001 {
            let name = idx < names.count ? names[idx] : (names.last ?? "C")
            let chord = chordTable[name] ?? chordTable["C"]!
            let isLast = segStart + song.chordBeats >= totalBeats - 0.001
            var bassMidi = 48 + chord.root
            if bassMidi > 54 { bassMidi -= 12 }
            // 같은 화음이 이어지면 5음으로 베이스를 바꿔 단조로움을 줄인다
            if prevRoot == chord.root && !isLast && song.style == .oompah {
                bassMidi = 48 + (chord.root + 7) % 12
                if bassMidi > 54 { bassMidi -= 12 }
                prevRoot = nil
            } else {
                prevRoot = chord.root
            }
            let chordMidis = chord.tones.map { pc -> Int in
                var m = 60 + pc
                if m > 67 { m -= 12 }
                return m
            }
            let t0 = segStart * spb
            if song.style == .pad || isLast {
                let dur = (isLast ? song.chordBeats + 1 : song.chordBeats) * spb
                addTone(&buf, sr: srf, start: t0, dur: dur, midi: bassMidi, voice: bass)
                for m in chordMidis { addTone(&buf, sr: srf, start: t0, dur: dur, midi: m, voice: pad, amp: isLast ? 1.6 : 1) }
            } else {
                addTone(&buf, sr: srf, start: t0, dur: spb * 0.95, midi: bassMidi, voice: bass)
                var b = 1.0
                while b < song.chordBeats - 0.001 {
                    for m in chordMidis {
                        addTone(&buf, sr: srf, start: t0 + b * spb, dur: spb * 0.6, midi: m, voice: pluck)
                    }
                    b += 1
                }
            }
            segStart += song.chordBeats
            idx += 1
        }

        if song.jingle {
            var rng = SplitMix(state: 7)
            var b = 0.0
            while b < totalBeats - 1 {
                addJingle(&buf, sr: srf, start: b * spb, amp: b.truncatingRemainder(dividingBy: 2) == 1 ? 0.05 : 0.025, rng: &rng)
                b += 1
            }
        }

        // 정규화 + 끝부분 페이드아웃
        let peak = buf.reduce(0) { max($0, abs($1)) }
        let norm: Float = peak > 0 ? 0.72 / peak : 1
        let fadeN = Int(0.6 * sr)
        for i in 0..<frames {
            var g = norm
            let fromEnd = frames - i
            if fromEnd < fadeN { g *= Float(fromEnd) / Float(fadeN) }
            buf[i] *= g
        }

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2),
              let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let ch = pcm.floatChannelData else { return nil }
        pcm.frameLength = AVAudioFrameCount(frames)
        buf.withUnsafeBufferPointer { src in
            ch[0].update(from: src.baseAddress!, count: frames)
            ch[1].update(from: src.baseAddress!, count: frames)
        }
        return pcm
    }
}

/// AVAudioEngine 기반 재생기. 곡은 처음 재생할 때 백그라운드에서 합성해 캐시한다.
final class MusicPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private let sampleRate = 44100.0
    private var configured = false
    private var cache: [Int: AVAudioPCMBuffer] = [:]
    private var generation = 0
    private var queue: [Int] = []
    private var queuePos = 0
    private var selection = -1
    private var fadeTimer: Timer?
    private(set) var isPlaying = false
    private(set) var currentSong: Int?
    var onSongChange: (() -> Void)?

    var volume: Float = 0.55 {
        didSet { if isPlaying && fadeTimer == nil { engine.mainMixerNode.outputVolume = volume } }
    }

    init() {
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                                               queue: .main) { [weak self] _ in
            // 출력 장치가 바뀌면(이어폰 연결 등) 엔진이 멈추므로 다시 시작
            guard let self, self.isPlaying else { return }
            self.play(selection: self.selection)
        }
    }

    private func configure() {
        guard !configured else { return }
        configured = true
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        engine.attach(player)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 24
        engine.connect(player, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }

    func play(selection: Int) {
        configure()
        self.selection = selection
        generation += 1
        let gen = generation
        fadeTimer?.invalidate()
        fadeTimer = nil
        player.stop()
        engine.mainMixerNode.outputVolume = 0
        if !engine.isRunning {
            do { try engine.start() } catch {
                NSLog("ChristmasTree: audio engine start failed: \(error)")
                return
            }
        }
        if selection >= 0 && selection < Songs.all.count {
            queue = [selection]
        } else {
            queue = Array(Songs.all.indices)
        }
        queuePos = 0
        isPlaying = true
        scheduleNext(gen, first: true)
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        generation += 1
        currentSong = nil
        onSongChange?()
        fade(to: 0, duration: 0.5) { [weak self] in
            guard let self, !self.isPlaying else { return }
            self.player.stop()
            self.engine.pause()
        }
    }

    private func scheduleNext(_ gen: Int, first: Bool = false) {
        guard gen == generation, !queue.isEmpty else { return }
        let idx = queue[queuePos % queue.count]
        queuePos += 1
        withBuffer(idx) { [weak self] buffer in
            guard let self, gen == self.generation, let buffer else { return }
            self.currentSong = idx
            self.onSongChange?()
            self.player.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.async { self?.scheduleNext(gen) }
            }
            if first || !self.player.isPlaying {
                self.player.play()
                self.fade(to: self.volume, duration: 0.8)
            }
        }
    }

    private func withBuffer(_ idx: Int, _ done: @escaping (AVAudioPCMBuffer?) -> Void) {
        if let b = cache[idx] { done(b); return }
        let song = Songs.all[idx]
        let sr = sampleRate
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let b = Synth.render(song, sampleRate: sr)
            DispatchQueue.main.async {
                self?.cache[idx] = b
                done(b)
            }
        }
    }

    private func fade(to target: Float, duration: Double, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        let mixer = engine.mainMixerNode
        let from = mixer.outputVolume
        let steps = 24
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { [weak self] timer in
            step += 1
            let p = Float(step) / Float(steps)
            mixer.outputVolume = from + (target - from) * p
            if step >= steps {
                timer.invalidate()
                self?.fadeTimer = nil
                if let self, self.isPlaying, target > 0 { mixer.outputVolume = self.volume }
                completion?()
            }
        }
    }
}
