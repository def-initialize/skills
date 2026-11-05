---
name: liquid-glass-controls
description: Build custom SwiftUI Liquid Glass controls on macOS 26+ with glassEffect, GlassEffectContainer and glassEffectID, such as a glass pill holding a clock and buttons where Play splits into Pause and Stop, buttons melt back together, or a button widens into a "Sure?" confirmation, using SwiftUI's own glass morphs. Covers choosing legible dark or light glass over any background (custom glass doesn't adapt by itself), glass inside glass, morphs that clip or skip, inactive-window tints, snapshots that lose the glass, and testing the motion. Use when designing or debugging custom glass shapes, morphs or glass legibility in a SwiftUI app. Not for system toolbars, tab bars or sidebars; for hover highlights on glass buttons use the macos-glass-hover skill. The same APIs exist on iOS 26, but this was only tested on the Mac.
---

# Custom Liquid Glass controls (SwiftUI)

What this covers: controls you build yourself out of SwiftUI's glass pieces, not system bars, toolbars
or sidebars. Everything here uses SwiftUI's own glass and its own morph; nothing draws a fake blob or
metaball.

- `.glassEffect(_:in:)` puts glass behind a view, in a shape.
- `GlassEffectContainer(spacing:)` lets the glass shapes inside it blend and morph into each other.
  While two shapes blend, a **neck** of glass joins them.
- `.glassEffectID(_:in:)` gives a shape an identity, so it morphs when it appears, moves or goes.
- `.buttonStyle(.glass)` for the buttons themselves; it's also what makes them light up under the
  pointer (see the macos-glass-hover skill for its padding, sizes and tints).

Verified on macOS 27 with Xcode 27.1, in a one-file lab app, with each round checked by a person,
October–November 2026. On another OS version, run the harness (below) first.

The snippets share these names, as in `harness/GlassMorphLab.swift`:

```swift
let red = Color(red: 0xB2 / 255, green: 0x3F / 255, blue: 0x2E / 255)
let slow = max(1, UserDefaults.standard.double(forKey: "slow"))   // -slow N stretches every animation
let spring = Animation.spring(duration: 0.65 * slow, bounce: 0.35)
let button: CGFloat = 40, gap: CGFloat = 4                       // button size, and the gap between buttons

@Namespace private var ns
@State private var split = false        // Stop is out beside Play/Pause
@State private var confirming = false   // "Sure?" is showing
@State private var spacing: CGFloat = 0 // the buttons' container spacing
@State private var generation = 0       // bumped by every action

/// Runs `body` after `seconds` (times `slow`), unless another action came in between.
private func after(_ seconds: Double, _ body: @escaping () -> Void) {
    let g = generation
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds * slow) { if g == generation { body() } }
}
```

## 1. Legible glass: set the colour scheme yourself

Custom glass **doesn't** pick light or dark from what's behind it. It follows the view's
`colorScheme`: with no override, every pill goes light in light mode and dark in dark mode, whatever
the background. Only system bars flip with the content.

So measure the background behind the control and set the scheme on the control:

```swift
@State private var ink: ColorScheme = .dark

pill
    .environment(\.colorScheme, ink)   // the glass, its tint and .primary / .secondary text follow it

// When the background changes (a new image, a new scene; not every frame):
ink = meanLuma > 0.5 ? .light : .dark  // bright: light glass, dark text; dark: dark glass, white text
```

- **What to measure:** the mean luma of the region the control covers at its widest:
  0.2126 R + 0.7152 G + 0.0722 B on the gamma-encoded sRGB values, from 0 to 1. Measure once each
  time the background changes. For an image, crop that region and average it. For Metal content,
  blit that region of one drawn frame into a buffer and average it on the CPU.
- A background whose luma hovers around 0.5 can flip the ink back and forth. If yours changes
  continuously, add some hysteresis (switch at 0.55 going up and 0.45 going down).
- Use `.primary` and `.secondary` for text and glyphs on the glass, so they follow the scheme.
- Real dark glass darkens a bright background enough for white text to stay legible, more than a
  flat translucent white fill in a design mock-up would suggest.
- The Mac's Appearance may be on Auto and switch from light to dark mid-test.
  `defaults read -g AppleInterfaceStyleSwitchesAutomatically` prints 1 when it's on Auto. Check it
  before comparing screenshots taken at different times.

## 2. Glass inside glass

A pill whose own glass holds glass buttons: give the buttons **their own** `GlassEffectContainer`,
inside the pill's `.glassEffect`. If one container holds both the pill's glass and the buttons, the
buttons don't morph into each other (a new button only fades in), and a neck can reach out to the
rest of the pill.

```swift
HStack(spacing: 10) {
    Text(clock).font(.system(size: 32, weight: .light)).monospacedDigit()
    GlassEffectContainer(spacing: spacing) {           // only the buttons blend
        HStack(spacing: gap) { primaryButton; if split && !confirming { stopButton } }
    }
}
.padding(.leading, 16).padding(.trailing, 6)
.frame(height: 52)
.glassEffect(.regular, in: .capsule)
```

