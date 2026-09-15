import type { ReactNode } from 'react';
import { X } from 'lucide-react';

type ActionBtnProps = {
  icon: ReactNode;
  label: string;
  onClick: () => void;
  primary?: boolean;
  danger?: boolean;
  active?: boolean;
};

export function ActionBtn({ icon, label, onClick, primary, danger, active }: ActionBtnProps) {
  const cls = primary
    ? 'bg-moss-800 text-stone-50 hover:bg-moss-900 border-transparent dark:bg-moss-200 dark:text-moss-950 dark:hover:bg-moss-100'
    : danger
      ? 'border-clay-600/30 text-clay-600 hover:bg-clay-600/10 dark:border-clay-300/30 dark:text-clay-300 dark:hover:bg-clay-300/10'
      : active
        ? 'border-moss-600/50 bg-moss-600/10 text-moss-800 dark:border-moss-300/40 dark:bg-moss-300/10 dark:text-moss-100'
        : 'border-stone-900/10 text-stone-700 hover:bg-stone-900/[0.04] dark:border-white/10 dark:text-stone-300 dark:hover:bg-white/[0.06]';
  return (
    <button onClick={onClick} className={`flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-[13px] font-medium transition ${cls}`}>
      {icon} {label}
    </button>
  );
}

type ModalProps = {
  dark: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  wide?: boolean;
};

export function Modal({ dark, onClose, title, children, wide }: ModalProps) {
  return (
    <div className="animate-fade fixed inset-0 z-50 grid place-items-center bg-stone-950/40 p-4" onClick={onClose}>
      <div
        onClick={(e) => e.stopPropagation()}
        className={`animate-pop max-h-[85vh] w-full overflow-y-auto rounded-xl border p-6 ${wide ? 'max-w-2xl' : 'max-w-lg'} ${dark ? 'border-white/10 bg-coal' : 'border-stone-900/10 bg-cream'}`}
      >
        <div className="mb-4 flex items-center justify-between">
          <h3 className="font-serif text-[17px] font-medium tracking-tight">{title}</h3>
          <button onClick={onClose} className="rounded-md p-1.5 opacity-60 hover:bg-stone-900/5 hover:opacity-100 dark:hover:bg-white/10" aria-label="Close">
            <X size={15} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
