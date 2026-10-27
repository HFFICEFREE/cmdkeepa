# Native Assembly Review

Static review of `main.asm`, `db.asm`, `platform_x11.asm`, `ui_f1.asm`, `ui_f2.asm`, `rec.inc`, and `build.sh`. Line numbers refer to the current sources. Findings are ordered approximately by impact; no runtime behavior was changed while preparing this review.

## Problem
**1. Critical — live filtering can move editing and cancellation to the wrong snippet.** In `ui_f2.asm:2044-2052`, `cur_rec` resolves the target through `filt_idx[sel]` every time it is called. `ui_draw` rebuilds that filter from live-edited contents on every repaint (`ui_f2.asm:2929-2955,3018`). If editing snippet A makes it stop matching, snippet B can move into A's old filter slot; subsequent edits then modify B. The cancel path is worse: it directly indexes `filt_idx[sel]` and restores A's backups into whichever record is currently mapped there (`ui_f2.asm:1412-1453`), potentially corrupting B while leaving A modified.

## Fix
Pin the target when `begin_edit` runs, using an `edit_rec` pointer or stable record index, and use that identity for every edit helper, commit, cancel, and detail render. Keep the edited record visible while editing, or re-resolve selection by record identity after each filter rebuild. Add a regression test with two matching records where editing the first makes it leave the filter, followed by more input and Esc.

## Problem
**2. High — an existing database can be replaced by demo data.** All open failures, empty files, read failures, and parses that produce zero snippets reach `.seed` in `db.asm:287-335`; the seed is then saved over the loaded path. A valid database with an empty `snippets` array is therefore repopulated, and malformed or partially read existing data can be destroyed rather than preserved for recovery.

## Fix
Seed only on an explicit first-run condition, normally `open` returning `ENOENT`. Treat a valid empty snippets array as a successful load. Return distinct open/read/parse errors and never call `db_save` after an existing file could not be read or validated. Preserve the original file and surface the error to the UI.

## Problem
**3. High — output-buffer exhaustion is saved as successful, truncated JSON.** `emit_byte`, `emit_raw`, and `emit_esc` silently stop at `FILE_MAX` without reporting failure (`db.asm:1586-1687`). `db_save` then writes the truncated buffer, renames it over the database, and returns success (`db.asm:2064-2097`). This is reachable because the maximum in-memory data already exceeds 1 MiB, and JSON escaping can expand one byte to six.

## Fix
Make every emitter propagate overflow and abort before writing or renaming. Prefer a dynamically sized buffer based on the escaped output length, or a growable buffer. Return `-1` on exhaustion so the previous database remains intact, and add tests that force worst-case escaping and full version histories.

## Problem
**4. High — oversized input and read errors are treated as complete input.** Once 1 MiB has been read, the loop in `db.asm:296-318` exits without checking for more bytes. Read errors, including interruption, share the same `.eof` path. A truncated document can yield some records and later overwrite the complete original with partial data.

## Fix
Grow the input buffer or explicitly reject files above the limit. Use a file-size check or an additional read to distinguish an exact-fit EOF from truncation. Handle read errors separately, retry `EINTR`, and never parse a partial read as a complete document.

## Problem
**5. High — valid imports are silently truncated and can later overwrite their source.** Fixed limits in `rec.inc:4-37` cap snippets at 64, collections at 16, versions at 8, code at 4095 bytes, descriptions at 511 bytes, and other fields at fixed sizes. The parser truncates strings and skips excess records (`db.asm:444-450,539-551,1031-1044,1166-1178,1560-1573`) without recording that the import was lossy. A normal later save replaces the source with only the retained subset.

## Fix
Use dynamically sized storage where practical. If fixed limits are intentional, detect every truncation and skipped entry, report a lossy-import error, and refuse to replace the original unless the user explicitly approves a reduced export. Include the limits in import validation and tests.