`primaryButton` and `stopButton` are in section 4.

## 3. Split and merge that show, then rest apart

A shape added to or removed from a container morphs out of or into its neighbour only if its nearest
edge is within the container's `spacing`:

- **spacing ≥ the gap** between the buttons: they're joined by a neck. Above the gap they stay joined
  for good; at exactly the gap they part at rest, but the neck lasts only an instant while splitting.
- **spacing < the gap:** the new shape doesn't morph; it appears with Apple's default `.materialize`
  transition (see `glassEffectTransition`).
- To keep shapes joined at rest on purpose, Apple's tool is `glassEffectUnion(id:namespace:)`.

The container's spacing animates. So the approved split opens it wide (24 pt, against a 4 pt gap) for
the moment of the split, then closes it to 0, below the gap: the neck shows, thins and breaks, and
the buttons rest apart.

```swift
func startSplit() {                 // Play becomes Pause + Stop
    generation += 1
    spacing = 24                    // no animation: wide open
    withAnimation(spring) { split = true }
    after(0.12) { withAnimation(.easeIn(duration: 0.3 * slow)) { spacing = 0 } }   // the neck breaks
}

func merge() {                      // Stop flows back into Play
    generation += 1
    withAnimation(.easeOut(duration: 0.18 * slow)) { spacing = 24 }   // a neck reaches across first
    after(0.12) { withAnimation(spring) { split = false } }
    after(0.9) { spacing = 0 }
}
```

- The generation check in `after` matters: without it, a quick double tap runs an old step late and
  can leave the spacing open.
- The `if` around the second button is what inserts and removes its shape. Keep the first button the
  same view throughout.

## 4. A button that widens into a confirmation

Example: Stop asks first. Pause widens into one "Sure?" capsule as wide as both buttons, and Stop
melts into it. Tapping "Sure?" stops.

