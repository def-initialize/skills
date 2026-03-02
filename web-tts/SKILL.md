---
name: web-tts
description: Convert a web page to a Telegram voice message, with optional translation. Use when the user asks to read, listen to, or get a voice version of a URL — with or without translation (e.g. "leggi questo articolo", "traduci e mandamelo come vocale", "read this page in Italian").
---

# web-tts

Convert a web page to one or more Telegram voice messages, optionally translating first.

## Constants

- **TTS hard limit**: 40,000 characters per request (enforced by `tts-file.ts`)
- **Translation soft limit**: ~64,000 tokens input. Beyond this, the sub-agent will summarize instead of translating fully — **always warn the user** when this applies.

## TTS script

```bash
cd /root/.openclaw/workspace/scripts/tts

# Heredoc (default — recommended)
tsx tts-file.ts --output /tmp/out.ogg --send --caption "<title>" << 'ENDOFTEXT'
<text here>
ENDOFTEXT
```

Config (API key, voice, model, language) is read from `openclaw.json`. Run `tsx tts-file.ts --help` for all available arguments and overrides.

## Workflow

### Step 0 — Spawn sub-agent

Always delegate the full workflow to a **spawned sub-agent** using `haiku64k`:

```
sessions_spawn(
  task="<full instructions including URL, target language if any, and steps 1–5 below>",
  model="haiku64k",
  mode="run"
)
```

`haiku64k` is the configured alias for `anthropic/claude-haiku-4-5` with `maxTokens: 64000` — required for long translations.

Exception: if the page is very short (< 500 chars), handle inline without spawning.

### Step 1 — Fetch and read

Use `web_fetch` to retrieve the page. Read the content to identify:
- The meaningful text (skip nav, footers, ads)
- Total character count of the relevant content
- Logical split points if chunking is needed (headings, sections, chapters)

Token cost here is unavoidable — the LLM must read the page to understand it.

### Step 2 — Decide strategy

| Condition | Action |
|-----------|--------|
| `chars ≤ 40k`, no translation | → **Single TTS call** |
| `chars ≤ 40k`, with translation | → **Translate inline, single TTS call** |
| `chars > 40k`, no translation | → **Split by sections, one TTS call per chunk** |
| `chars > 40k`, with translation | → **Translate each chunk inline, one TTS call per chunk** |
| Translation needed AND text likely > 64k tokens | → **Warn user**, proceed (output will be a recap, not a full translation) |

**Do not save intermediate chunks to files unless strictly necessary.** Write the chunk and call `tts-file.ts` in the same `exec` step using a heredoc or temp file in `/tmp/`.

### Step 3 — Chunking (when needed)

- Split at logical boundaries (headings, sections, paragraphs) — never mid-sentence
- Each chunk must be ≤ 40,000 characters
- If a single section exceeds 40,000 characters, split further at paragraph boundaries
- If a chunk still exceeds 40k after splitting, `tts-file.ts` will exit with code `2` and print `[AI_INSTRUCTION]` — follow it to split further

### Step 4 — Translate (when requested)

- Translate **each chunk separately**, inline, before passing to TTS
- Do not translate the entire document first and then split — translate already-chunked text to keep it in one pass
- Use the sub-agent model (haiku64k) for translation to preserve max output tokens
- Preserve the meaning faithfully — no summarizing unless the 64k token limit forces it

### Step 5 — TTS and send

For each chunk (or the full text if short), pass text via heredoc (stdin) — no escaping, no temp files:

```bash
cd /root/.openclaw/workspace/scripts/tts && tsx tts-file.ts \
  --output /tmp/chunk_1.ogg \
  --send \
  --caption "<Section title>" << 'ENDOFTEXT'
<chunk text here>
ENDOFTEXT
```

Alternatively use `--text "..."` for short texts, or `--file <path>` to read from disk.

## Edge cases

- **Page behind auth / JS wall**: `web_fetch` will fail or return incomplete content. Try the `browser` tool as fallback.
- **Very short page** (< 500 chars): skip the sub-agent, handle inline.
- **Multiple voice messages**: send them in order with a numbered caption (e.g. "Parte 1/3 — Introduction").
