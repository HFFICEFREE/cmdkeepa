; rec.inc — layout compartilhado do registro de snippet (db.asm <-> ui).
; F4: metadados completos p/ round-trip sem perdas (id/desc/collid/datas/views).
; versions[]: até 8 entradas {code + at u64 + note}, NUL-terminated (sem lens).
; Fix #22: VER_CODE_LEN == REC_CODE_LEN (revisões nativas completas, sem
; truncar em 2047); cada versão guarda `note` (modelo web) p/ round-trip.
%define MAX_SNIPPETS  64
%define REC_TITLE_LEN 96
%define REC_LANG_LEN  32
%define REC_TAGS_LEN  128
%define REC_CODE_LEN  4096
%define REC_TITLE_OFF 0
%define REC_LANG_OFF  96
%define REC_TAGS_OFF  128
%define REC_CODE_OFF  256
%define REC_TLEN_OFF  4352
%define REC_LLEN_OFF  4356
%define REC_GLEN_OFF  4360
%define REC_CLEN_OFF  4364
%define REC_FAV_OFF   4368
%define REC_ID_LEN    32
%define REC_DESC_LEN  512
%define REC_CID_LEN   32
%define REC_ID_OFF    4376
%define REC_DESC_OFF  4408
%define REC_CID_OFF   4920
%define REC_CREATED_OFF 4952
%define REC_UPDATED_OFF 4960
%define REC_VIEWS_OFF 4968
%define REC_VNUM_OFF  4972
%define MAX_VERSIONS  8
%define VER_CODE_LEN  REC_CODE_LEN
%define VER_AT_OFF    VER_CODE_LEN
%define VER_NOTE_LEN  256
%define VER_NOTE_OFF  (VER_CODE_LEN + 8)
%define VER_SIZE      (VER_NOTE_OFF + VER_NOTE_LEN)
%define REC_VERS_OFF  4976
%define REC_SIZE      (REC_VERS_OFF + MAX_VERSIONS * VER_SIZE)
; invariantes de layout (quebram o build se o layout dessincronizar — fix #35)
%if VER_CODE_LEN < REC_CODE_LEN
%error "VER_CODE_LEN deve cobrir REC_CODE_LEN (fix #22)"
%endif
%if REC_SIZE != 4976 + 8 * (4096 + 8 + 256)
%error "REC_SIZE fora do esperado p/ o layout atual"
%endif
; offsets derivados de (off anterior + len anterior): qualquer deriva manual
; entre campo e sucessor falha aqui em vez de corromper DB/UI em silêncio.
%if REC_LANG_OFF != REC_TITLE_OFF + REC_TITLE_LEN
%error "REC_LANG_OFF dessincronizado"
%endif
%if REC_TAGS_OFF != REC_LANG_OFF + REC_LANG_LEN
%error "REC_TAGS_OFF dessincronizado"
%endif
%if REC_CODE_OFF != REC_TAGS_OFF + REC_TAGS_LEN
%error "REC_CODE_OFF dessincronizado"
%endif
%if REC_LLEN_OFF != REC_TLEN_OFF + 4
%error "REC_LLEN_OFF dessincronizado"
%endif
%if REC_GLEN_OFF != REC_LLEN_OFF + 4
%error "REC_GLEN_OFF dessincronizado"
%endif
%if REC_CLEN_OFF != REC_GLEN_OFF + 4
%error "REC_CLEN_OFF dessincronizado"
%endif
%if REC_FAV_OFF != REC_CLEN_OFF + 4
%error "REC_FAV_OFF dessincronizado"
%endif
%if REC_ID_OFF != REC_FAV_OFF + 8
%error "REC_ID_OFF dessincronizado (fav+pad)"
%endif
%if REC_DESC_OFF != REC_ID_OFF + REC_ID_LEN
%error "REC_DESC_OFF dessincronizado"
%endif
%if REC_CID_OFF != REC_DESC_OFF + REC_DESC_LEN
%error "REC_CID_OFF dessincronizado"
%endif
%if REC_CREATED_OFF != REC_CID_OFF + REC_CID_LEN
%error "REC_CREATED_OFF dessincronizado"
%endif
%if REC_UPDATED_OFF != REC_CREATED_OFF + 8
%error "REC_UPDATED_OFF dessincronizado"
%endif
%if REC_VIEWS_OFF != REC_UPDATED_OFF + 8
%error "REC_VIEWS_OFF dessincronizado"
%endif
%if REC_VNUM_OFF != REC_VIEWS_OFF + 4
%error "REC_VNUM_OFF dessincronizado"
%endif
%if REC_VERS_OFF != REC_VNUM_OFF + 4
%error "REC_VERS_OFF dessincronizado"
%endif
%if VER_NOTE_OFF != VER_CODE_LEN + 8
%error "VER_NOTE_OFF dessincronizado"
%endif
%if VER_SIZE != VER_NOTE_OFF + VER_NOTE_LEN
%error "VER_SIZE dessincronizado"
%endif
%if REC_SIZE % 8 != 0
%error "REC_SIZE deve ser múltiplo de 8 (alinhamento qword)"
%endif
%define QUERY_MAX     127
%define ROWS_VISIBLE  11
%define MAX_COLLS    16
%define COLL_NAME_LEN 64
%define COLL_ID_LEN   32
%define CODE_ROWS     29
; largura exibida da linha "lang - tags" no detail (fix #25): render, lt_pick
; e carets usam estes limites, nunca o comprimento total do campo.
; TAGS 36: 621+24*9+27+36*9+54(fav)=1242, dentro do cartão (borda 1267).
%define LANG_DISP_MAX 24
%define TAGS_DISP_MAX 36
; linha "desc: <texto>" no detail (fix #32): rótulo em 621, texto em 675.
%define DESC_LBL_X 621
%define DESC_TXT_X 675
%define DESC_DISP_MAX 64
%define DESC_BASE_Y 141
%define CODE_TOP_Y 199
