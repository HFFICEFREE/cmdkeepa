; db.asm — carrega o export JSON do CmdKeepa web e parseia snippets.
; Uso: db_load(path) -> rax = nº snippets (0пат? usa seed builtin se falhar).
; Registros em sn_recs (layout em rec.inc), contagem em sn_count.
; Parser propositalmente mínimo: extrai title/language/code/tags[] de
; {"snippets":[{...}]}; ignora o resto (skip_value com nesting + strings).
; Convenção interna: r12 = cursor, r15 = fim. rbx/r13-r15 preservados
; pelos helpers; r11 TAMBÉM preservado (índice de loops chamadores).
; Scratch: rax,rcx,rdx,rsi,rdi,r8-r10.
default rel
%include "rec.inc"

global db_load
global db_count
global db_default_path
global db_save
global sn_recs
global sn_count
global coll_names
global coll_lens
global coll_count
global coll_ids
global coll_cats

extern getenv

%define FILE_MAX 1048576
%define PATH_MAX 512

section .data
    home_var:    db "HOME", 0
    home_suffix: db "/.cmdkeepa/db.json", 0
    rel_path:    db "db.json", 0
    k_snip:      db "snippets", 0
    k_coll:      db "collections", 0
    k_title:     db 'title"', 0
    k_code:      db 'code"', 0
    k_tags:      db 'tags"', 0
    k_lang:      db 'language"', 0
    k_fav:       db 'favorite"', 0
    k_name:      db 'name"', 0
    k_id:        db 'id"', 0
    k_desc:      db 'description"', 0
    k_collid:    db 'collectionId"', 0
    k_created:   db 'createdAt"', 0
    k_updated:   db 'updatedAt"', 0
    k_views:     db 'views"', 0
    k_versions:  db 'versions"', 0
    k_at:        db 'at"', 0
    hexdig:      db "0123456789abcdef"
    tmp_suffix:  db ".tmp", 0
    bak_suffix:  db ".bak", 0
    ; peças do writer JSON (subset round-trip p/ web)
    j_open:  db '{"app":"cmdkeepa","version":1,"exportedAt":'
j_open_len equ $ - j_open
    j_mid1:  db ',"snippets":['
j_mid1_len equ $ - j_mid1
    j_sopen: db '{"id":"'
j_sopen_len equ $ - j_sopen
    j_sopen2: db '","title":"'
j_sopen2_len equ $ - j_sopen2
    j_l1:    db '","code":"'
j_l1_len equ $ - j_l1
    j_l2:    db '","language":"'
j_l2_len equ $ - j_l2
    j_l3a:   db '","description":"'
j_l3a_len equ $ - j_l3a
    j_l3b:   db '","tags":['
j_l3b_len equ $ - j_l3b
    j_l4a:   db '],"collectionId":'
j_l4a_len equ $ - j_l4a
    j_null:  db 'null'
j_null_len equ $ - j_null
    j_l4b:   db ',"favorite":'
j_l4b_len equ $ - j_l4b
    j_l5a:   db ',"createdAt":'
j_l5a_len equ $ - j_l5a
    j_l5b:   db ',"updatedAt":'
j_l5b_len equ $ - j_l5b
    j_l5c:   db ',"views":'
j_l5c_len equ $ - j_l5c
    j_l5d:   db ',"versions":['
j_l5d_len equ $ - j_l5d
    j_vopen: db '{"code":"'
j_vopen_len equ $ - j_vopen
    j_vmid:  db '","at":'
j_vmid_len equ $ - j_vmid
    j_vclose: db '}'
j_vclose_len equ $ - j_vclose
    j_l5e:   db ']}'
j_l5e_len equ $ - j_l5e
    j_true:  db 'true'
j_true_len equ $ - j_true
    j_false: db 'false'
j_false_len equ $ - j_false
    j_l5:    db ',"createdAt":0,"updatedAt":0,"views":0,"versions":[]}'
j_l5_len equ $ - j_l5
    j_mid2:  db '],"collections":['
j_mid2_len equ $ - j_mid2
    j_copen: db '{"id":"'
j_copen_len equ $ - j_copen
    j_cmid:  db '","name":"'
j_cmid_len equ $ - j_cmid
    j_ccat:  db '","createdAt":'
j_ccat_len equ $ - j_ccat
    j_cclose: db '}'
j_cclose_len equ $ - j_cclose
    j_end:   db ']}'
j_end_len equ $ - j_end
    d_untitled:  db "Untitled"
    d_plain:     db "plaintext"

    ; --- seed builtin (usado quando o arquivo falta ou parse dá 0) ---
    b1t: db "postgres docker"
b1t_len equ $ - b1t
    b1l: db "bash"
b1l_len equ $ - b1l
    b1g: db "docker, postgres"
b1g_len equ $ - b1g
    b1c: db "# postgres local (builtin)", 10
         db "docker run -d --name pg \", 10
         db "  -e POSTGRES_PASSWORD=secret \", 10
         db "  -p 5432:5432 postgres:16", 10
         db "psql -h localhost -U postgres"
b1c_len equ $ - b1c
    b2t: db "k8s port-forward"
b2t_len equ $ - b2t
    b2l: db "bash"
b2l_len equ $ - b2l
    b2g: db "k8s, net"
b2g_len equ $ - b2g
    b2c: db "kubectl port-forward svc/api 8080:80", 10
         db "curl localhost:8080/healthz"
b2c_len equ $ - b2c
    b3t: db "jq filter users"
b3t_len equ $ - b3t
    b3l: db "jq"
b3l_len equ $ - b3l
    b3g: db "json, cli"
b3g_len equ $ - b3g
    b3c: db "curl -s localhost:3000/users | jq '.[] | .name'"
b3c_len equ $ - b3c
    b_id1: db "s1"
b_id1_len equ $ - b_id1
    b_id2: db "s2"
b_id2_len equ $ - b_id2
    b_id3: db "s3"
b_id3_len equ $ - b_id3
    b_c1: db "dotfiles"
b_c1_len equ $ - b_c1
    b_c2: db "docker"
b_c2_len equ $ - b_c2
    b_c3: db "sql"
b_c3_len equ $ - b_c3
    b_cid1: db "c1"
b_cid1_len equ $ - b_cid1
    b_cid2: db "c2"
b_cid2_len equ $ - b_cid2
    b_cid3: db "c3"
b_cid3_len equ $ - b_cid3

section .bss
    file_buf:  resb FILE_MAX
    file_len:  resq 1
    sn_recs:   resb REC_SIZE * MAX_SNIPPETS
    sn_count:  resq 1
    cur_rec:   resq 1
    path_buf:  resb PATH_MAX
    load_path_buf: resb PATH_MAX
    save_path_buf: resb PATH_MAX + 16
    tag_tmp:   resb 256
    tag_len:   resd 1
    coll_names: resb MAX_COLLS * COLL_NAME_LEN
    coll_lens:  resd MAX_COLLS
    coll_count: resq 1
    coll_ids:   resb MAX_COLLS * COLL_ID_LEN
    coll_cats:  resq MAX_COLLS
    fk_ptr:    resq 1
    fk_len:    resd 1
    save_fd:   resd 1
    num_tmp:   resb 24

