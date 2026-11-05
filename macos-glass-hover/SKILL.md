---
name: macos-glass-hover
description: Make SwiftUI Liquid Glass buttons in a native macOS 26+ app light up under the pointer (mouse-over), as Apple's apps do, without losing a tint or the layout. Use when glass buttons on the Mac don't react to hover, when asked to add a hover highlight or hover effect to Mac glass buttons or to a glass capsule holding several buttons (Safari-style), or when a tinted glass button turns plain after changing its style. Not for iOS, iPadOS, visionOS or Mac Catalyst (they have hoverEffect), and not for buttons without Liquid Glass.
metadata:
  version: "1.0"
  updated: "2026-11-05"
---

# Hover on Liquid Glass buttons (macOS)

Native macOS has no hover-effect modifier. `hoverEffect` exists on iOS, iPadOS, Mac Catalyst, tvOS
and visionOS, not in an AppKit-based SwiftUI app. `onHover` only reports whether the pointer is over
a view; it draws nothing. A button lights up under the pointer only if its **button style** draws a
hover state, so the fix is choosing the right style and refitting the button to it.

These recipes are for glass buttons in your own window content. Items in a SwiftUI `.toolbar { }`
are drawn by the system; whether they need any of this wasn't tested.

Verified on macOS 27.0.1 with Xcode 27.1 (SDK 27.0), deployment target macOS 26.0, at the default
control size, by a person hovering each variant. On any other macOS, including 26.x, re-check with
the harness (below) before trusting it.

## What lights up

"Label-only style" below means a custom `ButtonStyle` whose `makeBody` returns `configuration.label`,
with Liquid Glass added on the button by hand: the usual way custom glass buttons are built.

| Style | Lights up | Keeps a tint |
|---|---|---|
| Label-only style + `.glassEffect(.regular.interactive())` | no | yes |
| `.buttonStyle(.glass)` + `.tint(color)` | **yes** | **yes** |
| `GlassButtonStyle(.regular.tint(color))` (macOS 26.1+) | yes | **no, the tint is dropped** |
| `.buttonStyle(.glassProminent)` + `.tint(color)` | barely | yes |

For several buttons on **one shared glass capsule**:

| Style on each button | Lights up |
|---|---|
| `.plain`, `.borderless`, `.accessoryBarAction` | no |
| `.accessoryBar` | **yes**: a highlight that fills the button out to the capsule's edge |
| `.accessoryBar` + `.buttonBorderShape(.circle)` + padding inside the capsule | **yes**: a circle inset from the edge, like Safari's toolbar buttons |

`.borderless`, `.accessoryBarAction` and `.roundedRectangle` were tested in the original lab but have
no row in the harness.

## Recipe 1: standalone glass buttons

Replace the button's custom style with `.buttonStyle(.glass)`, and **delete its `.glassEffect(...)`**
(and any `contentShape` sized for the old glass). The style draws the glass and the press feedback;
keeping the old glass stacks two layers.

```swift
Button(action: play) {
    Image(systemName: "play.fill")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(isProminent ? Color.white : Color.primary)
        .frame(width: 32, height: 32)   // the button comes out 40 x 40: the style adds 4 pt all round
}
.buttonStyle(.glass)
.buttonBorderShape(.circle)              // or .capsule
.tint(isProminent ? red.opacity(0.78) : nil)   // nil keeps plain glass; changing it animates
```

- The tint goes through the `.tint` modifier. Never pass it inside the glass
  (`GlassButtonStyle(.regular.tint(...))`); that silently renders plain glass.
- `.tint(nil)` versus a color on the same view keeps its identity, so one button can switch between
  red and plain (Play turning into Pause) and still morph.
- `.glassEffectID(_:in:)` and a surrounding `GlassEffectContainer(spacing:)` keep working when applied
  outside `.buttonStyle(.glass)` in the modifier chain: splits, merges and a capsule that widens still
  morph.

### Sizes

The glass style pads the label. Shrink the label by the padding to keep the button's old size.
Measured at the default control size; with no `buttonBorderShape` set, measure first.

| Border shape | Padding around the label |
|---|---|
| `.circle` | 4 pt on every side |
| `.capsule` (also `.roundedRectangle`) | 12 pt at the sides, 4 pt top and bottom |

A capsule that has to keep the label area a circle would have (inset 4 pt on every side), for example
a button that widens into a longer label and clips its contents to the capsule, can take the extra
8 pt back with negative padding:

```swift
label
    .frame(width: width - 8, height: height - 8)     // the label area, inset 4 pt as in a circle
    .clipShape(.capsule)
    .contentShape(.capsule)
    .padding(.horizontal, 4 - 12)                     // a capsule's wider sides take it back
```

## Recipe 2: several buttons on one glass capsule (Safari-style)

```swift
HStack(spacing: 8) {
    Button(action: feedback) { glyph("hand.thumbsup") }
    SettingsLink { glyph("slider.horizontal.3") }
}
.buttonStyle(.accessoryBar)
.buttonBorderShape(.circle)       // circles, not rectangles out to the capsule's edge
.padding(4)                       // the inset between the highlight and the capsule's edge
.glassEffect(.regular.interactive(), in: .capsule)

func glyph(_ name: String) -> some View {   // a member of the same view
    Image(systemName: name)
        .font(.system(size: 16, weight: .semibold))
        .frame(width: 28, height: 28)   // an accessory-bar circle is square, 8 pt larger each way: 36 pt
        .contentShape(.circle)
}
```

- 4 + 36 + 8 + 36 + 4 = an 88 x 44 pt capsule. Adjust the spacing or the padding to fit an existing size.
- Without `.circle`, `.accessoryBar` pads a label 12 pt at the sides and 4 pt top and bottom, and its
  highlight runs to the capsule's edge. That doesn't look like the system's toolbar hover.
- The style's padding is in points and doesn't scale. If sizes are multiplied by a scale factor `k`,
  size the label as `36 * k - 8`, not `28 * k`.

## Pitfalls

- **A background window shows tinted glass grey.** That's the inactive-window look, on purpose. Judge
  the tint only with the window active. A screenshot taken through background control shows the
  inactive look; don't read a grey there as a lost tint, and don't read it as fine either.
- **ImageRenderer draws no Liquid Glass.** Snapshot or export code needs a flat stand-in. Keep the
  old label-only style plus a drawn shape on that path, padded by the same amounts so sizes match.
- If the design can't use these styles at all, the remaining option is custom: `onHover` changing
  the glass, for example its tint's opacity. That was not verified by a person; check it the same way.

## How to verify

1. Run the harness to compare the variants on this machine:
   `sh <this skill's folder>/harness/run.sh`, for example `sh .claude/skills/macos-glass-hover/harness/run.sh` from the root of a repository that has it (Claude Code shows the folder when the skill loads). It
   builds `HoverLab.swift` into `$TMPDIR/hoverlab/HoverLab.app`, quits any running HoverLab, and opens
   a window with each variant over a light and a dark backdrop, numbered and labelled.
2. Measure sizes in points: from a computer-use screenshot's element summary, with Accessibility
   Inspector, or with a temporary `.onGeometryChange(for: CGSize.self) { $0.size } action: { print($0) }`
   on the button.
3. **Ask the person to hover.** An agent working through background app control can't move the
   pointer, and its screenshots show an inactive window. Ask in one question about both the hover
   and the tint ("is the red the same red, and does it light up?"), with the window active.
4. After changing the app, run through every state that changes a button's shape or tint (splits,
   confirmations, a button that widens) and check that the morphs still play.
