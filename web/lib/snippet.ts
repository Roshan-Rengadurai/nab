// Text-share rendering: classify a snippet as terminal / code / prose, then
// highlight code with highlight.js (real language grammars + auto-detection)
// so hosted text shares render on the viewer page — selectable, copyable, and
// accurately colored — instead of a baked-in PNG.
//
// The app uploads raw text with no language hint, so we lean on highlight.js's
// automatic language detection (restricted to a common subset for speed and
// fewer misfires). Prose is rendered as Markdown by the page, not here.

import hljs from "highlight.js";

export type SnippetKind = "terminal" | "code" | "prose";

/**
 * Count distinct Markdown signals. Kept deliberately conservative — the shell
 * heuristic below reads `#` and `>` line prefixes as terminal prompts, so a
 * note using Markdown headings/blockquotes would otherwise be misread as a
 * terminal. Requiring two *different* signal types avoids flipping real code or
 * a stray `#` comment into prose.
 */
function markdownScore(s: string): number {
  let n = 0;
  if (/^#{1,6}\s+\S/m.test(s)) n++; // heading
  if (/\*\*[^*\n]+\*\*/.test(s)) n++; // **bold**
  if (/(?<!\!)\[[^\]\n]+\]\([^)\n]+\)/.test(s)) n++; // [text](url) link
  if (/(^|\n)```/.test(s)) n += 2; // fenced code block (strong)
  if ((s.match(/^[ \t]*[-*+]\s+\S/gm) || []).length >= 2) n++; // bullet list
  if ((s.match(/^[ \t]*\d+\.\s+\S/gm) || []).length >= 2) n++; // ordered list
  if (/^>\s+\S/m.test(s)) n++; // blockquote
  if (/`[^`\n]+`/.test(s)) n++; // inline code
  return n;
}

/** Heuristics: terminal vs code vs prose (mirrors SnippetImage.classify). */
export function classify(s: string): SnippetKind {
  // Markdown wins first — its heading/blockquote syntax overlaps shell prompts.
  if (markdownScore(s) >= 2) return "prose";

  const lines = s.split("\n");
  let codeScore = 0;
  let termScore = 0;
  const codeTokens = [
    "{", "}", ";", "=>", "->", "::", "</", "/>", "def ", "func ",
    "class ", "import ", "const ", "let ", "var ", "function ",
    "return ", "#include", "public ", "private ", "==",
  ];
  const shellCmds = [
    "sudo ", "brew ", "npm ", "npx ", "git ", "cd ", "ls ", "echo ",
    "curl ", "mkdir ", "rm ", "export ", "cat ", "grep ", "mc ", "minio ",
  ];
  for (const line of lines) {
    const trimmed = line.trim();
    if (["$ ", "% ", "# ", "> "].some((p) => trimmed.startsWith(p))) termScore += 2;
    if (line.startsWith("  ") || line.startsWith("\t")) codeScore += 1;
    for (const t of codeTokens) if (line.includes(t)) codeScore += 1;
    for (const c of shellCmds) if (trimmed.startsWith(c)) termScore += 1;
  }
  if (termScore >= 2 && termScore >= codeScore) return "terminal";
  if (codeScore >= 3) return "code";
  const punct = [...s].filter((ch) => "{}[]();=<>/*&|".includes(ch)).length;
  if (s.length > 0 && punct / s.length > 0.06) return "code";
  return "prose";
}

/** A short label for the snippet — its detected language, or a sensible default. */
export function labelFor(kind: SnippetKind, language?: string): string {
  if (kind === "terminal") return "shell";
  if (kind === "prose") return "text";
  return language && language.length ? language : "code";
}

// Languages highlight.js may auto-detect against. A curated subset keeps
// detection fast and cuts down on exotic-language false positives.
const SUBSET = [
  "javascript", "typescript", "python", "bash", "shell", "json", "xml",
  "css", "scss", "go", "rust", "c", "cpp", "csharp", "java", "kotlin",
  "swift", "ruby", "php", "sql", "yaml", "toml", "markdown", "diff",
  "dockerfile", "makefile", "objectivec", "lua", "r", "perl", "graphql",
];

export interface Highlighted {
  /** Safe HTML: highlight.js escapes the source text and wraps tokens in spans. */
  html: string;
  /** The detected (or forced) language, when known. */
  language?: string;
}

/**
 * Highlight a code/terminal snippet to safe HTML. Terminal snippets are forced
 * to `bash`; code snippets use highlight.js auto-detection over {@link SUBSET}.
 * The returned HTML is XSS-safe — highlight.js escapes the input and only its
 * own `<span class="hljs-…">` wrappers are markup.
 */
export function highlightCode(text: string, kind: SnippetKind): Highlighted {
  try {
    if (kind === "terminal") {
      return { html: hljs.highlight(text, { language: "bash" }).value, language: "shell" };
    }
    const res = hljs.highlightAuto(text, SUBSET);
    return { html: res.value, language: res.language };
  } catch {
    // Never let a highlighter hiccup 500 the page — fall back to escaped text.
    return { html: escapeHtml(text) };
  }
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