section .text

; u64 db_count(void)
db_count:
    mov rax, [sn_count]
    ret

; char *db_default_path(void) — $HOME/.cmdkeepa/db.json ou "db.json"
db_default_path:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8                      ; 2 pushes = 16B; 8-16 mod16 = 8 -> alinha
    lea rdi, [home_var]
    call getenv wrt ..plt
    test rax, rax
    jz .rel
    mov rbx, rax
    lea rdi, [path_buf]
    xor ecx, ecx
.cp1:
    cmp ecx, PATH_MAX - 24
    jae .rel
    mov al, [rbx+rcx]
    mov [rdi+rcx], al
    inc ecx
    test al, al
    jnz .cp1
    dec ecx                         ; volta ao NUL
    lea rsi, [home_suffix]
.cp2:
    mov al, [rsi]
    mov [rdi+rcx], al
    inc rsi
    inc ecx
    test al, al
    jnz .cp2
    lea rax, [path_buf]
    jmp .done
.rel:
    lea rax, [rel_path]
.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret

; db_prepare_dir(rdi=path) — cria o diretório de path (mkdir de 1 nível,
; ignora EEXIST/erro). O default $HOME/.cmdkeepa pode não existir no 1o uso;
; sem isso o save falharia silenciosamente. Não cria cadeia (um nível basta).
; Preserva rdi. Não chama libc (pode rodar antes de tudo).
db_prepare_dir:
    push r12
    mov r12, rdi
    xor ecx, ecx
    mov r8, -1
.find:
    mov al, [r12+rcx]
    test al, al
    jz .end
    cmp al, '/'
    jne .nx
    mov r8, rcx
.nx:
    inc ecx
    jmp .find
.end:
    cmp r8, 0
    jle .ret                        ; sem '/' ou raiz: nada a criar
    mov byte [r12+r8], 0
    mov eax, 83                     ; sys_mkdir
    mov rdi, r12
    mov esi, 493                    ; 0755
    syscall
    mov byte [r12+r8], '/'
.ret:
    pop r12
    ret

; u64 db_load(const char *path)
db_load:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    ; 5 pushes = 40B; 8-40 mod16 = 0 — alinhado, sem sub
    mov r14, rdi                    ; path
    ; garante o diretório do DB (ex. ~/.cmdkeepa no 1o uso)
    call db_prepare_dir
    ; guarda cópia: db_save regrava NESTE caminho (é o banco)
    mov rsi, rdi
    lea rdi, [load_path_buf]
    xor ecx, ecx
.cppath:
    cmp ecx, PATH_MAX - 1
    jae .pathdone
    mov al, [rsi+rcx]
    mov [rdi+rcx], al
    inc ecx
    test al, al
    jnz .cppath
.pathdone:

    mov eax, 2                      ; sys_open
    mov rdi, r14
    xor esi, esi                    ; O_RDONLY
    xor edx, edx
    syscall
    cmp rax, 0
    jl .seed
    mov ebx, eax                    ; fd

    xor r13d, r13d                  ; total
.rd:
    mov rax, FILE_MAX
    sub rax, r13
    jle .eof
    xor eax, eax                    ; sys_read
    mov edi, ebx
    lea rsi, [file_buf]
    add rsi, r13
    mov rdx, FILE_MAX
    sub rdx, r13
    syscall
    cmp rax, 0
    jle .eof
    add r13, rax
    jmp .rd
.eof:
    mov eax, 3                      ; sys_close
    mov edi, ebx
    syscall
    mov [file_len], r13
    test r13, r13
    jz .seed

    lea r12, [file_buf]
    lea r15, [file_buf]
    add r15, r13
    call parse_doc
    lea r12, [file_buf]             ; collections: recomeça do início
    call parse_colls
    cmp qword [sn_count], 0
    je .seed
    mov rax, [sn_count]
    jmp .done
.seed:
    call db_seed_builtin
    ; materializa o seed no DB já no 1o start: sem isso, ids/datas nasceriam
    ; de novo a cada abertura e o arquivo só existiria após alguma mutação.
    ; Falha de save é silenciosa aqui (app continua com o seed em memória).
    call db_save
    mov rax, [sn_count]
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ---------- helpers de parse ----------

; skip_ws — avança r12 sobre espaço/tab/LF/CR
skip_ws:
.sw:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, ' '
    je .adv
    cmp al, 9
    je .adv
    cmp al, 10
    je .adv
    cmp al, 13
    je .adv
    ret
.adv:
    inc r12
    jmp .sw
.ret:
    ret

; j_memeq(rdi=a, rsi=b, edx=len) — eax 0 se iguais
j_memeq:
    test edx, edx
    jz .eq
    xor ecx, ecx
.lp:
    mov al, [rdi+rcx]
    cmp al, [rsi+rcx]
    jne .ne
    inc ecx
    cmp ecx, edx
    jb .lp
.eq:
    xor eax, eax
    ret
.ne:
    mov eax, 1
    ret

; parse_u64 — r12=cursor (ws já pulado). rax=u64, cursor após dígitos.
parse_u64:
    xor eax, eax
    cmp r12, r15
    jae .ret
    cmp byte [r12], '-'
    jne .plus
    inc r12
    jmp .lp
.plus:
    cmp byte [r12], '+'
    jne .lp
    inc r12
.lp:
    cmp r12, r15
    jae .ret
    movzx ecx, byte [r12]
    sub ecx, '0'
    cmp ecx, 9
    ja .ret
    imul rax, rax, 10
    add rax, rcx
    inc r12
    jmp .lp
.ret:
    ret

; strlen_cap(rsi=ptr, edx=cap) — eax=len até NUL ou cap
strlen_cap:
    xor eax, eax
.lp:
    cmp eax, edx
    jae .ret
    cmp byte [rsi+rax], 0
    je .ret
    inc eax
    jmp .lp
.ret:
    ret

; parse_str_field(rdi=dst, esi=cap, r8=lenstore dword*)
; r12 deve apontar para '"'. Consome até após a aspa final, com unescape.
parse_str_field:
    cmp r12, r15
    jae .abort
    cmp byte [r12], '"'
    jne .abort
    inc r12
    xor ecx, ecx
.loop:
    cmp r12, r15
    jae .abort
    mov al, [r12]
    cmp al, '"'
    je .done
    cmp al, '\'
    je .esc
    cmp ecx, esi
    jae .skip1
    mov [rdi+rcx], al
.skip1:
    inc rcx
    inc r12
    jmp .loop
.esc:
    inc r12
    cmp r12, r15
    jae .abort
    mov al, [r12]
    inc r12
    cmp al, '"'
    je .emit
    cmp al, '\'
    je .emit
    cmp al, '/'
    je .emit
    cmp al, 'n'
    jne .e_r
    mov al, 10
    jmp .emit
