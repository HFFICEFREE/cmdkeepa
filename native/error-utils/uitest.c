/* uitest.c — harness headless p/ ui_f2.o (fixes #21-26). Sem X11:
 *   gcc -no-pie uitest.c ui_f2.o db.o platform_x11.o -lX11 -o /tmp/uitest
 * Nenhum caminho aqui toca Xlib (sem kind 5/copy, sem ui_draw). */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

extern long db_load(const char *p);
extern long db_save(void);
extern int app_on_key(void);
extern int edit_commit_save(void);
extern int begin_edit(int mode);
extern int lt_pick(void);
extern int filter_rebuild(void);

/* ui BSS */
extern long edit_mode, edit_rec, backup_len, edit_cursor;
extern long title_blen, lang_blen, tags_blen;
extern long creating_sn, creating_coll;
extern long sel, scroll, filt_n, qlen, libsel;
extern unsigned char filt_idx[];
extern char sn_recs[];
extern long sn_count;
extern char qbuf[];

/* platform ev globals */
extern int ev_kind, ev_mx, ev_btn, ev_my;
extern char ev_char;
static void mouse(int x, int y) { ev_kind = 13; ev_btn = 1; ev_mx = x; ev_my = y; app_on_key(); }

static int fails = 0;
#define CHECK(name, cond) do { \
    if (cond) printf("PASS %s\n", name); \
    else { printf("FAIL %s\n", name); fails++; } } while (0)

static void key(int kind) { ev_kind = kind; ev_char = 0; app_on_key(); }
static void typech(char c) { ev_kind = 1; ev_char = c; app_on_key(); }

