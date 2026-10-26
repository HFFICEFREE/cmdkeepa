; main.asm — ponto de entrada do CmdKeepa nativo (F2)
; argv[1] opcional = caminho do export JSON; senão ~/.cmdkeepa/db.json.
; Loop: poll -> 0 nada, 1 sair, 2 tecla (app_on_key + repaint).
default rel

global main

extern platform_init
extern platform_poll
extern platform_paint
extern platform_shutdown
extern db_load
extern db_default_path
extern app_on_key

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    ; 3 pushes = 24B; 8-24 mod16 = 0 — alinhado
    mov rbx, rdi                    ; argc
    mov r12, rsi                    ; argv

    cmp rbx, 2
    jl .defpath
    mov rdi, [r12+8]                ; argv[1]
    jmp .load
.defpath:
    call db_default_path wrt ..plt  ; rax = path
    mov rdi, rax
.load:
    call db_load wrt ..plt          ; rax = n (0? seed builtin dentro)

    call platform_init wrt ..plt
    test eax, eax
    jnz .fail

; main.asm — ponto de entrada do CmdKeepa nativo (F4)
; argv[1] opcional = caminho do export JSON; senão ~/.cmdkeepa/db.json.
; Loop: poll -> 0 nada, 1 sair (X), 2..21 tecla/mouse (app_on_key + repaint;
; app retorna 1 p/ sair via Esc fora do edit).
.loop:
    call platform_poll wrt ..plt
    cmp eax, 1
    je .quit
    cmp eax, 2                     ; kinds 2..22 = tecla/mouse
    jb .loop
    cmp eax, 22
    ja .loop
    call app_on_key wrt ..plt
    test eax, eax
    jnz .quit
    call platform_paint wrt ..plt
    jmp .loop

.quit:
    call platform_shutdown wrt ..plt
    xor eax, eax
    jmp .done
.fail:
    mov eax, 1
.done:
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