.e_r:
    cmp al, 'r'
    jne .e_t
    mov al, 13
    jmp .emit
.e_t:
    cmp al, 't'
    jne .e_b
    mov al, 9
    jmp .emit
.e_b:
    cmp al, 'b'
    jne .e_f
    mov al, 8
    jmp .emit
.e_f:
    cmp al, 'f'
    jne .e_u
    mov al, 12
    jmp .emit
.e_u:
    cmp al, 'u'
    jne .emit                       ; escape desconhecido: usa o char cru
    push r9                         ; hex usa r9/r10 (tags loop os usa!)
    push r10
    xor edx, edx                    ; valor \uXXXX
    mov r9d, 4
.hex:
    cmp r12, r15
    jae .hexdone
    mov r10b, [r12]
    mov eax, 0
    cmp r10b, '0'
    jb .hexbreak
    cmp r10b, '9'
    jbe .hexdig
    cmp r10b, 'a'
    jb .hexup
    cmp r10b, 'f'
    ja .hexbreak
    movzx eax, r10b
    sub eax, 'a' - 10
    jmp .hexgot
.hexup:
    cmp r10b, 'A'
    jb .hexbreak
    cmp r10b, 'F'
    ja .hexbreak
    movzx eax, r10b
    sub eax, 'A' - 10
    jmp .hexgot
.hexdig:
    movzx eax, r10b
    sub eax, '0'
.hexgot:
    shl edx, 4
    or edx, eax
    inc r12
    dec r9d
    jnz .hex
.hexdone:
.hexbreak:
    pop r10
    pop r9
    cmp edx, 0xFF
    ja .qmark
    mov al, dl
    jmp .emit
.qmark:
    mov al, '?'
    jmp .emit
.emit:
    cmp ecx, esi
    jae .skip2
    mov [rdi+rcx], al
.skip2:
    inc rcx
    jmp .loop
.done:
    inc r12
    mov eax, ecx
    cmp eax, esi
    cmova eax, esi
    mov [r8], eax
    mov byte [rdi+rax], 0
    ret
.abort:
    xor eax, eax
    mov [r8], eax
    mov byte [rdi], 0
    ret

; skip_value — pula string/objeto/array/literal a partir de r12
skip_value:
    call skip_ws
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, '"'
    je .str
    cmp al, '{'
    je .bra
    cmp al, '['
    je .bra
.lit:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, ','
    je .ret
    cmp al, '}'
    je .ret
    cmp al, ']'
    je .ret
    inc r12
    jmp .lit
.str:
    inc r12
.strlp:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    inc r12
    cmp al, '\'
    jne .nsq
    cmp r12, r15
    jae .ret
    inc r12
    jmp .strlp
.nsq:
    cmp al, '"'
    jne .strlp
    ret
.bra:
    inc r12
    mov edx, 1
.bloop:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    inc r12
    cmp al, '"'
    je .inner
    cmp al, '{'
    je .open
    cmp al, '['
    je .open
    cmp al, '}'
    je .close
    cmp al, ']'
    je .close
    jmp .bloop
.open:
    inc edx
    jmp .bloop
.close:
    dec edx
    jnz .bloop
    ret
.inner:
.il:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    inc r12
    cmp al, '\'
    jne .iq
    cmp r12, r15
    jae .ret
    inc r12
    jmp .il
.iq:
    cmp al, '"'
    jne .il
    jmp .bloop
.ret:
    ret

; expect_colon — ws ':' ws. CF=0 ok.
expect_colon:
    call skip_ws
    cmp r12, r15
    jae .fail
    cmp byte [r12], ':'
    jne .fail
    inc r12
    call skip_ws
    clc
    ret
.fail:
    stc
    ret

; find_key_array — fk_ptr/fk_len = chave SEM aspas. Posiciona r12 após '['. eax 1/0.
find_key_array:
.scan:
    mov rax, r15
    sub rax, r12
    cmp rax, 12
    jb .fail
    cmp byte [r12], '"'
    jne .next
    lea rdi, [r12+1]
    mov rsi, [fk_ptr]
    mov edx, [fk_len]
    call j_memeq
    test eax, eax
    jnz .skipstr
    mov eax, [fk_len]
    lea rcx, [r12+1]
    cmp byte [rcx+rax], '"'
    jne .skipstr
    lea r12, [rcx+rax+1]
    call skip_ws
    cmp r12, r15
    jae .fail
    cmp byte [r12], ':'
    jne .scan                       ; falso positivo — segue scan
    inc r12
    call skip_ws
    cmp r12, r15
    jae .fail
    cmp byte [r12], '['
    jne .scan
    inc r12
    mov eax, 1
    ret
.skipstr:
    ; pula a string atual e segue
    inc r12
.sstr:
    cmp r12, r15
    jae .fail
    mov al, [r12]
    inc r12
    cmp al, '\'
    jne .sstrq
    cmp r12, r15
    jae .fail
    inc r12
    jmp .sstr
.sstrq:
    cmp al, '"'
    jne .sstr
    jmp .scan
.next:
    inc r12
    jmp .scan
.fail:
    xor eax, eax
    ret

; parse_tags_array — r12 em '['; junta strings com ", " em rec+tAGS. rec em rbx.
parse_tags_array:
    cmp r12, r15
    jae .ret
    cmp byte [r12], '['
    jne .notarr
    inc r12
    xor r10d, r10d                  ; curlen
    mov r9d, REC_TAGS_LEN - 1       ; cap
    mov r11d, 1                     ; first
.tloop:
    call skip_ws
    cmp r12, r15
    jae .fin
    mov al, [r12]
    cmp al, ']'
    je .close
    cmp al, ','
    je .comma
    cmp al, '"'
    je .str
    call skip_value
    jmp .tloop
.comma:
    inc r12
    jmp .tloop
.close:
    inc r12
    jmp .fin
.str:
    lea rdi, [tag_tmp]
    mov esi, 255
    lea r8, [tag_len]
    call parse_str_field
    mov r11d, 0
    ; append ", " se não é a primeira e há espaço
    cmp r10d, 0
    je .app
    mov eax, r10d
    cmp eax, r9d
    jae .app
    lea rdi, [rbx+REC_TAGS_OFF]
    mov byte [rdi+rax], ','
    inc eax
    cmp eax, r9d
    ja .setlen
    mov byte [rdi+rax], ' '
    inc eax
    jmp .setlen
.app:
    mov eax, r10d
.setlen:
    mov r10d, eax
    ; append tag_tmp
    mov ecx, [tag_len]
    test ecx, ecx
    jz .tloop
    lea rsi, [tag_tmp]
    lea rdi, [rbx+REC_TAGS_OFF]
.cp:
    cmp r10d, r9d
    jae .tloop
    mov al, [rsi]
    mov [rdi+r10], al
    inc rsi
    inc r10d
    dec ecx
    jnz .cp
    jmp .tloop