/* linelen/rbx=rec,eax=pos -> eax=len (operando 0 amarra pos em eax) */
static int call_linelen(char *rec, int pos) {
    int out;
    asm volatile("call linelen" : "=a"(out) : "b"(rec), "0"(pos)
                 : "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "memory");
    return out;
}
static int call_line_index(char *rec, int pos) {
    int out;
    asm volatile("call line_index" : "=a"(out) : "b"(rec), "0"(pos)
                 : "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "memory");
    return out;
}
/* lt_pick usa resolve_rec (filt), não rbx: prepara sn_recs[0]+filt antes */
static int call_lt_pick(int mx, int *col) {
    int mode, c;
    ev_mx = mx;
    asm volatile("call lt_pick" : "=a"(mode), "=d"(c) : "b"(sn_recs)
                 : "rcx", "rsi", "rdi", "r8", "r9", "r10", "r11", "memory");
    *col = c;
    return mode;
}

#define REC_SIZE 39856
#define REC_CODE_OFF 256
#define REC_CLEN_OFF 4364
#define REC_VNUM_OFF 4972
#define REC_VERS_OFF 4976
static int vnum(char *r) { int v; memcpy(&v, r + REC_VNUM_OFF, 4); return v; }
static int clen(char *r) { int v; memcpy(&v, r + REC_CLEN_OFF, 4); return v; }

static void cp_fixture(const char *name, const char *work) {
    char src[512], buf[65536];
    snprintf(src, sizeof src, "/home/neo-allan/Documentos/projects/cmdkeepaV9/native/error-utils/fixtures-11-20/%s", name);
    int f = open(src, O_RDONLY), n;
    int g = open(work, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    while ((n = read(f, buf, sizeof buf)) > 0) write(g, buf, n);
    close(f); close(g);
}

int main(void) {
    cp_fixture("ui-21.json", "/tmp/uu-21.json");
    CHECK("21 load", db_load("/tmp/uu-21.json") == 1);
    sel = 0; scroll = 0; qlen = 0; libsel = 0;
    filter_rebuild();

    /* ---------- #21: commits ---------- */
    ev_kind = 9; ev_char = 0; app_on_key();       /* enter -> edit */
    CHECK("21 edit mode on", edit_mode == 1 || edit_mode == 2);
    if (edit_mode == 2) key(9);                    /* título -> código */
    CHECK("21 in code mode", edit_mode == 1);
    { int v0 = vnum(sn_recs);
      key(6);                                      /* commit sem mudar nada */
      CHECK("21 noop: sem versão nova", vnum(sn_recs) == v0);
      CHECK("21 noop: saiu do edit", edit_mode == 0); }
    begin_edit(2);                                 /* só título */
    typech('X');
    { int v0 = vnum(sn_recs);
      key(6);
      CHECK("21 title-only: sem versão", vnum(sn_recs) == v0);
      CHECK("21 title-only: saiu", edit_mode == 0); }
    begin_edit(1);                                 /* muda o código */
    edit_cursor = clen(sn_recs);
    typech('!');
    { int v0 = vnum(sn_recs);
      key(6);
      CHECK("21 code change: +1 versão", vnum(sn_recs) == v0 + 1); }
    begin_edit(1);
    key(6);
    CHECK("21 dup: sem versão repetida", vnum(sn_recs) == 1);

    /* ---------- #22: revisão nativa completa ---------- */
    { memset(sn_recs + REC_CODE_OFF, 'B', 3000);
      sn_recs[REC_CODE_OFF + 3000] = 0;
      int c3000 = 3000;
      memcpy(sn_recs + REC_CLEN_OFF, &c3000, 4);
      edit_cursor = 3000;
      begin_edit(1);                               /* backup = código atual */
      sn_recs[REC_CODE_OFF] = 'C';                 /* 1 byte difere */
      key(6);
      CHECK("22 versão guarda 3000B", (int)strlen(sn_recs + REC_VERS_OFF) == 3000);
      CHECK("22 vnum cresce", vnum(sn_recs) == 2); }

    /* ---------- #26: Esc cancela criação ---------- */
    { long n0 = sn_count;
      key(14);                                     /* Ctrl+N */
      CHECK("26 criou + editando", sn_count == n0 + 1 && edit_mode == 2);
      key(10);                                     /* Esc */
      CHECK("26 Esc removeu", sn_count == n0 && edit_mode == 0);
      CHECK("26 flag limpa", creating_sn == -1);
      key(14);
      CHECK("26 criou de novo", sn_count == n0 + 1);
      key(6);                                      /* commit vazio */
      CHECK("26 commit vazio mantém", sn_count == n0 + 1 && edit_mode == 0);
      CHECK("26 commit vazio sem versão", vnum(sn_recs + n0 * REC_SIZE) == 0); }

    /* ---------- #24: CRLF nas linhas ---------- */
    { char rec[8192];
      memset(rec, 0, sizeof rec);
      const char *code = "ab\r\ncdef\r\nx";
      int len = strlen(code);
      memcpy(rec + REC_CODE_OFF, code, len);
      memcpy(rec + REC_CLEN_OFF, &len, 4);
      CHECK("24 linelen CRLF", call_linelen(rec, 0) == 2);
      CHECK("24 linelen 2a linha", call_linelen(rec, 4) == 4);
      CHECK("24 line_index", call_line_index(rec, 10) == 2);
      const char *code2 = "a\rb";
      int len2 = 3;
      memcpy(rec + REC_CODE_OFF, code2, len2);
      memcpy(rec + REC_CLEN_OFF, &len2, 4);
      CHECK("24 CR solitário", call_linelen(rec, 0) == 3);
      CHECK("24 CR índice 0", call_line_index(rec, 2) == 0); }

    /* ---------- #25: lt_pick com lang longa ---------- */    { edit_mode = 0;
      memset(sn_recs, 0, REC_SIZE);
      memset(sn_recs + 96, 'L', 31);               /* lang 31 */
      int ll = 31, gl = 10;
      memcpy(sn_recs + 4356, &ll, 4);
      memset(sn_recs + 128, 't', 10);
      memcpy(sn_recs + 4360, &gl, 4);
      sn_count = 1; filt_n = 1; filt_idx[0] = 0; sel = 0;
      int col = -1;
      int mode = call_lt_pick(870, &col);          /* tags visíveis (>=864) */
      CHECK("25 click tags visíveis -> tags", mode == 6);
      mode = call_lt_pick(700, &col);              /* lang visível */
      CHECK("25 click lang -> lang", mode == 5); }

    /* ---------- #32: busca por descrição (paridade web) ---------- */
    { char buf[65536]; int f = open("/home/neo-allan/Documentos/projects/cmdkeepaV9/native/error-utils/fixtures-11-20/ui-32.json", O_RDONLY), n;
      int g = open("/tmp/uu-32.json", O_WRONLY | O_CREAT | O_TRUNC, 0644);
      while ((n = read(f, buf, sizeof buf)) > 0) write(g, buf, n);
      close(f); close(g);
      CHECK("32 load", db_load("/tmp/uu-32.json") == 2);
      const char *term = "term-zz9-quux";
      int tl = strlen(term);
      memcpy(qbuf, term, tl);
      qlen = tl; libsel = 0; sel = 0; scroll = 0;
      filter_rebuild();
      CHECK("32 termo só-na-desc acha 1", filt_n == 1);
      CHECK("32 é o d1", filt_idx[0] == 0);
      /* edita a descrição e commita */
      begin_edit(7);
      edit_cursor = 0;
      extern long desc_cursor;
      desc_cursor = 0;
      typech('!');
      key(6);
      CHECK("32 commit desc saiu", edit_mode == 0);
      CHECK("32 desc salva", sn_recs[4408] == '!');
      /* Esc restaura */
      begin_edit(7);
      typech('?');
      key(10);
      CHECK("32 esc restaurou", sn_recs[4408] == '!');
      CHECK("32 esc saiu", edit_mode == 0); }

    /* ---------- #35: mesma-ms IDs únicos ---------- */
    { char id1[32], id2[32];
      key(14);
      memcpy(id1, sn_recs + (sn_count - 1) * REC_SIZE + 4376, 32);
      key(10);
      key(14);
      memcpy(id2, sn_recs + (sn_count - 1) * REC_SIZE + 4376, 32);
      CHECK("35 ids únicos", memcmp(id1, id2, 32) != 0);
      key(10); }

    /* ---------- #35: filtro muda durante edição ---------- */
    { cp_fixture("ui-21.json", "/tmp/uu-21.json");
      CHECK("35 setup", db_load("/tmp/uu-21.json") == 1);
      /* uu-21 tem 1 rec; usa ui-32 (2 recs) */
      CHECK("35 load2", db_load("/tmp/uu-32.json") == 2);
      const char *q = "plain code";
      memcpy(qbuf, q, 10);
      qlen = 10; libsel = 0; sel = 0; scroll = 0;
      filter_rebuild();
      CHECK("35 filtro 1 (só d1)", filt_n == 1);
      begin_edit(1);                               /* edita d1 (idx 0) */
      /* muda o código p/ não casar mais (simula digitação ao vivo) */
      int c0 = clen(sn_recs);
      memset(sn_recs + 256, 'z', c0);
      filter_rebuild();                            /* filtro agora exclui d1 */
      CHECK("35 filtro esvaziou", filt_n == 0);
      key(6);                                      /* commit atinge o rec fixo */
      CHECK("35 commit no rec fixo", edit_mode == 0);
      CHECK("35 d1 mudou", sn_recs[256] == 'z');
      CHECK("35 d2 intacto", sn_recs[REC_SIZE + 256] == 'o'); }

    /* ---------- #33: edição UTF-8 ---------- */
    { cp_fixture("ui-21.json", "/tmp/uu-21.json");
      CHECK("33 setup", db_load("/tmp/uu-21.json") == 1);
      sel = 0; scroll = 0; qlen = 0; libsel = 0;
      filter_rebuild();
      begin_edit(1);
      int c0 = clen(sn_recs);
      edit_cursor = c0;
      typech((char)0xC3); typech((char)0xA9);      /* é em UTF-8 */
      CHECK("33 2 bytes inseridos", clen(sn_recs) == c0 + 2);
      key(2);                                      /* backspace: some a sequência */
      CHECK("33 backspace levou os 2", clen(sn_recs) == c0);
      typech((char)0xC3); typech((char)0xA9);
      key(6);
      CHECK("33 commit utf-8", clen(sn_recs) == c0 + 2); }

    /* ---------- #32b: backspace em campo 1-linha (regressão: usava rdx/rcx
       destruídos pelo helper — cursor andava mas o texto ficava) ---------- */
    { cp_fixture("ui-32.json", "/tmp/uu-32b.json");
      CHECK("32b load", db_load("/tmp/uu-32b.json") == 2);
      sel = 0; scroll = 0; qlen = 0; libsel = 0;
      filter_rebuild();
      begin_edit(7);
      extern int desc_len;
      extern long desc_cursor;
      int d0 = desc_len;
      desc_cursor = d0;
      typech('Z');
      CHECK("32b digitou", desc_len == d0 + 1);
      key(2);                                      /* backspace */
      CHECK("32b backspace apagou", desc_len == d0);
      CHECK("32b cursor voltou", desc_cursor == d0);
      key(10);                                     /* Esc: sem sujeira */
      CHECK("32b esc saiu", edit_mode == 0); }

    /* ---------- #32c: mouse troca de campo em modo 1-linha (regressão:
       click era ignorado em 5/6/7 — Enter commitava em vez de newline) ----- */
    { cp_fixture("ui-32.json", "/tmp/uu-32c.json");
      CHECK("32c load", db_load("/tmp/uu-32c.json") == 2);
      sel = 0; scroll = 0; qlen = 0; libsel = 0;
      filter_rebuild();
      mouse(700, 145);                             /* linha desc */
      CHECK("32c click desc -> 7", edit_mode == 7);
      mouse(700, 650);                             /* área do código, abaixo da 1a linha */
      CHECK("32c click código -> 1", edit_mode == 1);
      /* cursor exato: linha min(row,última) + min(col,len) — regressão do
         dummy que zerava o min e punha o cursor em 2*pos */
      { int c0 = clen(sn_recs);
        extern long edit_cursor;
        CHECK("32c cursor no fim", edit_cursor == c0);
        key(9);                                    /* Enter = newline */
        CHECK("32c enter virou newline", clen(sn_recs) == c0 + 1);
        CHECK("32c newline no lugar certo", sn_recs[256 + c0] == '\n');
        CHECK("32c cursor após newline", edit_cursor == c0 + 1);
        CHECK("32c ainda editando", edit_mode == 1);
        key(10);
        CHECK("32c esc saiu", edit_mode == 0); } }

    if (fails == 0) printf("OK uitest\n");
    else printf("FALHAS uitest: %d\n", fails);
    return fails != 0;
}
