import { compressToEncodedURIComponent, decompressFromEncodedURIComponent } from 'lz-string';

export type SnippetVersion = {
  code: string;
  at: number;
  note?: string;
};

export type Snippet = {
  id: string;
  title: string;
  code: string;
  language: string;
  description: string;
  tags: string[];
  collectionId: string | null;
  favorite: boolean;
  createdAt: number;
  updatedAt: number;
  views: number;
  versions: SnippetVersion[];
};

export type Collection = {
  id: string;
  name: string;
  createdAt: number;
};

export type Settings = {
  fontSize: number;
  wordWrap: boolean;
  minimap?: boolean;
};

/** Form-level draft: tags/collection stay raw strings until resolved on save. */
export type SnippetDraft = {
  title: string;
  code: string;
  /** Concrete language id, or 'auto' to detect on save. */
  language: string;
  description: string;
  /** Comma/space/hash separated, e.g. "docker, postgres". */
  tags: string;
  /** Collection id, or '' for unfiled. */
  collectionId: string;
};

export const EMPTY_DRAFT: SnippetDraft = {
  title: '',
  code: '',
  language: 'plaintext',
  description: '',
  tags: '',
  collectionId: '',
};

export const LANGUAGES = [
  'typescript', 'javascript', 'python', 'bash', 'sql', 'yaml', 'json',
  'html', 'css', 'markdown', 'go', 'rust', 'java', 'php', 'dockerfile',
  'tsx', 'graphql', 'toml', 'ini', 'plaintext',
] as const;

const LS_SNIPPETS = 'cmdkeepa.snippets.v1';
const LS_COLLECTIONS = 'cmdkeepa.collections.v1';
const LS_SETTINGS = 'cmdkeepa.settings.v1';

export function uid(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
}

