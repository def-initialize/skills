// HoverLab: which SwiftUI Liquid Glass button styles light up under the pointer on this Mac, and which
// keep their tint. Each numbered row is one variant, drawn over a light and a dark backdrop. Activate the
// window (tints show grey in an inactive one), then hover each row. Built and opened by run.sh.

import SwiftUI

let red = Color(red: 0xB2 / 255, green: 0x3F / 255, blue: 0x2E / 255)

@main
struct HoverLab: App {
    var body: some Scene {
        WindowGroup("HoverLab") {
            HStack(spacing: 12) {
                Column(dark: false)
                Column(dark: true)
            }
            .padding(12)
            .background(Color(white: 0.15))
        }
        .windowResizability(.contentSize)
    }
}

struct Column: View {
    let dark: Bool
    var body: some View {
        Rows()
            .padding(.vertical, 24)
            .frame(width: 380)
            .background(backdrop)
            .environment(\.colorScheme, dark ? .dark : .light)
    }

    /// Something for the glass to refract: soft colour blobs on a gradient.
    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: dark ? [Color(white: 0.08), Color(red: 0.1, green: 0.1, blue: 0.25)]
                                        : [Color(red: 0.85, green: 0.92, blue: 0.75), Color(red: 0.55, green: 0.75, blue: 0.45)],
                           startPoint: .top, endPoint: .bottom)
            ForEach(0..<9) { i in
                Circle()
                    .fill(dark ? Color.white.opacity(0.10) : Color.yellow.opacity(0.35))
                    .frame(width: CGFloat(30 + i * 9))
                    .offset(x: CGFloat((i * 73) % 300) - 150, y: CGFloat((i * 131) % 560) - 280)
            }
        }
    }
}

struct Rows: View {
    var body: some View {
        VStack(spacing: 20) {
            item("1 · label-only style on .interactive() glass: no hover") {
                Button {} label: { glyph("play.fill", white: true).frame(width: 40, height: 40).contentShape(.circle) }
                    .buttonStyle(LabelOnly()).glassEffect(.regular.tint(red.opacity(0.78)).interactive(), in: .circle)
                Button {} label: { glyph("pause.fill").frame(width: 40, height: 40).contentShape(.circle) }
                    .buttonStyle(LabelOnly()).glassEffect(.regular.interactive(), in: .circle)
            }
            // .glass pads the label by 4 pt, so a 32 pt label makes a 40 pt circle.
            item("2 · .glass + .tint(): hover, keeps the tint") {
                Button {} label: { glyph("play.fill", white: true).frame(width: 32, height: 32) }
                    .buttonStyle(.glass).tint(red.opacity(0.78))
                Button {} label: { glyph("pause.fill").frame(width: 32, height: 32) }.buttonStyle(.glass)
                Button {} label: { glyph("stop.fill").frame(width: 32, height: 32) }.buttonStyle(.glass)
            }
            .buttonBorderShape(.circle)
            item("3 · GlassButtonStyle(.regular.tint()): drops the tint") {
                if #available(macOS 26.1, *) {
                    Button {} label: { glyph("play.fill", white: true).frame(width: 32, height: 32) }
                        .buttonStyle(GlassButtonStyle(.regular.tint(red.opacity(0.78))))
                        .buttonBorderShape(.circle)
                } else {
                    Text("needs macOS 26.1").font(.caption).foregroundStyle(.secondary)
                }
            }
            item("4 · .glassProminent + .tint(): barely lights up") {
                Button {} label: { glyph("play.fill", white: true).frame(width: 32, height: 32) }
                    .buttonStyle(.glassProminent).tint(red)
            }
            .buttonBorderShape(.circle)
            item("5 · .glass as a capsule: 12 pt at the sides") {
                Button {} label: { Text("Sure?").font(.system(size: 15, weight: .semibold)).frame(width: 60, height: 32) }
                    .buttonStyle(.glass).buttonBorderShape(.capsule).tint(red.opacity(0.78))
            }
            item("6 · one capsule, .plain: no hover") { capsule(.plain, side: 44) }
            item("7 · one capsule, .accessoryBar: to the edge") { capsule(.accessoryBar, side: 44) }
            item("8 · .accessoryBar circles, inset 4 pt: Safari-style") {
                HStack(spacing: 8) {
                    Button {} label: { glyph("hand.thumbsup", size: 16).frame(width: 28, height: 28).contentShape(.circle) }
                    Button {} label: { glyph("slider.horizontal.3", size: 16).frame(width: 28, height: 28).contentShape(.circle) }
                }
                .buttonStyle(.accessoryBar)
                .buttonBorderShape(.circle)
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
    }

    private func item(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 6).background(.black.opacity(0.55), in: .capsule)
            HStack(spacing: 12) { content() }
        }
    }

    private func glyph(_ name: String, size: CGFloat = 15, white: Bool = false) -> some View {
        Image(systemName: name).font(.system(size: size, weight: .semibold))
            .foregroundStyle(white ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
    }

    /// Two glyphs on one interactive glass capsule, each button `side` pt square.
    private func capsule(_ style: some PrimitiveButtonStyle, side: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button {} label: { glyph("hand.thumbsup", size: 16).frame(width: side, height: side).contentShape(.rect) }
            Button {} label: { glyph("slider.horizontal.3", size: 16).frame(width: side, height: side).contentShape(.rect) }
        }
        .buttonStyle(style)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// A button that draws only its label.
struct LabelOnly: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}
