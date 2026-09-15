import { useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import {
  ChevronLeft, Copy, Eye, Folder, GitFork, History, Maximize2, MoreHorizontal,
  Pencil, Play, Share2, Star, Trash2, X,
} from 'lucide-react';
import CodeEditor from './CodeEditor';
import { ActionBtn } from './ui';
import type { Collection, Settings, Snippet } from '../lib/core';
import { extractVariables, formatDate, renderWithVariables, timeAgo } from '../lib/core';

function VersionRow({ label, active, onClick, dark, extra }: {
  label: string;
  active?: boolean;
  onClick: () => void;
  dark?: boolean;
  extra?: ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex items-center justify-between rounded-lg border px-3 py-2 text-left text-[13px] transition ${active
        ? 'border-moss-600/50 bg-moss-600/[0.08] font-medium dark:border-moss-300/40 dark:bg-moss-200/[0.08]'
        : dark ? 'border-white/10 hover:bg-white/[0.04]' : 'border-stone-900/10 hover:bg-stone-900/[0.03]'}`}
    >
      <span>{label}</span>{extra}
    </button>
  );
}

function DiffView({ oldCode, newCode, dark, language, settings }: {
  oldCode: string;
  newCode: string;
  dark: boolean;
  language: string;
  settings: Settings;
}) {
  const oldLines = oldCode.split('\n');
  const newLines = newCode.split('\n');
  const max = Math.max(oldLines.length, newLines.length);
  const changed = Array.from({ length: max }, (_, i) => i).filter((i) => oldLines[i] !== newLines[i]).length;

  return (
    <div className="mt-4">
      <p className={`mb-2 text-[12.5px] ${dark ? 'text-stone-400' : 'text-stone-500'}`}>
        {changed === 0 ? 'Identical to current.' : `${changed} line${changed === 1 ? '' : 's'} differ from current.`}
      </p>
      <div className={`max-h-64 overflow-auto rounded-lg border font-mono text-[11.5px] leading-relaxed ${dark ? 'border-white/10' : 'border-stone-900/10'}`}>
        {Array.from({ length: max }, (_, i) => {
          const o = oldLines[i];
          const n = newLines[i];
          if (o === n) {
            return (
              <div key={i} className="flex gap-3 px-3 py-0.5 opacity-45">
                <span className="w-8 shrink-0 select-none text-right">{i + 1}</span>
                <span className="whitespace-pre-wrap">{n ?? ''}</span>
              </div>
            );
          }
          return (
            <div key={i}>
              {o !== undefined && <div className="flex gap-3 bg-clay-600/10 px-3 py-0.5 dark:bg-clay-300/10"><span className="w-8 shrink-0 select-none text-right opacity-60">{i + 1}</span><span className="whitespace-pre-wrap">− {o}</span></div>}
              {n !== undefined && <div className="flex gap-3 bg-moss-600/10 px-3 py-0.5 dark:bg-moss-300/10"><span className="w-8 shrink-0 select-none text-right opacity-60">{i + 1}</span><span className="whitespace-pre-wrap">+ {n}</span></div>}
            </div>
          );
        })}
      </div>
      <div className="mt-3 h-40 overflow-hidden rounded-lg border opacity-90 dark:border-white/10">
        <CodeEditor value={newCode} language={language} dark={dark} fontSize={settings.fontSize - 1} wordWrap={settings.wordWrap} editable={false} />
      </div>
    </div>
  );
}

/** Executes JS/TS snippets in-page with a captured console; HTML renders in a sandboxed preview. */
function execute(code: string, language: string): string {
  const lang = language.toLowerCase();
  if (lang === 'html' || lang === 'xml') return '__html__';
  if (lang === 'javascript' || lang === 'typescript' || lang === 'tsx' || lang === 'jsx') {
    const logs: string[] = [];
    const fakeConsole = {
      log: (...a: unknown[]) => logs.push(a.map(String).join(' ')),
      error: (...a: unknown[]) => logs.push('ERROR: ' + a.map(String).join(' ')),
      warn: (...a: unknown[]) => logs.push('WARN: ' + a.map(String).join(' ')),
    };
    try {
      // Best-effort type-annotation stripping so TS snippets run as JS.
      const js = code.replace(/:\s*[A-Za-z_][\w<>[\]| ]*?(?=[=;,)\n])/g, '');
      const fn = new Function('console', `"use strict";\n${js}`);
      const r = fn(fakeConsole);
      if (r !== undefined) logs.push('→ ' + String(r));
      return logs.join('\n') || '(no output — code ran cleanly)';
    } catch (e) {
      return 'Error: ' + (e instanceof Error ? e.message : String(e));
    }
  }
  return 'The runner supports JavaScript, TypeScript and HTML. For other languages, copy and run locally.';
}

function MenuItem({ icon, label, danger, onClick }: { icon: ReactNode; label: string; danger?: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={`flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-left text-[13px] transition ${danger
        ? 'text-clay-600 hover:bg-clay-600/10 dark:text-clay-300 dark:hover:bg-clay-300/10'
        : 'text-stone-700 hover:bg-stone-900/[0.05] dark:text-stone-300 dark:hover:bg-white/[0.06]'}`}
    >
      <span className="opacity-60">{icon}</span> {label}
    </button>
  );
}

type SnippetDetailProps = {
  snippet: Snippet;
  collections: Collection[];
  dark: boolean;
  settings: Settings;
  onEdit: () => void;
  onDelete: () => void;
  onFork: () => void;
  onShare: () => void;
  onToggleFav: () => void;
  onCopy: (text: string, msg?: string) => void;
  onTagClick: (tag: string) => void;
  onBack: () => void;
};

/**
 * Read-only view of one snippet. Remount via key={snippet.id} to reset
 * variable inputs, version selection and runner output on navigation.
 */
export default function SnippetDetail({
  snippet, collections, dark, settings,
  onEdit, onDelete, onFork, onShare, onToggleFav, onCopy, onTagClick, onBack,
}: SnippetDetailProps) {
  const [varValues, setVarValues] = useState<Record<string, string>>({});
  const [showVersions, setShowVersions] = useState(false);
  const [versionIdx, setVersionIdx] = useState<number | null>(null);
  const [runOutput, setRunOutput] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [expanded, setExpanded] = useState(false);

  const variables = useMemo(() => extractVariables(snippet.code), [snippet.code]);
  const renderedCode = useMemo(() => renderWithVariables(snippet.code, varValues), [snippet.code, varValues]);
  const collection = collections.find((c) => c.id === snippet.collectionId);

  const closeMenu = () => setMenuOpen(false);
  const menuAction = (fn: () => void) => () => { closeMenu(); fn(); };

  useEffect(() => {
    if (!expanded) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') setExpanded(false); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [expanded]);

  return (
    <div className={`animate-pop overflow-hidden rounded-2xl border ${dark ? 'border-white/[0.08] bg-coal' : 'border-stone-900/[0.08] bg-cream'}`}>
      <div className={`border-b px-6 pb-5 pt-6 sm:px-8 ${dark ? 'border-white/[0.06]' : 'border-stone-900/[0.06]'}`}>
        <div className="flex items-start gap-2">
          <button className="mt-1 rounded-md p-1.5 opacity-60 hover:bg-stone-900/5 hover:opacity-100 lg:hidden dark:hover:bg-white/10" onClick={onBack} aria-label="Back to list">
            <ChevronLeft size={17} />
          </button>
          <div className="min-w-0 flex-1">
            <div className={`flex flex-wrap items-center gap-x-2.5 gap-y-1 text-[12px] ${dark ? 'text-stone-500' : 'text-stone-500'}`}>
              <span className="font-mono uppercase tracking-[0.1em]">{snippet.language}</span>
              {collection && (
                <span className="flex items-center gap-1"><Folder size={11} className="opacity-60" />{collection.name}</span>
              )}
              <span className="flex items-center gap-1"><Eye size={11} className="opacity-60" />{snippet.views}</span>
              <span>updated {timeAgo(snippet.updatedAt)}</span>
            </div>
            <h1 className="mt-2 font-serif text-[26px] font-medium leading-snug tracking-tight">{snippet.title}</h1>
            {snippet.description && <p className={`mt-1.5 max-w-2xl text-[13.5px] leading-relaxed ${dark ? 'text-stone-400' : 'text-stone-600'}`}>{snippet.description}</p>}
            {snippet.tags.length > 0 && (
              <div className="mt-2.5 flex flex-wrap gap-x-3 gap-y-1">
                {snippet.tags.map((t) => (
                  <button key={t} onClick={() => onTagClick(t)} className={`text-[12.5px] transition ${dark ? 'text-stone-500 hover:text-stone-200' : 'text-stone-500 hover:text-stone-800'}`}>#{t}</button>
                ))}
              </div>
            )}
          </div>
          <button onClick={onToggleFav} title={snippet.favorite ? 'Remove from favorites' : 'Add to favorites'} className="rounded-md p-2 transition hover:bg-stone-900/5 dark:hover:bg-white/10" aria-label="Toggle favorite">
            <Star size={17} className={snippet.favorite ? 'fill-moss-600 text-moss-600 dark:fill-moss-300 dark:text-moss-300' : dark ? 'text-stone-500' : 'text-stone-400'} />
          </button>
        </div>

        <div className="mt-5 flex flex-wrap items-center gap-2">
          <ActionBtn primary icon={<Copy size={13} />} label="Copy" onClick={() => onCopy(renderedCode)} />
          <ActionBtn icon={<Pencil size={13} />} label="Edit" onClick={onEdit} />
          <ActionBtn icon={<Maximize2 size={13} />} label="Expand" onClick={() => setExpanded(true)} />
          <div className="relative">
            <ActionBtn icon={<MoreHorizontal size={14} />} label="More" onClick={() => setMenuOpen((v) => !v)} active={menuOpen} />
            {menuOpen && (
              <>
                <div className="fixed inset-0 z-10" onClick={closeMenu} />
                <div className={`absolute left-0 z-20 mt-1.5 w-48 rounded-lg border p-1.5 ${dark ? 'border-white/10 bg-coal' : 'border-stone-900/10 bg-cream'}`}>
                  <MenuItem icon={<Play size={13} />} label="Run" onClick={menuAction(() => setRunOutput(execute(renderedCode, snippet.language)))} />
                  <MenuItem icon={<GitFork size={13} />} label="Duplicate" onClick={menuAction(onFork)} />
                  <MenuItem icon={<Share2 size={13} />} label="Share link" onClick={menuAction(onShare)} />
                  <MenuItem icon={<History size={13} />} label={`History (${snippet.versions.length})`} onClick={menuAction(() => { setShowVersions((v) => !v); setVersionIdx(null); })} />
                  <div className={`my-1.5 border-t ${dark ? 'border-white/10' : 'border-stone-900/10'}`} />
                  <MenuItem icon={<Trash2 size={13} />} label="Delete" danger onClick={menuAction(onDelete)} />
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {variables.length > 0 && (
        <div className={`border-b px-6 py-5 sm:px-8 ${dark ? 'border-white/[0.06] bg-moss-200/[0.04]' : 'border-stone-900/[0.06] bg-moss-800/[0.04]'}`}>
          <div className="mb-3 text-[11px] font-medium uppercase tracking-[0.14em] opacity-50">Variables</div>
          <div className="grid max-w-2xl gap-2.5 sm:grid-cols-2">
            {variables.map((v) => (
              <label key={v} className="flex items-center gap-2.5 text-[13px]">
                <code className={`shrink-0 rounded px-1.5 py-0.5 font-mono text-[12px] ${dark ? 'bg-white/[0.07] text-moss-100' : 'bg-stone-900/[0.05] text-moss-900'}`}>{v}</code>
                <input
                  value={varValues[v] ?? ''}
                  onChange={(e) => setVarValues((p) => ({ ...p, [v]: e.target.value }))}
                  placeholder="value…"
                  className={`w-full rounded-lg border bg-transparent px-3 py-1.5 text-[13px] outline-none placeholder:opacity-40 focus:border-moss-600/60 ${dark ? 'border-white/10' : 'border-stone-900/10'}`}
                />
              </label>
            ))}
          </div>
        </div>
      )}

      <div className="h-[400px] px-4 py-4 sm:h-[460px] sm:px-5">
        <CodeEditor value={renderedCode} language={snippet.language} dark={dark} fontSize={settings.fontSize} wordWrap={settings.wordWrap} editable={false} />
      </div>

      {runOutput !== null && (
        <div className={`mx-4 mb-4 overflow-hidden rounded-lg border sm:mx-5 ${dark ? 'border-white/10 bg-stone-950' : 'border-stone-900/10 bg-stone-900'}`}>
          <div className="flex items-center justify-between px-4 py-2.5 text-[12px] font-medium text-stone-400">
            <span>Output</span>
            <button onClick={() => setRunOutput(null)} className="rounded p-1 hover:bg-white/10" aria-label="Close output"><X size={13} /></button>
          </div>
          {runOutput === '__html__' ? (
            <iframe title="preview" srcDoc={renderedCode} sandbox="allow-scripts" className="h-64 w-full bg-white" />
          ) : (
            <pre className="max-h-56 overflow-auto px-4 pb-4 font-mono text-[12px] leading-relaxed text-stone-300">{runOutput}</pre>
          )}
        </div>
      )}

      {showVersions && (
        <div className={`border-t px-6 py-5 sm:px-8 ${dark ? 'border-white/[0.06]' : 'border-stone-900/[0.06]'}`}>
          <h3 className="mb-3 text-[11px] font-medium uppercase tracking-[0.14em] opacity-50">History</h3>
          {snippet.versions.length === 0 && (
            <p className={`text-[12.5px] ${dark ? 'text-stone-500' : 'text-stone-500'}`}>No older versions. Edits are saved here automatically.</p>
          )}
          <div className="flex max-w-xl flex-col gap-1.5">
            <VersionRow label={`Current version · ${formatDate(snippet.updatedAt)}`} active={versionIdx === null} onClick={() => setVersionIdx(null)} dark={dark} />
            {[...snippet.versions].reverse().map((v, ri) => {
              const idx = snippet.versions.length - 1 - ri;
              return (
                <VersionRow
                  key={idx}
                  label={`Version ${idx + 1} · ${formatDate(v.at)} · ${v.code.split('\n').length} lines`}
                  active={versionIdx === idx}
                  onClick={() => setVersionIdx(idx)}
                  dark={dark}
                  extra={<button onClick={(e) => { e.stopPropagation(); onCopy(v.code, 'Version copied'); }} className="rounded p-1 opacity-50 hover:opacity-100" aria-label="Copy this version"><Copy size={12} /></button>}
                />
              );
            })}
          </div>
          {versionIdx !== null && snippet.versions[versionIdx] && (
            <DiffView oldCode={snippet.versions[versionIdx].code} newCode={snippet.code} dark={dark} language={snippet.language} settings={settings} />
          )}
        </div>
      )}

      {expanded && (
        <div className="fixed inset-0 z-50 p-3 sm:p-8" role="dialog" aria-modal="true" aria-label={`${snippet.title}, expanded view`}>
          <div className="absolute inset-0 bg-stone-950/55" onClick={() => setExpanded(false)} />
          <div className={`animate-pop relative mx-auto flex h-full max-w-5xl flex-col overflow-hidden rounded-2xl border ${dark ? 'border-white/10 bg-coal' : 'border-stone-900/10 bg-cream'}`}>
            <div className={`flex items-center gap-3 border-b px-5 py-3.5 ${dark ? 'border-white/[0.07]' : 'border-stone-900/[0.07]'}`}>
              <span className="shrink-0 font-mono text-[11px] uppercase tracking-[0.1em] opacity-50">{snippet.language}</span>
              <span className="min-w-0 flex-1 truncate font-serif text-[16px] font-medium tracking-tight">{snippet.title}</span>
              <button
                onClick={() => onCopy(renderedCode)}
                title="Copy code"
                aria-label="Copy code"
                className="rounded-md p-2 opacity-60 transition hover:bg-stone-900/5 hover:opacity-100 dark:hover:bg-white/10"
              >
                <Copy size={15} />
              </button>
              <button
                onClick={() => setExpanded(false)}
                title="Close (Esc)"
                aria-label="Close expanded view"
                className="rounded-md p-2 opacity-60 transition hover:bg-stone-900/5 hover:opacity-100 dark:hover:bg-white/10"
              >
                <X size={16} />
              </button>
            </div>
            <div className="min-h-0 flex-1 px-4 py-4 sm:px-5">
              <CodeEditor value={renderedCode} language={snippet.language} dark={dark} fontSize={settings.fontSize} wordWrap={settings.wordWrap} editable={false} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
