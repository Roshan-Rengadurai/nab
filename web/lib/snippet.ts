// Text-share rendering: classification + gruvbox syntax highlighting.
// A TypeScript port of the app's SnippetImage classifier/highlighter
// (Sources/Nab/SnippetImage.swift) so hosted text shares render on the viewer
// page — selectable, copyable, and styled — instead of a baked-in PNG.

export type SnippetKind = "terminal" | "code" | "prose";

/** Same heuristics as SnippetImage.classify: terminal vs code vs prose. */
export function classify(s: string): SnippetKind {
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

/** Window-chrome title, mirroring the app: zsh / snippet / note. */
export function titleFor(kind: SnippetKind): string {
  return kind === "terminal" ? "zsh" : kind === "code" ? "snippet" : "note";
}

export interface Token {
  text: string;
  /** Tailwind classes; undefined = default foreground. */
  className?: string;
}

// Highlight rules in application order — later rules override earlier ones,
// exactly like the repeated color() passes in SnippetImage.highlighted.
interface Rule {
  re: RegExp;
  className: string;
  group?: number;
}

const RULES: Rule[] = [
  // Types (Capitalized identifiers) → yellow
  { re: /\b[A-Z][A-Za-z0-9_]*\b/g, className: "text-yellow" },
  // Function calls → blue, bold
  { re: /\b([A-Za-z_][A-Za-z0-9_]*)\s*(?=\()/g, className: "text-blue font-bold", group: 1 },
  // Control keywords → red, bold
  { re: /\b(if|else|for|while|do|switch|case|default|break|continue|return|try|catch|finally|throw|await|async|yield|in|of)\b/g, className: "text-red font-bold" },
  // Declaration / storage keywords → orange, bold
  { re: /\b(let|const|var|func|function|def|class|struct|enum|interface|type|import|export|from|as|public|private|protected|static|extends|implements|new|namespace|package)\b/g, className: "text-orange font-bold" },
  // Shell builtins → aqua
  { re: /\b(echo|cd|sudo|npm|npx|yarn|git|ls|cat|grep|export|brew|curl|mkdir|rm|cp|mv|mc|minio)\b/g, className: "text-aqua" },
  // Constants / booleans → purple
  { re: /\b(true|false|null|nil|None|undefined|this|self|super)\b/g, className: "text-purple" },
  // Numbers → purple
  { re: /\b\d+(?:\.\d+)?\b/g, className: "text-purple" },
  // Operators → orange
  { re: /(=>|===|!==|==|!=|<=|>=|&&|\|\||[=+\-*/%])/g, className: "text-orange" },
];

const MARKUP_RULES: Rule[] = [
  // Tag names → aqua
  { re: /<\/?([A-Za-z][\w.-]*)/g, className: "text-aqua", group: 1 },
  // Attribute names → yellow
  { re: /\b([A-Za-z_:][\w:-]*)(?=\s*=)/g, className: "text-yellow", group: 1 },
];

const LATE_RULES: Rule[] = [
  // Strings → green (override tokens inside)
  { re: /"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`/g, className: "text-green" },
  // Comments → gray italic (override everything inside)
  { re: /(\/\/[^\n]*|#[^\n]*)$/gm, className: "text-gray italic" },
];

/** Tokenize `text` into styled runs for code/terminal snippets. */
export function highlight(text: string): Token[] {
  // Per-character class map; later rules overwrite earlier ones.
  const styles: (string | undefined)[] = new Array(text.length).fill(undefined);

  const rules = [...RULES];
  if (/<\/?[A-Za-z][\w.-]*[\s/>]/.test(text)) rules.push(...MARKUP_RULES);
  rules.push(...LATE_RULES);

  for (const rule of rules) {
    rule.re.lastIndex = 0;
    for (const m of text.matchAll(rule.re)) {
      const g = rule.group ?? 0;
      const s = rule.group != null ? m[g] : m[0];
      if (s == null) continue;
      // Compute the group's offset within the whole match (first occurrence).
      const start = (m.index ?? 0) + (rule.group != null ? m[0].indexOf(s) : 0);
      for (let i = start; i < start + s.length; i++) styles[i] = rule.className;
    }
  }

  // Merge consecutive characters with identical styling into runs.
  const tokens: Token[] = [];
  let runStart = 0;
  for (let i = 1; i <= text.length; i++) {
    if (i === text.length || styles[i] !== styles[runStart]) {
      tokens.push({ text: text.slice(runStart, i), className: styles[runStart] });
      runStart = i;
    }
  }
  return tokens;
}