## Problem
**6. High — failed saves leave failed-looking mutations active in memory.** Favorite toggling, snippet deletion, collection deletion, assignment, rename, and edit commit all mutate state before calling `db_save`; failure paths generally only display `falha ao salvar` (`ui_f2.asm:475-498,762-792,913-983,1293-1296,1558-1605,2608-2615,2744-2808`). Deleted items remain deleted in the UI, edits close, and a later unrelated successful save can persist an action the user was told had failed.

## Fix
Give mutations transactional semantics. Snapshot and roll back all affected in-memory state on failure, or maintain an explicit dirty/unsaved state with a persistent indicator and retry path. Keep editors open after failed commits and avoid adding another version on each retry.

## Problem
**7. High — snippets and collections created in the same second receive duplicate IDs.** Both generators use `sys_time`, truncate the result to 32 bits, and emit only `n-<seconds>` or `c-<seconds>` (`ui_f2.asm:669-699,793-826`). Duplicate collection IDs are especially damaging because matching and deletion use the ID, so two collections become indistinguishable and deleting one can unfile snippets associated with both.

## Fix
Generate IDs with a uniqueness guarantee, such as a cryptographically random value or a full timestamp plus a monotonic counter, and check the existing namespace before use. Apply the same scheme to snippets and collections and test multiple creations within one clock tick.

## Problem
**8. Medium — clipboard requests serve mutable record memory, not a copy-time snapshot.** Copying sets `clip_ptr` directly into `sn_recs` (`ui_f2.asm:436-452`), while later `SelectionRequest` events serve whatever bytes are then at that address (`platform_x11.asm:679-692`). Editing, deleting/compacting, or creating records can therefore make paste return modified text, another snippet, or stale bytes under the old length.

## Fix
At copy time, copy the code into a dedicated clipboard buffer of at least `REC_CODE_LEN` bytes and snapshot its length. Serve only that immutable buffer until the next copy, and clear or release it appropriately on `SelectionClear`.

## Problem
**9. Medium — fixed-width key comparisons can read beyond the JSON input.** Object parsers call `j_memeq` with lengths up to 13 without first checking the remaining input (`db.asm:815-887,1097-1110,1460-1477`). A quote near `r15` therefore causes reads past the logical buffer. `find_key_array` checks for only 12 remaining bytes, although `collections` needs 13 bytes including both quotes (`db.asm:660-678`).

## Fix
Centralize bounded key parsing. Before every comparison, require enough remaining bytes for the complete key and closing quote; for `find_key_array`, require at least `fk_len + 2` bytes from the opening quote. Add truncated-input tests at every byte boundary.

## Problem
**10. Medium — `\uXXXX` decoding corrupts valid Unicode strings.** In `db.asm:487-537`, values up to `0xFF` are emitted as one raw byte instead of UTF-8, larger values become `?`, surrogate pairs are not combined, and incomplete hexadecimal escapes are accepted. For example, `\u00e9` becomes byte `E9` rather than UTF-8 `C3 A9`, which can also make subsequently saved JSON invalid UTF-8.

## Fix
Require exactly four hexadecimal digits, combine valid surrogate pairs, encode the resulting code point as UTF-8, and reject malformed or unpaired surrogates. Test ASCII, Latin-1, BMP, supplementary characters, malformed escapes, and U+0000; use length-aware storage wherever embedded NUL is allowed.

## Problem
**11. Medium — tags are not round-trip safe.** Parsing flattens tag arrays into a comma-separated string, and saving splits that string on commas and trims spaces (`db.asm:719-794,1839-1910`). Thus `["a,b"]` becomes `["a","b"]`, meaningful edge spaces disappear, and empty tags can disturb separator placement because the initialized `first` state is not actually used.

## Fix
Store tags as structured values throughout import/export. If the flattened UI representation must remain, define a reversible escaping scheme and track first-tag state independently of accumulated output length. Add round-trip tests for commas, spaces, empty strings, quotes, and backslashes.