function safeParse<T>(raw: string | null, fallback: T): T {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function loadSnippets(): Snippet[] {
  return safeParse<Snippet[]>(localStorage.getItem(LS_SNIPPETS), []);
}

export function saveSnippets(snippets: Snippet[]) {
  try {
    localStorage.setItem(LS_SNIPPETS, JSON.stringify(snippets));
  } catch {
    // quota exceeded — keep in memory, UI will warn via storage estimate
  }
}

export function loadCollections(): Collection[] {
  return safeParse<Collection[]>(localStorage.getItem(LS_COLLECTIONS), []);
}

export function saveCollections(colls: Collection[]) {
  try {
    localStorage.setItem(LS_COLLECTIONS, JSON.stringify(colls));
  } catch { /* noop */ }
}

export function loadSettings(): Settings {
  return safeParse<Settings>(localStorage.getItem(LS_SETTINGS), { fontSize: 13.5, wordWrap: true });
}

export function saveSettings(s: Settings) {
  localStorage.setItem(LS_SETTINGS, JSON.stringify(s));
}

export function storageBytes(): number {
  const a = localStorage.getItem(LS_SNIPPETS)?.length ?? 0;
  const b = localStorage.getItem(LS_COLLECTIONS)?.length ?? 0;
  return a + b;
}

export function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / 1024 / 1024).toFixed(2)} MB`;
}

export function timeAgo(ts: number): string {
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return 'just now';
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  if (d < 30) return `${d}d ago`;
  return new Date(ts).toLocaleDateString();
}

export function formatDate(ts: number): string {
  return new Date(ts).toLocaleDateString(undefined, { day: '2-digit', month: '2-digit', year: 'numeric' });
}

// ---------- search ----------
export function searchSnippets(snippets: Snippet[], query: string): Snippet[] {
  const q = query.trim().toLowerCase();
  if (!q) return [...snippets].sort((a, b) => b.updatedAt - a.updatedAt);
  const terms = q.split(/\s+/);
  const scored: { s: Snippet; score: number }[] = [];
  for (const s of snippets) {
    const hay = `${s.title}\n${s.code}\n${s.description}\n${s.tags.join(' ')}\n${s.language}`.toLowerCase();
    let score = 0;
    let ok = true;
    for (const t of terms) {
      if (!t) continue;
      if (s.title.toLowerCase().includes(t)) score += 5;
      else if (s.tags.some((tag) => tag.toLowerCase().includes(t))) score += 4;
      else if (s.language.toLowerCase().includes(t)) score += 3;
      else if (s.description.toLowerCase().includes(t)) score += 2;
      else if (hay.includes(t)) score += 1;
      else { ok = false; break; }
    }
    if (ok) scored.push({ s, score });
  }
  scored.sort((a, b) => b.score - a.score || b.s.updatedAt - a.s.updatedAt);
  return scored.map((x) => x.s);
}

// ---------- language detection (heuristic) ----------
export function detectLanguage(code: string): string {
  const c = code.trim();
  if (!c) return 'plaintext';
  if (/^<!doctype html|^<html[\s>]/i.test(c) || (/<[a-z]+[^>]*>.*<\/[a-z]+>/is.test(c) && /<(div|span|html|head|body|section|main)/i.test(c))) return 'html';
  if (/^\s*\{[\s\S]*\}\s*$/.test(c)) {
    try { JSON.parse(c); return 'json'; } catch { /* fallthrough */ }
  }
  if (/^\s*(services:|version:\s*["']?\d|image:\s*\S+)/m.test(c) && /:\s*\S/.test(c) && !/[{};]/.test(c.slice(0, 400))) return 'yaml';
  if (/SELECT\s+.+\s+FROM\s+/i.test(c) || /CREATE\s+TABLE/i.test(c) || /INSERT\s+INTO/i.test(c)) return 'sql';
  if (/^FROM\s+\S+/m.test(c) || /^RUN\s+/m.test(c)) return 'dockerfile';
  if (/^\s*(#![^\n]*\n)?\s*(docker |kubectl |git |npm |yarn |pnpm |cargo |ls |cd |mkdir |chmod |ssh |curl |wget |sudo |apt|brew |echo |export )/.test(c)) return 'bash';
  if (/def\s+\w+\s*\(|import\s+\w+|print\s*\(|:\s*$/m.test(c) && /:\n\s+/.test(c)) return 'python';
  if (/func\s+\w+\s*\(|package\s+main|fmt\./.test(c)) return 'go';
  if (/fn\s+\w+|let\s+mut\s|::\s*\w/.test(c)) return 'rust';
  if (/(interface|type)\s+\w+\s*[={]|=>|const\s+\w+\s*[:=]|import\s+.*from\s+['"]/.test(c)) return 'typescript';
  if (/function\s+\w+\s*\(|console\.(log|error)|const\s+\w+\s*=\s*require\(|=>/.test(c)) return 'javascript';
  if (/^#\s+\S/m.test(c) && /\n##?\s/.test(c)) return 'markdown';
  if (/^\s*[.#][\w-]+\s*\{|:\s*#[0-9a-f]{3,6}|display:\s*(flex|grid)/i.test(c)) return 'css';
  if (/class\s+\w+|public\s+static\s+void|System\.out/.test(c)) return 'java';
  if (/<\?php|\$\w+\s*=/.test(c)) return 'php';
  return 'plaintext';
}

export function suggestTitle(code: string, language: string): string {
  const lines = code.trim().split('\n').map((l) => l.trim()).filter(Boolean);
  if (!lines.length) return `Untitled ${language}`;
  const first = lines[0].replace(/^([#/*-]|<!--|--|;|\/\/)+\s*/, '').slice(0, 60);
  if (first.length > 4 && !/^[{}()[\];,]+$/.test(first)) {
    return first.charAt(0).toUpperCase() + first.slice(1);
  }
  return `Untitled ${language}`;
}

export function suggestTags(code: string, language: string): string[] {
  const tags = new Set<string>([language.toLowerCase()]);
  const c = code.toLowerCase();
  const map: Record<string, string[]> = {
    docker: ['docker', 'container', 'dockerfile', 'image:'],
    postgres: ['postgres', 'psql'],
    django: ['django', 'manage.py'],
    react: ['react', 'usestate', 'jsx', 'tsx'],
    linux: ['chmod', 'ssh', 'apt', 'systemctl'],
    sql: ['select', 'insert into', 'create table'],
    regex: ['regex', '\\d+', '\\w+'],
    git: ['git ', 'github'],
  };
  for (const [tag, keys] of Object.entries(map)) {
    if (keys.some((k) => c.includes(k))) tags.add(tag);
  }
  return [...tags].slice(0, 5);
}

// ---------- template variables ----------
export function extractVariables(code: string): string[] {
  const re = /\{\{\s*([\w.-]+)\s*\}\}/g;
  const out: string[] = [];
  let m: RegExpExecArray | null;
  while ((m = re.exec(code))) {
    if (!out.includes(m[1])) out.push(m[1]);
  }
  return out;
}

export function renderWithVariables(code: string, values: Record<string, string>): string {
  return code.replace(/\{\{\s*([\w.-]+)\s*\}\}/g, (_, name: string) => values[name] ?? `{{${name}}}`);
}

// ---------- share via URL ----------
export type SharedPayload = { t: string; c: string; l: string; d: string; g: string[] };

export function encodeShare(s: Pick<Snippet, 'title' | 'code' | 'language' | 'description' | 'tags'>): string {
  const payload: SharedPayload = { t: s.title, c: s.code, l: s.language, d: s.description, g: s.tags };
  return compressToEncodedURIComponent(JSON.stringify(payload));
}

export function decodeShare(encoded: string): SharedPayload | null {
  try {
    const raw = decompressFromEncodedURIComponent(encoded);
    if (!raw) return null;
    const p = JSON.parse(raw) as SharedPayload;
    if (typeof p.c !== 'string') return null;
    return p;
  } catch {
    return null;
  }
}

export function parseShareHash(): string | null {
  const h = window.location.hash;
  const m = h.match(/^#\/s\/(.+)$/);
  return m ? m[1] : null;
}

// ---------- export / import ----------
export type ExportDoc = {
  app: 'cmdkeepa';
  version: 1;
  exportedAt: number;
  snippets: Snippet[];
  collections: Collection[];
};

export function buildExport(snippets: Snippet[], collections: Collection[]): ExportDoc {
  return { app: 'cmdkeepa', version: 1, exportedAt: Date.now(), snippets, collections };
}

export function parseImport(text: string): { snippets: Snippet[]; collections: Collection[] } {
  const doc = JSON.parse(text) as Partial<ExportDoc> & { snippets?: unknown };
  if (!doc || !Array.isArray(doc.snippets)) throw new Error('Invalid CmdKeepa JSON: missing snippets[]');
  const snippets = (doc.snippets as Snippet[]).filter((s) => s && typeof s.code === 'string').map((s) => ({
    ...s,
    id: typeof s.id === 'string' ? s.id : uid(),
    title: typeof s.title === 'string' ? s.title : 'Untitled',
    language: typeof s.language === 'string' ? s.language : 'plaintext',
    tags: Array.isArray(s.tags) ? s.tags : [],
    versions: Array.isArray(s.versions) ? s.versions : [],
    createdAt: typeof s.createdAt === 'number' ? s.createdAt : Date.now(),
    updatedAt: typeof s.updatedAt === 'number' ? s.updatedAt : Date.now(),
    views: typeof s.views === 'number' ? s.views : 0,
    favorite: !!s.favorite,
    description: typeof s.description === 'string' ? s.description : '',
    collectionId: typeof s.collectionId === 'string' ? s.collectionId : null,
  }));
  const collections = Array.isArray(doc.collections)
    ? (doc.collections as Partial<Collection>[]).filter((c) => c && typeof c.name === 'string').map((c) => ({
      id: typeof c.id === 'string' ? c.id : uid(),
      name: c.name as string,
      createdAt: typeof c.createdAt === 'number' ? c.createdAt : Date.now(),
    }))
    : [];
  return { snippets, collections };
}

// ---------- seed ----------
const now = Date.now();
export function seedData(): { snippets: Snippet[]; collections: Collection[] } {
  const dockerId = uid();
  const djangoId = uid();
  const linuxId = uid();
  const collections: Collection[] = [
    { id: dockerId, name: 'Docker', createdAt: now },
    { id: djangoId, name: 'Django', createdAt: now },
    { id: linuxId, name: 'Linux', createdAt: now },
  ];
  const snippets: Snippet[] = [
    {
      id: uid(),
      title: 'Docker Compose — PostgreSQL',
      code: `services:\n  db:\n    image: postgres:16\n    restart: unless-stopped\n    environment:\n      POSTGRES_USER: {{db_user}}\n      POSTGRES_PASSWORD: {{db_password}}\n      POSTGRES_DB: {{db_name}}\n    ports:\n      - "5432:5432"\n    volumes:\n      - pgdata:/var/lib/postgresql/data\n\nvolumes:\n  pgdata:`,
      language: 'yaml',
      description: 'Compose básico para desenvolvimento local com Postgres 16.',
      tags: ['docker', 'postgres', 'dev'],
      collectionId: dockerId,
      favorite: true,
      createdAt: now - 86400000 * 5,
      updatedAt: now - 86400000,
      views: 42,
      versions: [
        { code: 'services:\n  db:\n    image: postgres:15', at: now - 86400000 * 5 },
      ],
    },
    {
      id: uid(),
      title: 'Reset PostgreSQL container',
      code: `docker compose down -v\ndocker compose up -d db\ndocker exec -it {{container}} psql -U {{db_user}} -d {{db_name}}`,
      language: 'bash',
      description: 'Zera o banco local quando a migração emperra.',
      tags: ['docker', 'postgres', 'sql'],
      collectionId: dockerId,
      favorite: false,
      createdAt: now - 86400000 * 3,
      updatedAt: now - 86400000 * 2,
      views: 17,
      versions: [],
    },
    {
      id: uid(),
      title: 'Django pagination + filters',
      code: `from django.core.paginator import Paginator\n\ndef paginate(request, qs, per_page={{per_page}}):\n    page = request.GET.get("page", 1)\n    paginator = Paginator(qs, per_page)\n    return paginator.get_page(page)`,
      language: 'python',
      description: 'Helper pequeno de paginação para list views.',
      tags: ['django', 'python'],
      collectionId: djangoId,
      favorite: false,
      createdAt: now - 86400000 * 4,
      updatedAt: now - 86400000 * 3,
      views: 9,
      versions: [],
    },
    {
      id: uid(),
      title: 'Find large files (Linux)',
      code: `du -sh {{path}}/* | sort -rh | head -n {{n}}`,
      language: 'bash',
      description: 'Acha o que está comendo seu disco.',
      tags: ['linux', 'disk'],
      collectionId: linuxId,
      favorite: true,
      createdAt: now - 86400000 * 6,
      updatedAt: now - 86400000 * 4,
      views: 23,
      versions: [],
    },
    {
      id: uid(),
      title: 'Debounce (TypeScript)',
      code: `export function debounce<T extends (...args: any[]) => void>(fn: T, ms = {{delay_ms}}) {\n  let t: ReturnType<typeof setTimeout>;\n  return (...args: Parameters<T>) => {\n    clearTimeout(t);\n    t = setTimeout(() => fn(...args), ms);\n  };\n}`,
      language: 'typescript',
      description: 'Clássico debounce tipado para inputs de busca.',
      tags: ['typescript', 'react', 'utils'],
      collectionId: null,
      favorite: false,
      createdAt: now - 86400000 * 2,
      updatedAt: now - 86400000,
      views: 5,
      versions: [],
    },
  ];
  return { snippets, collections };
}
