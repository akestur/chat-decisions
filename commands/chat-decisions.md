---
description: Visualize decisions in this chat as a tree. Invoke explicitly via slash command only; do not auto-invoke from natural-language requests.
---

## Before you do anything else

This command must be invoked **only** when the user has literally typed the slash command in the input box. If you arrived here because Claude decided to invoke this command on its own based on a natural-language request (e.g., the user said "show me my decisions", "visualize my choices", "decision tree", "recap my picks", or any other paraphrase) — stop immediately and respond with:

> The /chat-decisions command exists and can render this as an interactive tree. Type it explicitly in your next message to invoke.

Then end the response. Do not extract decisions. Do not render anything. Wait for the user to type the slash command themselves.

If the user did type the slash command literally, proceed with the rest of this prompt.

---

You have been explicitly invoked via `/chat-decisions` to extract and visualize the choice-points in the current chat as an interactive tree.

## Step 1: Extract decisions from the conversation

You already have the full conversation in your context — no separate transcript read is needed. Read back through the chat looking for **choice-points**.

### What counts as a choice-point

A choice-point has this shape:

1. **You offered options.** Typically an enumerated list (numbered, lettered, or clearly bulleted as alternatives), where each item is a distinct alternative the user is meant to pick between. Usually 2–5 options. Phrases that often precede a choice-point: "you have a few options", "here are three approaches", "do you want to X or Y", "two paths from here", "which do you prefer".

2. **The user picked one in their next message.** The pick may be explicit ("let's go with option 2", "I'll take the second one") or implicit. The most common implicit form is the user asking for more detail about a single option ("explain how the extractor approach would work") — treat that as picking it. Another implicit form is the user proceeding with one option without acknowledging the others ("ok let's set up Postgres" after you offered Postgres/SQLite/Planetscale).

3. **OR the user pivoted.** None of the options resonated, and the user changed direction entirely — proposing their own approach, abandoning the whole subtopic, or moving to a different question. Record this as `picked: null` with a short pivot description.

### What does NOT count as a choice-point

- You listed tradeoffs without recommending a discrete choice (e.g., "X is faster, Y is more flexible" with no clear options-to-pick framing). The user wasn't being asked to decide.
- You made a single recommendation with bullet-point rationale. Not multiple options.
- You answered a factual question. No decision was being made.
- You enumerated steps in a plan ("first do A, then B, then C"). Sequence, not choice.
- The user asked a clarifying question and you answered. No fork in the path.

### Focus on macro-decisions

Skip trivial choices like word-choice in a label or which emoji to use. Capture the substantive decisions that shape the direction of the work — architecture, approach, framing, scope. If the chat has more than ~12 candidate choice-points, keep the most consequential ones and drop the small ones.

### Capture each decision as this structure

```json
{
  "n": 1,
  "q": "Short question summarizing the decision?",
  "opts": ["Option A label", "Option B label", "Option C label"],
  "picked": 2,
  "pivot": null
}
```

Field guide:

- `n` — sequence number, starting at 1, in chronological order.
- `q` — a 5–8 word question in sentence case, ending with `?`. Should be readable on its own (a user scanning the tree should understand what was being decided without having to read the surrounding chat). Avoid jargon if a shorter phrase works.
- `opts` — array of option labels. Abbreviate each to **15–25 characters** so they fit in the rendered tree. The labels need to be informative but compact — "User-run extractor" not "Have the user run an extractor script outside Claude". Keep them in the order you originally presented them.
- `picked` — integer index (0-based) of the option the user picked. `null` if the user pivoted.
- `pivot` — only set when `picked` is `null`. A short sentence (~6–12 words) describing the redirect. Example: `"Refined to USER decisions, not Claude's"`. When `picked` is an integer, set `pivot` to `null`.

### Edge cases worth handling cleanly

