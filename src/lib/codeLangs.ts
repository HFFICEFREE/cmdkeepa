import { javascript } from '@codemirror/lang-javascript';
import { python } from '@codemirror/lang-python';
import { sql } from '@codemirror/lang-sql';
import { html } from '@codemirror/lang-html';
import { css } from '@codemirror/lang-css';
import { java } from '@codemirror/lang-java';
import { rust } from '@codemirror/lang-rust';
import { php } from '@codemirror/lang-php';
import { markdown } from '@codemirror/lang-markdown';
import { yaml } from '@codemirror/lang-yaml';
import { xml } from '@codemirror/lang-xml';
import { go } from '@codemirror/lang-go';
import { json } from '@codemirror/lang-json';
import type { Extension } from '@codemirror/state';

/** Maps a snippet language id to its CodeMirror language support. */
export function langExtension(language: string): Extension[] {
  const l = language.toLowerCase();
  switch (l) {
    case 'typescript':
    case 'tsx':
      return [javascript({ typescript: true, jsx: true })];
    case 'javascript':
    case 'jsx':
      return [javascript({ typescript: false, jsx: true })];
    case 'python':
      return [python()];
    case 'sql':
      return [sql()];
    case 'html':
    case 'xml':
      return l === 'xml' ? [xml()] : [html()];
    case 'css':
      return [css()];
    case 'java':
      return [java()];
    case 'rust':
      return [rust()];
    case 'php':
      return [php()];
    case 'markdown':
      return [markdown()];
    case 'yaml':
    case 'dockerfile':
      return [yaml()];
    case 'go':
      return [go()];
    case 'json':
      return [json()];
    default:
      return [];
  }
}