## Problem
**12. Medium — nested keys can be mistaken for the document's top-level arrays.** `find_key_array` scans for any matching `"snippets"` or `"collections"` key followed by an array, without tracking root-object structure (`db.asm:660-714,1146-1154,1540-1548`). An earlier nested object with the same key can cause the wrong array to be loaded.

## Fix
Parse the root object structurally and descend only into its direct `snippets` and `collections` members. At minimum, track object depth and ignore nested keys. Test documents containing decoy keys in nested objects and strings.

## Problem
**13. Medium — repeated loads inherit stale fields from previous records.** `parse_doc` and `parse_colls` reset counts but do not clear record, version, or collection slots (`db.asm:1147-1175,1541-1566`). On a second `db_load`, omitted fields can retain IDs, descriptions, timestamps, versions, or collection data from the prior document. Default title/language writes also do not explicitly append NUL terminators (`db.asm:1067-1079`). The current startup calls `db_load` once, so this is latent in the present flow but broken for the exported reload-capable API.

## Fix
Clear each complete slot immediately before parsing it, including version slots and collection metadata, or clear all record storage at load start. Explicitly NUL-terminate default strings and add two consecutive-load tests with disjoint field sets.

## Problem
**14. Medium — JSON numbers are transformed instead of validated.** `parse_u64` consumes a minus sign without applying it, accepts a non-JSON leading plus, wraps on overflow, returns zero when no digits exist, and does not validate the complete token (`db.asm:387-412`). `views` is additionally reduced to 32 bits at `db.asm:1004-1010`.

## Fix
Implement bounded JSON-number parsing with complete-token and overflow checks. Reject unsupported negative or fractional values rather than changing them, and either widen `views` or reject values above its representable range.

## Problem
**15. Medium — path handling mutates a `const` argument and silently accepts unsaveable paths.** `db_prepare_dir` temporarily replaces the final slash in the caller's path with NUL (`db.asm:229-256`), despite `db_load` accepting `const char *`; a read-only string containing a slash can fault. Separately, the load-path copy stops without a terminator at its cap (`db.asm:273-285`), so a long path can load successfully but every later save fails.

## Fix
Copy and validate the path first, then operate only on writable storage. Construct the parent directory in a separate buffer instead of modifying the input. Reject overlong paths before changing state, or use dynamically allocated path strings.

## Problem
**16. Medium — temporary-file replacement is unsafe with concurrent savers and can weaken permissions.** Every save opens the same predictable `<path>.tmp` with `O_TRUNC` (`db.asm:1731-1756`). Two processes can modify the same inode, and symlink clobbering is possible in an untrusted directory. The new file mode `0644`, followed by rename, can also replace a private `0600` database with a more broadly readable one.

## Fix
Create a unique temporary file in the same directory using exclusive, no-follow semantics, with `0600` as the safe default or explicit preservation of the existing mode and ownership. Add interprocess locking or a single-writer policy, and unlink temporary files on every failure path.

## Problem
**17. Medium — durability failures are ignored before rename.** `db_save` discards the results of `fsync` and `close` and proceeds to rename (`db.asm:2080-2097`). It can therefore report success after synchronization failed. There is also no parent-directory `fsync` after rename, so the directory entry is not covered by the claimed crash durability.

## Fix
Check `fsync` and `close`; on failure, do not rename and return `-1`. Retry interrupted syscalls as appropriate, clean up the temporary file, and `fsync` the parent directory after a successful rename where supported.

## Problem
**18. Medium — native timestamps use seconds while the web format uses milliseconds.** `sys_time` is used for created/updated/exported timestamps in `db.asm:1308-1312,1409-1412,1765-1768` and `ui_f2.asm:670-673,797-800,1573-1576,2761-2764`. The web application uses `Date.now()`, so native-created records interpreted by the web UI can appear to date from 1970 and sorting/time displays use incompatible scales.

## Fix
Introduce one shared realtime helper based on `clock_gettime` that returns Unix milliseconds, and use it at every native timestamp creation site. Keep the stored unit consistent throughout import/export and add native-to-web interoperability tests.