- **Keep one view and change its frame width.** Give it a capsule shape (a capsule is a circle while
  it's square). The alternative, swapping in a second view with the same `glassEffectID`, failed two
  ways: shrinking back, the container took its narrower frame at once and clipped the glass and its
  content; and with the two views, a state change made without animation in the same update made the
  glass skip the morph entirely. (`startSplit()`'s un-animated `spacing = 24` is fine: it's a single
  view and a different property.)
- **Clip the content to the capsule** (`.clipShape(.capsule)` on the label), so the fading text never
  pokes out while the button narrows.
- **Take turns, never cross-fade:** the glyph leaving fades out in 0.12 s. The one arriving waits
  0.22 s, until the shape has mostly turned, then fades in over 0.2 s. Same on the way back.
- Stop's `if` becomes `if split && !confirming`, so Stop melts in while asking.

```swift
private var fadeOut: Animation { .easeOut(duration: 0.12 * slow) }
private var fadeIn: Animation { .easeIn(duration: 0.2 * slow).delay(0.22 * slow) }

private var primaryButton: some View {
    Button(action: tapPrimary) {
        ZStack {
            Image(systemName: split ? "pause.fill" : "play.fill")
                .foregroundStyle(split ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                .opacity(confirming ? 0 : 1)
                .animation(confirming ? fadeOut : fadeIn, value: confirming)
            Text("Sure?").foregroundStyle(.primary).fixedSize()
                .opacity(confirming ? 1 : 0)
                .animation(confirming ? fadeIn : fadeOut, value: confirming)
        }
        .font(.system(size: 15, weight: .semibold))
        .frame(width: (confirming ? 2 * button + gap : button) - 8, height: button - 8)
        .clipShape(.capsule)
        .contentShape(.capsule)
        .padding(.horizontal, -8)    // .glass pads a capsule 12 pt at the sides, 4 pt top and bottom
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.capsule)
    .tint(split ? nil : red.opacity(0.78))    // red only while ready; "Sure?" is plain glass
    .glassEffectID("primary", in: ns)
}

private var stopButton: some View {
    Button(action: askToStop) {
        Image(systemName: "stop.fill").font(.system(size: 13, weight: .semibold))
            .frame(width: button - 8, height: button - 8)
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.circle)
    .glassEffectID("stop", in: ns)
}

func tapPrimary() {
    if confirming { generation += 1; withAnimation(spring) { confirming = false; split = false } }  // stop
    else if split { merge() } else { startSplit() }
}

func askToStop() {                  // a neck reaches across, then Pause widens and Stop melts in
    generation += 1
    withAnimation(.easeOut(duration: 0.18 * slow)) { spacing = 24 }
    after(0.12) { withAnimation(spring) { confirming = true } }
    after(0.9) { spacing = 0 }
    after(0.12 + 3) { cancelAsking() }    // no answer in 3 s
}

func cancelAsking() {               // like a split: Stop comes back out with a neck
    guard confirming else { return }
    generation += 1
    spacing = 24
    withAnimation(spring) { confirming = false }
    after(0.12) { withAnimation(.easeIn(duration: 0.3 * slow)) { spacing = 0 } }
}
```

**Cancelling without answering:** 3 s with no answer, Esc, or a click anywhere away from the buttons.

- For the click, the simplest is a tap gesture on the background behind the controls
  (`.contentShape(.rect).onTapGesture { cancelAsking() }`): the buttons' own taps win over it.
- A local `NSEvent` monitor for left-mouse-down sees every click, including the one on "Sure?", so
  it needs a hit test against the buttons' frame (for example from `onGeometryChange`), or it cancels
  the confirmation it should confirm.
- For Esc, a local key-down monitor that returns `nil` (consumes it) only while asking and returns
  the event otherwise.
- If the app uses the Space bar as a start/pause shortcut, don't let it confirm: drop the shortcut
  while asking.

## 5. Shape changes that animate

To move a shape between two looks, drive one view from computed properties; an `if/else` between two
views swaps them instead of animating.

## 6. Tints in an inactive window

A tinted glass control shows its tint grey while its window isn't the active one, like every
prominent macOS control. An override of the control's active state was tried and didn't change it
(which API wasn't recorded). Keeping the colour would mean painting it behind the glass instead of
tinting the glass, so keep the system behaviour. Screenshots of a background window show the grey too.

## 7. Snapshots lose the glass

`ImageRenderer` draws no Liquid Glass: the glass **and everything on it** come out empty. That
includes `.buttonStyle(.glass)` buttons. For exports, tests or layout checks, route all glass through
modifiers that draw a flat stand-in when an environment flag is set:

```swift
extension EnvironmentValues { @Entry var flatGlass = false }

struct AppGlass<S: Shape>: ViewModifier {          // shapes with .glassEffect
    let shape: S
    @Environment(\.flatGlass) private var flat
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        if flat {
            content
                .background(shape.fill(scheme == .light ? Color.white.opacity(0.6) : Color.black.opacity(0.35)))
                .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 0.5))
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}

struct LabelOnly: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label } }

struct AppGlassButton: ViewModifier {              // buttons: .glass live, a padded label on the stand-in when flat
    let capsule: Bool
    let tint: Color?
    @Environment(\.flatGlass) private var flat
    func body(content: Content) -> some View {
        if flat {
            content.buttonStyle(LabelOnly())
                .padding(.horizontal, capsule ? 12 : 4).padding(.vertical, 4)   // the same padding as .glass
                .modifier(AppGlass(shape: capsule ? AnyShape(Capsule()) : AnyShape(Circle())))
        } else {
            content.buttonStyle(.glass).buttonBorderShape(capsule ? .capsule : .circle).tint(tint)
        }
    }
}
// ImageRenderer(content: view.environment(\.flatGlass, true))
```

The stand-in ignores the tint; add a fill for it if snapshots need the colour. Real-glass stills need
the live window.

## 8. Scaling with the window

Lay the controls out once at the design width and scale them as a whole, then give the outer frame
the scaled size, because `scaleEffect` doesn't change the layout size:

```swift
let k = windowWidth / 360
controls
    .frame(width: 360)
    .scaleEffect(k, anchor: .top)
    .frame(width: windowWidth)     // otherwise the layout keeps 360 pt
```

The glass, the morphs, the spacing and the button styles' padding all scale with it. Only sizes
multiplied by `k` by hand need the styles' fixed padding taken out (see macos-glass-hover).

## Testing and filming the motion

- Prototype in a **one-file lab app** before touching the real app: the controls over a bright and a
  dark background side by side, one row per variant. This skill's harness is a starting point:
  `sh ~/.claude/skills/liquid-glass-controls/harness/run.sh -slow 20` (or wherever this skill is
  installed). It builds `GlassMorphLab.swift` into `$TMPDIR/glassmorphlab/`, quits any running copy,
  opens a window and passes its arguments on to the app.
- Give the lab and the app a **`-slow N`** launch argument that multiplies every animation duration
  (read it with `UserDefaults.standard.double(forKey: "slow")`), so a morph can be watched or filmed
  frame by frame.
- Launch with `open App.app --args -slow 20`. An argument that doesn't start with `-`, such as a file
  path, makes AppKit try to open it as a document, and no window appears. Add
  `-ApplePersistenceIgnoreState YES`, or a restored state with no window can stick.
- `screencapture` from a shell usually fails without a Screen Recording grant; computer-use
  screenshots of the app work. Screenshots inside one computer-use batch call come a fraction of a
  second apart: enough to step through a morph at normal speed (a widening button read 44, 80, then
  87 pt wide, overshooting its 84), and frame by frame with `-slow`.
- Check every state that changes a shape: split, merge, confirm, cancel by timeout, by Esc and by a
  click, stop, and each of them again with a quick double tap.