.fin:
    lea rdi, [rbx+REC_TAGS_OFF]
    mov eax, r10d
    cmp eax, r9d
    cmova eax, r9d
    mov [rbx+REC_GLEN_OFF], eax
    mov byte [rdi+rax], 0
.ret:
    ret
.notarr:
    call skip_value
    ret

; parse_object — r12 em '{', rec em rbx. Consome até '}'.
parse_object:
    inc r12
.loop:
    call skip_ws
    cmp r12, r15
    jae .end
    mov al, [r12]
    cmp al, '}'
    je .endok
    cmp al, ','
    je .comma
    cmp al, '"'
    jne .skip1
    ; tenta as 4 chaves ([r12+1], com aspa final inclusa)
    lea rdi, [r12+1]
    lea rsi, [k_title]
    mov edx, 6
    call j_memeq
    test eax, eax
    jz .f_title
    lea rdi, [r12+1]
    lea rsi, [k_code]
    mov edx, 5
    call j_memeq
    test eax, eax
    jz .f_code
    lea rdi, [r12+1]
    lea rsi, [k_tags]
    mov edx, 5
    call j_memeq
    test eax, eax
    jz .f_tags
    lea rdi, [r12+1]
    lea rsi, [k_lang]
    mov edx, 9
    call j_memeq
    test eax, eax
    jz .f_lang
    lea rdi, [r12+1]
    lea rsi, [k_fav]
    mov edx, 9
    call j_memeq
    test eax, eax
    jz .f_fav
    lea rdi, [r12+1]
    lea rsi, [k_id]
    mov edx, 3
    call j_memeq
    test eax, eax
    jz .f_id
    lea rdi, [r12+1]
    lea rsi, [k_desc]
    mov edx, 12
    call j_memeq
    test eax, eax
    jz .f_desc
    lea rdi, [r12+1]
    lea rsi, [k_collid]
    mov edx, 13                         ; 'collectionId"' = 13 (pegava o ':' junto!)
    call j_memeq
    test eax, eax
    jz .f_collid
    lea rdi, [r12+1]
    lea rsi, [k_created]
    mov edx, 10
    call j_memeq
    test eax, eax
    jz .f_created
    lea rdi, [r12+1]
    lea rsi, [k_updated]
    mov edx, 10
    call j_memeq
    test eax, eax
    jz .f_updated
    lea rdi, [r12+1]
    lea rsi, [k_views]
    mov edx, 6
    call j_memeq
    test eax, eax
    jz .f_views
    lea rdi, [r12+1]
    lea rsi, [k_versions]
    mov edx, 9
    call j_memeq
    test eax, eax
    jz .f_versions
    call skip_value                  ; chave desconhecida: pula a string + valor
    jmp .colon_val
.skip1:
    inc r12
    jmp .loop
.comma:
    inc r12
    jmp .loop
.f_title:
    add r12, 7
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_TITLE_OFF]
    mov esi, REC_TITLE_LEN - 1
    lea r8, [rbx+REC_TLEN_OFF]
    call parse_str_field
    jmp .loop
.f_code:
    add r12, 6
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_CODE_OFF]
    mov esi, REC_CODE_LEN - 1
    lea r8, [rbx+REC_CLEN_OFF]
    call parse_str_field
    jmp .loop
.f_tags:
    add r12, 6
    call expect_colon
    jc .loop
    call parse_tags_array
    jmp .loop
.f_lang:
    add r12, 10
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_LANG_OFF]
    mov esi, REC_LANG_LEN - 1
    lea r8, [rbx+REC_LLEN_OFF]
    call parse_str_field
    jmp .loop
.f_fav:
    add r12, 10
    call expect_colon
    jc .loop
    mov rax, r15
    sub rax, r12
    cmp rax, 5
    jb .fav0
    cmp dword [r12], 0x65757274     ; "true"
    jne .favchk
    add r12, 4
    mov byte [rbx+REC_FAV_OFF], 1
    jmp .loop
.favchk:
    cmp dword [r12], 0x736C6166     ; "fals"
    jne .favskip
    cmp byte [r12+4], 'e'
    jne .favskip
    add r12, 5
.fav0:
    mov byte [rbx+REC_FAV_OFF], 0
    jmp .loop
.favskip:
    call skip_value
    mov byte [rbx+REC_FAV_OFF], 0
    jmp .loop
.f_id:
    add r12, 4
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_ID_OFF]
    mov esi, REC_ID_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_desc:
    add r12, 13
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_DESC_OFF]
    mov esi, REC_DESC_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_collid:
    add r12, 14                         ; '"collectionId"' = 14 chars
    call expect_colon
    jc .loop
    cmp r12, r15
    jae .loop
    cmp byte [r12], 'n'             ; null -> vazio
    jne .cidstr
    call skip_value
    mov byte [rbx+REC_CID_OFF], 0
    jmp .loop
.cidstr:
    lea rdi, [rbx+REC_CID_OFF]
    mov esi, REC_CID_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_created:
    add r12, 11
    call expect_colon
    jc .loop
    call parse_u64
    mov [rbx+REC_CREATED_OFF], rax
    jmp .loop
.f_updated:
    add r12, 11
    call expect_colon
    jc .loop
    call parse_u64
    mov [rbx+REC_UPDATED_OFF], rax
    jmp .loop
.f_views:
    add r12, 7
    call expect_colon
    jc .loop
    call parse_u64
    mov [rbx+REC_VIEWS_OFF], eax
    jmp .loop
.f_versions:
    add r12, 10
    call expect_colon
    jc .loop
    cmp r12, r15
    jae .loop
    cmp byte [r12], '['
    jne .vskip
    inc r12
.vloop:
    call skip_ws
    cmp r12, r15
    jae .loop
    mov al, [r12]
    cmp al, ']'
    je .vclosed
    cmp al, ','
    je .vcomma
    cmp al, '{'
    jne .vskip1
    mov eax, [rbx+REC_VNUM_OFF]
    cmp eax, MAX_VERSIONS
    jae .vskipobj
    push rbx
    imul rax, rax, VER_SIZE
    lea rbx, [rbx+REC_VERS_OFF+rax]
    call parse_ver_obj
    pop rbx
    mov eax, [rbx+REC_VNUM_OFF]
    inc eax
    mov [rbx+REC_VNUM_OFF], eax
    jmp .vloop
.vskipobj:
    call skip_value
    jmp .vloop
.vcomma:
    inc r12
    jmp .vloop
.vclosed:
    inc r12
    jmp .loop
.vskip1:
    inc r12
    jmp .vloop
.vskip:
    call skip_value
    jmp .loop
.colon_val:
    ; após pular chave desconhecida (string), pula : valor
    call expect_colon
    jc .loop
    call skip_value
    jmp .loop
.endok:
    inc r12