## Problem
**19. Medium — several callable routines violate register-preservation and stack-alignment contracts.** `db_load` writes `r15` without saving it (`db.asm:262-343`), `app_on_key` uses `rbx` and `r12` without preserving them (`ui_f2.asm:307-1465`), and `itoa` clobbers `rbx` (`ui_f2.asm:2965-3003`). Numerous call sites also have `rsp % 16 == 8` immediately before `call`, including `db_save` and several UI helpers (`db.asm:1721-1729`; `ui_f2.asm:1471-1475,2013-2017,2059-2063,2672-2675,2745-2749`). Current callers often happen not to depend on the corrupted state, but these are latent ABI failures.

## Fix
Save and restore every callee-saved register used by each routine, including all early-return paths. Audit every prologue so `rsp % 16 == 0` before each call, adjusting epilogues symmetrically. Replace misleading alignment comments with a systematic convention and add small ABI harness tests that seed callee-saved registers and verify stack alignment.

## Problem
**20. Medium — `seed_one`'s capacity return corrupts the stack.** When `sn_count >= MAX_SNIPPETS`, execution jumps to `.ret` before `sub rsp,32`, but the common epilogue still executes `add rsp,32` (`db.asm:1204-1214,1316-1324`). It then pops registers from incorrect locations. The current builtin caller seeds only three records, so the branch is latent rather than normally reachable.

## Fix
Use separate early and normal epilogues, or reserve the spill area before the capacity branch. Add a direct unit test that calls `seed_one` at capacity and verifies the return address, stack pointer, and preserved registers.

## Problem
**21. Medium — metadata-only and no-op commits create duplicate versions.** Every edit commit shifts history and inserts `edit_backup`, even when the code is unchanged or no field changed (`ui_f2.asm:2744-2805`). Title-only edits therefore add duplicate code snapshots, repeated no-op commits evict useful history, and a new snippet's first commit can record an empty initial version.

## Fix
Compare current code length and bytes with `edit_backup` before shifting versions. Push a version only for an actual code change, while still allowing real metadata changes to update `updatedAt` and save. Skip the empty pre-creation snapshot for new records and avoid duplicate versions on save retries.

## Problem
**22. Medium — version history cannot preserve complete native revisions or web notes.** Current code can contain 4095 bytes, but `VER_CODE_LEN` is 2048 and commit explicitly truncates the backup to 2047 bytes (`rec.inc:8,29-32`; `ui_f2.asm:2787-2799`). The parser and writer also retain only `code` and `at`, discarding the web model's optional version `note` (`db.asm:1083-1144,1980-1998`).

## Fix
Make version storage at least as large as current-code storage, derive `REC_SIZE` from the layout, and replace the hardcoded timestamp offset `2048` with a named constant. Add note storage and parser/writer support if native saves are expected to be lossless for web exports.

## Problem
**23. Medium — `code_scroll` leaks between selected records.** Selection changes through arrows, wheel, and mouse do not reset `code_scroll` (`ui_f2.asm:419-430,547-552`), while the renderer applies it to every selected record even outside editing (`ui_f2.asm:3421-3441`). After scrolling deeply in one snippet, a shorter snippet can open midway through its contents or render no code.

## Fix
Associate the scroll position with a record identity and reset it whenever the selected record changes. Alternatively, use it only while editing the corresponding record and always render normal read-only details from line zero.

## Problem
**24. Medium — CRLF and CR-only code are rendered differently from how they are edited.** Drawing treats both CR and LF as terminators but advances over only one byte, so CRLF produces an extra empty displayed line (`ui_f2.asm:3426-3478`). Cursor movement, line calculations, and scrolling recognize only LF (`ui_f2.asm:1478-1512,2123-2183,3489-3518`), causing display and edit positions to diverge.

