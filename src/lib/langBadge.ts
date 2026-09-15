const LANG_COLORS: Record<string, string> = {
  typescript: 'bg-sky-500/15 text-sky-700 dark:text-sky-300',
  javascript: 'bg-yellow-500/15 text-yellow-700 dark:text-yellow-300',
  python: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300',
  bash: 'bg-stone-500/15 text-stone-600 dark:text-stone-300',
  sql: 'bg-indigo-500/15 text-indigo-700 dark:text-indigo-300',
  yaml: 'bg-rose-500/15 text-rose-700 dark:text-rose-300',
  json: 'bg-orange-500/15 text-orange-700 dark:text-orange-300',
  html: 'bg-orange-600/15 text-orange-700 dark:text-orange-300',
  css: 'bg-blue-500/15 text-blue-700 dark:text-blue-300',
  markdown: 'bg-zinc-500/15 text-zinc-600 dark:text-zinc-300',
  go: 'bg-cyan-500/15 text-cyan-700 dark:text-cyan-300',
  rust: 'bg-red-500/15 text-red-700 dark:text-red-300',
};

/** Tailwind classes for a language badge. */
export function langBadge(lang: string): string {
  return LANG_COLORS[lang.toLowerCase()] ?? 'bg-amber-500/15 text-amber-700 dark:text-amber-300';
}