.end:
    ; defaults: title vazio -> "Untitled", lang vazia -> "plaintext"
    cmp dword [rbx+REC_TLEN_OFF], 0
    jne .havet
    mov rax, 0x64656C7469746E55     ; "Untitled"
    mov [rbx+REC_TITLE_OFF], rax
    mov dword [rbx+REC_TLEN_OFF], 8
.havet:
    cmp dword [rbx+REC_LLEN_OFF], 0
    jne .ret
    mov rax, 0x7865746E69616C70     ; "plaint ex"? "plaintext"[0..7]
    mov [rbx+REC_LANG_OFF], rax
    mov byte [rbx+REC_LANG_OFF+8], 't'
    mov dword [rbx+REC_LLEN_OFF], 9
.ret:
    ret

; parse_ver_obj — r12 em '{', rbx = slot versão (code+0 2048B, at+2048).
; rbx preservado pelo chamador via push (aqui rbx é scratch permitido).
parse_ver_obj:
    push r10
    inc r12
.loop:
    call skip_ws
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, '}'
    je .endok
    cmp al, ','
    je .comma
    cmp al, '"'
    jne .skip1
    lea rdi, [r12+1]
    lea rsi, [k_code]
    mov edx, 5
    call j_memeq
    test eax, eax
    jz .f_code
    lea rdi, [r12+1]
    lea rsi, [k_at]
    mov edx, 3
    call j_memeq
    test eax, eax
    jz .f_at
    call skip_value
    jmp .cval
.skip1:
    inc r12
    jmp .loop
.comma:
    inc r12
    jmp .loop
.f_code:
    add r12, 6
    call expect_colon
    jc .loop
    mov rdi, rbx
    mov esi, VER_CODE_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_at:
    add r12, 4
    call expect_colon
    jc .loop
    call parse_u64
    mov [rbx+2048], rax
    jmp .loop
.cval:
    call expect_colon
    jc .loop
    call skip_value
    jmp .loop
.endok:
    inc r12
.ret:
    pop r10
    ret

; parse_doc — r12=início, r15=fim. Preenche sn_recs/sn_count.
parse_doc:
    mov qword [sn_count], 0
    lea rax, [k_snip]
    mov [fk_ptr], rax
    mov dword [fk_len], 8
    call find_key_array
    test eax, eax
    jz .ret
.arr:
    call skip_ws
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, ']'
    je .closed
    cmp al, ','
    je .comma
    cmp al, '{'
    jne .skip1
    mov rax, [sn_count]
    cmp rax, MAX_SNIPPETS
    jae .skipobj
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    mov [cur_rec], rbx
    call parse_object
    mov rax, [sn_count]
    inc rax
    mov [sn_count], rax
    jmp .arr
.skipobj:
    call skip_value
    jmp .arr
.comma:
    inc r12
    jmp .arr
.closed:
    inc r12
    jmp .ret
.skip1:
    inc r12
    jmp .arr
.ret:
    ret

; seed_one(tptr,tlen, lptr,llen, gptr,glen, cptr,clen, iptr,ilen, dptr,dlen)
; 12 args: 6 em regs + 6 na pilha (caller faz sub rsp,48). dptr/dlen =
; collectionId (NUL-terminated no rec; vazio = unfiled).
seed_one:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                      ; 6 pushes=48B; 8-48 mod16=8 -> alinha
    mov rax, [sn_count]
    cmp rax, MAX_SNIPPETS
    jae .ret
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    mov r12, [rbp+16]               ; cptr
    mov r13d, [rbp+24]              ; clen
    mov r14, [rbp+32]               ; iptr
    mov r15d, [rbp+40]              ; ilen
    ; spill: rep movsb destrói rcx/rsi/rdi — salva args restantes
    sub rsp, 32
    mov [rsp], rdx                  ; lsrc
    mov [rsp+8], rcx                ; llen
    mov [rsp+16], r8                ; gsrc
    mov [rsp+24], r9                ; glen
    ; title: rdi=src esi=len
    mov r10, rdi
    mov r11d, esi
    lea rdi, [rbx+REC_TITLE_OFF]
    mov rsi, r10
    mov eax, r11d
    mov edx, REC_TITLE_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_TLEN_OFF], eax
    mov ecx, eax
    jecxz .t0
    rep movsb
.t0:
    mov byte [rdi], 0
    ; lang: lsrc/llen do spill
    mov r10, [rsp]
    mov r11d, [rsp+8]
    lea rdi, [rbx+REC_LANG_OFF]
    mov rsi, r10
    mov eax, r11d
    mov edx, REC_LANG_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_LLEN_OFF], eax
    mov ecx, eax
    jecxz .l0
    rep movsb
.l0:
    mov byte [rdi], 0
    ; tags: gsrc/glen do spill
    mov r10, [rsp+16]
    mov r11d, [rsp+24]
    lea rdi, [rbx+REC_TAGS_OFF]
    mov rsi, r10
    mov eax, r11d
    mov edx, REC_TAGS_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_GLEN_OFF], eax
    mov ecx, eax
    jecxz .g0
    rep movsb
.g0:
    mov byte [rdi], 0
    ; code: r12=src r13d=len
    lea rdi, [rbx+REC_CODE_OFF]
    mov rsi, r12
    mov eax, r13d
    mov edx, REC_CODE_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_CLEN_OFF], eax
    mov ecx, eax
    jecxz .c0
    rep movsb
.c0:
    mov byte [rdi], 0
    mov byte [rbx+REC_FAV_OFF], 0
    ; id
    lea rdi, [rbx+REC_ID_OFF]
    mov rsi, r14
    mov eax, r15d
    mov edx, REC_ID_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov ecx, eax
    jecxz .i0
    rep movsb
.i0:
    mov byte [rdi], 0
    ; resto zerado pelo BSS; datas = agora
    mov byte [rbx+REC_DESC_OFF], 0
    ; cid: r12/r13 (code) já mortos aqui
    mov r12, [rbp+48]
    mov r13d, [rbp+56]
    lea rdi, [rbx+REC_CID_OFF]
    mov rsi, r12
    mov eax, r13d
    mov edx, REC_CID_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov ecx, eax
    jecxz .cid0
    rep movsb
.cid0:
    mov byte [rdi], 0
    mov dword [rbx+REC_VIEWS_OFF], 0
    mov dword [rbx+REC_VNUM_OFF], 0
    mov eax, 201                    ; sys_time
    xor edi, edi
    syscall                         ; rax = epoch (clobber rcx,r11 — mortos aqui)
    mov [rbx+REC_CREATED_OFF], rax
    mov [rbx+REC_UPDATED_OFF], rax
    mov rax, [sn_count]
    inc rax
    mov [sn_count], rax
