import { useMemo } from 'react';
import CodeMirror from '@uiw/react-codemirror';
import { EditorView } from '@codemirror/view';
import { langExtension } from '../lib/codeLangs';

type Props = {
  value: string;
  language: string;
  dark: boolean;
  fontSize: number;
  wordWrap: boolean;
  editable?: boolean;
  onChange?: (v: string) => void;
};

export default function CodeEditor({ value, language, dark, fontSize, wordWrap, editable = true, onChange }: Props) {
  const extensions = useMemo(() => {
    const list = [...langExtension(language)];
    list.push(
      EditorView.theme({
        '&': { backgroundColor: 'transparent' },
        '.cm-content': { fontSize: `${fontSize}px` },
        '.cm-gutters': {
          backgroundColor: 'transparent',
          borderRight: 'none',
          fontSize: `${fontSize - 1}px`,
        },
      }),
    );
    if (wordWrap) list.push(EditorView.lineWrapping);
    return list;
  }, [language, fontSize, wordWrap]);

  return (
    <CodeMirror
      value={value}
      height="100%"
      theme={dark ? 'dark' : 'light'}
      extensions={extensions}
      editable={editable}
      basicSetup={{
        lineNumbers: true,
        highlightActiveLine: true,
        highlightActiveLineGutter: true,
        foldGutter: true,
        autocompletion: false,
        searchKeymap: true,
      }}
      onChange={(v) => onChange?.(v)}
      className="h-full text-left"
    />
  );
}
