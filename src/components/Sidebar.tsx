import { useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { Download, FileCode2, Folder, FolderOpen, Star, X } from 'lucide-react';
import type { Collection, Snippet } from '../lib/core';
import type { View } from '../hooks/useStore';

function SideSection({ label, children, action }: { label: string; children: ReactNode; action?: ReactNode }) {
  return (
    <div className="mb-7">
      <div className="mb-2 flex items-center justify-between px-2 text-[11px] font-medium uppercase tracking-[0.14em] opacity-50">
        <span>{label}</span>{action}
      </div>
      <div className="flex flex-col gap-0.5">{children}</div>
    </div>
  );
}

function SideItem({ active, onClick, icon, label, count }: {
  active?: boolean;
  onClick: () => void;
  icon: ReactNode;
  label: string;
  count?: number;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex w-full items-center gap-2.5 rounded-lg px-2.5 py-[7px] text-left text-[13.5px] transition ${active
        ? 'bg-moss-800/[0.08] font-medium text-moss-950 dark:bg-moss-100/[0.08] dark:text-moss-50'
        : 'text-stone-600 hover:bg-stone-900/[0.04] dark:text-stone-400 dark:hover:bg-white/[0.05]'}`}
    >
      <span className="opacity-60">{icon}</span>
      <span className="flex-1 truncate">{label}</span>
      {typeof count === 'number' && (
        <span className="text-[11px] tabular-nums opacity-45">{count}</span>
      )}
    </button>
  );
}

type SidebarProps = {
  view: View;
  onView: (v: View) => void;
  snippets: Snippet[];
  collections: Collection[];
  tags: [string, number][];
  activeTag: string | null;
  onTag: (t: string | null) => void;
  onCreateCollection: (name: string) => void;
  onExportCollection: (id: string) => void;
  dark: boolean;
  mobileOpen: boolean;
  onCloseMobile: () => void;
};

export default function Sidebar({
  view, onView, snippets, collections, tags, activeTag, onTag,
  onCreateCollection, onExportCollection, dark, mobileOpen, onCloseMobile,
}: SidebarProps) {
  const [newCollName, setNewCollName] = useState('');

  const counts = useMemo(() => {
    const byColl = new Map<string, number>();
    let fav = 0;
    let unfiled = 0;
    for (const s of snippets) {
      if (s.favorite) fav++;
      if (s.collectionId) byColl.set(s.collectionId, (byColl.get(s.collectionId) ?? 0) + 1);
      else unfiled++;
    }
    return { fav, unfiled, byColl };
  }, [snippets]);

  const submitCollection = () => {
    if (!newCollName.trim()) return;
    onCreateCollection(newCollName);
    setNewCollName('');
  };

  return (
    <>
      <aside
        className={`fixed inset-y-0 left-0 z-40 w-64 transform overflow-y-auto p-5 transition-transform lg:static lg:z-auto lg:w-60 lg:shrink-0 lg:translate-x-0 lg:p-0 lg:pt-2 ${mobileOpen ? 'translate-x-0' : '-translate-x-full'} ${dark ? 'bg-ink' : 'bg-paper'} lg:bg-transparent`}
      >
        <div className="mb-4 flex items-center justify-between lg:hidden">
          <span className="font-medium">Library</span>
          <button onClick={onCloseMobile} className="rounded-md p-1.5 hover:bg-stone-900/5 dark:hover:bg-white/10" aria-label="Close menu">
            <X size={15} />
          </button>
        </div>

        <SideSection label="Library">
          <SideItem active={view === 'all' && !activeTag} onClick={() => { onView('all'); onCloseMobile(); }} icon={<FileCode2 size={14} />} label="All snippets" count={snippets.length} />
          <SideItem active={view === 'fav' && !activeTag} onClick={() => { onView('fav'); onCloseMobile(); }} icon={<Star size={14} />} label="Favorites" count={counts.fav} />
          <SideItem active={view === 'unfiled'} onClick={() => { onView('unfiled'); onCloseMobile(); }} icon={<FolderOpen size={14} />} label="Unfiled" count={counts.unfiled} />
        </SideSection>

        <SideSection
          label="Collections"
          action={
            <input
              value={newCollName}
              onChange={(e) => setNewCollName(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') submitCollection(); }}
              placeholder="New…"
              aria-label="New collection name"
              className={`w-20 rounded-md border bg-transparent px-2 py-0.5 text-[12px] normal-case tracking-normal outline-none placeholder:opacity-40 focus:border-moss-600/60 ${dark ? 'border-white/10' : 'border-stone-900/15'}`}
            />
          }
        >
          {collections.map((c) => (
            <div key={c.id} className="group flex items-center">
              <div className="flex-1">
                <SideItem
                  active={view === c.id}
                  onClick={() => { onView(c.id); onCloseMobile(); }}
                  icon={<Folder size={14} />}
                  label={c.name}
                  count={counts.byColl.get(c.id) ?? 0}
                />
              </div>
              <button title={`Export ${c.name}`} onClick={() => onExportCollection(c.id)} className="mr-1 hidden rounded p-1 opacity-40 hover:opacity-100 group-hover:block" aria-label={`Export ${c.name}`}>
                <Download size={12} />
              </button>
            </div>
          ))}
          {collections.length === 0 && (
            <p className={`px-2 text-[12px] ${dark ? 'text-stone-500' : 'text-stone-500'}`}>None yet. Type a name above, press Enter.</p>
          )}
        </SideSection>

        <SideSection label="Tags">
          <div className="flex flex-wrap gap-x-3 gap-y-1.5 px-2">
            {tags.slice(0, 24).map(([t, n]) => (
              <button
                key={t}
                onClick={() => onTag(activeTag === t ? null : t)}
                className={`text-[12.5px] transition ${activeTag === t
                  ? 'font-medium text-moss-800 underline underline-offset-4 dark:text-moss-100'
                  : 'text-stone-500 hover:text-stone-800 dark:text-stone-400 dark:hover:text-stone-200'}`}
              >
                #{t} <span className="opacity-50">{n}</span>
              </button>
            ))}
            {tags.length === 0 && <p className="text-[12px] text-stone-500">Tags appear as you add them.</p>}
          </div>
          {activeTag && (
            <button onClick={() => onTag(null)} className="mt-2 px-2 text-left text-[12px] text-stone-500 hover:underline">
              Clear filter
            </button>
          )}
        </SideSection>
      </aside>
      {mobileOpen && <div className="fixed inset-0 z-30 bg-stone-950/40 lg:hidden" onClick={onCloseMobile} />}
    </>
  );
}