.ret:
    add rsp, 32
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; db_seed_builtin — 3 snippets demo quando sem arquivo
db_seed_builtin:
    push rbp
    mov rbp, rsp
    mov qword [sn_count], 0
    mov qword [coll_count], 0
    ; seed_one recebe cptr/clen/iptr/ilen/dptr/dlen na pilha (48B)
    sub rsp, 48
    lea rdi, [b1t]
    mov esi, b1t_len
    lea rdx, [b1l]
    mov ecx, b1l_len
    lea r8, [b1g]
    mov r9d, b1g_len
    lea rax, [b1c]
    mov [rsp], rax
    mov qword [rsp+8], b1c_len
    lea rax, [b_id1]
    mov [rsp+16], rax
    mov qword [rsp+24], b_id1_len
    lea rax, [b_cid2]
    mov [rsp+32], rax
    mov qword [rsp+40], b_cid2_len
    call seed_one
    lea rdi, [b2t]
    mov esi, b2t_len
    lea rdx, [b2l]
    mov ecx, b2l_len
    lea r8, [b2g]
    mov r9d, b2g_len
    lea rax, [b2c]
    mov [rsp], rax
    mov qword [rsp+8], b2c_len
    lea rax, [b_id2]
    mov [rsp+16], rax
    mov qword [rsp+24], b_id2_len
    lea rax, [b_cid1]
    mov [rsp+32], rax
    mov qword [rsp+40], b_cid1_len
    call seed_one
    lea rdi, [b3t]
    mov esi, b3t_len
    lea rdx, [b3l]
    mov ecx, b3l_len
    lea r8, [b3g]
    mov r9d, b3g_len
    lea rax, [b3c]
    mov [rsp], rax
    mov qword [rsp+8], b3c_len
    lea rax, [b_id3]
    mov [rsp+16], rax
    mov qword [rsp+24], b_id3_len
    lea rax, [b_cid3]
    mov [rsp+32], rax
    mov qword [rsp+40], b_cid3_len
    call seed_one
    add rsp, 48
    lea rsi, [b_c1]
    mov edx, b_c1_len
    lea r8, [b_cid1]
    mov r9d, b_cid1_len
    call seed_coll_one
    lea rsi, [b_c2]
    mov edx, b_c2_len
    lea r8, [b_cid2]
    mov r9d, b_cid2_len
    call seed_coll_one
    lea rsi, [b_c3]
    mov edx, b_c3_len
    lea r8, [b_cid3]
    mov r9d, b_cid3_len
    call seed_coll_one
    pop rbp
    ret

; seed_coll_one(rsi=name, edx=namelen, r8=idptr, r9d=idlen) — leaf, sem calls
; syscall só clobbera rax/rcx/r11: args em rsi/rdx/r8/r9 sobrevivem.
seed_coll_one:
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .ret
    mov r10, rax                    ; idx
    mov eax, 201                    ; sys_time
    xor edi, edi
    syscall
    mov [coll_cats+r10*8], rax
    imul rax, r10, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    mov eax, edx
    mov ecx, COLL_NAME_LEN - 1
    cmp eax, ecx
    cmova eax, ecx
    mov [coll_lens+r10*4], eax
    mov ecx, eax
    jecxz .noname
    rep movsb
.noname:
    mov byte [rdi], 0
    ; id
    imul rax, r10, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    mov rsi, r8
    mov eax, r9d
    mov ecx, COLL_ID_LEN - 1
    cmp eax, ecx
    cmova eax, ecx
    mov ecx, eax
    jecxz .noid
    rep movsb
.noid:
    mov byte [rdi], 0
    mov rax, [coll_count]
    inc rax
    mov [coll_count], rax
.ret:
    ret

; ---------- collections ----------

; parse_coll_obj — r12 em '{'. Extrai "name" p/ slot coll_count (ou descarta).
parse_coll_obj:
    inc r12
.loop:
    call skip_ws
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, '}'
    je .endok
    cmp al, ','
    je .comma
    cmp al, '"'
    jne .skip1
    lea rdi, [r12+1]
    lea rsi, [k_name]
    mov edx, 5
    call j_memeq
    test eax, eax
    jz .f_name
    lea rdi, [r12+1]
    lea rsi, [k_id]
    mov edx, 3
    call j_memeq
    test eax, eax
    jz .f_id
    lea rdi, [r12+1]
    lea rsi, [k_created]
    mov edx, 10
    call j_memeq
    test eax, eax
    jz .f_created
    call skip_value
    jmp .cval
.skip1:
    inc r12
    jmp .loop
.comma:
    inc r12
    jmp .loop
.f_name:
    add r12, 6
    call expect_colon
    jc .loop
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .discard
    mov rsi, rax
    imul rax, rax, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    lea r8, [coll_lens]
    lea r8, [r8+rsi*4]
    mov esi, COLL_NAME_LEN - 1
    call parse_str_field
    jmp .loop
.discard:
    lea rdi, [tag_tmp]
    mov esi, 255
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_id:
    add r12, 4
    call expect_colon
    jc .loop
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .discard
    imul rax, rax, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    mov esi, COLL_ID_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_created:
    add r12, 11
    call expect_colon
    jc .loop
    call parse_u64
    mov rcx, [coll_count]
    cmp rcx, MAX_COLLS
    jae .loop
    mov [coll_cats+rcx*8], rax
    jmp .loop
.cval:
    call expect_colon
    jc .loop
    call skip_value
    jmp .loop
.endok:
    inc r12
.ret:
    ret

; parse_colls — r12=início, r15=fim. Preenche coll_names/coll_lens/coll_count.
parse_colls:
    mov qword [coll_count], 0
    lea rax, [k_coll]
    mov [fk_ptr], rax
    mov dword [fk_len], 11
    call find_key_array
    test eax, eax
    jz .ret
.arr:
    call skip_ws
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, ']'
    je .closed
    cmp al, ','
    je .comma
    cmp al, '{'
    jne .skip1
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .skipobj
    call parse_coll_obj
    mov rax, [coll_count]
    inc rax
    mov [coll_count], rax
    jmp .arr
.skip1:
    inc r12
    jmp .arr
.skipobj:
    call skip_value
    jmp .arr
.comma:
    inc r12
    jmp .arr
.closed:
    inc r12
.ret:
    ret

; ---------- writer JSON (subset) ----------
; Cursor de saída: r12 sobre file_buf (reuso pós-parse). Preservados: rbx,r13-r15.
; Scratch dos helpers: rax,rcx,rdx,rsi,rdi,r8,r9,r11.

; emit_byte — al -> saída
emit_byte:
    cmp r12, FILE_MAX - 1
    jae .ret
    lea rcx, [file_buf]
    mov [rcx+r12], al
    inc r12
.ret:
    ret

; emit_raw(rsi=ptr, edx=len)
emit_raw:
    test edx, edx
    jz .ret
    lea rdi, [file_buf]
.loop:
    test edx, edx
    jz .ret
    cmp r12, FILE_MAX - 1
    jae .ret
    mov al, [rsi]
    mov [rdi+r12], al
    inc rsi
    inc r12
    dec edx
    jmp .loop
.ret:
    ret

