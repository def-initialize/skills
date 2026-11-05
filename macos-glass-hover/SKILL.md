---
name: macos-glass-hover
description: Make SwiftUI Liquid Glass buttons on macOS 26+ light up under the pointer, as Apple's apps do, without losing a tint or the layout. Use when glass buttons on the Mac don't react to hover, when asked to add a hover highlight or hover effect to glass buttons or to a capsule holding several buttons (Safari-style toolbar hover), or when a tinted glass button turns plain after changing its style.
---

# Hover on Liquid Glass buttons (macOS)

On the Mac there is no hover modifier to add. `hoverEffect` exists only on iOS, iPadOS, tvOS and
visionOS. A button lights up under the pointer only if its **button style** draws a hover state, so
the fix is choosing the right style and refitting the button to it.

Verified on macOS 27.0.1 with Xcode 27.1 (SDK 27.0), deployment target macOS 26.0, by a person
hovering each variant. On a newer macOS, re-check with the harness (below) before trusting it.

## What lights up

| Style | Lights up | Keeps a tint |
|---|---|---|
| Label-only `ButtonStyle` + `.glassEffect(.regular.interactive())` | no | yes |
| `.buttonStyle(.glass)` + `.tint(color)` | **yes** | **yes** |
| `GlassButtonStyle(.regular.tint(color))` (macOS 26.1+) | yes | **no, the tint is dropped** |
| `.buttonStyle(.glassProminent)` + `.tint(color)` | barely | yes |

For several buttons on **one shared glass capsule** (like a toolbar group):

| Style on each button | Lights up |
|---|---|
| `.plain`, `.borderless`, `.accessoryBarAction` | no |
| `.accessoryBar` | **yes**: a highlight that fills the button out to the capsule's edge |
| `.accessoryBar` + `.buttonBorderShape(.circle)` + padding inside the capsule | **yes**: a circle inset from the edge, like Safari's toolbar buttons |

## Recipe 1: standalone glass buttons

```swift
Button(action: play) {
    Image(systemName: "play.fill")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
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
- `.glassEffectID(_:in:)` and a surrounding `GlassEffectContainer(spacing:)` keep working when put
  after the style: splits, merges and a capsule that widens still morph.

### Sizes

The glass style pads the label. Shrink the label by the padding to keep the button's old size.

| Border shape | Padding around the label |
|---|---|
| `.circle` | 4 pt on every side |
| `.capsule` (also `.roundedRectangle`) | 12 pt at the sides, 4 pt top and bottom |

A capsule that has to keep a circle's content box (for example, a button that widens into a wider
label and clips its contents to the capsule) can take the extra 8 pt back with negative padding:

```swift
label
    .frame(width: width - 8, height: height - 8)     // content box, as with a circle's 4 pt
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

func glyph(_ name: String) -> some View {
    Image(systemName: name)
        .font(.system(size: 16, weight: .semibold))
        .frame(width: 28, height: 28)   // an accessory-bar circle is square, 8 pt wider than its label: 36 pt
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
- **Press feedback** now comes from the style, not from `.interactive()` glass.
- If the design can't use these styles at all, the remaining option is custom: `onHover` changing
  the glass, for example its tint's opacity. That was not verified by a person; check it the same way.

## How to verify

1. Run the harness in this skill's folder to compare the variants on this machine:
   `sh harness/run.sh` builds `harness/HoverLab.swift` into a small app and opens it. It shows each
   variant over a light and a dark backdrop, with labels.
2. Measure sizes from the accessibility frames, for example through a computer-use screenshot's
   element summary. Button frames are reported in points.
3. **Ask the person to hover.** An agent working through background app control can't move the
   pointer, and its screenshots show an inactive window. Ask in one question about both the hover
   and the tint ("is the red the same red, and does it light up?"), with the window active.
4. After changing the app, run through every state that changes a button's shape or tint (splits,
   confirmations, a button that widens) and check that the morphs still play.
