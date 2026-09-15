import { useMemo, useState } from 'react';
import { AlertTriangle, Copy, Download, ExternalLink, Moon, Plus, Sun, Upload, Zap } from 'lucide-react';
import { Modal } from './ui';
import type { Settings, Snippet } from '../lib/core';
import { decodeShare, detectLanguage, formatBytes, uid } from '../lib/core';

/* ---------- welcome ---------- */

export function WelcomeCard({ dark, onNew, onCapture }: { dark: boolean; onNew: () => void; onCapture: () => void }) {
  return (
    <div className={`animate-pop rounded-2xl border px-8 py-16 text-center sm:py-20 ${dark ? 'border-white/[0.08] bg-coal' : 'border-stone-900/[0.08] bg-cream'}`}>
      <h2 className="mx-auto max-w-md font-serif text-[28px] font-medium leading-snug tracking-tight">A quiet place for code you reuse</h2>
      <p className={`mx-auto mt-3 max-w-sm text-[13.5px] leading-relaxed ${dark ? 'text-stone-400' : 'text-stone-500'}`}>
        Everything stays in this browser. Capture a snippet, find it with <kbd className="key">Ctrl K</kbd>, copy it, carry on.
      </p>
      <div className="mt-7 flex justify-center gap-2.5">
        <button onClick={onNew} className="flex items-center gap-1.5 rounded-lg bg-moss-800 px-4 py-2.5 text-[13.5px] font-medium text-stone-50 hover:bg-moss-900 dark:bg-moss-200 dark:text-moss-950 dark:hover:bg-moss-100"><Plus size={14} /> New snippet</button>
        <button onClick={onCapture} className={`flex items-center gap-1.5 rounded-lg border px-4 py-2.5 text-[13.5px] font-medium ${dark ? 'border-white/10 hover:bg-white/[0.05]' : 'border-stone-900/10 hover:bg-stone-900/[0.03]'}`}><Zap size={14} /> Quick capture</button>
      </div>
    </div>
  );
}

/* ---------- quick capture ---------- */