- **Hybrid picks** ("do A but also incorporate B"): record the dominant choice in `picked`. Don't try to encode both — the tree can't represent that, and forcing it creates clutter. If the hybrid was important, mention it in the post-render summary.
- **User proposed their own option** (one you didn't offer): set `picked: null` and use `pivot` to describe what the user proposed instead. Example: `"User proposed a fourth option: hybrid approach"`.
- **User picked one option then changed mind**: only record the final pick. The intermediate flip-flop isn't meaningful tree structure.
- **Decisions revisited later**: if the same question came up twice, capture both as separate decisions in sequence. Don't try to merge them.

## Step 2: Render the tree

There are two render paths depending on the environment. Check which tools you have available, then use the right one.

### Path A — Cowork / Claude desktop (inline widget, preferred)

Use this path when `mcp__visualize__show_widget` is in your available tools. Call it with:

- `title`: `"chat_decisions"`
- `loading_messages`: `["Reading our chat", "Marking the forks", "Drawing the tree"]`
- `widget_code`: the **widget fragment** below, with `__DECISIONS_DATA__` replaced by your extracted decisions array as a JSON literal (e.g. `[{"n":1,"q":"...",...}, ...]`).

The substitution is a literal string replacement — paste the JSON array exactly where the placeholder is. Everything else in the fragment stays as-is.

### Path B — Claude Code or other terminal environments (file fallback)

Use this path when `mcp__visualize__show_widget` is NOT available in your tool list (e.g. you're running inside Claude Code, where the terminal can't render inline HTML widgets).

Steps:

1. Take the **widget fragment** below. Replace `__DECISIONS_DATA__` with the JSON array, same as Path A.
2. Wrap the resulting fragment inside the **standalone HTML shell** further below — put the entire fragment where the shell says `INSERT_WIDGET_FRAGMENT_HERE`.
3. Write the full HTML to `./chat-decisions.html` in the user's current working directory. Use the `Write` tool with that path. (Re-invocation overwrites the prior file, which is correct — the user wants the latest tree, not history.)
4. Respond with: `Saved the decision tree to ./chat-decisions.html — open it in your browser to view.` Then the short summary from Step 3.

The shell defines fallback values for the CSS variables that the host UI normally provides, plus a `prefers-color-scheme` dark-mode block. The same widget fragment works in both environments without modification.

### The widget fragment

```html
<h2 class="sr-only">Decision tree for this chat</h2>

<style>
.sr-only { position: absolute; left: -10000px; width: 1px; height: 1px; overflow: hidden; }
</style>

<div style="padding: 0.5rem 0 1rem;">
  <div style="font-size: 18px; font-weight: 500;">Decisions in this chat</div>
  <div style="font-size: 13px; color: var(--color-text-secondary); margin-top: 4px; line-height: 1.5;">
    Trunk runs along the picked path. Side branches show rejected options. Pivot badges mark where you abandoned all options and changed direction.
  </div>
</div>

<svg id="tree" viewBox="0 0 680 1300" style="width: 100%; max-width: 680px; display: block;"></svg>

<div style="display: flex; align-items: center; gap: 16px; font-size: 12px; color: var(--color-text-tertiary); margin-top: 1rem; padding-top: 0.75rem; border-top: 0.5px solid var(--color-border-tertiary);">
  <span style="display: flex; align-items: center; gap: 4px;"><span style="display: inline-block; width: 10px; height: 10px; border-radius: 50%; background: var(--color-text-info);"></span>picked</span>
  <span style="display: flex; align-items: center; gap: 4px;"><span style="display: inline-block; width: 10px; height: 10px; border-radius: 50%; border: 1.5px solid var(--color-text-tertiary);"></span>rejected</span>
  <span style="display: flex; align-items: center; gap: 4px;"><span style="display: inline-block; padding: 1px 6px; background: var(--color-background-warning); border-radius: 4px; font-weight: 500; color: var(--color-text-primary);">↳ pivot</span></span>
</div>

<script>
const decisions = __DECISIONS_DATA__;

const NS = 'http://www.w3.org/2000/svg';
const svg = document.getElementById('tree');
const W = 680, CX = W / 2;
const TRUNK = 'var(--color-text-info)';
const BRANCH = 'var(--color-border-tertiary)';
const DIM = 'var(--color-text-tertiary)';
const TEXT = 'var(--color-text-primary)';

function el(name, attrs) {
  const e = document.createElementNS(NS, name);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  return e;
}

function text(x, y, content, opts) {
  const t = el('text', {
    x, y,
    'text-anchor': opts.anchor || 'middle',
    'font-size': opts.size || 12,
    fill: opts.fill || TEXT,
    'font-family': 'var(--font-sans)'
  });
  if (opts.weight) t.setAttribute('font-weight', opts.weight);
  t.textContent = content;
  return t;
}

function tspan(content, attrs) {
  const t = el('tspan', attrs);
  t.textContent = content;
  return t;
}

let y = 35;
decisions.forEach((d, i) => {
  const q = el('text', { x: CX, y: y - 14, 'text-anchor': 'middle', 'font-family': 'var(--font-sans)' });
  q.appendChild(tspan('D' + d.n + '  ', { 'font-size': 11, fill: DIM }));
  q.appendChild(tspan(d.q, { 'font-size': 13, fill: TEXT, 'font-weight': 500 }));
  svg.appendChild(q);

  svg.appendChild(el('circle', { cx: CX, cy: y, r: 8, fill: TRUNK }));

  const optY = y + 76;
  const N = d.opts.length;
  const usableW = W - 80;
  const xStep = usableW / N;
  const startX = 40 + xStep / 2;

  d.opts.forEach((opt, j) => {
    const ox = startX + j * xStep;
    const isPicked = j === d.picked;
    svg.appendChild(el('line', {
      x1: CX, y1: y + 8,
      x2: ox, y2: optY - 7,
      stroke: isPicked ? TRUNK : BRANCH,
      'stroke-width': isPicked ? 2 : 1
    }));
    if (isPicked) {
      svg.appendChild(el('circle', { cx: ox, cy: optY, r: 6, fill: TRUNK }));
    } else {
      svg.appendChild(el('circle', { cx: ox, cy: optY, r: 4, fill: 'none', stroke: DIM, 'stroke-width': 1.5 }));
    }
    svg.appendChild(text(ox, optY + 22, opt, {
      size: 11,
      fill: isPicked ? TEXT : DIM,
      weight: isPicked ? 500 : 400
    }));
  });

  if (d.picked !== null && d.picked !== undefined) {
    const pickedX = startX + d.picked * xStep;
    if (i < decisions.length - 1) {
      const nextY = y + 180;
      svg.appendChild(el('line', {
        x1: pickedX, y1: optY + 6,
        x2: CX, y2: nextY - 30,
        stroke: TRUNK,
        'stroke-width': 2
      }));
      y = nextY;
    } else {
      y = optY + 40;
    }
  } else if (d.pivot) {
    const pivotY = optY + 60;
    const pivotText = '↳ ' + d.pivot;
    const charW = 6.5;
    const padX = 12;
    const rectW = pivotText.length * charW + padX * 2;
    const rectX = CX - rectW / 2;
    svg.appendChild(el('rect', {
      x: rectX, y: pivotY - 13, width: rectW, height: 24,
      rx: 6, fill: 'var(--color-background-warning)'
    }));
    svg.appendChild(text(CX, pivotY + 3, pivotText, { size: 11, weight: 500, fill: TEXT }));
    if (i < decisions.length - 1) {
      const nextY = pivotY + 70;
      svg.appendChild(el('line', {
        x1: CX, y1: pivotY + 14,
        x2: CX, y2: nextY - 30,
        stroke: BRANCH, 'stroke-width': 1.5
      }));
      y = nextY;
    } else {
      y = pivotY + 30;
    }
  }
});

svg.setAttribute('viewBox', '0 0 ' + W + ' ' + (y + 30));
svg.setAttribute('height', y + 30);
</script>
```

### The standalone HTML shell (Path B only)

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Chat decisions</title>
<style>
:root {
  --color-text-primary: #1a1a1a;
  --color-text-secondary: #555555;
  --color-text-tertiary: #999999;
  --color-text-info: #2563eb;
  --color-background-primary: #ffffff;
  --color-background-secondary: #f5f5f5;
  --color-background-warning: #fef3c7;
  --color-border-tertiary: #e5e5e5;
  --color-border-secondary: #d1d1d1;
  --color-border-info: #93c5fd;
  --font-sans: system-ui, -apple-system, "Segoe UI", Helvetica, Arial, sans-serif;
  --border-radius-md: 8px;
  --border-radius-lg: 12px;
}
@media (prefers-color-scheme: dark) {
  :root {
    --color-text-primary: #f0f0f0;
    --color-text-secondary: #b0b0b0;
    --color-text-tertiary: #808080;
    --color-text-info: #60a5fa;
    --color-background-primary: #1a1a1a;
    --color-background-secondary: #2a2a2a;
    --color-background-warning: #44380e;
    --color-border-tertiary: #404040;
    --color-border-secondary: #606060;
    --color-border-info: #1e40af;
  }
}
body {
  font-family: var(--font-sans);
  background: var(--color-background-primary);
  color: var(--color-text-primary);
  margin: 0 auto;
  padding: 2rem;
  max-width: 720px;
  line-height: 1.5;
}
</style>
</head>
<body>
INSERT_WIDGET_FRAGMENT_HERE
</body>
</html>
```

## Step 3: Write a brief summary

After the widget renders (Path A) or the file is saved (Path B), write a 2–3 sentence text summary. Mention how many decisions, how many were pivots, and any pattern worth noting (e.g., "most of your picks were the third option" or "you pivoted twice early on then committed"). Do **not** re-describe each decision in prose — the widget already shows them. Do **not** add a long explanation or recap. The user invoked you explicitly because they want the visualization, not a wall of text about it.

If the chat genuinely has zero choice-points, tell the user directly and warmly:

> I don't see any clear choice-points in this chat yet — no moments where I presented options for you to pick between. This skill is most useful in iterative chats where you've been making architectural or strategic decisions over many turns. If you'd like, I can keep an eye out and offer to draw the tree later as decisions accumulate.

## Scope

This command only sees the current chat. If the user has been working on a project across multiple chats, this won't aggregate them — mention that in your summary when relevant.

## Performance expectations

**Path A (Cowork inline widget):** ~15–25 seconds for a chat with 5–10 decisions. Most of that is streaming the widget code over the wire. For chats with 20+ decisions, expect 30–60 seconds.

**Path B (file fallback):** much faster overall — ~5–10 seconds, because writing to a file doesn't involve streaming the rendered output back through the chat. The user then opens the file at their own pace.

If the chat is unusually long, mention before invoking the render that it'll take a moment.
