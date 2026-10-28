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
/* wrap_rows(p, len) -> nº de faixas visuais.
 * Chamadas com registradores pinados (+r): movs sequenciais no template
 * destruiriam inputs ainda não lidos se o GCC os alocasse sobrepostos. */
static int call_wrap_rows(char *p, int len) {
    int out;
    register char *_b asm("rsi") = p;
    register long _c asm("rcx") = len;
    asm volatile("call wrap_rows"
                 : "=a"(out), "+r"(_b), "+r"(_c)
                 : : "cc", "memory", "rdx", "rdi", "r8", "r9", "r10", "r11");
    return out;
}
/* wrap_vrow(base, total, off, scroll) -> rel (eax); col (edx).
 * off entra em edx e col sai em edx: operando único in-out (+d). */
static int call_wrap_vrow(char *base, int total, int off, int scroll, int *col) {
    int rel;
    register char *_b asm("rsi") = base;
    register long _t asm("rcx") = total;
    register long _o asm("rdx") = off;
    register long _s asm("r8") = scroll;
    asm volatile("call wrap_vrow"
                 : "=a"(rel), "+d"(_o), "+r"(_b), "+r"(_t), "+r"(_s)
                 : : "cc", "memory", "rdi", "r9", "r10", "r11");
    *col = (int)_o;
    return rel;
}
/* wrap_vrow_off(base, total, relrow, scroll) -> line_start (eax); chunk (edx) */
static int call_wrap_vrow_off(char *base, int total, int relrow, int scroll, int *chunk) {
    int start;
    register char *_b asm("rsi") = base;
    register long _t asm("rcx") = total;
    register long _r asm("rdx") = relrow;
    register long _s asm("r8") = scroll;
    asm volatile("call wrap_vrow_off"
                 : "=a"(start), "+d"(_r), "+r"(_b), "+r"(_t), "+r"(_s)
                 : : "cc", "memory", "rdi", "r9", "r10", "r11");
    *chunk = (int)_r;
    return start;
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

    /* ---------- undo por palavra/rajada (Ctrl+Z kind 27 / Ctrl+Y kind 28) -- */
    { cp_fixture("ui-21.json", "/tmp/uu-undo.json");
      CHECK("undo load", db_load("/tmp/uu-undo.json") == 1);
      sel = 0; scroll = 0; qlen = 0; libsel = 0;
      filter_rebuild();
      begin_edit(1);
      int c0 = clen(sn_recs);
      edit_cursor = c0;
      typech('A'); typech('B');          /* rajada rápida: 1 unidade */
      CHECK("undo digitou 2", clen(sn_recs) == c0 + 2);
      key(27);                                     /* Ctrl+Z */
      CHECK("undo tirou a rajada", clen(sn_recs) == c0);
      CHECK("undo cursor voltou", edit_cursor == c0);
      key(28);                                     /* Ctrl+Y */
      CHECK("redo pôs a rajada", clen(sn_recs) == c0 + 2);
      usleep(1200000);                             /* pausa > BURST: quebra */
      typech(' '); typech('C');                    /* ' ' ancora: 2 unidades */
      CHECK("undo digitou ' C'", clen(sn_recs) == c0 + 4);
      key(27);
      CHECK("undo tirou 'C' (espaço fica)", clen(sn_recs) == c0 + 3);
      key(27);
      CHECK("undo tirou ' '", clen(sn_recs) == c0 + 2);
      key(27);
      CHECK("undo tirou 'AB'", clen(sn_recs) == c0);
      typech('D'); usleep(1200000); typech('E');    /* mesma palavra, lenta */
      CHECK("undo palavra lenta digitou", clen(sn_recs) == c0 + 2);
      key(27);
      CHECK("undo palavra lenta saiu inteira", clen(sn_recs) == c0);
      /* replace por cima de seleção = 1 undo (skip do delete) */
      key(28);                                     /* refaz 'DE' p/ ter o que trocar */
      extern long sel_active, sel_a, sel_b, sel_rec;
      sel_active = 1; sel_rec = (long)sn_recs; sel_a = c0; sel_b = c0 + 2;
      edit_cursor = c0 + 2;
      typech('Z');
      CHECK("replace trocou", clen(sn_recs) == c0 + 1 && sn_recs[256 + c0] == 'Z');
      key(27);
      CHECK("replace desfez tudo de 1x", clen(sn_recs) == c0 + 2);
      key(10);                                     /* Esc: cancela a sessão */
      CHECK("undo esc saiu", edit_mode == 0); }

    /* ---------- undo ancora em fronteira (espaço/tab/newline) ------------- */
    { cp_fixture("ui-21.json", "/tmp/uu-undo4.json");
      CHECK("undo4 load", db_load("/tmp/uu-undo4.json") == 1);
      sel = 0; scroll = 0; qlen = 0; libsel = 0;
      filter_rebuild();
      begin_edit(1);
      int c0 = clen(sn_recs);
      edit_cursor = c0;
      /* "hi you" rápido: 2 unidades ("hi ", "you") */
      typech('h'); typech('i'); typech(' '); typech('y'); typech('o'); typech('u');
      CHECK("undo4 digitou 'hi you'", clen(sn_recs) == c0 + 6);
      key(27);
      CHECK("undo4 tirou 'you' (âncora fica)",
            clen(sn_recs) == c0 + 3 && sn_recs[256 + c0 + 2] == ' ');
      key(27);
      CHECK("undo4 tirou 'hi '", clen(sn_recs) == c0);
      /* Enter ancora: "a\nb" desfaz em 2 passos */
      typech('a'); key(9); typech('b');
      CHECK("undo4 digitou 'a\\nb'", clen(sn_recs) == c0 + 3);
      key(27);
      CHECK("undo4 tirou 'b' (newline fica)",
            clen(sn_recs) == c0 + 2 && sn_recs[256 + c0 + 1] == '\n');
      key(27);
      CHECK("undo4 tirou 'a\\n'", clen(sn_recs) == c0);
      /* espaço duplo funde p/ trás: "x  y" = ["x  ", "y"] */
      typech('x'); typech(' '); typech(' '); typech('y');
      CHECK("undo4 digitou 'x  y'", clen(sn_recs) == c0 + 4);
      key(27);
      CHECK("undo4 tirou 'y'", clen(sn_recs) == c0 + 3);
      key(27);
      CHECK("undo4 tirou 'x  '", clen(sn_recs) == c0);
      /* espaço após pausa longa ainda ancora na palavra anterior */
      typech('p'); typech('q');
      usleep(1200000);
      typech(' '); typech('r');
      CHECK("undo4 digitou 'pq r'", clen(sn_recs) == c0 + 4);
      key(27);
      CHECK("undo4 tirou 'r'", clen(sn_recs) == c0 + 3);
      key(27);
      CHECK("undo4 tirou 'pq '", clen(sn_recs) == c0);
      key(10);
      CHECK("undo4 esc saiu", edit_mode == 0); }

    /* ---------- undo no título + histórico por campo ---------- */
    { cp_fixture("ui-32.json", "/tmp/uu-undo2.json");
      CHECK("undo2 load", db_load("/tmp/uu-undo2.json") == 2);
      sel = 0; scroll = 0; qlen = 0; libsel = 0;
      filter_rebuild();
      begin_edit(2);
      extern long title_cursor;
      int t0; memcpy(&t0, sn_recs + 4352, 4);
      title_cursor = t0;
      typech('Q');
      { int t1; memcpy(&t1, sn_recs + 4352, 4);
        CHECK("undo2 digitou título", t1 == t0 + 1); }
      key(17);                                     /* Tab: título -> código */
      CHECK("undo2 tab foi p/ código", edit_mode == 1);
      edit_cursor = clen(sn_recs);
      typech('X');
      int c1 = clen(sn_recs);
      key(27);
      CHECK("undo2 desfaz código", clen(sn_recs) == c1 - 1);
      key(27);
      { int t2; memcpy(&t2, sn_recs + 4352, 4);
        CHECK("undo2 título intacto (histórico por campo)", t2 == t0 + 1); }
      key(10);
      CHECK("undo2 esc saiu", edit_mode == 0); }

    /* ---------- undo no nome da coleção ---------- */
    { cp_fixture("ui-21.json", "/tmp/uu-undo3.json");
      CHECK("undo3 load", db_load("/tmp/uu-undo3.json") == 1);
      sel = 0; scroll = 0; qlen = 0; libsel = 0;
      filter_rebuild();
      extern int coll_lens[];
      extern long coll_cursor;
      key(18);                                     /* Ctrl+G */
      CHECK("undo3 coll editando", edit_mode == 3);
      int k0 = coll_lens[0];
      coll_cursor = k0;
      typech('Z');
      CHECK("undo3 digitou", coll_lens[0] == k0 + 1);
      key(27);
      CHECK("undo3 desfaz nome", coll_lens[0] == k0);
      key(28);
      CHECK("undo3 refaz nome", coll_lens[0] == k0 + 1);
      key(10);
      CHECK("undo3 esc saiu", edit_mode == 0); }

    /* ---------- soft wrap: faixas visuais de 69 células ---------- */
    { char w[256];
      memset(w, 'a', sizeof w);
      CHECK("wrap rows 0->1", call_wrap_rows(w, 0) == 1);
      CHECK("wrap rows 69->1", call_wrap_rows(w, 69) == 1);
      CHECK("wrap rows 70->2", call_wrap_rows(w, 70) == 2);
      CHECK("wrap rows 138->2", call_wrap_rows(w, 138) == 2);
      CHECK("wrap rows 139->3", call_wrap_rows(w, 139) == 3);
      /* duas linhas lógicas: 70 a's + \n + 10 b's */
      char t[256];
      memset(t, 'a', 70); t[70] = '\n';
      memset(t + 71, 'b', 10);
      int tot = 81;
      int col = -1;
      int r = call_wrap_vrow(t, tot, 0, 0, &col);
      CHECK("wrap vrow off0 -> (0,0)", r == 0 && col == 0);
      r = call_wrap_vrow(t, tot, 69, 0, &col);
      CHECK("wrap vrow off69 -> (1,0)", r == 1 && col == 0);
      r = call_wrap_vrow(t, tot, 70, 0, &col);
      CHECK("wrap vrow off70 (\\n) -> (1,1)", r == 1 && col == 1);
      r = call_wrap_vrow(t, tot, 71, 0, &col);
      CHECK("wrap vrow off71 -> (2,0)", r == 2 && col == 0);
      r = call_wrap_vrow(t, tot, 81, 0, &col);
      CHECK("wrap vrow fim -> (2,10)", r == 2 && col == 10);
      r = call_wrap_vrow(t, tot, 71, 1, &col);
      CHECK("wrap vrow scroll1 -> (0,0)", r == 0 && col == 0);
      r = call_wrap_vrow(t, tot, 0, 1, &col);
      CHECK("wrap vrow acima do scroll -> (-2,0)", r == -2 && col == 0);
      int ch = -1;
      int s = call_wrap_vrow_off(t, tot, 0, 0, &ch);
      CHECK("wrap off faixa0 -> (0,c0)", s == 0 && ch == 0);
      s = call_wrap_vrow_off(t, tot, 1, 0, &ch);
      CHECK("wrap off faixa1 -> (0,c1)", s == 0 && ch == 1);
      s = call_wrap_vrow_off(t, tot, 2, 0, &ch);
      CHECK("wrap off faixa2 -> (71,c0)", s == 71 && ch == 0);
      s = call_wrap_vrow_off(t, tot, 0, 1, &ch);
      CHECK("wrap off scroll1 faixa0 -> (71,c0)", s == 71 && ch == 0);
      s = call_wrap_vrow_off(t, tot, 5, 0, &ch);
      CHECK("wrap off além -> fim", s == tot && ch == 0); }

    if (fails == 0) printf("OK uitest\n");
    else printf("FALHAS uitest: %d\n", fails);
    return fails != 0;
}