## Fix
Use one shared line-delimiter policy. Either normalize CRLF to LF when loading/editing, or make rendering, scrolling, navigation, and cursor calculations recognize CRLF as one terminator and handle CR consistently. Add round-trip and cursor tests for LF, CRLF, and CR input.

## Problem
**25. Medium — language/tags rendering and hit-testing disagree for long custom languages.** Detail rendering clamps language length to 24 before positioning the separator and tags (`ui_f2.asm:3338-3364`), but `lt_pick` and the tags caret use the full length, which can be 31 (`ui_f2.asm:1765-1814,3400-3412`). Clicking visible tags can select the language field, and the caret appears shifted from the text.

## Fix
Centralize detail-line layout calculation and use the same displayed language width in rendering, hit-testing, and caret placement. If truncation remains, consistently use `min(llen,24)`; preferably implement horizontal scrolling from shared viewport state.

## Problem
**26. Medium — Esc does not cancel creation of a new snippet or collection.** Ctrl+N increments `sn_count` before editing and Ctrl+G increments `coll_count` before renaming (`ui_f2.asm:669-714,793-838`). Esc only restores field snapshots (`ui_f2.asm:1257-1259,1412-1458`), leaving a blank snippet or default `Nova colecao` collection in memory that a later save can persist, despite the `edicao cancelada` message.

## Fix
Track a creating flag and remove the uncommitted new entity on Esc, or edit a temporary record and insert it only on successful commit. If immediate creation is intentional, change the cancellation message and make the surviving entity explicit.

## Problem
**27. Medium — X11 initialization can continue with a null GC and leaks partial initialization on failure.** `XCreateGC` is stored but never checked (`platform_x11.asm:211-232`), so a null GC can reach font and drawing calls while initialization reports success. Failures after `XOpenDisplay` return without closing the display (`platform_x11.asm:242-249`), and `main`'s failure path does not call `platform_shutdown` (`main.asm:37-39,63-65`).

## Fix
Check `p_gc` immediately and route every partial-initialization failure through one cleanup path that closes any open display and resets global handles. Call that cleanup internally or invoke `platform_shutdown` from `main` on failure.

## Problem
**28. Medium — WM close messages are not authenticated as `WM_PROTOCOLS`.** The client-message handler compares only `data.l[0]` with `WM_DELETE_WINDOW` (`platform_x11.asm:587-593`). It never checks `message_type` or `format`; `atom_protos_name` is defined but unused. Any client message with the same first data value can therefore trigger exit.

## Fix
Intern and store `WM_PROTOCOLS`, then require `message_type == WM_PROTOCOLS`, `format == 32`, and `data.l[0] == WM_DELETE_WINDOW`. Also verify the event window against `p_win`.

## Problem
**29. Low — Escape is decoded from a hard-coded keycode.** Keycode 9 is treated as Escape before `XLookupString` runs (`platform_x11.asm:71,400-410`). That keycode is conventional, not guaranteed; remapped keyboards can put Escape elsewhere or assign another action to keycode 9.

## Fix
Run `XLookupString` for every key press and compare the resulting KeySym with `XK_Escape` (`0xFF1B`), alongside the existing symbolic BackSpace, Return, and navigation checks.

## Problem
**30. Low — several X11 selection protocol edge cases are handled incorrectly.** A legacy request with `property=None` is passed unchanged to `XChangeProperty` instead of substituting the target atom (`platform_x11.asm:650-692`). `XA_STRING` is served the same UTF-8 bytes as `UTF8_STRING`, although `STRING` is Latin-1, and ownership always uses `CurrentTime` rather than the triggering event timestamp (`platform_x11.asm:614-625`).

## Fix
For supported requests, resolve `property=None` to the target atom before changing the property and use that value in `SelectionNotify`. Convert clipboard data to Latin-1 for `XA_STRING`, refusing or omitting that target when conversion is impossible. Pass and store the copy event's timestamp when acquiring ownership and validate request times where applicable.