export function QuickCapture({ dark, onClose, onSave }: { dark: boolean; onClose: () => void; onSave: (code: string) => void }) {
  const [code, setCode] = useState('');
  const detected = code.trim() ? detectLanguage(code) : null;

  return (
    <div className="animate-fade fixed inset-0 z-50 grid place-items-center bg-stone-950/40 p-4" onClick={onClose}>
      <div onClick={(e) => e.stopPropagation()} className={`animate-pop w-full max-w-xl overflow-hidden rounded-xl border ${dark ? 'border-white/10 bg-coal' : 'border-stone-900/10 bg-cream'}`}>
        <div className="px-6 pt-5">
          <div className="font-serif text-[17px] font-medium tracking-tight">Quick capture</div>
          <p className="mt-0.5 text-[12.5px] opacity-50">Paste now, organize later.</p>
        </div>
        <div className="p-5 pt-4">
          <textarea
            value={code}
            onChange={(e) => setCode(e.target.value)}
            autoFocus
            rows={9}
            aria-label="Code to capture"
            placeholder="Paste code here…"
            className={`w-full resize-y rounded-lg border bg-transparent p-4 font-mono text-[13px] leading-relaxed outline-none placeholder:opacity-40 focus:border-moss-600/60 ${dark ? 'border-white/10' : 'border-stone-900/10'}`}
          />
          <div className="mt-2 min-h-5 text-[12.5px]">
            {detected
              ? <span className={dark ? 'text-stone-400' : 'text-stone-500'}>Detected as <span className="font-mono text-[12px] uppercase tracking-[0.08em]">{detected}</span>. Title and tags will be suggested.</span>
              : <span className="opacity-45">The language will be detected automatically.</span>}
          </div>
          <div className="mt-3 flex justify-end gap-2">
            <button onClick={onClose} className={`rounded-lg border px-4 py-2 text-[13px] font-medium ${dark ? 'border-white/10 hover:bg-white/[0.05]' : 'border-stone-900/10 hover:bg-stone-900/[0.03]'}`}>Cancel</button>
            <button onClick={() => code.trim() && onSave(code)} disabled={!code.trim()} className="rounded-lg bg-moss-800 px-5 py-2 text-[13px] font-medium text-stone-50 hover:bg-moss-900 disabled:opacity-40 dark:bg-moss-200 dark:text-moss-950 dark:hover:bg-moss-100">Save snippet</button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ---------- share (outgoing) ---------- */

export function ShareDialog({ dark, shareUrl, onCopy, onClose }: {
  dark: boolean;
  shareUrl: string;
  onCopy: (text: string, msg?: string) => void;
  onClose: () => void;
}) {
  const long = shareUrl.length > 6000;
  return (
    <Modal dark={dark} onClose={onClose} title="Share link">
      <p className={`text-[13.5px] leading-relaxed ${dark ? 'text-stone-400' : 'text-stone-600'}`}>
        This link contains the snippet itself, compressed. Nothing is uploaded anywhere — whoever opens it can read it and save a copy to their own library.
      </p>
      <div className={`mt-4 break-all rounded-lg border p-3.5 font-mono text-[11px] leading-relaxed ${dark ? 'border-white/10 bg-stone-950 text-stone-400' : 'border-stone-900/10 bg-stone-900/[0.03] text-stone-600'}`}>{shareUrl}</div>
      <p className={`mt-2.5 text-[12px] ${dark ? 'text-stone-500' : 'text-stone-500'}`}>
        {shareUrl.length} characters{long ? '. Very long links can break in some apps — use Export for large snippets.' : '.'}
      </p>
      <div className="mt-4 flex gap-2">
        <button onClick={() => onCopy(shareUrl, 'Share link copied')} className="flex items-center gap-1.5 rounded-lg bg-moss-800 px-4 py-2 text-[13px] font-medium text-stone-50 hover:bg-moss-900 dark:bg-moss-200 dark:text-moss-950 dark:hover:bg-moss-100"><Copy size={13} /> Copy link</button>
        <a href={shareUrl} target="_blank" rel="noreferrer" className={`flex items-center gap-1.5 rounded-lg border px-4 py-2 text-[13px] font-medium ${dark ? 'border-white/10 hover:bg-white/[0.05]' : 'border-stone-900/10 hover:bg-stone-900/[0.03]'}`}>Open <ExternalLink size={13} /></a>
      </div>
    </Modal>
  );
}

/* ---------- share (incoming) ---------- */

export function IncomingShare({ encoded, dark, onDismiss, onSave }: {
  encoded: string;
  dark: boolean;
  onDismiss: () => void;
  onSave: (s: Snippet) => void;
}) {
  const payload = decodeShare(encoded);
  if (!payload) {
    return (
      <Modal dark={dark} onClose={onDismiss} title="Broken share link">
        <p className="text-[13.5px] opacity-70">This link does not contain a valid snippet. It may have been truncated by the app that sent it.</p>
        <button onClick={onDismiss} className="mt-4 rounded-lg border px-4 py-2 text-[13px] font-medium">Close</button>
      </Modal>
    );
  }
  return (
    <Modal dark={dark} onClose={onDismiss} title="Shared snippet">
      <div className={`rounded-lg border p-4 ${dark ? 'border-white/10 bg-white/[0.02]' : 'border-stone-900/10 bg-white'}`}>
        <div className="flex items-baseline gap-2.5">
          <span className="font-mono text-[11px] uppercase tracking-[0.08em] opacity-50">{payload.l || 'code'}</span>
          <span className="font-serif text-[17px] font-medium">{payload.t || 'Untitled'}</span>
        </div>
        {payload.d && <p className="mt-1 text-[13px] opacity-70">{payload.d}</p>}
        <pre className={`mt-3 max-h-56 overflow-auto rounded-lg p-3.5 font-mono text-[11.5px] leading-relaxed ${dark ? 'bg-stone-950' : 'bg-stone-900 text-stone-200'}`}>{payload.c}</pre>
        {(payload.g ?? []).length > 0 && (
          <div className="mt-2.5 flex gap-3">{(payload.g ?? []).map((t) => <span key={t} className="text-[12px] opacity-55">#{t}</span>)}</div>
        )}
      </div>
      <div className="mt-4 flex gap-2">
        <button
          onClick={() => {
            const n = Date.now();
            onSave({
              id: uid(),
              title: payload.t || 'Shared snippet',
              code: payload.c,
              language: payload.l || 'plaintext',
              description: payload.d || '',
              tags: payload.g ?? [],
              collectionId: null,
              favorite: false,
              createdAt: n,
              updatedAt: n,
              views: 0,
              versions: [],
            });
          }}
          className="rounded-lg bg-moss-800 px-4 py-2 text-[13px] font-medium text-stone-50 hover:bg-moss-900 dark:bg-moss-200 dark:text-moss-950 dark:hover:bg-moss-100"
        >
          Save to my library
        </button>
        <button onClick={onDismiss} className={`rounded-lg border px-4 py-2 text-[13px] font-medium ${dark ? 'border-white/10' : 'border-stone-900/10'}`}>Not now</button>
      </div>
    </Modal>
  );
}

/* ---------- settings ---------- */

function StatsGrid({ snippets, tags, dark }: { snippets: Snippet[]; tags: [string, number][]; dark: boolean }) {
  const langs = useMemo(() => {
    const m = new Map<string, number>();
    for (const s of snippets) m.set(s.language, (m.get(s.language) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4);
  }, [snippets]);
  const totalViews = snippets.reduce((a, s) => a + s.views, 0);
  const cell = `rounded-lg border px-3.5 py-3 ${dark ? 'border-white/10 bg-white/[0.02]' : 'border-stone-900/10 bg-white'}`;
  return (
    <div className="grid grid-cols-2 gap-2 text-[13px]">
      <div className={cell}><div className="font-serif text-[20px]">{snippets.length}</div><div className="text-[12px] opacity-55">snippets</div></div>
      <div className={cell}><div className="font-serif text-[20px]">{totalViews}</div><div className="text-[12px] opacity-55">local opens</div></div>
      <div className={`${cell} col-span-2`}><div className="font-medium">Top languages</div><div className="mt-0.5 text-[12.5px] opacity-60">{langs.map(([l, n]) => `${l} (${n})`).join('  ·  ') || '—'}</div></div>
      <div className={`${cell} col-span-2`}><div className="font-medium">Top tags</div><div className="mt-0.5 text-[12.5px] opacity-60">{tags.slice(0, 5).map(([t, n]) => `#${t} (${n})`).join('  ·  ') || '—'}</div></div>
    </div>
  );
}

export function SettingsDialog({ dark, onToggleTheme, settings, onFontSize, onToggleWrap, snippets, tags, storageUsed, onExportAll, onImportClick, onClearAll, onClose }: {
  dark: boolean;
  onToggleTheme: () => void;
  settings: Settings;
  onFontSize: (v: number) => void;
  onToggleWrap: () => void;
  snippets: Snippet[];
  tags: [string, number][];
  storageUsed: number;
  onExportAll: () => void;
  onImportClick: () => void;
  onClearAll: () => void;
  onClose: () => void;
}) {
  const [confirmClear, setConfirmClear] = useState(false);

  return (
    <Modal dark={dark} onClose={onClose} title="Settings" wide>
      <div className="grid gap-8 sm:grid-cols-2">
        <div>
          <h4 className="mb-3 text-[11px] font-medium uppercase tracking-[0.14em] opacity-50">Appearance</h4>
          <div className="flex flex-col gap-3 text-[13.5px]">
            <div className="flex items-center justify-between gap-3">Theme
              <button onClick={onToggleTheme} className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 font-medium ${dark ? 'border-white/10 hover:bg-white/[0.05]' : 'border-stone-900/10 hover:bg-stone-900/[0.03]'}`}>
                {dark ? <><Moon size={13} /> Dark</> : <><Sun size={13} /> Light</>}
              </button>
            </div>
            <div className="flex items-center justify-between gap-3">Font size <span className="font-mono text-[12px] opacity-60">{settings.fontSize.toFixed(1)}px</span></div>
            <input type="range" min={11} max={18} step={0.5} value={settings.fontSize} onChange={(e) => onFontSize(Number(e.target.value))} className="w-full accent-moss-700 dark:accent-moss-300" aria-label="Editor font size" />
            <div className="flex items-center justify-between gap-3">Word wrap
              <button onClick={onToggleWrap} className={`rounded-full px-3 py-1 text-[12px] font-medium ${settings.wordWrap ? 'bg-moss-800/10 text-moss-800 dark:bg-moss-100/10 dark:text-moss-100' : dark ? 'bg-white/10 text-stone-400' : 'bg-stone-900/5 text-stone-500'}`}>{settings.wordWrap ? 'On' : 'Off'}</button>
            </div>
          </div>
          <h4 className="mb-3 mt-7 text-[11px] font-medium uppercase tracking-[0.14em] opacity-50">Statistics</h4>
          <StatsGrid snippets={snippets} tags={tags} dark={dark} />
        </div>
        <div>
          <h4 className="mb-3 text-[11px] font-medium uppercase tracking-[0.14em] opacity-50">Data</h4>
          <div className={`rounded-lg border p-4 text-[13.5px] ${dark ? 'border-white/10 bg-white/[0.02]' : 'border-stone-900/10 bg-white'}`}>
            <div className="flex justify-between"><span className="opacity-60">Snippets</span><span className="tabular-nums">{snippets.length}</span></div>
            <div className="mt-1.5 flex justify-between"><span className="opacity-60">Storage used</span><span className="tabular-nums">{formatBytes(storageUsed)}</span></div>
            <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-stone-900/10 dark:bg-white/10">
              <div className="h-full rounded-full bg-moss-600 dark:bg-moss-300" style={{ width: `${Math.min(100, (storageUsed / (4.5 * 1024 * 1024)) * 100)}%` }} />
            </div>
            <p className="mt-2 text-[12px] opacity-55">Local storage holds about 5 MB. Export a backup from time to time.</p>
          </div>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <button onClick={onExportAll} className="flex items-center justify-center gap-1.5 rounded-lg border px-3 py-2 text-[13px] font-medium hover:bg-stone-900/[0.03] dark:border-white/10 dark:hover:bg-white/[0.05]"><Download size={13} /> Export all</button>
            <button onClick={onImportClick} className="flex items-center justify-center gap-1.5 rounded-lg border px-3 py-2 text-[13px] font-medium hover:bg-stone-900/[0.03] dark:border-white/10 dark:hover:bg-white/[0.05]"><Upload size={13} /> Import</button>
          </div>
          {!confirmClear ? (
            <button onClick={() => setConfirmClear(true)} className="mt-2 flex w-full items-center justify-center gap-1.5 rounded-lg border border-clay-600/30 px-3 py-2 text-[13px] font-medium text-clay-600 hover:bg-clay-600/[0.07] dark:border-clay-300/30 dark:text-clay-300"><AlertTriangle size={13} /> Clear local data</button>
          ) : (
            <div className="mt-2 rounded-lg border border-clay-600/40 bg-clay-600/[0.07] p-3.5 text-[13px] dark:border-clay-300/30 dark:bg-clay-300/[0.07]">
              <p className="font-medium text-clay-600 dark:text-clay-300">Delete all {snippets.length} snippets on this device? Export a backup first.</p>
              <div className="mt-2.5 flex gap-2">
                <button onClick={() => { onClearAll(); onClose(); }} className="rounded-md bg-clay-600 px-3 py-1.5 font-medium text-white">Delete everything</button>
                <button onClick={() => setConfirmClear(false)} className="rounded-md border px-3 py-1.5">Keep</button>
              </div>
            </div>
          )}
          <h4 className="mb-2.5 mt-7 text-[11px] font-medium uppercase tracking-[0.14em] opacity-50">Shortcuts</h4>
          <ul className={`flex flex-col gap-2 text-[13px] ${dark ? 'text-stone-400' : 'text-stone-600'}`}>
            <li className="flex justify-between">Command palette <span><kbd className="key">Ctrl</kbd> <kbd className="key">K</kbd></span></li>
            <li className="flex justify-between">Save while editing <span><kbd className="key">Ctrl</kbd> <kbd className="key">S</kbd></span></li>
            <li className="flex justify-between">Close dialogs <span><kbd className="key">Esc</kbd></span></li>
          </ul>
        </div>
      </div>
    </Modal>
  );
}