; emit_esc(rsi=ptr, edx=len) — string com escape JSON
emit_esc:
    test edx, edx
    jz .ret
    lea rdi, [file_buf]
.loop:
    test edx, edx
    jz .ret
    cmp r12, FILE_MAX - 8
    jae .ret
    mov al, [rsi]
    inc rsi
    dec edx
    cmp al, '"'
    je .q
    cmp al, '\'
    je .bs
    cmp al, 10
    je .n
    cmp al, 13
    je .r
    cmp al, 9
    je .t
    cmp al, 8
    je .b
    cmp al, 12
    je .f
    cmp al, 0x20
    jae .raw
    push r11                        ; hex usa r11 (índice de loops chamadores!)
    mov byte [rdi+r12], '\'
    mov byte [rdi+r12+1], 'u'
    mov byte [rdi+r12+2], '0'
    mov byte [rdi+r12+3], '0'
    movzx r11d, al
    shr r11d, 4
    and al, 0x0F
    lea rcx, [hexdig]
    mov r11b, [rcx+r11]
    mov [rdi+r12+4], r11b
    movzx eax, al
    mov r11b, [rcx+rax]
    mov [rdi+r12+5], r11b
    pop r11
    add r12, 6
    jmp .loop
.q:  mov word [rdi+r12], 0x225C
    add r12, 2
    jmp .loop
.bs: mov word [rdi+r12], 0x5C5C
    add r12, 2
    jmp .loop
.n:  mov word [rdi+r12], 0x6E5C
    add r12, 2
    jmp .loop
.r:  mov word [rdi+r12], 0x725C
    add r12, 2
    jmp .loop
.t:  mov word [rdi+r12], 0x745C
    add r12, 2
    jmp .loop
.b:  mov word [rdi+r12], 0x625C
    add r12, 2
    jmp .loop
.f:  mov word [rdi+r12], 0x665C
    add r12, 2
    jmp .loop
.raw:
    mov [rdi+r12], al
    inc r12
    jmp .loop
.ret:
    ret

; emit_u64(rax=num) — decimal via num_tmp
; Preserva r11 (usado como índice por loops chamadores).
emit_u64:
    push r11
    lea rdi, [num_tmp]
    lea rcx, [num_tmp+20]
    mov rsi, rcx
    test rax, rax
    jnz .loop
    dec rsi
    mov byte [rsi], '0'
    jmp .out
.loop:
    mov r11, 10
    xor edx, edx
    div r11
    add dl, '0'
    dec rsi
    mov [rsi], dl
    test rax, rax
    jnz .loop
.out:
    mov rdx, rcx
    sub rdx, rsi
    call emit_raw
    pop r11
    ret

; i64 db_save(void) — grava o DB no MESMO caminho carregado (persistência
; real). Atômico: escreve <path>.tmp, fsync, rename -> <path>. Um crash no
; meio deixa o DB anterior intacto (antes salvávamos num sibling .native.json
; e as mudanças sumiam no próximo start). Retorna n ou -1.
db_save:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    ; 6 pushes = 48B, alinhado

    lea rsi, [load_path_buf]
    lea rdi, [save_path_buf]
    xor ecx, ecx
.cp:
    cmp ecx, PATH_MAX - 1
    jae .fail
    mov al, [rsi+rcx]
    mov [rdi+rcx], al
    inc ecx
    test al, al
    jnz .cp
    dec ecx
    lea rsi, [tmp_suffix]
.cp2:
    mov al, [rsi]
    mov [rdi+rcx], al
    inc rsi
    inc ecx
    test al, al
    jnz .cp2

    mov eax, 2                      ; sys_open
    lea rdi, [save_path_buf]
    mov esi, 577                    ; O_WRONLY|O_CREAT|O_TRUNC
    mov edx, 420                    ; 0644
    syscall
    cmp rax, 0
    jl .fail
    mov [save_fd], eax              ; fd em BSS: rbx vira ponteiro de rec na emissão!

    xor r12d, r12d                  ; cursor de saída
    lea rsi, [j_open]
    mov edx, j_open_len
    call emit_raw
    mov eax, 201                    ; sys_time
    xor edi, edi
    syscall
    call emit_u64
    lea rsi, [j_mid1]
    mov edx, j_mid1_len
    call emit_raw

    mov rax, [sn_count]
    mov rdx, MAX_SNIPPETS
    cmp rax, rdx
    cmova rax, rdx
    mov r15, rax                    ; total
    xor r14d, r14d                  ; i
.sloop:
    cmp r14, r15
    jae .sdone
    test r14, r14
    jz .first
    mov al, ','
    call emit_byte
.first:
    mov rax, r14
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    lea rsi, [j_sopen]
    mov edx, j_sopen_len
    call emit_raw
    lea rsi, [rbx+REC_ID_OFF]
    mov edx, REC_ID_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    lea rsi, [j_sopen2]
    mov edx, j_sopen2_len
    call emit_raw
    lea rsi, [rbx+REC_TITLE_OFF]
    mov edx, [rbx+REC_TLEN_OFF]
    cmp edx, REC_TITLE_LEN - 1
    jbe .titleok
    mov edx, REC_TITLE_LEN - 1
.titleok:
    call emit_esc
    lea rsi, [j_l1]
    mov edx, j_l1_len
    call emit_raw
    lea rsi, [rbx+REC_CODE_OFF]
    mov edx, [rbx+REC_CLEN_OFF]
    cmp edx, REC_CODE_LEN - 1
    jbe .codeok
    mov edx, REC_CODE_LEN - 1
.codeok:
    call emit_esc
    lea rsi, [j_l2]
    mov edx, j_l2_len
    call emit_raw
    lea rsi, [rbx+REC_LANG_OFF]
    mov edx, [rbx+REC_LLEN_OFF]
    cmp edx, REC_LANG_LEN - 1
    jbe .langok
    mov edx, REC_LANG_LEN - 1
.langok:
    call emit_esc
    lea rsi, [j_l3a]
    mov edx, j_l3a_len
    call emit_raw
    lea rsi, [rbx+REC_DESC_OFF]
    mov edx, REC_DESC_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    lea rsi, [j_l3b]
    mov edx, j_l3b_len
    call emit_raw
    ; tags "a, b" -> "a","b" (colchetes vêm de j_l3/j_l4)
    ; Robusto por construção: glen limitado ao buffer, sem push/pop, e
    ; cada iteração consome >=1 byte de r10d (ou sai) -> termina sempre.
    lea r13, [rbx+REC_TAGS_OFF]
    mov r10d, [rbx+REC_GLEN_OFF]
    cmp r10d, REC_TAGS_LEN - 1
    jbe .gok
    mov r10d, REC_TAGS_LEN - 1
.gok:
    mov r11d, 1                     ; first=1 (nz=primeiro: pula a vírgula)
.tloop:
    test r10d, r10d
    jz .tdone
    cmp byte [r13], ' '
    jne .tok
    inc r13
    dec r10d
    jmp .tloop
