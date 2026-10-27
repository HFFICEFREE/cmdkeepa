/* dbtest.c — harness headless p/ db.o (fixes #11-20). Compila sem X11:
 *   gcc -no-pie dbtest.c db.o -o /tmp/dbtest && /tmp/dbtest
 * Usa só a API exportada (db_load/db_save/db_count/db_error/...). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

extern long db_load(const char *path);
extern long db_save(void);
extern long db_count(void);
extern long db_error;
extern long db_readonly;
extern long sn_count;
extern long coll_count;

static int fails = 0;
#define CHECK(name, cond) do { \
    if (cond) printf("PASS %s\n", name); \
    else { printf("FAIL %s\n", name); fails++; } } while (0)

static void cp(const char *a, const char *b) {
    char buf[65536]; int f = open(a, O_RDONLY), n;
    int g = open(b, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    while ((n = read(f, buf, sizeof buf)) > 0) write(g, buf, n);
    close(f); close(g);
}

int main(void) {
    const char *F = "/home/neo-allan/Documentos/projects/cmdkeepaV9/native/error-utils/fixtures-11-20";
    char src[512], tmp[512];

    /* A (#11) tags round-trip */
    snprintf(src, sizeof src, "%s/tags.json", F);
    snprintf(tmp, sizeof tmp, "/tmp/dbtest-tags.json");
    cp(src, tmp);
    CHECK("tags load n==3", db_load(tmp) == 3);
    CHECK("tags save ok", db_save() >= 0);
    /* B (#12) decoy */
    snprintf(src, sizeof src, "%s/decoy.json", F);
    snprintf(tmp, sizeof tmp, "/tmp/dbtest-decoy.json");
    cp(src, tmp);
    CHECK("decoy load n==1", db_load(tmp) == 1);
    /* C (#13) consecutive */
    snprintf(src, sizeof src, "%s/consec1.json", F);
    snprintf(tmp, sizeof tmp, "/tmp/dbtest-consec.json");
    cp(src, tmp);
    CHECK("consec1 n==1", db_load(tmp) == 1);
    snprintf(src, sizeof src, "%s/consec2.json", F);
    cp(src, tmp);
    CHECK("consec2 n==1 (sem herdar)", db_load(tmp) == 1);
    CHECK("consec2 save ok", db_save() >= 0);
    /* D (#14) numbers */
    snprintf(src, sizeof src, "%s/num-bad-views.json", F);
    snprintf(tmp, sizeof tmp, "/tmp/dbtest-numbad.json");
    cp(src, tmp);
    CHECK("views>u32 rejeitado", db_load(tmp) == -1 && db_error == 4);
    snprintf(src, sizeof src, "%s/num-bad-neg.json", F);
    cp(src, tmp);
    CHECK("views negativa rejeitada", db_load(tmp) == -1 && db_error == 4);
    snprintf(src, sizeof src, "%s/num-ok-maxu32.json", F);
    cp(src, tmp);
    CHECK("views=u32max aceito", db_load(tmp) == 1);
    /* E (#18) seed ms */
    unlink("/tmp/dbtest-seed.json");
    CHECK("seed n==3", db_load("/tmp/dbtest-seed.json") == 3);
    CHECK("seed save ok", db_save() >= 0);
    /* G (#15) overlong const */
    char longp[600];
    memset(longp, 'a', sizeof longp - 1);
    longp[sizeof longp - 1] = 0;
    CHECK("overlong rejeitado", db_load(longp) == -1);
    /* H (#16) modo do arquivo novo */
    struct stat st;
    CHECK("seed file 0600", stat("/tmp/dbtest-seed.json", &st) == 0 && (st.st_mode & 0777) == 0600);

    /* F (#20) stress: 64 snippets (capacidade) via loads repetidos */
    snprintf(src, sizeof src, "%s/many.json", F);
    snprintf(tmp, sizeof tmp, "/tmp/dbtest-many.json");
    cp(src, tmp);
    long n = db_load(tmp);
    CHECK("many n==64", n == 64);
    CHECK("many save ok", db_save() >= 0);
    CHECK("many reload n==64", db_load(tmp) == 64);

    /* ---------- #35: entradas vazias/malformadas/oversize ---------- */
    { int g = open("/tmp/dbtest-empty.json", O_WRONLY | O_CREAT | O_TRUNC, 0644);
      close(g);
      extern long db_error;
      CHECK("vazio rejeitado", db_load("/tmp/dbtest-empty.json") == -1 && db_error == 4); }
    { int g = open("/tmp/dbtest-trunc.json", O_WRONLY | O_CREAT | O_TRUNC, 0644);
      write(g, "{\"snippets\":[{\"id\":\"x\",", 24);
      close(g);
      extern long db_error;
      CHECK("truncado rejeitado", db_load("/tmp/dbtest-trunc.json") == -1 && db_error == 4); }
    { int g = open("/tmp/dbtest-big.json", O_WRONLY | O_CREAT | O_TRUNC, 0644);
      char z[8192];
      memset(z, ' ', sizeof z);
      for (int i = 0; i < 129; i++) write(g, z, sizeof z); /* >1 MiB */
      close(g);
      extern long db_error;
      CHECK("oversize rejeitado", db_load("/tmp/dbtest-big.json") == -1 && db_error == 3); }
    /* save que falha preserva a memória: dir sem escrita */
    { system("mkdir -p /tmp/uu-ro && chmod 755 /tmp/uu-ro");
      snprintf(tmp, sizeof tmp, "/tmp/uu-ro/fs.json");
      cp("/tmp/dbtest-many.json", tmp);
      CHECK("fs load", db_load(tmp) == 64);
      chmod("/tmp/uu-ro", 0555);
      long r = db_save();
      chmod("/tmp/uu-ro", 0755);
      CHECK("save sem escrita falha", r == -1);
      CHECK("memória intacta", sn_count == 64);
      CHECK("save volta a ok", db_save() >= 0); }

    if (fails == 0) printf("OK dbtest\n");
    else printf("FALHAS dbtest: %d\n", fails);
    return fails != 0;
}
