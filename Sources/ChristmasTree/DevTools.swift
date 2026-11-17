import AVFoundation
import AppKit
import SwiftUI

/// 빌드 스크립트와 개발 중 확인용 렌더링 도구
enum DevTools {
    @MainActor
    static func renderPreviews(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (bgName, bg) in [("dark", Color(hex: 0x23262E)), ("light", Color(hex: 0xECEFF3))] {
            let sheet = VStack(spacing: 6) {
                ForEach(0..<4) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<4) { col in
                            let d = TreeDesign(rawValue: min(TreeDesign.allCases.count - 1, row * 4 + col))!
                            VStack(spacing: 2) {
                                DesignStill(design: d, size: CGSize(width: 180, height: 225), scale: 2, t: 2.0)
                                Text(d.name).font(.system(size: 11)).foregroundStyle(bgName == "dark" ? .white : .black)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(bg)
            save(view: sheet, scale: 2, to: "\(dir)/sheet-\(bgName).png")
        }
        for d in TreeDesign.allCases {
            save(view: DesignStill(design: d, size: CGSize(width: 360, height: 450), scale: 2, t: 2.0)
                    .background(Color(hex: 0x23262E)),
                 scale: 2, to: "\(dir)/\(d.rawValue)-\(d).png")
        }
    }

    @MainActor
    private static func save<V: View>(view: V, scale: CGFloat, to path: String) {
        let r = ImageRenderer(content: view)
        r.scale = scale
        guard let cg = r.cgImage else { print("render failed: \(path)"); return }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }

    static func renderAudio(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (i, song) in Songs.all.enumerated() {
            let start = Date()
            guard let buf = Synth.render(song) else { continue }
            let url = URL(fileURLWithPath: "\(dir)/\(i)-\(song.title.replacingOccurrences(of: " ", with: "_")).wav")
            do {
                let file = try AVAudioFile(forWriting: url, settings: buf.format.settings)
                try file.write(from: buf)
                print(String(format: "wrote %@ (%.1fs audio, rendered in %.2fs)", url.lastPathComponent,
                             Double(buf.frameLength) / buf.format.sampleRate, Date().timeIntervalSince(start)))
            } catch { print("audio write failed: \(error)") }
        }
    }
}
