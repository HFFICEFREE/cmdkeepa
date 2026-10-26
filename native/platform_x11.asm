; platform_x11.asm — backend Xlib do CmdKeepa nativo (F1)
; Responsabilidade: abrir janela, loop de eventos, primitivas de desenho, fechar.
; Desenho da UI vive em ui_f1.asm (chamado via ui_draw no repaint).
default rel

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
extern XLoadFont
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
extern ui_draw

section .data
    win_title:        db "CmdKeepa", 0
    atom_delete_name: db "WM_DELETE_WINDOW", 0
    atom_protos_name: db "WM_PROTOCOLS", 0
    atom_clip_name:   db "CLIPBOARD", 0
    atom_utf8_name:   db "UTF8_STRING", 0
    atom_tgt_name:    db "TARGETS", 0
    font_name:        db "9x15", 0

%define WIN_W      1280
%define WIN_H      800
%define BG_COLOR   0x191817
; KeyPressMask(1) | ButtonPressMask(1<<2) | ButtonReleaseMask(1<<3)
; | ExposureMask(1<<15) | StructureNotifyMask(1<<17)
%define INPUT_MASK 163853
; XSizeHints.flags p/ janela de tamanho fixo: PMinSize(1<<4)|PMaxSize(1<<5)
%define HINT_FIXED 48
%define EVT_EXPOSE 12
%define EVT_KEYPRESS 2
%define EVT_BUTTONPRESS 4
%define EVT_BUTTONREL 5
%define EVT_CLIENTMSG 33
%define EVT_SELCLEAR 29
%define EVT_SELREQ 30
%define KEY_ESC 9

section .bss
    p_display:   resq 1
    p_win:       resq 1
    p_gc:        resq 1
    p_font:      resq 1
    p_wm_delete: resq 1
    a_clipboard: resq 1
    a_utf8:      resq 1
    a_targets:   resq 1
    clip_ptr:    resq 1          ; bytes p/ servir no clipboard
    clip_len:    resd 1
    ev_kind:     resd 1          ; 0=none 1=printable 2=backspace 3=up 4=down
                                ; 5=copy 6=save 7=fav 8=clearq 9=enter 10=esc
                                ; 11=left 12=right 13=mouse 14=create 15=delkey
                                ; 16=delete 17=tab 18=mkcoll 19=rencoll 20=delcoll
                                ; 21=movecoll (snippet -> próxima coleção)
                                ; 22=help (Ctrl+H abre a tabela de comandos)
    ev_char:     resb 1
    ev_btn:      resd 1          ; botão do mouse (1=esq, 4/5=wheel)
    ev_mx:       resd 1          ; x do click (coords da janela)
    ev_my:       resd 1          ; y do click
    alignb 8
    ksym:        resq 1          ; KeySym da última tecla (XLookupString)
    kbuf:        resb 32         ; chars decodificados
    targ_buf:    resq 4          ; resposta TARGETS
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

    ; atoms do clipboard: CLIPBOARD, UTF8_STRING, TARGETS
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

    ; font = XLoadFont(display, "9x15"); XSetFont(display, gc, font)
    mov rdi, rbx
    lea rsi, [font_name]
    call XLoadFont wrt ..plt
    mov [p_font], rax
    test rax, rax
    jz .nofont
    mov rdi, rbx
    mov rsi, [p_gc]
    mov rdx, rax
    call XSetFont wrt ..plt
.nofont:

    call platform_paint_internal

    xor eax, eax
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.fail:
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
; x,y = baseline do texto (origem XDrawString). GC usa a fonte 9x15 do init.
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
    je .cont
    cmp eax, EVT_CLIENTMSG
    je .client
    cmp eax, EVT_SELREQ
    je .selreq
    cmp eax, EVT_SELCLEAR
    je .cont
    xor eax, eax
    jmp .done

.expose:
    call platform_paint_internal
    xor eax, eax
    jmp .done

.selreq:
    call sel_respond
    xor eax, eax
    jmp .done

.key:
    mov eax, dword [p_event+84]     ; keycode (layout XKeyEvent)
    cmp eax, KEY_ESC
    je .escape                       ; Esc vira kind 10 (app decide: cancela/sai)
    ; XLookupString(&event, kbuf, 32, &ksym, NULL) — 5 args em regs
    lea rdi, [p_event]
    lea rsi, [kbuf]
    mov edx, 32
    lea rcx, [ksym]
    xor r8d, r8d
    call XLookupString wrt ..plt    ; eax = nbytes
    mov rdx, [ksym]
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
    jz .cont
    mov al, [kbuf]                  ; primeiro byte (F2: só ASCII)
    cmp al, 32
    jb .cont
    cmp al, 127
    jae .cont
    mov [ev_char], al
    mov dword [ev_kind], 1
    mov eax, 2
    jmp .done
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
.quit:
    mov eax, 1
    jmp .done
.cont:
    xor eax, eax
    jmp .done

.client:
    mov rax, qword [p_event+56]     ; data.l[0]
    mov rdx, [p_wm_delete]
    cmp rax, rdx
    jne .cont
    mov eax, 1
    jmp .done

.done:
    pop r12
    pop rbx
    pop rbp
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
platform_claim_clipboard:
    push rbp
    mov rbp, rsp
    mov rdi, [p_display]
    mov rsi, [a_clipboard]
    mov rdx, [p_win]
    xor ecx, ecx                    ; CurrentTime
    call XSetSelectionOwner wrt ..plt
    mov rdi, [p_display]
    mov rsi, [a_clipboard]
    call XGetSelectionOwner wrt ..plt
    cmp rax, [p_win]
    jne .no
    mov eax, 1
    pop rbp
    ret
.no:
    xor eax, eax
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
    cmp r13, [a_targets]
    je .targets
    cmp r13, [a_utf8]
    je .text
    cmp r13d, 31                    ; XA_STRING
    je .text
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
