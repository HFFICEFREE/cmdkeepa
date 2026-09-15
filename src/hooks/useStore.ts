import { useEffect, useMemo, useState } from 'react';
import type { Collection, Settings, Snippet, SnippetDraft } from '../lib/core';
import {
  buildExport,
  detectLanguage,
  loadCollections,
  loadSettings,
  loadSnippets,
  parseImport,
  saveCollections,
  saveSettings,
  saveSnippets,
  seedData,
  suggestTags,
  suggestTitle,
  uid,
} from '../lib/core';

/** Which library slice is shown. A bare string is a collection id. */
export type View = 'all' | 'fav' | 'unfiled' | string;

function resolveDraft(draft: SnippetDraft): Pick<Snippet, 'title' | 'code' | 'language' | 'description' | 'tags' | 'collectionId'> {
  const code = draft.code;
  const language = draft.language === 'auto' ? detectLanguage(code) : draft.language;
  const title = draft.title.trim() || suggestTitle(code, language);
  const parsed = draft.tags.split(/[,\s#]+/).map((t) => t.trim().toLowerCase()).filter(Boolean);
  const tags = parsed.length ? [...new Set(parsed)] : suggestTags(code, language);
  return {
    title,
    code,
    language,
    description: draft.description.trim(),
    tags,
    collectionId: draft.collectionId || null,
  };
}

function downloadJson(filename: string, data: unknown) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

export function useStore() {
  const [snippets, setSnippets] = useState<Snippet[]>(() => loadSnippets());
  const [collections, setCollections] = useState<Collection[]>(() => loadCollections());
  const [settings, setSettings] = useState<Settings>(() => loadSettings());
  const [dark, setDark] = useState<boolean>(() => {
    const saved = localStorage.getItem('cmdkeepa.theme');
    if (saved) return saved === 'dark';
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  });
  const [ready, setReady] = useState(false);

  // First run: seed a small, realistic library so the app doesn't open empty.
  useEffect(() => {
    if (loadSnippets().length === 0 && loadCollections().length === 0 && !localStorage.getItem('cmdkeepa.seeded')) {
      const seed = seedData();
      setSnippets(seed.snippets);
      setCollections(seed.collections);
      saveSnippets(seed.snippets);
      saveCollections(seed.collections);
      localStorage.setItem('cmdkeepa.seeded', '1');
    }
    setReady(true);
  }, []);

  useEffect(() => {
    if (ready) saveSnippets(snippets);
  }, [snippets, ready]);

  useEffect(() => {
    if (ready) saveCollections(collections);
  }, [collections, ready]);

  useEffect(() => {
    if (ready) saveSettings(settings);
  }, [settings, ready]);

  useEffect(() => {
    document.documentElement.classList.toggle('dark', dark);
    localStorage.setItem('cmdkeepa.theme', dark ? 'dark' : 'light');
  }, [dark]);

  /** Exact byte size of the persisted payload (localStorage is ~5 MB per origin). */
  const storageUsed = useMemo(
    () => JSON.stringify(snippets).length + JSON.stringify(collections).length,
    [snippets, collections],
  );

  const tags = useMemo(() => {
    const m = new Map<string, number>();
    for (const s of snippets) for (const t of s.tags) m.set(t, (m.get(t) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]) as [string, number][];
  }, [snippets]);

  // ---------- actions ----------

  function createSnippet(draft: SnippetDraft): Snippet {
    const now = Date.now();
    const s: Snippet = {
      id: uid(),
      ...resolveDraft(draft),
      favorite: false,
      createdAt: now,
      updatedAt: now,
      views: 0,
      versions: [],
    };
    setSnippets((prev) => [s, ...prev]);
    return s;
  }

  function updateSnippet(id: string, draft: SnippetDraft) {
    setSnippets((prev) =>
      prev.map((s) => {
        if (s.id !== id) return s;
        const next = resolveDraft(draft);
        const codeChanged = s.code !== next.code;
        const versions = codeChanged ? [...s.versions, { code: s.code, at: s.updatedAt }] : s.versions;
        return { ...s, ...next, updatedAt: Date.now(), versions: versions.slice(-20) };
      }),
    );
  }

  function deleteSnippet(id: string) {
    setSnippets((prev) => prev.filter((s) => s.id !== id));
  }

  function duplicateSnippet(id: string): Snippet | null {
    const s = snippets.find((x) => x.id === id);
    if (!s) return null;
    const now = Date.now();
    const copy: Snippet = { ...s, id: uid(), title: `${s.title} (copy)`, createdAt: now, updatedAt: now, views: 0, versions: [] };
    setSnippets((prev) => [copy, ...prev]);
    return copy;
  }

  /** Stores a snippet received via share link, re-iding on collision. */
  function saveSharedSnippet(s: Snippet): Snippet {
    const fresh = snippets.some((x) => x.id === s.id) ? { ...s, id: uid() } : s;
    setSnippets((prev) => [fresh, ...prev]);
    return fresh;
  }

  function toggleFav(id: string) {
    setSnippets((prev) => prev.map((s) => (s.id === id ? { ...s, favorite: !s.favorite, updatedAt: Date.now() } : s)));
  }

  function bumpViews(id: string) {
    setSnippets((prev) => prev.map((s) => (s.id === id ? { ...s, views: s.views + 1 } : s)));
  }

  function addCollection(name: string): Collection | null {
    const clean = name.trim();
    if (!clean) return null;
    const c: Collection = { id: uid(), name: clean, createdAt: Date.now() };
    setCollections((prev) => [...prev, c]);
    return c;
  }

  function exportAll(onlyCollectionId?: string): number {
    const list = onlyCollectionId ? snippets.filter((s) => s.collectionId === onlyCollectionId) : snippets;
    downloadJson(`cmdkeepa-export-${new Date().toISOString().slice(0, 10)}.json`, buildExport(list, collections));
    return list.length;
  }

  /** Parses an export file and merges it in, re-iding on collision. Returns count added. */
  function importText(text: string): number {
    const { snippets: imp, collections: impColls } = parseImport(text);
    const existingIds = new Set(snippets.map((s) => s.id));
    const fresh = imp.map((s) => (existingIds.has(s.id) ? { ...s, id: uid() } : s));
    setSnippets((prev) => [...fresh, ...prev]);
    if (impColls.length) {
      const existingC = new Set(collections.map((c) => c.id));
      setCollections((prev) => [...prev, ...impColls.filter((c) => !existingC.has(c.id))]);
    }
    return fresh.length;
  }

  function clearAll() {
    setSnippets([]);
    setCollections([]);
    localStorage.removeItem('cmdkeepa.snippets.v1');
    localStorage.removeItem('cmdkeepa.collections.v1');
  }

  function patchSettings(patch: Partial<Settings>) {
    setSettings((s) => ({ ...s, ...patch }));
  }

  return {
    ready,
    snippets,
    collections,
    settings,
    dark,
    setDark,
    tags,
    storageUsed,
    createSnippet,
    updateSnippet,
    deleteSnippet,
    duplicateSnippet,
    saveSharedSnippet,
    toggleFav,
    bumpViews,
    addCollection,
    exportAll,
    importText,
    clearAll,
    patchSettings,
  };
}

export type Store = ReturnType<typeof useStore>;
