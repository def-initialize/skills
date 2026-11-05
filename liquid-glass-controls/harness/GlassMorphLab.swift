// GlassMorphLab: a glass pill whose buttons split, merge and widen, using SwiftUI's own glass morphs, over
// a bright and a dark backdrop with the ink set for each. Play splits into Pause + Stop; Pause merges them
// back; Stop widens Pause into "Sure?" (tap it to stop; it cancels after 3 s, on Esc or on a click elsewhere).
// Launch arguments: -slow N stretches every animation N times. Built and opened by run.sh.

import AppKit
import SwiftUI

let red = Color(red: 0xB2 / 255, green: 0x3F / 255, blue: 0x2E / 255)
let slow = max(1, UserDefaults.standard.double(forKey: "slow"))
let spring = Animation.spring(duration: 0.65 * slow, bounce: 0.35)

/// Esc, or a click away from the buttons: any open "Sure?" cancels. `asking` counts the pills showing one.
final class Cancel: ObservableObject {
    @Published var count = 0
    var asking = 0
}

@main
struct GlassMorphLab: App {
    @StateObject private var cancel = Cancel()
    var body: some Scene {
        WindowGroup("GlassMorphLab") {
            HStack(spacing: 12) {
                Column(dark: false)
                Column(dark: true)
            }
            .padding(12)
            .background(Color(white: 0.15))
            .environmentObject(cancel)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard event.keyCode == 53, cancel.asking > 0 else { return event } // Esc, only while asking
                    cancel.count += 1
                    return nil
                }
            }
        }
        .windowResizability(.contentSize)
    }
}

struct Column: View {
    let dark: Bool
    @EnvironmentObject private var cancel: Cancel
    var body: some View {
        VStack(spacing: 14) {
            Text(dark ? "dark backdrop: .dark scheme, white ink" : "bright backdrop: .light scheme, dark ink")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 6).background(.black.opacity(0.55), in: .capsule)
            Pill()
                .environment(\.colorScheme, dark ? .dark : .light) // custom glass follows this, not the backdrop
        }
        .padding(.top, 40)
        .frame(width: 380, height: 240, alignment: .top)
        .background(backdrop)
        .contentShape(.rect)
        .onTapGesture { cancel.count += 1 } // the buttons' own taps win; anything else counts as elsewhere
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: dark ? [Color(white: 0.06), Color(red: 0.08, green: 0.08, blue: 0.22)]
                                        : [Color(red: 0.93, green: 0.95, blue: 0.80), Color(red: 0.60, green: 0.80, blue: 0.50)],
                           startPoint: .top, endPoint: .bottom)
            ForEach(0..<7) { i in
                Circle()
                    .fill(dark ? Color.white.opacity(0.10) : Color.yellow.opacity(0.40))
                    .frame(width: CGFloat(30 + i * 10))
                    .offset(x: CGFloat((i * 83) % 300) - 150, y: CGFloat((i * 47) % 200) - 100)
            }
        }
    }
}

struct Pill: View {
    static let button: CGFloat = 40, gap: CGFloat = 4
    @EnvironmentObject private var cancel: Cancel
    @Namespace private var ns
    @State private var split = false
    @State private var confirming = false
    @State private var spacing: CGFloat = 0
    @State private var generation = 0

    var body: some View {
        HStack(spacing: 10) {
            Text(split ? "17:30" : "25:00").font(.system(size: 32, weight: .light)).monospacedDigit()
                .contentTransition(.numericText())
            // The buttons get their own container, inside the pill's glass, so only they blend.
            GlassEffectContainer(spacing: spacing) {
                HStack(spacing: Self.gap) { primary; if split && !confirming { stop } }
            }
        }
        .padding(.leading, 16).padding(.trailing, 6)
        .frame(height: 52)
        .glassEffect(.regular, in: .capsule)
        .onChange(of: cancel.count) { cancelAsking() }
        .onChange(of: confirming) { _, now in cancel.asking += now ? 1 : -1 }
    }

    // One view throughout: Play, Pause and "Sure?" are the same capsule, whose width changes.
    private var primary: some View {
        Button { tapPrimary() } label: {
            ZStack {
                Image(systemName: split ? "pause.fill" : "play.fill")
                    .foregroundStyle(split ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(confirming ? 0 : 1)
                    .animation(confirming ? fadeOut : fadeIn, value: confirming)
                Text("Sure?").foregroundStyle(.primary).fixedSize()
                    .opacity(confirming ? 1 : 0)
                    .animation(confirming ? fadeIn : fadeOut, value: confirming)
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(width: (confirming ? 2 * Self.button + Self.gap : Self.button) - 8, height: Self.button - 8)
            .clipShape(.capsule) // the fading "Sure?" stays inside the button as it narrows
            .contentShape(.capsule)
            .padding(.horizontal, -8) // .glass pads a capsule 12 pt at the sides, 4 pt top and bottom
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .tint(split ? nil : red.opacity(0.78))
        .glassEffectID("primary", in: ns)
    }

    private var stop: some View {
        Button { askToStop() } label: {
            Image(systemName: "stop.fill").font(.system(size: 13, weight: .semibold))
                .frame(width: Self.button - 8, height: Self.button - 8)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .glassEffectID("stop", in: ns)
    }

    private var fadeOut: Animation { .easeOut(duration: 0.12 * slow) }
    private var fadeIn: Animation { .easeIn(duration: 0.2 * slow).delay(0.22 * slow) }

    /// Runs `body` after `seconds` (times `slow`), unless another action came in between.
    private func after(_ seconds: Double, _ body: @escaping () -> Void) {
        let g = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds * slow) { if g == generation { body() } }
    }

    private func tapPrimary() {
        generation += 1
        if confirming {                      // "Sure?": stop. The capsule narrows back into Play.
            withAnimation(spring) { confirming = false; split = false }
        } else if !split {                   // Play: split, with a neck that shows and breaks
            spacing = 24
            withAnimation(spring) { split = true }
            after(0.12) { withAnimation(.easeIn(duration: 0.3 * slow)) { spacing = 0 } }
        } else {                             // Pause: merge, the neck reaching across first
            withAnimation(.easeOut(duration: 0.18 * slow)) { spacing = 24 }
            after(0.12) { withAnimation(spring) { split = false } }
            after(0.9) { spacing = 0 }
        }
    }

    /// Stop asks first: a neck reaches across, then Pause widens into "Sure?" and Stop melts in.
    private func askToStop() {
        generation += 1
        withAnimation(.easeOut(duration: 0.18 * slow)) { spacing = 24 }
        after(0.12) { withAnimation(spring) { confirming = true } }
        after(0.9) { spacing = 0 }
        after(0.12 + 3) { cancelAsking() }
    }

    /// Not confirmed: it splits back into Pause and Stop, with the same neck as the first split.
    private func cancelAsking() {
        guard confirming else { return }
        generation += 1
        spacing = 24
        withAnimation(spring) { confirming = false }
        after(0.12) { withAnimation(.easeIn(duration: 0.3 * slow)) { spacing = 0 } }
    }
}