## Problem
**31. Low — two smaller UI state defects remain.** Clicking the title while already editing only changes `edit_mode` and does not reposition `title_cursor` (`ui_f2.asm:1215-1217`), unlike normal-mode title clicks. The list clamp also keeps selection visible but does not cap `scroll` at `max(filt_n-ROWS_VISIBLE,0)` (`ui_f2.asm:3020-3050`), leaving avoidable blank rows after a filter shrinks.

## Fix
Factor title click-to-cursor calculation into one helper used by both mouse paths. After clamping selection, also clamp scroll to the maximum useful offset and reapply the visibility adjustment.

## Problem
**32. Enhancement — descriptions are persisted but absent from native search and editing.** The DB parses and writes `description`, but `match_rec` searches only title, language, tags, and code (`ui_f2.asm:2894-2919`), and no detail/edit mode exposes the description. Native search therefore differs from the web application's global search, and users cannot inspect or correct this stored field natively.

## Fix
Include `REC_DESC_OFF` in search, display it in the detail pane, and add it to the edit-field cycle with snapshot/cancel support. Add a native/web search-parity fixture containing a unique term only in the description.

## Problem
**33. Enhancement — text input and rendering are limited to ASCII and assumed fixed metrics.** `platform_poll` accepts only printable ASCII (`platform_x11.asm:505-530`), while JSON UTF-8 is passed raw to a core-font `XDrawString` UI. Long queries, titles, tags, and code are clipped without horizontal scrolling, and a missing `9x15` font leaves rendering with metrics that disagree with the hard-coded 9-pixel geometry (`platform_x11.asm:219-232`; `ui_f2.asm:3165-3204,3338-3364,3442-3478`).

## Fix
For localized input, migrate to XIM/XIC with `Xutf8LookupString` and Unicode-capable text rendering; account for UTF-8 character boundaries rather than treating bytes as display columns. Load/query a defined font fallback and derive geometry from actual metrics. Add horizontal scrolling or a consistent viewport for long single-line fields and code.

## Problem
**34. Low — dead dispatch logic and legacy sources make the active code path unclear.** `main.asm:46-53` compares `platform_poll`'s return value with 22, but that function returns only 0, 1, or 2; event kinds live separately in `ev_kind`, so the upper-bound check is dead. `ui_f1.asm` is a static fake-data preview not included by `build.sh`, yet it remains beside active sources and defines the same `ui_draw` symbol as `ui_f2.asm`. Several phase headers are duplicated or stale.

## Fix
Remove the dead upper-bound comparison and dispatch solely on documented poll statuses, or explicitly validate `ev_kind` after importing it. Move `ui_f1.asm` to an explicitly named archive/example location or remove it, and consolidate comments around the active implementation. Do not link both UI files together.

## Problem
**35. Enhancement — record layout and build invariants rely too heavily on manual discipline.** The offsets in `rec.inc:4-32` are arithmetically consistent now, but independent constants can silently desynchronize DB and UI code after a future field change. `build.sh:8-23` checks only NASM, does not enable assembler warnings, and there is no automated regression gate for the parser, persistence, ABI, and state-transition bugs listed above.

## Fix
Define the layout with NASM `struc` or add compile-time `%if`/`%error` assertions for derived offsets, `VER_SIZE`, `REC_SIZE`, and qword alignment. Check the compiler and required tools, enable useful NASM warnings, and add automated tests using the existing `error-utils` harness for JSON round trips, empty/malformed/oversized input, same-second creation, filter changes during editing, failed saves, and ABI preservation.

## Problem
**36. Enhancement — expose bursts cause redundant full-window repaints.** Every `Expose` immediately runs the complete UI draw and flush (`platform_x11.asm:390-393`), even when more expose rectangles are already queued. This needlessly repeats the filter rebuild and all Xlib drawing calls during window uncover and compositor activity.

## Fix
Use `XExposeEvent.count` and repaint only when it reaches zero, or coalesce pending expose events before the full redraw. Keep selection-request and other non-drawing events responsive while coalescing.
