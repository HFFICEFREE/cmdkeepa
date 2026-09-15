import { useEffect, useState } from 'react';
import CodeEditor from './CodeEditor';
import type { Collection, Settings, SnippetDraft } from '../lib/core';
import { detectLanguage, EMPTY_DRAFT, LANGUAGES } from '../lib/core';

type EditorFormProps = {
  /** Prefilled values (empty draft for create, snippet values for edit). */
  initial?: SnippetDraft;
  heading: string;
  dark: boolean;
  settings: Settings;
  collections: Collection[];
  onFontSize: (v: number) => void;
  onToggleWrap: () => void;
  onSave: (draft: SnippetDraft) => void;
  onCancel: () => void;
};

export default function EditorForm({
  initial = EMPTY_DRAFT, heading, dark, settings, collections, onFontSize, onToggleWrap, onSave, onCancel,
}: EditorFormProps) {
  const [draft, setDraft] = useState<SnippetDraft>(initial);
  const detected = draft.code.trim() ? detectLanguage(draft.code) : null;

  // Ctrl/Cmd+S saves from anywhere inside the form.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 's') {
        e.preventDefault();
        if (draft.code.trim()) onSave(draft);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [draft, onSave]);

  const fieldCls = `w-full rounded-lg border bg-transparent px-3.5 py-2.5 text-[13.5px] outline-none placeholder:opacity-40 focus:border-moss-600/60 ${dark ? 'border-white/10' : 'border-stone-900/10'}`;

  return (
    <div className={`animate-pop overflow-hidden rounded-2xl border ${dark ? 'border-white/[0.08] bg-coal' : 'border-stone-900/[0.08] bg-cream'}`}>
      <div className={`flex items-center justify-between border-b px-6 py-4 sm:px-8 ${dark ? 'border-white/[0.06]' : 'border-stone-900/[0.06]'}`}>
        <span className="font-serif text-[17px] font-medium tracking-tight">{heading}</span>
        <span className="hidden text-[12px] opacity-45 sm:block"><kbd className="key">Ctrl S</kbd> to save</span>
      </div>
      <div className="grid gap-4 px-6 py-6 sm:px-8">
        <input
          value={draft.title}
          onChange={(e) => setDraft({ ...draft, title: e.target.value })}
          placeholder="Title"
          autoFocus
          aria-label="Snippet title"
          className="w-full border-b border-stone-900/15 bg-transparent pb-2 font-serif text-[22px] font-medium tracking-tight outline-none placeholder:opacity-30 focus:border-moss-600/60 dark:border-white/15"
        />
        <div className="grid gap-3 sm:grid-cols-3">
          <label className="text-[12px] font-medium opacity-70">Language
            <select
              value={draft.language}
              onChange={(e) => setDraft({ ...draft, language: e.target.value })}
              className={`mt-1.5 w-full rounded-lg border px-3 py-2 text-[13px] outline-none ${dark ? 'border-white/10 bg-coal' : 'border-stone-900/10 bg-cream'}`}
            >
              <option value="auto">Auto-detect{detected ? ` (${detected})` : ''}</option>
              {LANGUAGES.map((l) => <option key={l} value={l}>{l}</option>)}
            </select>
          </label>
          <label className="text-[12px] font-medium opacity-70">Collection
            <select
              value={draft.collectionId}
              onChange={(e) => setDraft({ ...draft, collectionId: e.target.value })}
              className={`mt-1.5 w-full rounded-lg border px-3 py-2 text-[13px] outline-none ${dark ? 'border-white/10 bg-coal' : 'border-stone-900/10 bg-cream'}`}
            >
              <option value="">Unfiled</option>
              {collections.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </label>
          <label className="text-[12px] font-medium opacity-70">Tags, comma separated
            <input
              value={draft.tags}
              onChange={(e) => setDraft({ ...draft, tags: e.target.value })}
              placeholder="docker, postgres"
              className={`mt-1.5 ${fieldCls}`}
            />
          </label>
        </div>
        <textarea
          value={draft.description}
          onChange={(e) => setDraft({ ...draft, description: e.target.value })}
          placeholder="Notes — what is this for?"
          rows={2}
          className={`${fieldCls} resize-none`}
        />
        <div className="h-[340px] overflow-hidden rounded-lg border dark:border-white/10">
          <CodeEditor
            value={draft.code}
            language={draft.language === 'auto' ? (detected ?? 'plaintext') : draft.language}
            dark={dark}
            fontSize={settings.fontSize}
            wordWrap={settings.wordWrap}
            onChange={(v) => setDraft({ ...draft, code: v })}
          />
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <label className={`flex items-center gap-2 text-[12.5px] ${dark ? 'text-stone-400' : 'text-stone-500'}`}>
            Font size
            <input type="range" min={11} max={18} step={0.5} value={settings.fontSize} onChange={(e) => onFontSize(Number(e.target.value))} className="w-24 accent-moss-700 dark:accent-moss-300" aria-label="Editor font size" />
          </label>
          <button onClick={onToggleWrap} className={`rounded-md px-2.5 py-1.5 text-[12px] font-medium ${settings.wordWrap ? 'bg-moss-800/10 text-moss-800 dark:bg-moss-100/10 dark:text-moss-100' : 'bg-stone-900/5 dark:bg-white/10'}`}>
            Wrap {settings.wordWrap ? 'on' : 'off'}
          </button>
          <div className="ml-auto flex gap-2">
            <button onClick={onCancel} className={`rounded-lg border px-4 py-2 text-[13px] font-medium ${dark ? 'border-white/10 hover:bg-white/[0.05]' : 'border-stone-900/10 hover:bg-stone-900/[0.03]'}`}>Cancel</button>
            <button
              onClick={() => onSave(draft)}
              disabled={!draft.code.trim()}
              className="rounded-lg bg-moss-800 px-5 py-2 text-[13px] font-medium text-stone-50 transition hover:bg-moss-900 disabled:opacity-40 dark:bg-moss-200 dark:text-moss-950 dark:hover:bg-moss-100"
            >
              Save snippet
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
