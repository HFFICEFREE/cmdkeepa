; ui_f1.asm — layout estático F1 do CmdKeepa nativo (Sidebar | Lista | Detail)
; Fonte única 9x15 via Xlib. Dados fake; DB/search interativos entram na F2.
; ASCII apenas (core font é ISO8859-1).
default rel

global ui_draw

extern platform_fill_rect
extern platform_draw_text

; Paleta (TrueColor 0xRRGGBB)
%define C_BG     0x191817
%define C_PANEL  0x201E1C
%define C_SEL    0x2E2A27
%define C_BOX    0x2A2724
%define C_BORDER 0x332F2B
%define C_TEXT   0xECE7DF
%define C_DIM    0xA8A29E
%define C_ACCENT 0xE0AF68
%define C_CODE   0xD6D0C7

%macro FILL 5
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    call platform_fill_rect wrt ..plt
%endmacro

; DTEXT x, y, color, label  (precisa de label_len via equ)
%macro DTEXT 4
    mov edi, %1
    mov esi, %2
    mov edx, %3
    lea rcx, [%4]
    mov r8d, %4_len
    call platform_draw_text wrt ..plt
%endmacro

section .data
    t_title:   db "CmdKeepa - native F1"
t_title_len equ $ - t_title
    t_hint:    db "Esc fecha"
t_hint_len equ $ - t_hint
    t_library: db "LIBRARY"
t_library_len equ $ - t_library
    t_all:     db "All snippets"
t_all_len equ $ - t_all
    t_fav:     db "Favorites"
t_fav_len equ $ - t_fav
    t_unfiled: db "Unfiled"
t_unfiled_len equ $ - t_unfiled
    t_colls:   db "COLLECTIONS"
t_colls_len equ $ - t_colls
    t_c1:      db "dotfiles"
t_c1_len equ $ - t_c1
    t_c2:      db "docker"
t_c2_len equ $ - t_c2
    t_c3:      db "sql"
t_c3_len equ $ - t_c3
    t_search:  db "Search snippets..."
t_search_len equ $ - t_search

    s1t: db "postgres docker"
s1t_len equ $ - s1t
    s1s: db "bash - docker, postgres"
s1s_len equ $ - s1s
    s2t: db "k8s port-forward"
s2t_len equ $ - s2t
    s2s: db "bash - k8s, net"
s2s_len equ $ - s2s
    s3t: db "rsync backup"
s3t_len equ $ - s3t
    s3s: db "bash - backup, files"
s3s_len equ $ - s3s
    s4t: db "jq filter users"
s4t_len equ $ - s4t
    s4s: db "jq - json, cli"
s4s_len equ $ - s4s
    s5t: db "ffmpeg to mp4"
s5t_len equ $ - s5t
    s5s: db "bash - media"
s5s_len equ $ - s5s

    d_title: db "postgres docker"
d_title_len equ $ - d_title
    d_meta:  db "bash - docker, postgres - fav"
d_meta_len equ $ - d_meta

    c1: db "# postgres local (static F1 preview)"
c1_len equ $ - c1
    c2: db "docker run -d --name pg \"
c2_len equ $ - c2
    c3: db "  -e POSTGRES_PASSWORD=secret \"
c3_len equ $ - c3
    c4: db "  -p 5432:5432 \"
c4_len equ $ - c4
    c5: db "  -v pgdata:/var/lib/postgresql/data \"
c5_len equ $ - c5
    c6: db "  postgres:16"
c6_len equ $ - c6
    c7: db "psql -h localhost -U postgres"
c7_len equ $ - c7

    t_status: db "5 snippets - 3 collections - F1 static layout"
t_status_len equ $ - t_status

section .text

; void ui_draw(void)
ui_draw:
    push rbp
    mov rbp, rsp
    ; só regs caller-saved usados; push rbp alinha — calls diretas ok

    ; --- fundo + moldura ---
    FILL 0, 0, 1280, 800, C_BG
    FILL 0, 0, 1280, 36, C_PANEL       ; topbar
    FILL 0, 772, 1280, 28, C_PANEL     ; statusbar
    FILL 0, 36, 240, 736, C_PANEL      ; sidebar
    FILL 241, 90, 359, 58, C_SEL       ; linha selecionada (lista)
    FILL 0, 70, 240, 28, C_SEL         ; item selecionado (sidebar)
    FILL 253, 48, 335, 30, C_BOX       ; search box
    FILL 240, 36, 1, 736, C_BORDER     ; divisor 1
    FILL 600, 36, 1, 736, C_BORDER     ; divisor 2
    FILL 621, 106, 639, 1, C_BORDER    ; separador do detail

    ; --- topbar / status ---
    DTEXT 16, 23, C_TEXT, t_title
    DTEXT 1183, 23, C_DIM, t_hint
    DTEXT 16, 791, C_DIM, t_status

    ; --- sidebar ---
    DTEXT 16, 60, C_DIM, t_library
    DTEXT 16, 90, C_TEXT, t_all
    DTEXT 16, 118, C_DIM, t_fav
    DTEXT 16, 146, C_DIM, t_unfiled
    DTEXT 16, 184, C_DIM, t_colls
    DTEXT 16, 214, C_DIM, t_c1
    DTEXT 16, 242, C_ACCENT, t_c2
    DTEXT 16, 270, C_DIM, t_c3

    ; --- lista ---
    DTEXT 263, 68, C_DIM, t_search
    DTEXT 261, 114, C_TEXT, s1t
    DTEXT 261, 134, C_DIM, s1s
    DTEXT 261, 172, C_TEXT, s2t
    DTEXT 261, 192, C_DIM, s2s
    DTEXT 261, 230, C_TEXT, s3t
    DTEXT 261, 250, C_DIM, s3s
    DTEXT 261, 288, C_TEXT, s4t
    DTEXT 261, 308, C_DIM, s4s
    DTEXT 261, 346, C_TEXT, s5t
    DTEXT 261, 366, C_DIM, s5s

    ; --- detail ---
    DTEXT 621, 72, C_TEXT, d_title
    DTEXT 621, 94, C_ACCENT, d_meta
    DTEXT 621, 130, C_CODE, c1
    DTEXT 621, 148, C_CODE, c2
    DTEXT 621, 166, C_CODE, c3
    DTEXT 621, 184, C_CODE, c4
    DTEXT 621, 202, C_CODE, c5
    DTEXT 621, 220, C_CODE, c6
    DTEXT 621, 256, C_TEXT, c7

    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
