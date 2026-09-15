import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Check, Copy, GitFork, Lock, Menu, Moon, Plus, Download, Upload,
  Search, Settings as SettingsIcon, Share2, Star, Sun, Terminal, Trash2, Zap,
} from 'lucide-react';
import { useStore } from './hooks/useStore';
import type { View } from './hooks/useStore';
import Sidebar from './components/Sidebar';
import SnippetList from './components/SnippetList';
import SnippetDetail from './components/SnippetDetail';
import EditorForm from './components/EditorForm';
import Palette from './components/Palette';
import type { PaletteCommand } from './components/Palette';
import { IncomingShare, QuickCapture, SettingsDialog, ShareDialog, WelcomeCard } from './components/Dialogs';
import { copyText } from './lib/clipboard';
import type { SnippetDraft } from './lib/core';
import { EMPTY_DRAFT, encodeShare, formatBytes, parseShareHash, searchSnippets } from './lib/core';

type Editing = { kind: 'new' } | { kind: 'edit' } | null;

export default function App() {
  const store = useStore();
  const { snippets, collections, settings, dark } = store;

  const [query, setQuery] = useState('');
  const [view, setView] = useState<View>('all');
  const [activeTag, setActiveTag] = useState<string | null>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [editing, setEditing] = useState<Editing>(null);

  const [paletteOpen, setPaletteOpen] = useState(false);
  const [quickOpen, setQuickOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [shareOpen, setShareOpen] = useState(false);
  const [incomingShare, setIncomingShare] = useState<string | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const fileRef = useRef<HTMLInputElement>(null);
  const toastTimer = useRef<number>(0);

  // First selection once the store is ready (seeded or restored).
  useEffect(() => {
    if (store.ready && selectedId === null && snippets.length > 0 && !editing) {
      setSelectedId(snippets[0].id);
    }
  }, [store.ready, snippets, selectedId, editing]);

  // A shared snippet link looks like #/s/<compressed-payload>.
  useEffect(() => {
    const h = parseShareHash();
    if (h) setIncomingShare(h);
  }, []);

  const showToast = useCallback((msg: string) => {
    setToast(msg);
    window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(null), 2200);
  }, []);

  const copy = useCallback(async (text: string, msg = 'Copied to clipboard') => {
    await copyText(text);
    showToast(msg);
  }, [showToast]);

  // ---------- derived ----------

  const filtered = useMemo(() => {
    let list = searchSnippets(snippets, query);
    if (view === 'fav') list = list.filter((s) => s.favorite);
    else if (view === 'unfiled') list = list.filter((s) => !s.collectionId);
    else if (view !== 'all') list = list.filter((s) => s.collectionId === view);
    if (activeTag) list = list.filter((s) => s.tags.includes(activeTag));
    return list;
  }, [snippets, query, view, activeTag]);

  const selected = useMemo(() => snippets.find((s) => s.id === selectedId) ?? null, [snippets, selectedId]);

  const collName = useCallback(
    (id: string | null) => collections.find((c) => c.id === id)?.name ?? 'Unfiled',
    [collections],
  );

  const shareUrl = useMemo(() => {
    if (!selected) return '';
    return `${window.location.origin}${window.location.pathname}#/s/${encodeShare(selected)}`;
  }, [selected]);

  const editInitial: SnippetDraft = useMemo(() => {
    if (editing?.kind === 'edit' && selected) {
      return {
        title: selected.title,
        code: selected.code,
        language: selected.language,
        description: selected.description,
        tags: selected.tags.join(', '),
        collectionId: selected.collectionId ?? '',
      };
    }
    const preset = view !== 'all' && view !== 'fav' && view !== 'unfiled' ? view : '';
    return { ...EMPTY_DRAFT, collectionId: preset };
  }, [editing, selected, view]);

  // ---------- selection & editing ----------

  const selectSnippet = useCallback((id: string) => {
    setSelectedId(id);
    setEditing(null);
    store.bumpViews(id);
  }, [store]);

  const startNew = useCallback(() => {
    setSelectedId(null);
    setEditing({ kind: 'new' });
    setSidebarOpen(false);
  }, []);

  const saveEditing = useCallback((draft: SnippetDraft) => {
    if (editing?.kind === 'new') {
      const s = store.createSnippet(draft);
      setSelectedId(s.id);
      showToast('Snippet saved');
    } else if (selectedId) {
      store.updateSnippet(selectedId, draft);
      showToast('Snippet updated');
    }
    setEditing(null);
  }, [editing, selectedId, store, showToast]);

  const cancelEditing = useCallback(() => setEditing(null), []);

  const deleteSelected = useCallback(() => {
    if (!selected) return;
    store.deleteSnippet(selected.id);
    const rest = snippets.filter((s) => s.id !== selected.id);
    setSelectedId(rest[0]?.id ?? null);
    setEditing(null);
    showToast('Snippet deleted');
  }, [selected, snippets, store, showToast]);

  const forkSelected = useCallback(() => {
    if (!selected) return;
    const dupe = store.duplicateSnippet(selected.id);
    if (dupe) {
      setSelectedId(dupe.id);
      setEditing(null);
      showToast('Duplicated. The original is untouched.');
    }
  }, [selected, store, showToast]);

  // ---------- import / export ----------

  const doExportAll = useCallback(() => {
    const n = store.exportAll();
    showToast(`Exported ${n} snippet${n === 1 ? '' : 's'}`);
  }, [store, showToast]);

  const doExportCollection = useCallback((id: string) => {
    const n = store.exportAll(id);
    showToast(`Exported ${n} snippet${n === 1 ? '' : 's'}`);
  }, [store, showToast]);

  const doImportFile = useCallback(async (file: File) => {
    try {
      const n = store.importText(await file.text());
      showToast(`Imported ${n} snippet${n === 1 ? '' : 's'}`);
    } catch {
      showToast('Import failed — invalid JSON');
    }
  }, [store, showToast]);

  const saveQuickCapture = useCallback((code: string) => {
    const s = store.createSnippet({ ...EMPTY_DRAFT, code, language: 'auto' });
    setSelectedId(s.id);
    setEditing(null);
    setQuickOpen(false);
    showToast(`Saved as ${s.language}`);
  }, [store, showToast]);

  // ---------- palette commands ----------

  const commands: PaletteCommand[] = useMemo(() => [
    { label: 'Create snippet', hint: 'new', icon: <Plus size={14} />, run: startNew },
    { label: 'Quick capture', hint: 'paste', icon: <Zap size={14} />, run: () => setQuickOpen(true) },
    { label: `Switch to ${dark ? 'light' : 'dark'} theme`, hint: 'theme', icon: dark ? <Sun size={14} /> : <Moon size={14} />, run: () => store.setDark(!dark) },
    { label: 'Export all (JSON)', hint: 'backup', icon: <Download size={14} />, run: doExportAll },
    { label: 'Import JSON', hint: 'restore', icon: <Upload size={14} />, run: () => fileRef.current?.click() },
    { label: 'Copy current snippet', hint: 'copy', icon: <Copy size={14} />, run: () => { if (selected) void copy(selected.code); } },
    { label: 'Toggle favorite', hint: 'star', icon: <Star size={14} />, run: () => { if (selected) store.toggleFav(selected.id); } },
    { label: 'Duplicate current snippet', hint: 'duplicate', icon: <GitFork size={14} />, run: forkSelected },
    { label: 'Share current snippet', hint: 'url', icon: <Share2 size={14} />, run: () => setShareOpen(true) },
    { label: 'Delete current snippet', hint: 'danger', icon: <Trash2 size={14} />, run: deleteSelected },
  ], [startNew, dark, store, doExportAll, selected, copy, forkSelected, deleteSelected]);

  // ---------- global shortcuts ----------

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const mod = e.metaKey || e.ctrlKey;
      if (mod && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setPaletteOpen((v) => !v);
      } else if (e.key === 'Escape') {
        setPaletteOpen(false);
        setQuickOpen(false);
        setSettingsOpen(false);
        setShareOpen(false);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  if (!store.ready) return null;

  const showWelcome = !selected && !editing;
  const iconBtn = `rounded-lg p-2 transition ${dark ? 'text-stone-400 hover:bg-white/[0.06] hover:text-stone-200' : 'text-stone-500 hover:bg-stone-900/[0.05] hover:text-stone-800'}`;

  return (
    <div className={`flex min-h-screen flex-col ${dark ? 'bg-ink text-stone-200' : 'bg-paper text-stone-800'}`}>
      <header className={`sticky top-0 z-30 border-b ${dark ? 'border-white/[0.07] bg-ink/90 backdrop-blur' : 'border-stone-900/[0.07] bg-paper/90 backdrop-blur'}`}>
        <div className="mx-auto flex max-w-[1400px] items-center gap-2 px-4 py-2.5 sm:gap-3 sm:px-6">
          <button className={`${iconBtn} lg:hidden`} onClick={() => setSidebarOpen(true)} aria-label="Open menu">
            <Menu size={17} />
          </button>
          <div className="flex items-center gap-2.5">
            <div className="grid h-7 w-7 place-items-center rounded-md bg-moss-800 text-stone-100 dark:bg-moss-200 dark:text-moss-950">
              <Terminal size={14} />
            </div>
            <span className="font-serif text-[17px] font-medium tracking-tight">CmdKeepa</span>
          </div>

          <button
            onClick={() => setPaletteOpen(true)}
            className={`mx-auto flex w-full max-w-md items-center gap-2.5 rounded-lg border px-3.5 py-[7px] text-left text-[13px] transition ${dark ? 'border-white/10 bg-white/[0.03] text-stone-400 hover:bg-white/[0.06]' : 'border-stone-900/10 bg-white/60 text-stone-500 hover:bg-white'}`}
          >
            <Search size={13} className="shrink-0 opacity-50" />
            <span className="flex-1 truncate">Search…</span>
            <span className="hidden items-center gap-1 sm:flex"><kbd className="key">Ctrl</kbd><kbd className="key">K</kbd></span>
          </button>

          <div className="flex items-center gap-0.5">
            {!editing && (
              <button
                onClick={startNew}
                title="New snippet"
                aria-label="New snippet"
                className="mr-1 grid h-9 w-9 place-items-center rounded-lg bg-moss-800 text-stone-50 transition hover:bg-moss-900 dark:bg-moss-200 dark:text-moss-950 dark:hover:bg-moss-100"
              >
                <Plus size={16} />
              </button>
            )}
            <button onClick={() => setQuickOpen(true)} title="Quick capture" className={iconBtn}>
              <Zap size={16} />
            </button>
            <button onClick={() => store.setDark(!dark)} title="Toggle theme" className={iconBtn}>
              {dark ? <Sun size={16} /> : <Moon size={16} />}
            </button>
            <button onClick={() => setSettingsOpen(true)} title="Settings" className={iconBtn}>
              <SettingsIcon size={16} />
            </button>
          </div>
        </div>
      </header>

      <div className="mx-auto flex w-full max-w-[1400px] flex-1 gap-8 px-4 py-6 sm:px-6">
        <Sidebar
          view={view}
          onView={setView}
          snippets={snippets}
          collections={collections}
          tags={store.tags}
          activeTag={activeTag}
          onTag={setActiveTag}
          onCreateCollection={(name) => { store.addCollection(name); }}
          onExportCollection={doExportCollection}
          dark={dark}
          mobileOpen={sidebarOpen}
          onCloseMobile={() => setSidebarOpen(false)}
        />

        <SnippetList
          snippets={filtered}
          selectedId={selectedId}
          onSelect={selectSnippet}
          query={query}
          onQuery={setQuery}
          activeTag={activeTag}
          collectionName={collName}
          onNew={startNew}
          dark={dark}
          hiddenOnMobile={!!selectedId && !editing}
        />

        <main className={`min-w-0 flex-1 ${showWelcome ? 'hidden lg:block' : ''}`}>
          {editing ? (
            <EditorForm
              key={editing.kind + (selectedId ?? 'new')}
              initial={editInitial}
              heading={editing.kind === 'new' ? 'New snippet' : 'Edit snippet'}
              dark={dark}
              settings={settings}
              collections={collections}
              onFontSize={(v) => store.patchSettings({ fontSize: v })}
              onToggleWrap={() => store.patchSettings({ wordWrap: !settings.wordWrap })}
              onSave={saveEditing}
              onCancel={cancelEditing}
            />
          ) : selected ? (
            <SnippetDetail
              key={selected.id}
              snippet={selected}
              collections={collections}
              dark={dark}
              settings={settings}
              onEdit={() => setEditing({ kind: 'edit' })}
              onDelete={deleteSelected}
              onFork={forkSelected}
              onShare={() => setShareOpen(true)}
              onToggleFav={() => store.toggleFav(selected.id)}
              onCopy={copy}
              onTagClick={setActiveTag}
              onBack={() => setSelectedId(null)}
            />
          ) : (
            <WelcomeCard dark={dark} onNew={startNew} onCapture={() => setQuickOpen(true)} />
          )}
        </main>
      </div>

      <footer className={`border-t py-5 text-center text-[12px] ${dark ? 'border-white/[0.06] text-stone-500' : 'border-stone-900/[0.06] text-stone-500'}`}>
        <span className="inline-flex items-center gap-1.5">
          <Lock size={11} className="opacity-60" />
          Stored only in this browser · {snippets.length} snippets · {formatBytes(store.storageUsed)}
        </span>
      </footer>

      {paletteOpen && (
        <Palette
          snippets={snippets}
          dark={dark}
          onClose={() => setPaletteOpen(false)}
          onJump={selectSnippet}
          commands={commands}
          onSearch={(q) => setQuery(q)}
        />
      )}

      {quickOpen && <QuickCapture dark={dark} onClose={() => setQuickOpen(false)} onSave={saveQuickCapture} />}

      {shareOpen && selected && (
        <ShareDialog dark={dark} shareUrl={shareUrl} onCopy={copy} onClose={() => setShareOpen(false)} />
      )}

      {incomingShare && (
        <IncomingShare
          encoded={incomingShare}
          dark={dark}
          onDismiss={() => { setIncomingShare(null); window.location.hash = ''; }}
          onSave={(s) => {
            const fresh = store.saveSharedSnippet(s);
            setSelectedId(fresh.id);
            setIncomingShare(null);
            window.location.hash = '';
            showToast('Shared snippet saved to your library');
          }}
        />
      )}

      {settingsOpen && (
        <SettingsDialog
          dark={dark}
          onToggleTheme={() => store.setDark(!dark)}
          settings={settings}
          onFontSize={(v) => store.patchSettings({ fontSize: v })}
          onToggleWrap={() => store.patchSettings({ wordWrap: !settings.wordWrap })}
          snippets={snippets}
          tags={store.tags}
          storageUsed={store.storageUsed}
          onExportAll={doExportAll}
          onImportClick={() => fileRef.current?.click()}
          onClearAll={() => { store.clearAll(); setSelectedId(null); setSettingsOpen(false); showToast('Local data cleared'); }}
          onClose={() => setSettingsOpen(false)}
        />
      )}

      <input
        ref={fileRef}
        type="file"
        accept="application/json,.json"
        className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) void doImportFile(f); e.target.value = ''; }}
      />

      {toast && (
        <div className="animate-pop fixed bottom-6 left-1/2 z-50 flex -translate-x-1/2 items-center gap-2 rounded-lg bg-stone-900 px-4 py-2.5 text-[13px] text-stone-100 dark:bg-stone-200 dark:text-stone-900">
          <Check size={13} className="opacity-70" /> {toast}
        </div>
      )}
    </div>
  );
}
