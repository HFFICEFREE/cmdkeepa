; platform_x11.asm — backend Xlib do CmdKeepa nativo (F1)
; Responsabilidade: abrir janela, loop de eventos, primitivas de desenho, fechar.
; Desenho da UI vive em ui_f2.asm (chamado via ui_draw no repaint).
default rel
%include "rec.inc"

global platform_init
global platform_poll
global platform_paint
global platform_shutdown
global platform_fill_rect
global platform_draw_text
global platform_claim_clipboard
global ev_kind
global ev_char
global ev_btn
global ev_mx
global ev_my
global clip_ptr
global clip_len
global clip_buf
global paste_ptr
global paste_len
global paste_buf
global platform_request_paste
global dead_pending

extern XOpenDisplay
extern XDefaultScreen
extern XRootWindow
extern XCreateSimpleWindow
extern XStoreName
extern XSelectInput
extern XMapWindow
extern XCreateGC
extern XSetForeground
extern XSetFont
extern XLoadQueryFont
extern XFillRectangle
extern XDrawString
extern XFlush
extern XNextEvent
extern XCloseDisplay
extern XInternAtom
extern XSetWMProtocols
extern XLookupString
extern XSetSelectionOwner
extern XGetSelectionOwner
extern XChangeProperty
extern XSetWMNormalHints
extern XSendEvent
extern XConvertSelection
extern XGetWindowProperty
extern XDeleteProperty
extern XGetSelectionOwner
extern XFree
extern dlopen
extern dlsym
extern XDefaultVisual
extern XDefaultColormap
extern XOpenIM
extern XCreateIC
extern Xutf8LookupString
extern XSetICFocus
extern XSetLocaleModifiers
extern ui_draw

section .data
    win_title:        db "CmdKeepa", 0
    atom_delete_name: db "WM_DELETE_WINDOW", 0
    atom_protos_name: db "WM_PROTOCOLS", 0
    atom_clip_name:   db "CLIPBOARD", 0
    atom_utf8_name:   db "UTF8_STRING", 0
    atom_tgt_name:    db "TARGETS", 0
    atom_paste_name:  db "CMDKEEPA_PASTE", 0
    font_name:        db "9x15", 0
    font_alt_name:   db "9x15bold", 0
    ; Xft (F3): fontes AA via dlopen — sem dep dura, fallback p/ core acima.
    s_libxft:        db "libXft.so.2", 0
    s_xft_f1:        db "JetBrains Mono:pixelsize=15", 0
    s_xft_f2:        db "JetBrainsMono Nerd Font Mono:pixelsize=15", 0
    s_xft_f3:        db "DejaVu Sans Mono:pixelsize=15", 0
    s_xft_f4:        db "monospace:pixelsize=15", 0
    s_sym_open:      db "XftFontOpenName", 0
    s_sym_draw:      db "XftDrawCreate", 0
    s_sym_str:       db "XftDrawStringUtf8", 0
    s_sym_ext:       db "XftTextExtentsUtf8", 0
    s_sym_col:       db "XftColorAllocName", 0
    s_col_text:      db "rgb:EC/E7/DF", 0
    s_col_dim:       db "rgb:A8/A2/9E", 0
    s_col_accent:    db "rgb:C9/D2/C2", 0
    s_col_code:      db "rgb:D6/D0/C7", 0
    s_digits:        db "0123456789", 0
    ; XIM (F4): nomes XN p/ XCreateIC + modificadores de locale.
    s_xim_empty:     db 0
    s_xn_style:      db "inputStyle", 0
    s_xn_client:    db "clientWindow", 0
    s_xn_focus:     db "focusWindow", 0
    ; compose_tab (F4): (dead_lo, base, len, b1, b2) p/ acentos pt-BR.
    ; dead: FE50 grave FE51 agudo FE52 circ FE53 til FE57 trema FE5B cedilha.
    ; Inclui (dead,spaco)->spacing, reusado quando a base não combina.
    compose_tab:
    db 0x51,'a',2,0xC3,0xA1, 0x51,'e',2,0xC3,0xA9, 0x51,'i',2,0xC3,0xAD
    db 0x51,'o',2,0xC3,0xB3, 0x51,'u',2,0xC3,0xBA, 0x51,'A',2,0xC3,0x81
    db 0x51,'E',2,0xC3,0x89, 0x51,'I',2,0xC3,0x8D, 0x51,'O',2,0xC3,0x93
    db 0x51,'U',2,0xC3,0x9A, 0x51,'y',2,0xC3,0xBD, 0x51,'Y',2,0xC3,0x9D
    db 0x51,' ',2,0xC2,0xB4
    db 0x50,'a',2,0xC3,0xA0, 0x50,'e',2,0xC3,0xA8, 0x50,'i',2,0xC3,0xAC
    db 0x50,'o',2,0xC3,0xB2, 0x50,'u',2,0xC3,0xB9, 0x50,'A',2,0xC3,0x80
    db 0x50,'E',2,0xC3,0x88, 0x50,'I',2,0xC3,0x8C, 0x50,'O',2,0xC3,0x92
    db 0x50,'U',2,0xC3,0x99, 0x50,' ',1,0x60,0x00
    db 0x52,'a',2,0xC3,0xA2, 0x52,'e',2,0xC3,0xAA, 0x52,'i',2,0xC3,0xAE
    db 0x52,'o',2,0xC3,0xB4, 0x52,'u',2,0xC3,0xBB, 0x52,'A',2,0xC3,0x82
    db 0x52,'E',2,0xC3,0x8A, 0x52,'I',2,0xC3,0x8E, 0x52,'O',2,0xC3,0x94
    db 0x52,'U',2,0xC3,0x9B, 0x52,' ',1,0x5E,0x00
    db 0x53,'a',2,0xC3,0xA3, 0x53,'A',2,0xC3,0x83, 0x53,'o',2,0xC3,0xB5
    db 0x53,'O',2,0xC3,0x95, 0x53,'n',2,0xC3,0xB1, 0x53,'N',2,0xC3,0x91
    db 0x53,' ',1,0x7E,0x00
    db 0x57,'a',2,0xC3,0xA4, 0x57,'e',2,0xC3,0xAB, 0x57,'i',2,0xC3,0xAF
    db 0x57,'o',2,0xC3,0xB6, 0x57,'u',2,0xC3,0xBC, 0x57,'y',2,0xC3,0xBF
    db 0x57,'A',2,0xC3,0x84, 0x57,'E',2,0xC3,0x8B, 0x57,'I',2,0xC3,0x8F
    db 0x57,'O',2,0xC3,0x96, 0x57,'U',2,0xC3,0x9C, 0x57,' ',2,0xC2,0xA8
    db 0x5B,'c',2,0xC3,0xA7, 0x5B,'C',2,0xC3,0x87, 0x5B,' ',2,0xC2,0xB8
    db 0

