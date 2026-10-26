; rec.inc — layout compartilhado do registro de snippet (db.asm <-> ui).
; F4: metadados completos p/ round-trip sem perdas (id/desc/collid/datas/views).
; versions[]: até 8 entradas {code 2KB + at u64}, NUL-terminated (sem lens).
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
%define VER_CODE_LEN  2048
%define VER_SIZE      2056
%define REC_VERS_OFF  4976
%define REC_SIZE      21424
%define QUERY_MAX     127
%define ROWS_VISIBLE  11
%define MAX_COLLS    16
%define COLL_NAME_LEN 64
%define COLL_ID_LEN   32
%define CODE_ROWS     34
