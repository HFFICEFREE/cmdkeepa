import { FileCode2, Plus, Search, Star, X } from 'lucide-react';
import type { Snippet } from '../lib/core';
import { timeAgo } from '../lib/core';

type SnippetListProps = {
  snippets: Snippet[];
  selectedId: string | null;
  onSelect: (id: string) => void;
  query: string;
  onQuery: (q: string) => void;
  activeTag: string | null;
  collectionName: (id: string | null) => string;
  onNew: () => void;
  dark: boolean;
  /** Hidden on small screens while a snippet is open. */
  hiddenOnMobile: boolean;
};

export default function SnippetList({
  snippets, selectedId, onSelect, query, onQuery, activeTag, collectionName, onNew, dark, hiddenOnMobile,
}: SnippetListProps) {
  return (
    <section className={`w-full shrink-0 flex-col gap-3 lg:w-[320px] ${hiddenOnMobile ? 'hidden lg:flex' : 'flex'}`}>
      <div className={`flex items-center gap-2.5 rounded-lg border px-3.5 py-2.5 ${dark ? 'border-white/10 bg-coal' : 'border-stone-900/10 bg-cream'}`}>
        <Search size={14} className="shrink-0 opacity-40" />
        <input
          value={query}
          onChange={(e) => onQuery(e.target.value)}
          placeholder="Filter snippets…"
          aria-label="Filter snippets"
          className="w-full bg-transparent text-[13.5px] outline-none placeholder:opacity-40"
        />
        {query && <button onClick={() => onQuery('')} className="opacity-40 hover:opacity-100" aria-label="Clear filter"><X size={13} /></button>}
      </div>
      <p className={`px-1 text-[12px] ${dark ? 'text-stone-500' : 'text-stone-500'}`}>
        {snippets.length} result{snippets.length === 1 ? '' : 's'}{activeTag ? ` · #${activeTag}` : ''}
      </p>
      <div className="flex max-h-[calc(100vh-240px)] flex-col gap-2 overflow-y-auto pb-8 lg:max-h-[calc(100vh-220px)]">
        {snippets.map((s) => {
          const firstLine = s.code.split('\n').find((l) => l.trim()) ?? '';
          return (
            <button
              key={s.id}
              onClick={() => onSelect(s.id)}
              className={`animate-pop rounded-xl border p-4 text-left transition ${selectedId === s.id
                ? 'border-moss-600/50 bg-moss-600/[0.07] dark:border-moss-300/30 dark:bg-moss-200/[0.07]'
                : dark ? 'border-white/[0.07] bg-coal hover:border-white/[0.14]' : 'border-stone-900/[0.08] bg-cream hover:border-stone-900/[0.16]'}`}
            >
              <div className="flex items-baseline gap-2">
                <span className="min-w-0 flex-1 truncate text-[14px] font-medium">{s.title}</span>
                {s.favorite && <Star size={11} className="shrink-0 fill-moss-600 text-moss-600 dark:fill-moss-300 dark:text-moss-300" />}
              </div>
              <div className="mt-1 truncate font-mono text-[11.5px] leading-relaxed opacity-50">{firstLine}</div>
              <div className={`mt-2 flex items-center gap-2 text-[11px] ${dark ? 'text-stone-500' : 'text-stone-500'}`}>
                <span className="font-mono uppercase tracking-[0.08em]">{s.language}</span>
                <span className="opacity-40">·</span>
                <span>{timeAgo(s.updatedAt)}</span>
                {s.collectionId && (
                  <>
                    <span className="opacity-40">·</span>
                    <span className="truncate">{collectionName(s.collectionId)}</span>
                  </>
                )}
              </div>
            </button>
          );
        })}
        {snippets.length === 0 && (
          <div className={`rounded-xl border border-dashed p-10 text-center ${dark ? 'border-white/10 text-stone-400' : 'border-stone-900/15 text-stone-500'}`}>
            <FileCode2 size={22} className="mx-auto mb-3 opacity-40" />
            <p className="text-[13.5px] font-medium">Nothing here</p>
            <p className="mt-1 text-[12px] opacity-70">Create a snippet, or clear the search.</p>
            <button onClick={onNew} className="mx-auto mt-4 flex items-center gap-1.5 rounded-lg bg-moss-800 px-3.5 py-2 text-[13px] font-medium text-stone-50 hover:bg-moss-900 dark:bg-moss-200 dark:text-moss-950 dark:hover:bg-moss-100">
              <Plus size={13} /> New snippet
            </button>
          </div>
        )}
      </div>
    </section>
  );
}
