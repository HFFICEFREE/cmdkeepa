import { useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { Search } from 'lucide-react';
import type { Snippet } from '../lib/core';
import { searchSnippets } from '../lib/core';

export type PaletteCommand = {
  label: string;
  hint: string;
  icon: ReactNode;
  run: () => void;
};

type PaletteProps = {
  snippets: Snippet[];
  dark: boolean;
  onClose: () => void;
  onJump: (id: string) => void;
  commands: PaletteCommand[];
  onSearch: (q: string) => void;
};

/** Ctrl+K overlay: matches commands (prefix with `>`) and jumps to snippets. */
export default function Palette({ snippets, dark, onClose, onJump, commands, onSearch }: PaletteProps) {
  const [q, setQ] = useState('');
  const [idx, setIdx] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  useEffect(() => { inputRef.current?.focus(); }, []);

  const matchedCmds = commands.filter((c) => (c.label + ' ' + c.hint).toLowerCase().includes(q.replace(/^>\s*/, '').toLowerCase()));
  const query = q.startsWith('>') ? '' : q;
  const matchedSnips = query ? searchSnippets(snippets, query).slice(0, 7) : snippets.slice(0, 5);
  const total = matchedCmds.length + matchedSnips.length;

  const go = (i: number) => {
    if (total === 0) return;
    if (i < matchedCmds.length) {
      matchedCmds[i].run();
      onClose();
    } else {
      const s = matchedSnips[i - matchedCmds.length];
      if (s) {
        onSearch('');
        onJump(s.id);
        onClose();
      }
    }
  };

  return (
    <div className="animate-fade fixed inset-0 z-50 bg-stone-950/40 p-4" onClick={onClose}>
      <div
        onClick={(e) => e.stopPropagation()}
        className={`animate-pop mx-auto mt-[10vh] max-w-xl overflow-hidden rounded-xl border ${dark ? 'border-white/10 bg-coal' : 'border-stone-900/10 bg-cream'}`}
      >
        <div className={`flex items-center gap-2.5 border-b px-4 py-3 ${dark ? 'border-white/10' : 'border-stone-900/10'}`}>
          <Search size={14} className="opacity-40" />
          <input
            ref={inputRef}
            value={q}
            onChange={(e) => { setQ(e.target.value); setIdx(0); }}
            onKeyDown={(e) => {
              if (e.key === 'ArrowDown') { e.preventDefault(); setIdx((i) => Math.min(total - 1, i + 1)); }
              else if (e.key === 'ArrowUp') { e.preventDefault(); setIdx((i) => Math.max(0, i - 1)); }
              else if (e.key === 'Enter') go(idx);
            }}
            placeholder="Type a command or search…"
            aria-label="Command palette"
            className="w-full bg-transparent text-[14px] outline-none placeholder:opacity-40"
          />
          <kbd className="key">esc</kbd>
        </div>
        <div className="max-h-[50vh] overflow-y-auto p-1.5">
          {matchedCmds.map((c, i) => (
            <button key={c.label} onClick={() => go(i)} onMouseEnter={() => setIdx(i)}
              className={`flex w-full items-center gap-2.5 rounded-lg px-3 py-2.5 text-left text-[13.5px] ${idx === i ? 'bg-moss-800/[0.08] dark:bg-moss-100/[0.08]' : ''}`}>
              <span className="opacity-50">{c.icon}</span>
              <span className="flex-1">{c.label}</span>
            </button>
          ))}
          <div className="px-3 pb-1 pt-3 text-[10.5px] font-medium uppercase tracking-[0.14em] opacity-40">{query ? 'Snippets' : 'Recent'}</div>
          {matchedSnips.map((s, j) => {
            const i = matchedCmds.length + j;
            return (
              <button key={s.id} onClick={() => go(i)} onMouseEnter={() => setIdx(i)}
                className={`flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left ${idx === i ? 'bg-moss-800/[0.08] dark:bg-moss-100/[0.08]' : ''}`}>
                <span className="w-20 shrink-0 truncate font-mono text-[11px] uppercase tracking-[0.06em] opacity-50">{s.language}</span>
                <span className="flex-1 truncate text-[13.5px]">{s.title}</span>
              </button>
            );
          })}
          {total === 0 && <p className="px-3 py-6 text-center text-[13px] opacity-50">No matches.</p>}
        </div>
      </div>
    </div>
  );
}