.tok:
    test r10d, r10d
    jz .tdone
    cmp byte [r13], ','
    jne .tok2
    inc r13
    dec r10d
    jmp .tloop
.tok2:
    ; ecx = span até ',' ou fim (limitado por r10d)
    xor ecx, ecx
    jmp .tscan
.tscan:
    cmp ecx, r10d
    jae .temit
    cmp byte [r13+rcx], ','
    je .temit
    inc ecx
    jmp .tscan
.temit:
    ; edx = span sem espaços à direita
    mov edx, ecx
.tr: test edx, edx
    jz .tempty
    cmp byte [r13+rdx-1], ' '
    jne .temit2
    dec edx
    jmp .tr
.temit2:
    test r11d, r11d
    jnz .tfirst
    mov al, ','
    call emit_byte
.tfirst:
    mov r11d, 0
    mov al, '"'
    call emit_byte
    mov rsi, r13
    call emit_esc                   ; rsi=token edx=len
    mov al, '"'
    call emit_byte
.tempty:
    ; avança re-escaneando até passar uma vírgula (consome >=1 sempre:
    ; o token tinha >=1 char não-espaço não-vírgula)
.adv:
    test r10d, r10d
    jz .tdone
    mov al, [r13]
    inc r13
    dec r10d
    cmp al, ','
    jne .adv
    jmp .tloop
.tdone:
    lea rsi, [j_l4a]
    mov edx, j_l4a_len
    call emit_raw
    cmp byte [rbx+REC_CID_OFF], 0
    jne .cidstr
    lea rsi, [j_null]
    mov edx, j_null_len
    call emit_raw
    jmp .cidend
.cidstr:
    mov al, '"'
    call emit_byte
    lea rsi, [rbx+REC_CID_OFF]
    mov edx, REC_CID_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    mov al, '"'
    call emit_byte
.cidend:
    lea rsi, [j_l4b]
    mov edx, j_l4b_len
    call emit_raw
    cmp byte [rbx+REC_FAV_OFF], 0
    je .ffalse
    lea rsi, [j_true]
    mov edx, j_true_len
    call emit_raw
    jmp .fend
.ffalse:
    lea rsi, [j_false]
    mov edx, j_false_len
    call emit_raw
.fend:
    lea rsi, [j_l5a]
    mov edx, j_l5a_len
    call emit_raw
    mov rax, [rbx+REC_CREATED_OFF]
    call emit_u64
    lea rsi, [j_l5b]
    mov edx, j_l5b_len
    call emit_raw
    mov rax, [rbx+REC_UPDATED_OFF]
    call emit_u64
    lea rsi, [j_l5c]
    mov edx, j_l5c_len
    call emit_raw
    mov eax, [rbx+REC_VIEWS_OFF]
    call emit_u64
    lea rsi, [j_l5d]
    mov edx, j_l5d_len
    call emit_raw
    ; versions
    mov r10d, [rbx+REC_VNUM_OFF]
    cmp r10d, MAX_VERSIONS
    jbe .vok
    mov r10d, MAX_VERSIONS
.vok:
    xor r11d, r11d                  ; i
.vloop:
    cmp r11d, r10d
    jae .vdone
    test r11d, r11d
    jz .vfirst
    mov al, ','
    call emit_byte
.vfirst:
    mov eax, r11d
    imul eax, eax, VER_SIZE
    lea rsi, [rbx+REC_VERS_OFF+rax]
    mov r13, rsi                    ; vcode ptr (r13 livre aqui? r13=write-total só DEPOIS — agora é scratch seguro)
    mov edx, VER_CODE_LEN
    call strlen_cap
    mov r9d, eax                    ; vlen
    lea rsi, [j_vopen]
    mov edx, j_vopen_len
    call emit_raw
    mov rsi, r13
    mov edx, r9d
    call emit_esc
    lea rsi, [j_vmid]
    mov edx, j_vmid_len
    call emit_raw
    mov rax, [r13+VER_CODE_LEN]
    call emit_u64
    lea rsi, [j_vclose]
    mov edx, j_vclose_len
    call emit_raw
    inc r11d
    jmp .vloop
.vdone:
    lea rsi, [j_l5e]
    mov edx, j_l5e_len
    call emit_raw
    inc r14
    jmp .sloop
.sdone:
    lea rsi, [j_mid2]
    mov edx, j_mid2_len
    call emit_raw
    mov rax, [coll_count]
    mov rdx, MAX_COLLS
    cmp rax, rdx
    cmova rax, rdx
    mov r15, rax
    xor r14d, r14d
.cloop:
    cmp r14, r15
    jae .cdone
    test r14, r14
    jz .cfirst
    mov al, ','
    call emit_byte
.cfirst:
    lea rsi, [j_copen]
    mov edx, j_copen_len
    call emit_raw
    mov rax, r14
    imul rax, rax, COLL_ID_LEN
    lea rsi, [coll_ids+rax]
    mov edx, COLL_ID_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    lea rsi, [j_cmid]
    mov edx, j_cmid_len
    call emit_raw
    mov rax, r14
    imul rax, rax, COLL_NAME_LEN
    lea rsi, [coll_names+rax]
    mov rdx, r14
    mov edx, [coll_lens+rdx*4]
    cmp edx, COLL_NAME_LEN - 1
    jbe .ccok
    mov edx, COLL_NAME_LEN - 1
.ccok:
    call emit_esc
    lea rsi, [j_ccat]
    mov edx, j_ccat_len
    call emit_raw
    mov rdx, r14
    mov rax, [coll_cats+rdx*8]
    call emit_u64
    lea rsi, [j_cclose]
    mov edx, j_cclose_len
    call emit_raw
    inc r14
    jmp .cloop
.cdone:
    lea rsi, [j_end]
    mov edx, j_end_len
    call emit_raw

    mov r13, r12                    ; total a escrever
    xor r14d, r14d                  ; feito
.wr:
    cmp r14, r13
    jae .ok
    mov eax, 1                      ; sys_write
    mov edi, [save_fd]
    lea rsi, [file_buf]
    add rsi, r14
    mov rdx, r13
    sub rdx, r14
    syscall
    cmp rax, 0
    jle .closefail
    add r14, rax
    jmp .wr
.ok:
    ; fsync: garante os bytes no disco antes do rename (durabilidade)
    mov eax, 74                     ; sys_fsync
    mov edi, [save_fd]
    syscall
    mov eax, 3                      ; sys_close
    mov edi, [save_fd]
    syscall
    ; rename(tmp, db) — atômico: leitores vêem o DB antigo ou o novo, nunca
    ; um arquivo truncado
    mov eax, 82                     ; sys_rename
    lea rdi, [save_path_buf]
    lea rsi, [load_path_buf]
    syscall
    cmp rax, 0
    jl .fail
    mov rax, [sn_count]
    jmp .done
.closefail:
    mov eax, 3
    mov edi, [save_fd]
    syscall
.fail:
    mov rax, -1
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
