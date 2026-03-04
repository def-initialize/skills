---
name: web-tts
description: Convert a web page to a Telegram voice message, with optional translation. Use when the user asks to read, listen to, or get a voice version of a URL — with or without translation (e.g. "leggi questo articolo", "traduci e mandamelo come vocale", "read this page in Italian").
---

# web-tts

Convert a web page to a Telegram voice message, optionally translating first.

## Scripts

**webfetch** — fetch a URL and save extracted text to file (no AI involved):
```bash
cd /root/.openclaw/workspace/scripts/webfetch
tsx webfetch.ts <url> --output /tmp/article.md
```

**tts-file** — convert text to speech and send as Telegram voice message:
```bash
cd /root/.openclaw/workspace/scripts/tts

# From file (preferred)
tsx tts-file.ts --file /tmp/article.md --send --caption "<title>"

# From heredoc (for translated text)
tsx tts-file.ts --output /tmp/out.ogg --send --caption "<title>" << 'ENDOFTEXT'
<text here>
ENDOFTEXT
```

`tts-file.ts` handles everything automatically: splits at sentence boundaries, uses ElevenLabs Request Stitching, concatenates chunks into a single OGG, cleans up temp files, sends one voice message.

Config (API key, voice, model, language) is read from `openclaw.json`. Run `tsx tts-file.ts --help` for all options.

## Workflow

### Step 0 — Spawn sub-agent

Always delegate the full workflow to a **spawned sub-agent** using `haiku64k`:

```
sessions_spawn(
  task="<full instructions including URL, target language if any, and steps below>",
  model="haiku64k",
  mode="run"
)
```

Exception: if the page is very short (< 500 chars), handle inline without spawning.

---

### Without translation

The text must **never pass through the LLM** — use webfetch.ts to save to disk, then pass the path directly to tts-file.ts via `--file`. Do not open or read the file.

**Step 1 — Fetch to file**
```bash
cd /root/.openclaw/workspace/scripts/webfetch
tsx webfetch.ts <url> --output /tmp/article.md
```

**Step 2 — TTS from file**
```bash
cd /root/.openclaw/workspace/scripts/tts
tsx tts-file.ts --file /tmp/article.md --send --caption "<page title>"
```

---

### With translation

Fetch in memory, translate, pass to TTS via heredoc.

**Step 1 — Fetch**

Use `web_fetch` to retrieve the page. Extract the meaningful text (skip nav, footers, ads).

**Step 2 — Translate**

Translate the **entire extracted text** in one pass. Preserve the meaning faithfully — **do not summarize**. Warn the user if the text was too long and a partial translation was produced.

**Step 3 — TTS via heredoc**
```bash
cd /root/.openclaw/workspace/scripts/tts && tsx tts-file.ts \
  --output /tmp/out.ogg \
  --send \
  --caption "<page title>" << 'ENDOFTEXT'
<translated text here>
ENDOFTEXT
```

---

## Edge cases

- **Page behind auth / JS wall**: `web_fetch` will fail or return incomplete content. Try the `browser` tool as fallback. For the no-translation path, `webfetch.ts` may also fail — fall back to `web_fetch` + save with the `write` tool.
- **Very short page** (< 500 chars): skip the sub-agent, handle inline.