%define WIN_W      1280
%define WIN_H      800
%define BG_COLOR   0x161513
; KeyPressMask(1) | ButtonPressMask(1<<2) | ButtonReleaseMask(1<<3)
; | PointerMotionMask(1<<6, F4: arrasto p/ seleção) | ExposureMask(1<<15)
; | StructureNotifyMask(1<<17)
%define INPUT_MASK 163917
; XSizeHints.flags p/ janela de tamanho fixo: PMinSize(1<<4)|PMaxSize(1<<5)
%define HINT_FIXED 48
%define EVT_EXPOSE 12
%define EVT_KEYPRESS 2
%define EVT_BUTTONPRESS 4
%define EVT_BUTTONREL 5
%define EVT_MOTION 6
%define EVT_CLIENTMSG 33
%define EVT_SELCLEAR 29
%define EVT_SELREQ 30
%define EVT_SELNOTIFY 31

section .bss
    p_display:   resq 1
    p_win:       resq 1
    p_gc:        resq 1
    p_font:      resq 1
    p_wm_delete: resq 1
    p_wm_protos: resq 1          ; WM_PROTOCOLS (autentica o close, fix #28)
    p_evtime:    resq 1          ; time do último KeyPress (dono do clipboard #30)
    p_owntime:   resq 1          ; time usado ao adquirir CLIPBOARD (#30)
    a_clipboard: resq 1
    a_utf8:      resq 1
    a_targets:   resq 1
    a_paste:     resq 1          ; property do nosso ConvertSelection (paste)
    clip_ptr:    resq 1          ; bytes p/ servir no clipboard
    clip_len:    resd 1
    clip_buf:    resb REC_CODE_LEN ; snapshot imutável do último Ctrl+C
    paste_ptr:   resq 1          ; bytes do último Ctrl+V (self ou externo)
    paste_len:   resd 1
    paste_buf:   resb REC_CODE_LEN ; destino do SelectionNotify (paste)
    ev_kind:     resd 1          ; 0=none 1=printable 2=backspace 3=up 4=down
                                ; 5=copy 6=save 7=fav 8=clearq 9=enter 10=esc
                                ; 11=left 12=right 13=mouse 14=create 15=delkey
                                ; 16=delete 17=tab 18=mkcoll 19=rencoll 20=delcoll
                                ; 21=movecoll (snippet -> próxima coleção)
                                 ; 22=help (Ctrl+H abre a tabela de comandos)
                                 ; 23=button-release 24=motion (F4: seleção)
                                 ; 25=paste pronto 26=Ctrl+V (paste)
    ev_char:     resb 1
    ev_btn:      resd 1          ; botão do mouse (1=esq, 4/5=wheel)
    ev_mx:       resd 1          ; x do click (coords da janela)
    ev_my:       resd 1          ; y do click
    alignb 8
    ksym:        resq 1          ; KeySym da última tecla (XLookupString)
    kbuf:        resb 32         ; chars decodificados
    targ_buf:    resq 4          ; resposta TARGETS
    latin_buf:   resb REC_CODE_LEN ; conversão UTF-8->Latin-1 p/ XA_STRING (#30)
    kpend:       resb 8            ; bytes UTF-8 pendentes (multibyte, fix #33)
    kpend_n:     resd 1            ; quantos bytes em kpend
    ; Xft (F3): tudo zerado = caminho core; xft_ok=1 habilita o AntiAliased.
    xft_ok:      resd 1
    p_screen:    resd 1
    xft_font:    resq 1
    xft_draw:    resq 1
    f_open:      resq 1
    f_draw:      resq 1
    f_str:       resq 1
    f_ext:       resq 1
    f_col:       resq 1
    xc_text:     resb 16
    xc_dim:      resb 16
    xc_accent:   resb 16
    xc_code:     resb 16
    ; XGlyphInfo local: 12B, xOff u16 @+8 (validado no alvo: 9/45/90px).
    xglyph:      resb 12
    ; XIM (F4): método de entrada p/ compor acentos (teclas mortas).
    xim:         resq 1
    xic:         resq 1
    xic_status:  resd 1
    ; F4: tecla morta pendente (keysym FE50..FE62, 0 = nenhuma).
    dead_pending: resd 1
    sel_ev:      resb 80         ; XSelectionEvent de resposta
    sz_hints:    resb 80         ; XSizeHints (BSS zerado; só flags+min/max usados)
    alignb 16
    p_event:     resb 192

section .text

; int platform_init(void) — 0 ok, 1 falha
platform_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    ; entrada rsp%16==8, 4 pushes (32B) -> rsp%16==8 de novo? 8-32 = -24 mod16 = 8.
    ; sub 8 para alinhar antes de calls.
    sub rsp, 8

    xor edi, edi
    call XOpenDisplay wrt ..plt
    mov [p_display], rax
    test rax, rax
    jz .fail
    mov rbx, rax                    ; rbx = display

    ; screen = XDefaultScreen(display)
    mov rdi, rbx
    call XDefaultScreen wrt ..plt   ; eax = screen
    mov [p_screen], eax
    mov esi, eax
    mov rdi, rbx
    call XRootWindow wrt ..plt      ; rax = root
    mov r12, rax                    ; r12 = root

    ; Window = XCreateSimpleWindow(dpy, parent, 0,0, W,H, 0, 0, BG)
    ; 9 args: 6 em regs + 3 na pilha (border_width, border, background)
    sub rsp, 32                     ; 24B args + 8B pad, mantém alinhamento
    mov qword [rsp], 0              ; 7o arg: border_width
    mov qword [rsp+8], 0            ; 8o arg: border pixel
    mov qword [rsp+16], BG_COLOR    ; 9o arg: background pixel
    mov rdi, rbx
    mov rsi, r12
    xor edx, edx                    ; x = 0
    xor ecx, ecx                    ; y = 0
    mov r8d, WIN_W
    mov r9d, WIN_H
    call XCreateSimpleWindow wrt ..plt
    add rsp, 32
    mov [p_win], rax
    mov r13, rax                    ; r13 = window
    test rax, rax
    jz .fail

    ; XStoreName(display, window, "CmdKeepa")
    mov rdi, rbx
    mov rsi, r13
    lea rdx, [win_title]
    call XStoreName wrt ..plt

    ; XSelectInput(display, window, INPUT_MASK)
    mov rdi, rbx
    mov rsi, r13
    mov rdx, INPUT_MASK
    call XSelectInput wrt ..plt

    ; wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", 0)
    mov rdi, rbx
    lea rsi, [atom_delete_name]
    xor edx, edx
    call XInternAtom wrt ..plt
    mov [p_wm_delete], rax

    ; wm_protos = XInternAtom(dpy, "WM_PROTOCOLS", 0) — sem ele o close não
    ; é autenticável (atom_protos_name era definido e ignorado, fix #28)
    mov rdi, rbx
    lea rsi, [atom_protos_name]
    xor edx, edx
    call XInternAtom wrt ..plt
    mov [p_wm_protos], rax

    ; atoms do clipboard: CLIPBOARD, UTF8_STRING, TARGETS (+paste próprio/INCR)
    mov rdi, rbx
    lea rsi, [atom_clip_name]
    xor edx, edx
    call XInternAtom wrt ..plt
    mov [a_clipboard], rax
    mov rdi, rbx
    lea rsi, [atom_utf8_name]
    xor edx, edx
    call XInternAtom wrt ..plt
    mov [a_utf8], rax
    mov rdi, rbx
    lea rsi, [atom_tgt_name]
    xor edx, edx
    call XInternAtom wrt ..plt
    mov [a_targets], rax
    mov rdi, rbx
    lea rsi, [atom_paste_name]
    xor edx, edx
    call XInternAtom wrt ..plt
    mov [a_paste], rax

    ; XSetWMProtocols(dpy, win, &wm_delete, 1)
    mov rdi, rbx
    mov rsi, r13
    lea rdx, [p_wm_delete]
    mov ecx, 1
    call XSetWMProtocols wrt ..plt

    ; Tamanho fixo 1280x800: a UI é toda em coords absolutas; sem isso o
    ; maximize do WM estica a janela e o desenho quebra. min=max no
    ; WM_NORMAL_HINTS desabilita maximize/resize (padrão p/ layout fixo).
    mov qword [sz_hints], HINT_FIXED
    mov dword [sz_hints+24], WIN_W   ; min_width
    mov dword [sz_hints+28], WIN_H   ; min_height
    mov dword [sz_hints+32], WIN_W   ; max_width
    mov dword [sz_hints+36], WIN_H   ; max_height
    mov rdi, rbx
    mov rsi, r13
    lea rdx, [sz_hints]
    call XSetWMNormalHints wrt ..plt

    ; XMapWindow(display, window)
    mov rdi, rbx
    mov rsi, r13
    call XMapWindow wrt ..plt

    ; gc = XCreateGC(display, window, 0, NULL)
    mov rdi, rbx
    mov rsi, r13
    xor edx, edx
    xor ecx, ecx
    call XCreateGC wrt ..plt
    mov [p_gc], rax
    test rax, rax
    jz .fail                         ; GC nulo contaminaria todo desenho (#27)

    ; fonte: tenta Xft (AA) primeiro; fallback p/ 9x15 core (fix #33).
    ; Sem Xft o init segue idêntico ao anterior — zero regressão.
    call xim_init
    call xft_init
    test eax, eax
    jnz .fontdone
    ; fonte core: tenta 9x15 e 9x15bold via XLoadQueryFont, EXIGINDO largura 9
    ; (fix #33). "fixed" genérico é 6px neste sistema e quebraria a geometria
    ; de 9px em silêncio; sem fonte 9px o init falha em vez de desrenderizar.
    ; XFontStruct.max_bounds.width @ 72 (verificado contra Xlib.h do sistema).
    lea rsi, [font_name]
    call .tryfont
    test rax, rax
    jnz .fonthave
    lea rsi, [font_alt_name]
    call .tryfont
    test rax, rax
    jz .fail
.fonthave:
    mov [p_font], rax
    mov rdi, rbx
    mov rsi, [p_gc]
    mov rdx, rax
    call XSetFont wrt ..plt
    jmp .fontdone
.tryfont:
    ; rsi=nome -> rax=fid (9px) ou 0. Sem push: X* preserva rbx (SysV).
    ; Sub-rotina LOCAL com call aninhado: `call .tryfont` empurra 8B, então
    ; sub 8 aqui (a auditoria linear não enxerga esse nível — fix #19).
    sub rsp, 8
    mov rdi, rbx
    call XLoadQueryFont wrt ..plt   ; rax = XFontStruct* (fonte carregada)
    test rax, rax
    jz .tfail
    cmp word [rax+72], 9            ; max_bounds.width == 9?
    jne .tfail
    mov rax, [rax+8]                ; fid (estrutura vaza 96B: singleton de
    add rsp, 8                      ; processo, documentado — XFreeFont
    ret                             ; descarregaria a fonte em uso
.tfail:                             ; descarregaria a fonte em uso
    xor eax, eax
    add rsp, 8
    ret
.fontdone:

    lea rax, [clip_buf]
    mov [clip_ptr], rax
    mov dword [clip_len], 0
    call platform_paint_internal

    xor eax, eax
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.fail:
    ; caminho único de limpeza (fix #27): fecha display parcial e zera os
    ; handles — sem isso, falha pós-XOpenDisplay vazava a conexão e um GC
    ; nulo/fonte ausente podia seguir como "sucesso". Válido de qualquer
    ; ponto de falha (usa os globais, não os regs do caminho).
    mov rdi, [p_display]
    test rdi, rdi
    jz .noclose
    call XCloseDisplay wrt ..plt
.noclose:
    mov qword [p_display], 0
    mov qword [p_win], 0
    mov qword [p_gc], 0
    mov qword [p_font], 0
    mov eax, 1
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; void platform_paint_internal — redesenha tudo via ui_draw + flush.
platform_paint_internal:
    push rbp
    mov rbp, rsp
    ; rsp%16==0 aqui — ui_draw não recebe args de pilha
    call ui_draw wrt ..plt
    mov rdi, [p_display]
    call XFlush wrt ..plt
    pop rbp
    ret

; void xim_init(void) — abre o método de entrada p/ compor acentos (F4).
; Sem IM no sistema continua tudo igual (xic=0: XLookupString + sem filtro).
; Preserva rbx/r12/r13; globais xim/xic (0 = ausente).
xim_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    ; XSetLocaleModifiers("") primeiro: sem isso o XOpenIM pode não achar
    ; o IM local (ibus/fcitx).
    lea rdi, [s_xim_empty]
    call XSetLocaleModifiers wrt ..plt
    mov rdi, [p_display]
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    call XOpenIM wrt ..plt
    test rax, rax
    jz .done
    mov [xim], rax
    mov rbx, rax
    ; XCreateIC(im, "inputStyle",0x408, "clientWindow",win, "focusWindow",win, NULL)
    ; XIMPreeditNothing|XIMStatusNothing = 0x08|0x400: sem preedit, eco direto.
    mov rdi, rbx
    lea rsi, [s_xn_style]
    mov edx, 0x408
    lea rcx, [s_xn_client]
    mov r8, [p_win]
    lea r9, [s_xn_focus]
    sub rsp, 16
    mov rax, [p_win]
    mov [rsp], rax
    mov qword [rsp+8], 0
    call XCreateIC wrt ..plt
    add rsp, 16
    test rax, rax
    jz .done
    mov [xic], rax
    mov rdi, rax
    call XSetICFocus wrt ..plt
.done:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; compose_dead — combina dead_pending + kbuf via compose_tab (F4, pt-BR).
; Entrada: eax=nbytes(>0), kbuf preenchido. Saída: eax=novo n, kbuf reescrito.
; Sem match: prefixa o spacing do dead (dead+espaço). Sempre limpa o pendente
; e preserva rbx (chamador .key depende disso). Clobbers: rax rcx rdx rsi
; rdi r8 r9 r10.
compose_dead:
    push rbx
    mov ebx, [dead_pending]
    mov dword [dead_pending], 0
    cmp eax, 1
    jne .cd_prepend                 ; base multibyte: só prefixa spacing
    cmp byte [kbuf], 0x80
    jae .cd_prepend                 ; base não-ASCII: idem
    movzx ecx, byte [kbuf]          ; base
    lea rsi, [compose_tab]
.cd_scan:
    cmp byte [rsi], 0
    je .cd_prepend                  ; fim da tabela: sem match
    cmp [rsi], bl                   ; dead (low byte do keysym)
    jne .cd_next
    cmp [rsi+1], cl                 ; base
    jne .cd_next
    movzx eax, byte [rsi+2]         ; len 1|2
    movzx edx, byte [rsi+3]
    mov [kbuf], dl
    cmp eax, 2
    jb .cd_ret
    movzx edx, byte [rsi+4]
    mov [kbuf+1], dl
.cd_ret:
    pop rbx
    ret
.cd_next:
    add rsi, 5
    jmp .cd_scan
.cd_prepend:
    ; spacing(dead)+bytes atuais: recicla a linha (dead,espaço) da tabela.
    lea rsi, [compose_tab]
.cd_sp:
    cmp byte [rsi], 0
    je .cd_drop                     ; sem spacing conhecido: descarta o dead
    cmp [rsi], bl
    jne .cd_spnext
    cmp byte [rsi+1], 0x20
    jne .cd_spnext
    movzx ecx, byte [rsi+2]         ; L = len do spacing
    mov edi, eax
    add edi, ecx
    cmp edi, 31
    ja .cd_drop                     ; não cabe: descarta o dead
    lea rdi, [kbuf]
    lea r10, [rdi+rcx]              ; base destino = kbuf + L
    mov r9d, eax
    dec r9d                         ; i = n-1
.cd_mv:
    cmp r9d, 0
    jl .cd_mvdone
    mov dl, [rdi+r9]
    mov [r10+r9], dl
    dec r9d
    jmp .cd_mv
.cd_mvdone:
    movzx edx, byte [rsi+3]
    mov [rdi], dl
    cmp ecx, 2
    jb .cd_sp1
    movzx edx, byte [rsi+4]
    mov [rdi+1], dl
.cd_sp1:
    add eax, ecx                    ; eax = n + L
    pop rbx
    ret
.cd_spnext:
    add rsi, 5
    jmp .cd_sp
.cd_drop:
    pop rbx                         ; eax intacto (só os bytes atuais)
    ret

; int xft_init(void) — 1 = Xft ativo, 0 = usar core. Leaf-safe p/ o init:
; preserva rbx/r12-r15; lê display/win/screen dos globais (já setados).
; Estratégia: dlopen("libXft.so.2") + dlsym x5 — sem -lXft no link de
; compilação (só -ldl, parte da glibc). Fonte mono size=15: advance 9px,
; então TODA a geometria 9px da UI continua válida sem retoque.
xft_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    lea rdi, [s_libxft]
    mov esi, 0x102                ; RTLD_NOW|RTLD_GLOBAL
    call dlopen wrt ..plt
    test rax, rax
    jz .fail
    mov rbx, rax                  ; handle
    mov rdi, rbx
    lea rsi, [s_sym_open]
    call dlsym wrt ..plt
    test rax, rax
    jz .fail
    mov [f_open], rax
    mov rdi, rbx
    lea rsi, [s_sym_draw]
    call dlsym wrt ..plt
    test rax, rax
    jz .fail
    mov [f_draw], rax
    mov rdi, rbx
    lea rsi, [s_sym_str]
    call dlsym wrt ..plt
    test rax, rax
    jz .fail
    mov [f_str], rax
    mov rdi, rbx
    lea rsi, [s_sym_ext]
    call dlsym wrt ..plt
    test rax, rax
    jz .fail
    mov [f_ext], rax
    mov rdi, rbx
    lea rsi, [s_sym_col]
    call dlsym wrt ..plt
    test rax, rax
    jz .fail
    mov [f_col], rax
    ; fonte: 4 nomes em ordem de preferência
    mov rdi, [p_display]
    mov esi, [p_screen]
    lea rdx, [s_xft_f1]
    call qword [f_open]
    test rax, rax
    jnz .havefont
    mov rdi, [p_display]
    mov esi, [p_screen]
    lea rdx, [s_xft_f2]
    call qword [f_open]
    test rax, rax
    jnz .havefont
    mov rdi, [p_display]
    mov esi, [p_screen]
    lea rdx, [s_xft_f3]
    call qword [f_open]
    test rax, rax
    jnz .havefont
    mov rdi, [p_display]
    mov esi, [p_screen]
    lea rdx, [s_xft_f4]
    call qword [f_open]
    test rax, rax
    jz .fail
.havefont:
    mov [xft_font], rax
    mov r12, rax                  ; r12 = fonte (preservado pelas calls X)
    ; sanity: advance de 10 dígitos deve dar ~90px (grade 9px intacta)
    mov rdi, [p_display]
    mov rsi, r12
    lea rdx, [s_digits]
    mov ecx, 10
    lea r8, [xglyph]
    call qword [f_ext]
    movzx eax, word [xglyph+8]    ; xOff de 10 dígitos: ~90px = grade 9px
    cmp eax, 80                   ; < 80? fonte não-mono/estranha
    jb .fail
    cmp eax, 100                  ; > 100? idem
    ja .fail
    ; visual + colormap default p/ criar o XftDraw da janela
    mov rdi, [p_display]
    mov esi, [p_screen]
    call XDefaultVisual wrt ..plt
    test rax, rax
    jz .fail
    mov r13, rax
    mov rdi, [p_display]
    mov esi, [p_screen]
    call XDefaultColormap wrt ..plt
    mov r14, rax
    mov rdi, [p_display]
    mov rsi, [p_win]
    mov rdx, r13
    mov rcx, r14
    call qword [f_draw]
    test rax, rax
    jz .fail
    mov [xft_draw], rax
    ; 4 cores da UI
    mov rdi, [p_display]
    mov rsi, r13
    mov rdx, r14
    lea rcx, [s_col_text]
    lea r8, [xc_text]
    call qword [f_col]
    test eax, eax
    jz .fail
    mov rdi, [p_display]
    mov rsi, r13
    mov rdx, r14
    lea rcx, [s_col_dim]
    lea r8, [xc_dim]
    call qword [f_col]
    test eax, eax
    jz .fail
    mov rdi, [p_display]
    mov rsi, r13
    mov rdx, r14
    lea rcx, [s_col_accent]
    lea r8, [xc_accent]
    call qword [f_col]
    test eax, eax
    jz .fail
    mov rdi, [p_display]
    mov rsi, r13
    mov rdx, r14
    lea rcx, [s_col_code]
    lea r8, [xc_code]
    call qword [f_col]
    test eax, eax
    jz .fail
    mov dword [xft_ok], 1
    mov eax, 1
    jmp .done
.fail:
    mov dword [xft_ok], 0
    xor eax, eax
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; void platform_fill_rect(int x, int y, int w, int h, uint32_t color)
; Primitiva de retângulo sólido. Todos os args em regs — sem slot de pilha.
platform_fill_rect:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                      ; 6 pushes = 48B; 8-48 mod16 = 8 -> alinha
    mov r12d, edi                   ; x
    mov r13d, esi                   ; y
    mov r14d, edx                   ; w
    mov r15d, ecx                   ; h
    mov ebx, r8d                    ; color

    mov rdi, [p_display]
    mov rsi, [p_gc]
    mov edx, ebx
    call XSetForeground wrt ..plt

    ; XFillRectangle(dpy, win, gc, x, y, width, height) — 7 args, height na pilha
    sub rsp, 16
    mov dword [rsp], r15d
    mov rdi, [p_display]
    mov rsi, [p_win]
    mov rdx, [p_gc]
    mov ecx, r12d
    mov r8d, r13d
    mov r9d, r14d
    call XFillRectangle wrt ..plt
    add rsp, 16

    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; void platform_draw_text(int x, int y, uint32_t color, const char *s, int len)
; x,y = baseline do texto. Com Xft ativo usa fonte AA (UTF-8 plena);
; senão o caminho core 9x15 (origem XDrawString). Mesma grade 9px.
platform_draw_text:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12d, edi                   ; x
    mov r13d, esi                   ; y
    mov r14d, edx                   ; color
    mov rbx, rcx                    ; str
    mov r15d, r8d                   ; len
    cmp dword [xft_ok], 0
    je .core
    ; mapeia a cor p/ XftColor alocada (default: texto)
    cmp r14d, 0xA8A29E
    je .xc_dim
    cmp r14d, 0xC9D2C2
    je .xc_accent
    cmp r14d, 0xD6D0C7
    je .xc_code
    cmp r14d, 0x161513
    je .xc_text                     ; caret-invertido usa C_BG: desenha claro
    lea rax, [xc_text]
    jmp .xdraw
.xc_dim:
    lea rax, [xc_dim]
    jmp .xdraw
.xc_accent:
    lea rax, [xc_accent]
    jmp .xdraw
.xc_code:
    lea rax, [xc_code]
    jmp .xdraw
.xc_text:
    lea rax, [xc_text]
.xdraw:
    ; XftDrawStringUtf8(draw, color, font, x, y, s, len) — 7 args
    sub rsp, 16
    mov dword [rsp], r15d
    mov rdi, [xft_draw]
    mov rsi, rax
    mov rdx, [xft_font]
    mov ecx, r12d
    mov r8d, r13d
    mov r9, rbx
    mov rax, [f_str]
    call rax
    add rsp, 16
    jmp .done
.core:

    mov rdi, [p_display]
    mov rsi, [p_gc]
    mov edx, r14d
    call XSetForeground wrt ..plt

    ; XDrawString(dpy, win, gc, x, y, s, len) — 7 args, len na pilha
    sub rsp, 16
    mov dword [rsp], r15d
    mov rdi, [p_display]
    mov rsi, [p_win]
    mov rdx, [p_gc]
    mov ecx, r12d
    mov r8d, r13d
    mov r9, rbx
    call XDrawString wrt ..plt
    add rsp, 16

.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; void platform_paint(void) — wrapper público
platform_paint:
    push rbp
    mov rbp, rsp
    call platform_paint_internal
    pop rbp
    ret

; int platform_poll(void)
; Bloqueia em XNextEvent. Retorno: 0 = expose (já repintado) ou evento
; ignorado; 1 = sair; 2 = tecla útil (ver ev_kind/ev_char).
; ev_kind: 1=printable(ev_char) 2=backspace 3=up 4=down
platform_poll:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    ; após push rbp+rbx+r12 (24B) rsp já está 16-alinhado — sem sub aqui
    ; (um `sub rsp,8` anterior quebrava o alinhamento e segfaultava no XNextEvent)

    ; bytes UTF-8 pendentes de tecla multibyte anterior? serve 1 sem bloquear
    ; (fix #33: XLookupString pode devolver 2-4 bytes p/ 1 keysym)
    cmp dword [kpend_n], 0
    je .noevent
    mov al, [kpend]
    mov [ev_char], al
    mov dword [ev_kind], 1
    ; desloca a fila
    mov ecx, [kpend_n]
    dec ecx
    mov [kpend_n], ecx
    jecxz .penddone
    lea rsi, [kpend+1]
    lea rdi, [kpend]
    rep movsb
.penddone:
    mov eax, 2
    jmp .done
.noevent:
    mov rdi, [p_display]
    lea rsi, [p_event]
    call XNextEvent wrt ..plt

    mov eax, dword [p_event]        ; type
    cmp eax, EVT_EXPOSE
    je .expose
    cmp eax, EVT_KEYPRESS
    je .key
    cmp eax, EVT_BUTTONPRESS
    je .button
    cmp eax, EVT_BUTTONREL
    je .buttonrel
    cmp eax, EVT_MOTION
    je .motion
    cmp eax, EVT_CLIENTMSG
    je .client
    cmp eax, EVT_SELREQ
    je .selreq
    cmp eax, EVT_SELCLEAR
    je .selclear
    cmp eax, EVT_SELNOTIFY
    je .selnotify
    xor eax, eax
    jmp .done

.selclear:
    mov dword [clip_len], 0
    lea rax, [clip_buf]
    mov [clip_ptr], rax
    xor eax, eax
    jmp .done

.selnotify:
    ; SelectionNotify do nosso XConvertSelection (paste Ctrl+V): só atende a
    ; property a_paste. property=None = dono recusou/morreu: ignora.
    ; Layout XSelectionEvent: property@56, target@48.
    mov rax, [p_event+56]
    test rax, rax
    jz .cont
    cmp rax, [a_paste]
    jne .cont
    ; XGetWindowProperty(dpy, win, prop, 0, 65536, False, Any(0),
    ;   &type, &fmt, &nitems, &after, &data) — 6 regs + 6 na pilha; os 5
    ; outs vão p/ o topo da reserva (a auditoria linear exige bal≡8 nos calls).
    sub rsp, 96
    mov rdi, [p_display]
    mov rsi, [p_win]
    mov rdx, [a_paste]
    xor ecx, ecx
    mov r8d, 65536
    xor r9d, r9d
    mov qword [rsp], 0
    lea rax, [rsp+48]
    mov [rsp+8], rax
    lea rax, [rsp+56]
    mov [rsp+16], rax
    lea rax, [rsp+64]
    mov [rsp+24], rax
    lea rax, [rsp+72]
    mov [rsp+32], rax
    lea rax, [rsp+80]
    mov [rsp+40], rax
    call XGetWindowProperty wrt ..plt
    cmp qword [rsp+48], 0
    je .snclean
    cmp dword [rsp+56], 8
    jne .snclean
    cmp qword [rsp+64], 0
    je .snclean
    mov rax, [rsp+80]
    test rax, rax
    jz .snclean
    mov rax, [rsp+48]               ; só texto: UTF8_STRING ou XA_STRING
    cmp rax, [a_utf8]
    je .sngot
    cmp rax, 31
    jne .snclean
.sngot:
    mov rcx, [rsp+64]               ; nitems: copia min(n, REC_CODE_LEN-1)
    cmp rcx, REC_CODE_LEN - 1
    jbe .snok
    mov ecx, REC_CODE_LEN - 1
.snok:
    mov [paste_len], ecx
    mov rsi, [rsp+80]
    lea rdi, [paste_buf]
    test ecx, ecx
    jz .snfree
    rep movsb
.snfree:
    mov rdi, [rsp+80]               ; XFree(data): GetWindowProperty aloca
    call XFree wrt ..plt
    mov rdi, [p_display]
    mov rsi, [p_win]
    mov rdx, [a_paste]
    call XDeleteProperty wrt ..plt
    add rsp, 96
    lea rax, [paste_buf]
    mov [paste_ptr], rax
    mov dword [ev_kind], 25
    mov eax, 2
    jmp .done
.snclean:
    mov rax, [rsp+80]
    test rax, rax
    jz .snodel
    mov rdi, rax
    call XFree wrt ..plt
.snodel:
    mov rdi, [p_display]
    mov rsi, [p_win]
    mov rdx, [a_paste]
    call XDeleteProperty wrt ..plt
    add rsp, 96
    jmp .cont

.expose:
    cmp dword [p_event+56], 0         ; XExposeEvent.count: repinta SÓ quando
    jne .cont                         ; zera (fix #36 — rajada não refaz filtro
    call platform_paint_internal      ; nem redesenha N vezes; SelectionRequest
    xor eax, eax                      ; continua responsivo: é outro evento)
    jmp .done

.selreq:
    call sel_respond
    xor eax, eax
    jmp .done

.key:
    mov rax, qword [p_event+56]       ; time do KeyPress (dono clipboard #30)
    mov [p_evtime], rax
    ; Lookup SEMPRE primeiro (fix #29): o KeySym decide Esc (0xFF1B);
    ; keycode 9 é convenção, não garantia (teclado remapeado quebrava).
    ; Com IC: Xutf8LookupString (UTF-8 direto); sem IM, XLookupString.
    ; Acentos vêm de compose_dead (cliente, determinístico — F4); o XFilterEvent
    ; NÃO é chamado porque o ibus local consome tudo e nada chega (verificado).
    ; Ambos os lookups devolvem eax=nbytes + ksym.
    cmp qword [xic], 0
    je .noim
    mov rdi, [xic]
    lea rsi, [p_event]
    lea rdx, [kbuf]
    mov ecx, 32
    lea r8, [ksym]
    lea r9, [xic_status]
    call Xutf8LookupString wrt ..plt  ; eax = nbytes
    cmp dword [xic_status], -1        ; XBufferOverflow: descarta
    je .cont
    jmp .havebytes
.noim:
    ; XLookupString(&event, kbuf, 32, &ksym, NULL) — 5 args em regs
    lea rdi, [p_event]
    lea rsi, [kbuf]
    mov edx, 32
    lea rcx, [ksym]
    xor r8d, r8d
    call XLookupString wrt ..plt    ; eax = nbytes
.havebytes:
    mov rdx, [ksym]
    cmp rdx, 0xFF1B                 ; XK_Escape
    je .escape                       ; Esc vira kind 10 (app decide: cancela/sai)
    ; Ctrl+letra -> ações (antes dos especiais/printable)
    mov ecx, dword [p_event+80]     ; state
    test ecx, 4                     ; ControlMask
    jz .nokey
    cmp rdx, 'c'
    je .copy
    cmp rdx, 'C'
    je .copy
    cmp rdx, 's'
    je .save
    cmp rdx, 'S'
    je .save
    cmp rdx, 'f'
    je .fav
    cmp rdx, 'F'
    je .fav
    cmp rdx, 'u'
    je .clearq
    cmp rdx, 'U'
    je .clearq
    cmp rdx, 'n'
    je .mknew
    cmp rdx, 'N'
    je .mknew
    cmp rdx, 'd'
    je .delkey
    cmp rdx, 'D'
    je .delkey
    cmp rdx, 'g'
    je .mkcoll
    cmp rdx, 'G'
    je .mkcoll
    cmp rdx, 'r'
    je .rencoll
    cmp rdx, 'R'
    je .rencoll
    cmp rdx, 'x'
    je .delcoll
    cmp rdx, 'X'
    je .delcoll
    cmp rdx, 'l'
    je .movecoll
    cmp rdx, 'L'
    je .movecoll
    cmp rdx, 'h'
    je .helpkey
    cmp rdx, 'H'
    je .helpkey
    cmp rdx, 'v'
    je .pastekey
    cmp rdx, 'V'
    je .pastekey
    jmp .cont
.copy:
    mov dword [ev_kind], 5
    mov eax, 2
    jmp .done
.save:
    mov dword [ev_kind], 6
    mov eax, 2
    jmp .done
.fav:
    mov dword [ev_kind], 7
    mov eax, 2
    jmp .done
.clearq:
    mov dword [ev_kind], 8
    mov eax, 2
    jmp .done
.mknew:
    mov dword [ev_kind], 14
    mov eax, 2
    jmp .done
.delkey:
    mov dword [ev_kind], 15
    mov eax, 2
    jmp .done
.mkcoll:
    mov dword [ev_kind], 18
    mov eax, 2
    jmp .done
.rencoll:
    mov dword [ev_kind], 19
    mov eax, 2
    jmp .done
.delcoll:
    mov dword [ev_kind], 20
    mov eax, 2
    jmp .done
.movecoll:
    mov dword [ev_kind], 21
    mov eax, 2
    jmp .done
.helpkey:
    mov dword [ev_kind], 22
    mov eax, 2
    jmp .done
.pastekey:
    mov dword [ev_kind], 26
    mov eax, 2
    jmp .done
.nokey:
    cmp rdx, 0xFF08                 ; BackSpace
    je .backspace
    cmp rdx, 0xFF52                 ; Up
    je .up
    cmp rdx, 0xFF54                 ; Down
    je .down
    cmp rdx, 0xFF0D                 ; Return/Enter
    je .enter
    cmp rdx, 0xFF51                 ; Left
    je .left
    cmp rdx, 0xFF53                 ; Right
    je .right
    cmp rdx, 0xFFFF                 ; Delete
    je .del
    cmp rdx, 0xFF09                 ; Tab
    je .tab
    test eax, eax
    jz .deadkey
    cmp dword [dead_pending], 0
    je .nodead
    call compose_dead               ; reescreve kbuf/eax, limpa o pendente
.nodead:
    cmp byte [kbuf], 32
    jb .cont                        ; controles nunca entram (fix #33)
    cmp byte [kbuf], 127
    je .cont                        ; DEL nunca entra
    ; UTF-8 (fix #33): 1+ bytes; valida prefixo completo e enfileira o resto.
    ; ASCII passa direto (sequência de 1 byte); multibyte validado e servido
    ; byte a byte nos próximos polls (UI insere bytes: sequência preservada).
    lea rsi, [kbuf]
    mov ecx, eax
    cmp ecx, 8
    jbe .oklen
    mov ecx, 8
.oklen:
    call utf8_prefix                ; eax = prefixo válido (0 = malformado)
    test eax, eax
    jz .cont
    mov ecx, eax                    ; L
    mov al, [kbuf]
    mov [ev_char], al
    lea rsi, [kbuf+1]
    lea rdi, [kpend]
    dec ecx
    jz .single
    mov [kpend_n], ecx
    rep movsb
.single:
    mov dword [ev_kind], 1
    mov eax, 2
    jmp .done
.deadkey:
    ; nbytes==0 com keysym de tecla morta (FE50..FE62): guarda p/ compor
    ; com a próxima tecla (F4). Outras teclas sem bytes: ignora.
    mov rdx, [ksym]
    cmp rdx, 0xFE50
    jb .cont
    cmp rdx, 0xFE62
    ja .cont
    mov [dead_pending], edx
    jmp .cont
.backspace:
    mov dword [ev_kind], 2
    mov eax, 2
    jmp .done
.up:
    mov dword [ev_kind], 3
    mov eax, 2
    jmp .done
.down:
    mov dword [ev_kind], 4
    mov eax, 2
    jmp .done
.enter:
    mov dword [ev_kind], 9
    mov eax, 2
    jmp .done
.escape:
    mov dword [ev_kind], 10
    mov eax, 2
    jmp .done
.left:
    mov dword [ev_kind], 11
    mov eax, 2
    jmp .done
.right:
    mov dword [ev_kind], 12
    mov eax, 2
    jmp .done
.del:
    mov dword [ev_kind], 16
    mov eax, 2
    jmp .done
.tab:
    mov dword [ev_kind], 17
    mov eax, 2
    jmp .done
.button:
    ; XButtonEvent: x@64, y@68, button@84 (dwords)
    mov eax, dword [p_event+64]
    mov [ev_mx], eax
    mov eax, dword [p_event+68]
    mov [ev_my], eax
    mov eax, dword [p_event+84]
    mov [ev_btn], eax
    mov dword [ev_kind], 13
    mov eax, 2
    jmp .done
.buttonrel:
    ; soltura: mesma geometria do press (F4: fim do arrasto de seleção)
    mov eax, dword [p_event+64]
    mov [ev_mx], eax
    mov eax, dword [p_event+68]
    mov [ev_my], eax
    mov eax, dword [p_event+84]
    mov [ev_btn], eax
    mov dword [ev_kind], 23
    mov eax, 2
    jmp .done
.motion:
    ; XMotionEvent: x@64, y@68 (mesmos offsets do ButtonEvent)
    mov eax, dword [p_event+64]
    mov [ev_mx], eax
    mov eax, dword [p_event+68]
    mov [ev_my], eax
    mov dword [ev_kind], 24
    mov eax, 2
    jmp .done
.quit:
    mov eax, 1
    jmp .done
.cont:
    xor eax, eax
    jmp .done

.client:
    ; fecha SÓ se autenticado (fix #28): janela, WM_PROTOCOLS, formato 32 e
    ; data.l[0]==WM_DELETE_WINDOW. Antes, qualquer ClientMessage com o mesmo
    ; l[0] matava o app. Layout XClientMessageEvent: window@32, type@40,
    ; format@48, data.l[0]@56.
    mov rax, qword [p_event+32]
    cmp rax, [p_win]
    jne .cont
    mov rax, qword [p_event+40]
    cmp rax, [p_wm_protos]
    jne .cont
    cmp dword [p_event+48], 32
    jne .cont
    mov rax, qword [p_event+56]     ; data.l[0]
    cmp rax, [p_wm_delete]
    jne .cont
    mov eax, 1
    jmp .done

.done:
    pop r12
    pop rbx
    pop rbp
    ret

; utf8_prefix(rsi=ptr, ecx=maxlen) — eax = nº de bytes do maior prefixo
; UTF-8 bem-formado (0 se o primeiro byte já é inválido). Corte no limite
; (sequência incompleta) PARA com o prefixo válido; byte estruturalmente
; inválido (80-BF solto, C0/C1, F5-FF, continuação errada) ZERA tudo.
; Leniente p/ overlong/surrogates (validação estrutural de entrada).
; Leaf: só rax/rcx/rdx/rsi/rdi/r8-r10.
utf8_prefix:
    push rbx
    mov rbx, rsi
    xor eax, eax
.loop:
    cmp eax, ecx
    jae .done
    mov dl, [rbx+rax]
    cmp dl, 0x80
    jb .one
    cmp dl, 0xC2
    jb .bad
    cmp dl, 0xE0
    jb .two
    cmp dl, 0xF0
    jb .three
    cmp dl, 0xF5
    jae .bad
    mov edx, 4
    jmp .need
.three:
    mov edx, 3
    jmp .need
.two:
    mov edx, 2
.need:
    mov r8d, eax
    add r8d, edx
    cmp r8d, ecx
    ja .done
    mov r9d, 1
.ck:
    cmp r9d, edx
    jae .okseq
    mov r10d, eax
    add r10d, r9d
    mov r10b, [rbx+r10]
    cmp r10b, 0x80
    jb .bad
    cmp r10b, 0xBF
    ja .bad
    inc r9d
    jmp .ck
.okseq:
    add eax, edx
    jmp .loop
.one:
    inc eax
    jmp .loop
.bad:
    xor eax, eax
.done:
    pop rbx
    ret

; void platform_shutdown(void)
platform_shutdown:
    push rbp
    mov rbp, rsp
    mov rdi, [p_display]
    test rdi, rdi
    jz .skip
    call XCloseDisplay wrt ..plt
.skip:
    mov qword [p_display], 0
    pop rbp
    ret

; int platform_claim_clipboard(void) — vira dono de CLIPBOARD. eax 1 ok.
; Usa o time do KeyPress que originou o Ctrl+C (fix #30): CurrentTime (0)
; corre contra outros donos; com timestamp o servidor arbitra corretamente.
platform_claim_clipboard:
    push rbp
    mov rbp, rsp
    mov rdi, [p_display]
    mov rsi, [a_clipboard]
    mov rdx, [p_win]
    mov rcx, [p_evtime]             ; 0 = CurrentTime (fallback)
    call XSetSelectionOwner wrt ..plt
    mov rdi, [p_display]
    mov rsi, [a_clipboard]
    call XGetSelectionOwner wrt ..plt
    cmp rax, [p_win]
    jne .no
    mov rax, [p_evtime]
    mov [p_owntime], rax
    mov eax, 1
    pop rbp
    ret
.no:
    xor eax, eax
    pop rbp
    ret

; int platform_request_paste(void) — eax = bytes prontos em paste_buf (>0),
; 0 = sem dono/vazio, -1 = ConvertSelection enviado (SelectionNotify vira
; ev_kind 25). Dono próprio: copia direto do clip_buf (sem roundtrip X).
platform_request_paste:
    push rbp
    mov rbp, rsp
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19; sem rbx aqui)
    mov rdi, [p_display]
    mov rsi, [a_clipboard]
    call XGetSelectionOwner wrt ..plt  ; rax = janela dona (0 = ninguém)
    test rax, rax
    jz .ppnone
    cmp rax, [p_win]
    jne .ppext
    mov eax, [clip_len]               ; próprio: serve do snapshot
    test eax, eax
    jz .ppnone
    cmp eax, REC_CODE_LEN - 1
    jbe .ppok
    mov eax, REC_CODE_LEN - 1
.ppok:
    mov [paste_len], eax
    mov ecx, eax
    mov rsi, [clip_ptr]
    lea rdi, [paste_buf]
    rep movsb
    lea rax, [paste_buf]
    mov [paste_ptr], rax
    mov eax, [paste_len]
    jmp .ppret
.ppext:
    ; XConvertSelection(dpy, CLIPBOARD, UTF8, a_paste, win, CurrentTime=0)
    mov rdi, [p_display]
    mov rsi, [a_clipboard]
    mov rdx, [a_utf8]
    mov rcx, [a_paste]
    mov r8, [p_win]
    xor r9d, r9d
    call XConvertSelection wrt ..plt
    mov rdi, [p_display]
    call XFlush wrt ..plt
    mov eax, -1
    jmp .ppret
.ppnone:
    xor eax, eax
.ppret:
    pop rbp
    ret

; sel_respond — atende SelectionRequest em p_event com clip_ptr/clip_len.
; TARGETS -> [TARGETS, UTF8_STRING, STRING]; UTF8/STRING -> bytes; resto recusa.
sel_respond:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    ; 5 pushes = 40B, alinhado
    mov rbx, [p_event+40]           ; requestor
    mov rax, [p_event+48]           ; selection
    cmp rax, [a_clipboard]
    jne .refuse
    mov r13, [p_event+56]           ; target
    mov r14, [p_event+64]           ; property
    test r14, r14
    jnz .propok
    mov r14, r13                    ; legado pede property=None: responde no
.propok:                            ; próprio target (fix #30), senão o XChange
    cmp r13, [a_targets]            ; falha e o solicitante trava
    je .targets
    cmp r13, [a_utf8]
    je .text
    cmp r13d, 31                    ; XA_STRING
    je .latin
    jmp .refuse
.targets:
    mov rax, [a_targets]
    mov [targ_buf], rax
    mov rax, [a_utf8]
    mov [targ_buf+8], rax
    mov qword [targ_buf+16], 31
    ; XChangeProperty(dpy, req, prop, XA_ATOM=4, 32, mode, data, nelem)
    mov rdi, [p_display]
    mov rsi, rbx
    mov rdx, r14
    mov ecx, 4
    mov r8d, 32
    mov r9d, 0                      ; 6o arg: PropModeReplace
    sub rsp, 16
    lea rax, [targ_buf]
    mov [rsp], rax                  ; 7o arg: data
    mov qword [rsp+8], 3            ; 8o arg: nelements
    call XChangeProperty wrt ..plt
    add rsp, 16
    jmp .notify
.text:
    mov rax, [p_event+72]           ; recusa pedido mais velho que a posse (#30)
    test rax, rax
    jz .textgo
    cmp rax, [p_owntime]
    jb .refuse
.textgo:
    ; XChangeProperty(dpy, req, prop, target, 8, mode, clip, len)
    mov rdi, [p_display]
    mov rsi, rbx
    mov rdx, r14
    mov rcx, r13
    mov r8d, 8
    mov r9d, 0                      ; 6o arg: PropModeReplace
    sub rsp, 16
    mov rax, [clip_ptr]
    mov [rsp], rax                  ; 7o arg: data
    mov eax, [clip_len]
    mov [rsp+8], rax                ; 8o arg: nelements
    call XChangeProperty wrt ..plt
    add rsp, 16
    jmp .notify
.latin:
    ; XA_STRING é Latin-1, não UTF-8 (fix #30): converte; byte fora de
    ; U+0000..U+00FF recusa o target (notify com property=None).
    mov rax, [p_event+72]           ; time do pedido (layout XSelectionRequest)
    test rax, rax
    jz .latconv                      ; CurrentTime: serve
    cmp rax, [p_owntime]
    jae .latconv
    jmp .refuse                      ; pedido mais velho que a posse: recusa
.latconv:
    mov rsi, [clip_ptr]
    mov eax, [clip_len]
    lea rdi, [latin_buf]
    mov ecx, eax
    jecxz .latdone
.latloop:
    mov al, [rsi]
    cmp al, 0x80
    jb .lat1                         ; ASCII: direto
    cmp al, 0xC2
    jb .refuse                       ; continuação solta / C0-C1: inválido
    cmp al, 0xC4
    jae .refuse                      ; U+0400+ (3+ bytes): fora do Latin-1
    cmp ecx, 2
    jb .refuse                       ; sequência truncada
    mov dl, [rsi+1]                  ; dl (ah+REX de rsi é inválido)
    cmp dl, 0x80
    jb .refuse
    cmp dl, 0xBF
    ja .refuse
    and al, 0x1F                     ; 110xxxxx -> xxxxx
    shl al, 6                        ; C2->0x80, C3->0xC0 (cento alto)
    and dl, 0x3F
    or al, dl                        ; C2 A9->A9, C3 A9->E9
    mov [rdi], al
    inc rdi
    add rsi, 2
    sub ecx, 2
    jmp .latloop
.lat1:
    mov [rdi], al
    inc rdi
    inc rsi
    dec ecx
    jnz .latloop
.latdone:
    lea rax, [latin_buf]
    mov rdx, rdi
    sub rdx, rax                    ; rdx = len convertido
    mov r10, rdx
    mov rdi, [p_display]
    mov rsi, rbx
    mov rdx, r14
    mov rcx, r13
    mov r8d, 8
    mov r9d, 0
    sub rsp, 16
    lea rax, [latin_buf]
    mov [rsp], rax
    mov [rsp+8], r10
    call XChangeProperty wrt ..plt
    add rsp, 16
    jmp .notify
.refuse:
    mov r14, 0                      ; property=None
.notify:
    mov dword [sel_ev], 31          ; SelectionNotify
    mov dword [sel_ev+16], 1        ; send_event
    mov rax, [p_display]
    mov [sel_ev+24], rax
    mov [sel_ev+32], rbx
    mov rax, [p_event+48]
    mov [sel_ev+40], rax
    mov rax, [p_event+56]
    mov [sel_ev+48], rax
    mov [sel_ev+56], r14
    mov rax, [p_event+72]
    mov [sel_ev+64], rax
    ; XSendEvent(dpy, requestor, False, 0, &sel_ev)
    mov rdi, [p_display]
    mov rsi, rbx
    xor edx, edx
    xor ecx, ecx
    lea r8, [sel_ev]
    call XSendEvent wrt ..plt
    mov rdi, [p_display]
    call XFlush wrt ..plt
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
