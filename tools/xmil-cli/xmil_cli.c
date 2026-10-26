/*
 * SPDX-License-Identifier: GPL-2.0-only
 *
 * xmil-cli: minimal headless libretro frontend for the X Millennium
 * (xmil-libretro) reference core, written for SharpX1_Mister.  Original
 * project code: it only uses the public libretro API header from the build
 * tree and a few exported core symbols looked up with dlsym().  It contains
 * no X Millennium source.
 *
 * Behaviour (see docs/XMIL_REFERENCE_STATUS.md):
 *  - creates a fresh work directory, copies the supplied ROMs/fonts and
 *    disks into it (the core writes to mounted disks), writes xmil.cfg and
 *    chdir()s there, because the core reads fonts/xmil.cfg from "./" and
 *    IPLs from <system>/xmil/;
 *  - runs whole core frames (retro_run) until the requested emulated time,
 *    measured from the core's own per-frame CPU clock count (4 MHz units);
 *  - injects keys through the core's PC-98-style keystat_senddata() at the
 *    first frame boundary at or after each scripted time;
 *  - writes RGB PNG frames and an optional 44.1 kHz stereo WAV;
 *  - prints a JSON summary.
 */
#define _DARWIN_C_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>
#include <zlib.h>
#include <CommonCrypto/CommonDigest.h>

#include "libretro.h"

#define MAX_FRAMES 256
#define MAX_EVENTS 4096

static void die(const char *fmt, const char *arg)
{
    fprintf(stderr, "xmil-cli: ");
    fprintf(stderr, fmt, arg ? arg : "");
    fprintf(stderr, "\n");
    exit(2);
}

/* ---------------------------------------------------------------- files */

static unsigned char *read_file(const char *path, size_t *size)
{
    FILE *f = fopen(path, "rb");
    if (!f) die("cannot open %s", path);
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    unsigned char *buf = malloc(n > 0 ? (size_t)n : 1);
    if (!buf || fread(buf, 1, (size_t)n, f) != (size_t)n) die("cannot read %s", path);
    fclose(f);
    *size = (size_t)n;
    return buf;
}

static void sha256_hex(const unsigned char *data, size_t size, char out[65])
{
    unsigned char md[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data, (CC_LONG)size, md);
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) sprintf(out + i * 2, "%02x", md[i]);
}

static void file_sha256(const char *path, char out[65], size_t *size)
{
    size_t n;
    unsigned char *buf = read_file(path, &n);
    sha256_hex(buf, n, out);
    if (size) *size = n;
    free(buf);
}

static void copy_file(const char *src, const char *dst)
{
    size_t n;
    unsigned char *buf = read_file(src, &n);
    FILE *f = fopen(dst, "wbx");
    if (!f) die("cannot create %s (must not exist)", dst);
    if (fwrite(buf, 1, n, f) != n) die("cannot write %s", dst);
    fclose(f);
    free(buf);
}

static void json_str(FILE *o, const char *s)
{
    fputc('"', o);
    for (; *s; s++) {
        if (*s == '"' || *s == '\\') fprintf(o, "\\%c", *s);
        else if ((unsigned char)*s < 0x20) fprintf(o, "\\u%04x", *s);
        else fputc(*s, o);
    }
    fputc('"', o);
}

/* ------------------------------------------------------------------ PNG */

static void png_chunk(FILE *f, const char *type, const unsigned char *data, uint32_t len)
{
    unsigned char hdr[8] = {len >> 24, len >> 16, len >> 8, len,
                            type[0], type[1], type[2], type[3]};
    fwrite(hdr, 1, 8, f);
    if (len) fwrite(data, 1, len, f);
    uLong crc = crc32(0, hdr + 4, 4);
    if (len) crc = crc32(crc, data, len);
    unsigned char c[4] = {crc >> 24, crc >> 16, crc >> 8, crc};
    fwrite(c, 1, 4, f);
}

static void write_png(const char *path, const uint16_t *rgb565, unsigned w, unsigned h, size_t pitch)
{
    size_t raw_size = (size_t)h * (w * 3 + 1);
    unsigned char *raw = malloc(raw_size);
    for (unsigned y = 0; y < h; y++) {
        unsigned char *row = raw + (size_t)y * (w * 3 + 1);
        const uint16_t *src = (const uint16_t *)((const unsigned char *)rgb565 + y * pitch);
        row[0] = 0;
        for (unsigned x = 0; x < w; x++) {
            uint16_t p = src[x];
            unsigned r = (p >> 11) & 31, g = (p >> 5) & 63, b = p & 31;
            row[1 + x * 3] = (unsigned char)((r << 3) | (r >> 2));
            row[2 + x * 3] = (unsigned char)((g << 2) | (g >> 4));
            row[3 + x * 3] = (unsigned char)((b << 3) | (b >> 2));
        }
    }
    uLongf zsize = compressBound(raw_size);
    unsigned char *z = malloc(zsize);
    if (compress2(z, &zsize, raw, raw_size, 9) != Z_OK) die("zlib failure for %s", path);
    FILE *f = fopen(path, "wb");
    if (!f) die("cannot create %s", path);
    static const unsigned char sig[8] = {137, 80, 78, 71, 13, 10, 26, 10};
    fwrite(sig, 1, 8, f);
    unsigned char ihdr[13] = {w >> 24, w >> 16, w >> 8, w, h >> 24, h >> 16, h >> 8, h,
                              8, 2, 0, 0, 0};
    png_chunk(f, "IHDR", ihdr, 13);
    png_chunk(f, "IDAT", z, (uint32_t)zsize);
    png_chunk(f, "IEND", NULL, 0);
    fclose(f);
    free(raw);
    free(z);
}

/* ------------------------------------------------------------- libretro */

static char system_dir[1024], save_dir[1024];
static const uint16_t *last_frame;
static unsigned last_w, last_h;
static size_t last_pitch;
static uint16_t frame_copy[1024 * 1024];
static FILE *wav;
static uint64_t wav_frames;

static bool env_cb(unsigned cmd, void *data)
{
    switch (cmd) {
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        *(const char **)data = system_dir;
        return true;
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
    case RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY:
        *(const char **)data = save_dir;
        return true;
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
        return *(const enum retro_pixel_format *)data == RETRO_PIXEL_FORMAT_RGB565;
    case RETRO_ENVIRONMENT_SET_VARIABLES:
    case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
    case RETRO_ENVIRONMENT_SET_GEOMETRY:
        return true;
    case RETRO_ENVIRONMENT_GET_VARIABLE:
        ((struct retro_variable *)data)->value = NULL;   /* core defaults */
        return false;
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
        *(bool *)data = false;
        return true;
    default:
        return false;
    }
}

static void video_cb(const void *data, unsigned w, unsigned h, size_t pitch)
{
    if (!data || (size_t)h * pitch > sizeof(frame_copy)) return;
    memcpy(frame_copy, data, (size_t)h * pitch);
    last_frame = frame_copy;
    last_w = w;
    last_h = h;
    last_pitch = pitch;
}

static void audio_cb(int16_t l, int16_t r)
{
    if (wav) { int16_t s[2] = {l, r}; fwrite(s, 2, 2, wav); wav_frames++; }
}

static size_t audio_batch_cb(const int16_t *data, size_t frames)
{
    if (wav) { fwrite(data, 4, frames, wav); wav_frames += frames; }
    return frames;
}

static void input_poll_cb(void) {}
static int16_t input_state_cb(unsigned port, unsigned device, unsigned index, unsigned id)
{
    (void)port; (void)device; (void)index; (void)id;
    return 0;   /* keys go through keystat_senddata(), see below */
}

static void wav_header(FILE *f, uint64_t frames)
{
    uint32_t data = (uint32_t)(frames * 4), rate = 44100;
    unsigned char h[44];
    memcpy(h, "RIFF", 4);
    uint32_t v = 36 + data;
    memcpy(h + 4, &v, 4);
    memcpy(h + 8, "WAVEfmt ", 8);
    v = 16; memcpy(h + 16, &v, 4);
    uint16_t s = 1; memcpy(h + 20, &s, 2);
    s = 2; memcpy(h + 22, &s, 2);
    memcpy(h + 24, &rate, 4);
    v = rate * 4; memcpy(h + 28, &v, 4);
    s = 4; memcpy(h + 32, &s, 2);
    s = 16; memcpy(h + 34, &s, 2);
    memcpy(h + 36, "data", 4);
    memcpy(h + 40, &data, 4);
    fseek(f, 0, SEEK_SET);
    fwrite(h, 1, 44, f);
}

/* ------------------------------------------------------------------ keys */

/* Names -> serial codes accepted by the core's keystat_senddata() (the
 * PC-98 style layout used by X Millennium's host keyboard tables). */
struct keyname { const char *name; int code; };
static const struct keyname keynames[] = {
    {"esc", 0x00}, {"1", 0x01}, {"2", 0x02}, {"3", 0x03}, {"4", 0x04}, {"5", 0x05},
    {"6", 0x06}, {"7", 0x07}, {"8", 0x08}, {"9", 0x09}, {"0", 0x0a}, {"minus", 0x0b},
    {"caret", 0x0c}, {"yen", 0x0d}, {"backspace", 0x0e}, {"tab", 0x0f},
    {"q", 0x10}, {"w", 0x11}, {"e", 0x12}, {"r", 0x13}, {"t", 0x14}, {"y", 0x15},
    {"u", 0x16}, {"i", 0x17}, {"o", 0x18}, {"p", 0x19}, {"at", 0x1a}, {"lbracket", 0x1b},
    {"return", 0x1c}, {"enter", 0x1c}, {"a", 0x1d}, {"s", 0x1e}, {"d", 0x1f},
    {"f", 0x20}, {"g", 0x21}, {"h", 0x22}, {"j", 0x23}, {"k", 0x24}, {"l", 0x25},
    {"semicolon", 0x26}, {"colon", 0x27}, {"rbracket", 0x28}, {"z", 0x29}, {"x", 0x2a},
    {"c", 0x2b}, {"v", 0x2c}, {"b", 0x2d}, {"n", 0x2e}, {"m", 0x2f}, {"comma", 0x30},
    {"period", 0x31}, {"slash", 0x32}, {"underscore", 0x33}, {"space", 0x34},
    {"xfer", 0x35}, {"rollup", 0x36}, {"rolldown", 0x37}, {"ins", 0x38}, {"del", 0x39},
    {"up", 0x3a}, {"left", 0x3b}, {"right", 0x3c}, {"down", 0x3d}, {"home", 0x3e},
    {"help", 0x3f}, {"kp_minus", 0x40}, {"kp_divide", 0x41}, {"kp7", 0x42}, {"kp8", 0x43},
    {"kp9", 0x44}, {"kp_multiply", 0x45}, {"kp4", 0x46}, {"kp5", 0x47}, {"kp6", 0x48},
    {"kp_plus", 0x49}, {"kp1", 0x4a}, {"kp2", 0x4b}, {"kp3", 0x4c}, {"kp_equals", 0x4d},
    {"kp0", 0x4e}, {"kp_comma", 0x4f}, {"kp_period", 0x50}, {"nfer", 0x51},
    {"stop", 0x60}, {"copy", 0x61}, {"f1", 0x62}, {"f2", 0x63}, {"f3", 0x64}, {"f4", 0x65},
    {"f5", 0x66}, {"f6", 0x67}, {"f7", 0x68}, {"f8", 0x69}, {"f9", 0x6a}, {"f10", 0x6b},
    {"shift", 0x70}, {"caps", 0x71}, {"kana", 0x72}, {"grph", 0x73}, {"ctrl", 0x74},
};

static int key_code(const char *name)
{
    if (!strncasecmp(name, "raw:", 4)) {
        char *end;
        long v = strtol(name + 4, &end, 16);
        if (*end || v < 0 || v > 0x7f) return -1;
        return (int)v;
    }
    for (size_t i = 0; i < sizeof(keynames) / sizeof(keynames[0]); i++)
        if (!strcasecmp(name, keynames[i].name)) return keynames[i].code;
    return -1;
}

struct event { double ms; int code; int up; char text[48]; };
static struct event events[MAX_EVENTS];
static int nevents;

static void add_event(double ms, int code, int up, const char *text)
{
    if (nevents >= MAX_EVENTS) die("too many key events%s", "");
    events[nevents].ms = ms;
    events[nevents].code = code;
    events[nevents].up = up;
    snprintf(events[nevents].text, sizeof(events[nevents].text), "%s", text);
    nevents++;
}

static int cmp_event(const void *a, const void *b)
{
    const struct event *x = a, *y = b;
    if (x->ms < y->ms) return -1;
    if (x->ms > y->ms) return 1;
    return (x < y) ? -1 : (x > y);
}

/* Script lines:  MS down KEY | MS up KEY | MS tap KEY [HOLD_MS]
 *                MS type TEXT [GAP_MS]   (letters/digits/space only)
 * '#' starts a comment.  Default hold 80 ms, type gap 200 ms. */
static void load_keys(const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f) die("cannot open key script %s", path);
    char line[512];
    int lineno = 0;
    while (fgets(line, sizeof(line), f)) {
        lineno++;
        char *hash = strchr(line, '#');
        if (hash) *hash = 0;
        double ms, arg = -1;
        char op[16], key[128];
        int n = sscanf(line, "%lf %15s %127s %lf", &ms, op, key, &arg);
        if (n <= 0) continue;
        if (n < 3) { fprintf(stderr, "line %d: ", lineno); die("bad key script line: %s", line); }
        if (!strcmp(op, "type")) {
            double gap = arg > 0 ? arg : 200, t = ms;
            for (const char *p = key; *p; p++, t += gap) {
                char nm[2] = {(char)(*p == '_' ? ' ' : *p), 0};
                int c = (*p == '_') ? 0x34 : key_code(nm);
                if (c < 0) die("cannot type character in %s", key);
                add_event(t, c, 0, nm);
                add_event(t + 80, c, 1, nm);
            }
            continue;
        }
        int c = key_code(key);
        if (c < 0) die("unknown key name %s", key);
        if (!strcmp(op, "down")) add_event(ms, c, 0, key);
        else if (!strcmp(op, "up")) add_event(ms, c, 1, key);
        else if (!strcmp(op, "tap")) {
            add_event(ms, c, 0, key);
            add_event(ms + (arg > 0 ? arg : 80), c, 1, key);
        } else die("unknown key op %s", op);
    }
    fclose(f);
    qsort(events, nevents, sizeof(events[0]), cmp_event);
}

/* ------------------------------------------------------- font checks */

/* X1 Turbo Kanji address of a JIS code as used by the core's font loader
 * (half-major, bank grouping per JIS row pair); 0xff = unmapped. */
static int x1t_bank(unsigned idx)
{
    static const unsigned char map[][2] = {
        {0x11, 0x00}, {0x12, 0x02}, {0x13, 0x01}, {0x19, 0x04}, {0x1a, 0x06}, {0x1b, 0x08},
        {0x1d, 0x05}, {0x1e, 0x07}, {0x1f, 0x09}, {0x21, 0x0a}, {0x22, 0x0c}, {0x23, 0x0e},
        {0x25, 0x0b}, {0x26, 0x0d}, {0x27, 0x0f}};   /* level 1 (JIS rows 21-4F) only */
    for (size_t i = 0; i < sizeof(map) / sizeof(map[0]); i++)
        if (map[i][0] == idx) return map[i][1];
    return -1;
}

static unsigned jis_to_sjis(unsigned jis)
{
    unsigned low = jis & 0x7f, high = (jis >> 8) & 0x7f;
    if (!(high & 1)) low += 0x5e;
    if (low >= 0x60) low++;
    high = ((high + 0x121) >> 1) ^ 0x20;
    return (high << 8) | (low + 0x1f);
}

static long sjis_file_offset(unsigned sjis)
{
    if (sjis >= 0x8140 && sjis < 0x84c0) return (long)(sjis - 0x8140) << 5;
    if (sjis >= 0x8890 && sjis < 0xa000) return 0x07000 + ((long)(sjis - 0x8890) << 5);
    if (sjis >= 0xe040 && sjis < 0xeab0) return 0x35e00 + ((long)(sjis - 0xe040) << 5);
    return -1;
}

/* Compare the core's live font arrays with the supplied files.  Returns the
 * number of mismatching bytes (ANK) or glyphs (Kanji level 1). */
static long check_bytes(const unsigned char *live, const char *path, size_t n)
{
    size_t size;
    unsigned char *f = read_file(path, &size);
    long bad = 0;
    if (size < n) bad = (long)n;
    else for (size_t i = 0; i < n; i++) bad += live[i] != f[i];
    free(f);
    return bad;
}

static long check_kanji(const unsigned char *knjx1t, const char *path, long *checked)
{
    size_t size;
    unsigned char *f = read_file(path, &size);
    long bad = 0;
    *checked = 0;
    if (size != 306176) { free(f); return -1; }
    for (unsigned high = 0x21; high < 0x50; high++)
        for (unsigned low = 0x21; low < 0x7f; low++) {
            unsigned jis = (high << 8) | low;
            int bank = x1t_bank(((jis >> 9) & 0x3c) + ((jis >> 5) & 3));
            long off = sjis_file_offset(jis_to_sjis(jis));
            if (bank < 0 || off < 0) continue;
            unsigned addr = ((unsigned)bank << 12) + ((jis & 0x700) << 1) + ((jis & 0x1f) << 4);
            int differ = 0;
            for (int row = 0; row < 16; row++)
                differ |= knjx1t[addr + row] != f[off + row * 2] ||
                          knjx1t[addr + 0x20000 + row] != f[off + row * 2 + 1];
            bad += differ;
            (*checked)++;
        }
    free(f);
    return bad;
}

static int count_tmp_fonts(const char *dir)
{
    const char *names[] = {"FNT0808.TMP", "FNT0816.TMP", "FNT1616.TMP"};
    char p[1200];
    int n = 0;
    struct stat st;
    for (int i = 0; i < 3; i++) {
        snprintf(p, sizeof(p), "%s/%s", dir, names[i]);
        n += stat(p, &st) == 0;
    }
    return n;
}

/* ------------------------------------------------------------------ main */

struct romslot { const char *opt, *dest; const char *src; char sha[65]; size_t size; int in_system; };
static struct romslot roms[] = {
    {"--ipl-x1", "IPLROM.X1", NULL, "", 0, 1},
    {"--ipl-turbo", "IPLROM.X1T", NULL, "", 0, 1},
    {"--font8", "FNT0808.X1", NULL, "", 0, 0},
    {"--font16", "FNT0816.X1", NULL, "", 0, 0},
    {"--kanji", "FNT1616.X1", NULL, "", 0, 0},
};
#define NROMS (sizeof(roms) / sizeof(roms[0]))

struct framereq { double ms; const char *path; int done; double at_ms; long at_frame; };

static void usage(void)
{
    fprintf(stderr,
        "usage: xmil-cli --core x1_libretro.dylib --work NEW_DIR --ms N\n"
        "  [--model x1|turbo|turboz] [--monitor standard|high] [--boot 2d|2hd] [--opm on|off]\n"
        "  [--ipl-x1 F] [--ipl-turbo F] [--font8 F] [--font16 F] [--kanji F]\n"
        "  [--fdd0 DISK] [--fdd1 DISK] [--keys SCRIPT] [--ini KEY=VALUE]...\n"
        "  [--frame MS OUT.png]... [--final OUT.png] [--wav OUT.wav] [--allow-virtual-fonts]\n"
        "  All three fonts are required unless --allow-virtual-fonts is given.\n");
    exit(2);
}

int main(int argc, char **argv)
{
    const char *core = NULL, *work = NULL, *model = "turbo", *monitor = "standard";
    const char *boot = "2d", *opm = "on", *fdd[2] = {NULL, NULL}, *keys = NULL;
    const char *final_png = NULL, *wav_path = NULL, *ini_extra[32];
    int nini = 0, nframes = 0, allow_virtual = 0;
    double total_ms = -1;
    struct framereq frames[MAX_FRAMES];

    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
#define NEXT() (i + 1 < argc ? argv[++i] : (usage(), (char *)NULL))
        int matched = 0;
        for (size_t r = 0; r < NROMS; r++)
            if (!strcmp(a, roms[r].opt)) { roms[r].src = NEXT(); matched = 1; }
        if (matched) continue;
        if (!strcmp(a, "--core")) core = NEXT();
        else if (!strcmp(a, "--work")) work = NEXT();
        else if (!strcmp(a, "--ms")) total_ms = atof(NEXT());
        else if (!strcmp(a, "--model")) model = NEXT();
        else if (!strcmp(a, "--monitor")) monitor = NEXT();
        else if (!strcmp(a, "--boot")) boot = NEXT();
        else if (!strcmp(a, "--opm")) opm = NEXT();
        else if (!strcmp(a, "--fdd0")) fdd[0] = NEXT();
        else if (!strcmp(a, "--fdd1")) fdd[1] = NEXT();
        else if (!strcmp(a, "--keys")) keys = NEXT();
        else if (!strcmp(a, "--final")) final_png = NEXT();
        else if (!strcmp(a, "--wav")) wav_path = NEXT();
        else if (!strcmp(a, "--allow-virtual-fonts")) allow_virtual = 1;
        else if (!strcmp(a, "--ini")) { if (nini >= 32) usage(); ini_extra[nini++] = NEXT(); }
        else if (!strcmp(a, "--frame")) {
            if (nframes >= MAX_FRAMES) usage();
            frames[nframes].ms = atof(NEXT());
            frames[nframes].path = NEXT();
            frames[nframes].done = 0;
            nframes++;
        } else if (!strcmp(a, "--tape")) {
            die("--tape: the pinned core has no cassette emulation (io/cmt.c returns 0)%s", "");
        } else usage();
    }
    if (!core || !work || total_ms <= 0) usage();
    /* Without a real file the core silently substitutes its embedded ANK
     * (font/font.c:108-115), FNT*.TMP files (font/fontx1.c:19-22) or fonts
     * synthesised from host glyphs (font/font.c:121-123, fontmake.c). */
    if (!allow_virtual && (!roms[2].src || !roms[3].src || !roms[4].src))
        die("--font8, --font16 and --kanji are required (real ROM fonts only)%s", "");

    int rom_type;
    if (!strcmp(model, "x1")) rom_type = 1;
    else if (!strcmp(model, "turbo")) rom_type = 2;
    else if (!strcmp(model, "turboz")) rom_type = 3;
    else die("unknown model %s", model);
    int dip = 0;
    if (!strcmp(monitor, "standard")) dip |= 0x01;          /* DIPSW_RESOLUTE set = standard */
    else if (strcmp(monitor, "high")) die("unknown monitor %s", monitor);
    if (!strcmp(boot, "2hd")) dip |= 0x04;
    else if (strcmp(boot, "2d")) die("unknown boot media %s", boot);

    /* Absolute paths before chdir(). */
    char core_abs[1024], work_abs[1024], cwd[1024];
    if (!getcwd(cwd, sizeof(cwd))) die("getcwd failed%s", "");
    if (!realpath(core, core_abs)) die("cannot resolve core %s", core);
    if (mkdir(work, 0755)) die("work directory must be new: %s", work);
    if (!realpath(work, work_abs)) die("cannot resolve %s", work);
#define ABS(p, buf) do { if ((p) && (p)[0] != '/') { snprintf(buf, sizeof(buf), "%s/%s", cwd, (p)); (p) = strdup(buf); } } while (0)
    char tmp[2048];
    for (int i = 0; i < nframes; i++) ABS(frames[i].path, tmp);
    ABS(final_png, tmp);
    ABS(wav_path, tmp);

    snprintf(system_dir, sizeof(system_dir), "%s/system", work_abs);
    snprintf(save_dir, sizeof(save_dir), "%s/save", work_abs);
    mkdir(system_dir, 0755);
    mkdir(save_dir, 0755);
    snprintf(tmp, sizeof(tmp), "%s/xmil", system_dir);
    mkdir(tmp, 0755);
    snprintf(tmp, sizeof(tmp), "%s/media", work_abs);
    mkdir(tmp, 0755);

    for (size_t r = 0; r < NROMS; r++) {
        if (!roms[r].src) continue;
        file_sha256(roms[r].src, roms[r].sha, &roms[r].size);
        snprintf(tmp, sizeof(tmp), "%s/%s%s", roms[r].in_system ? system_dir : work_abs,
                 roms[r].in_system ? "xmil/" : "", roms[r].dest);
        copy_file(roms[r].src, tmp);
    }

    char fdd_copy[2][1024], fdd_sha[2][65] = {"", ""};
    for (int d = 0; d < 2; d++) {
        if (!fdd[d]) continue;
        const char *dot = strrchr(fdd[d], '.');
        if (!dot || strlen(dot) > 5) die("disk needs an extension: %s", fdd[d]);
        file_sha256(fdd[d], fdd_sha[d], NULL);
        /* Space-free private copy: the core splits its content path on blanks
         * and writes back to mounted images. */
        snprintf(fdd_copy[d], sizeof(fdd_copy[d]), "%s/media/fdd%d%s", work_abs, d, dot);
        copy_file(fdd[d], fdd_copy[d]);
    }

    snprintf(tmp, sizeof(tmp), "%s/xmil.cfg", work_abs);
    FILE *cfg = fopen(tmp, "w");
    if (!cfg) die("cannot write %s", tmp);
    /* Every xmil.cfg key that affects emulation or display is written
     * explicitly (see docs/XMIL_REFERENCE_STATUS.md for the choices). */
    char ini_lines[16][64];
    int nlines = 0;
    snprintf(ini_lines[nlines++], 64, "IPL_TYPE=%d", rom_type);
    snprintf(ini_lines[nlines++], 64, "Resolute=%x", dip);
    snprintf(ini_lines[nlines++], 64, "OPMsound=%d", strcmp(opm, "off") ? 1 : 0);
    snprintf(ini_lines[nlines++], 64, "DispSync=true");
    snprintf(ini_lines[nlines++], 64, "Real_Pal=true");
    snprintf(ini_lines[nlines++], 64, "skipline=false");
    snprintf(ini_lines[nlines++], 64, "skplight=0");
    snprintf(ini_lines[nlines++], 64, "Seek_Snd=false");
    snprintf(ini_lines[nlines++], 64, "s_NOWAIT=false");
    snprintf(ini_lines[nlines++], 64, "SkpFrame=0");
    fprintf(cfg, "[Xmillennium]\r\n");
    for (int i = 0; i < nlines; i++) fprintf(cfg, "%s\r\n", ini_lines[i]);
    for (int i = 0; i < nini; i++) fprintf(cfg, "%s\r\n", ini_extra[i]);
    fclose(cfg);

    if (keys) load_keys(keys);
    /* The core prints progress to stdout; keep stdout for the JSON summary. */
    fflush(stdout);
    int json_fd = dup(1);
    dup2(2, 1);
    if (chdir(work_abs)) die("chdir %s failed", work_abs);

    char core_sha[65];
    file_sha256(core_abs, core_sha, NULL);
    void *h = dlopen(core_abs, RTLD_NOW | RTLD_LOCAL);
    if (!h) die("dlopen: %s", dlerror());
#define SYM(type, name) __typeof__(type) name = (__typeof__(type))dlsym(h, #name); if (!name) die("missing symbol %s", #name)
    SYM(void (*)(retro_environment_t), retro_set_environment);
    SYM(void (*)(retro_video_refresh_t), retro_set_video_refresh);
    SYM(void (*)(retro_audio_sample_t), retro_set_audio_sample);
    SYM(void (*)(retro_audio_sample_batch_t), retro_set_audio_sample_batch);
    SYM(void (*)(retro_input_poll_t), retro_set_input_poll);
    SYM(void (*)(retro_input_state_t), retro_set_input_state);
    SYM(void (*)(void), retro_init);
    SYM(bool (*)(const struct retro_game_info *), retro_load_game);
    SYM(void (*)(void), retro_run);
    SYM(void (*)(unsigned char), keystat_senddata);
    SYM(void (*)(unsigned char, const char *, uint32_t, int), diskdrv_setfddex);
    /* CORESTAT (pccore.h): SINT32 syncclock; SINT32 framebaseclock; ... */
    SYM(int32_t *, corestat);
    SYM(unsigned char *, pccore);   /* only for reporting the effective model */
    /* XMILCFG (pccore.h) begins with UINT8 ROM_TYPE, DIP_SW, fddequip,
     * DISPSYNC, RASTER, skipline: reported to show xmil.cfg took effect. */
    SYM(unsigned char *, xmilcfg);
    SYM(unsigned char *, font_ank);
    SYM(unsigned char *, font_txt);
    SYM(unsigned char *, font_knjx1t);

    retro_set_environment(env_cb);
    retro_set_video_refresh(video_cb);
    retro_set_audio_sample(audio_cb);
    retro_set_audio_sample_batch(audio_batch_cb);
    retro_set_input_poll(input_poll_cb);
    retro_set_input_state(input_state_cb);
    retro_init();

    struct retro_game_info info = {0};
    info.path = fdd[0] ? fdd_copy[0] : "x1";   /* "x1" = no content argument */
    if (!retro_load_game(&info)) die("retro_load_game failed%s", "");

    if (wav_path) {
        wav = fopen(wav_path, "wb");
        if (!wav) die("cannot create %s", wav_path);
        wav_header(wav, 0);
    }

    retro_run();   /* first call: core initialisation and reset, no emulation */

    /* The fonts actually loaded must be the supplied files, byte for byte. */
    long bad8 = roms[2].src ? check_bytes(font_ank, roms[2].src, 0x800) : -1;
    long bad16 = roms[3].src ? check_bytes(font_txt, roms[3].src, 0x1000) : -1;
    long kchecked = 0;
    long badk = roms[4].src ? check_kanji(font_knjx1t, roms[4].src, &kchecked) : -1;
    int tmp_fonts = count_tmp_fonts(work_abs);
    int fonts_real = bad8 == 0 && bad16 == 0 && badk == 0 && kchecked > 0 && tmp_fonts == 0;
    if (!fonts_real && !allow_virtual) {
        fprintf(stderr, "xmil-cli: loaded fonts differ from the supplied files "
                "(ank8 %ld, ank16 %ld bytes; kanji %ld of %ld glyphs; %d .TMP files)\n",
                bad8, bad16, badk, kchecked, tmp_fonts);
        exit(3);
    }
    if (fdd[1]) diskdrv_setfddex(1, fdd_copy[1], 0, 0);

    double now_ms = 0;
    long frame = 0;
    int next_event = 0;
    while (now_ms < total_ms) {
        while (next_event < nevents && events[next_event].ms <= now_ms) {
            keystat_senddata((unsigned char)(events[next_event].code | (events[next_event].up ? 0x80 : 0)));
            next_event++;
        }
        retro_run();
        frame++;
        now_ms += corestat[1] / 4000.0;     /* framebaseclock, 4 MHz CPU clocks */
        for (int i = 0; i < nframes; i++) {
            if (!frames[i].done && now_ms >= frames[i].ms && last_frame) {
                write_png(frames[i].path, last_frame, last_w, last_h, last_pitch);
                frames[i].done = 1;
                frames[i].at_ms = now_ms;
                frames[i].at_frame = frame;
            }
        }
    }
    if (final_png && last_frame) write_png(final_png, last_frame, last_w, last_h, last_pitch);
    if (wav) { wav_header(wav, wav_frames); fclose(wav); }

    fflush(stdout);
    dup2(json_fd, 1);
    FILE *o = stdout;
    fprintf(o, "{\n  \"tool\": \"xmil-cli\",\n  \"core\": ");
    json_str(o, core_abs);
    fprintf(o, ",\n  \"core_sha256\": \"%s\",\n  \"work\": ", core_sha);
    json_str(o, work_abs);
    fprintf(o, ",\n  \"model\": \"%s\", \"ipl_type\": %d, \"effective_rom_type\": %d,\n", model,
            rom_type, pccore[12]);   /* PCCORE (no FIX_Z80A): 3 x 32-bit, then ROM_TYPE */
    fprintf(o, "  \"monitor\": \"%s\", \"boot\": \"%s\", \"dip_sw\": %d, \"opm\": \"%s\",\n",
            monitor, boot, dip, opm);
    fprintf(o, "  \"roms\": [");
    int first = 1;
    for (size_t r = 0; r < NROMS; r++) {
        if (!roms[r].src) continue;
        fprintf(o, "%s\n    {\"name\": \"%s\", \"source\": ", first ? "" : ",", roms[r].dest);
        json_str(o, roms[r].src);
        fprintf(o, ", \"bytes\": %zu, \"sha256\": \"%s\"}", roms[r].size, roms[r].sha);
        first = 0;
    }
    fprintf(o, "\n  ],\n  \"font_check\": {\"real_rom_fonts\": %s, \"ank8_byte_mismatches\": %ld, "
            "\"ank16_byte_mismatches\": %ld, \"kanji_level1_glyphs_checked\": %ld, "
            "\"kanji_level1_glyph_mismatches\": %ld, \"tmp_font_files\": %d, "
            "\"virtual_fonts_allowed\": %s},\n",
            fonts_real ? "true" : "false", bad8, bad16, kchecked, badk, tmp_fonts,
            allow_virtual ? "true" : "false");
    fprintf(o, "  \"xmilcfg_effective\": {\"ROM_TYPE\": %u, \"DIP_SW\": %u, \"fddequip\": %u, "
            "\"DISPSYNC\": %u, \"RASTER\": %u, \"skipline\": %u},\n", xmilcfg[0], xmilcfg[1],
            xmilcfg[2], xmilcfg[3], xmilcfg[4], xmilcfg[5]);
    fprintf(o, "  \"xmil_cfg\": [");
    for (int i = 0; i < nlines + nini; i++) {
        fprintf(o, "%s", i ? ", " : "");
        json_str(o, i < nlines ? ini_lines[i] : ini_extra[i - nlines]);
    }
    fprintf(o, "],\n  \"core_variables\": \"none set (x1_analog, X1_GUI_controller, "
            "X1_GUIJOY_PAS left at core defaults; input-only)\",\n");
    fprintf(o, "  \"disks\": [");
    first = 1;
    for (int d = 0; d < 2; d++) {
        if (!fdd[d]) continue;
        fprintf(o, "%s\n    {\"drive\": %d, \"source\": ", first ? "" : ",", d);
        json_str(o, fdd[d]);
        fprintf(o, ", \"sha256\": \"%s\", \"private_copy\": ", fdd_sha[d]);
        json_str(o, fdd_copy[d]);
        fprintf(o, "}");
        first = 0;
    }
    fprintf(o, "\n  ],\n  \"keys\": ");
    if (keys) json_str(o, keys); else fprintf(o, "null");
    fprintf(o, ", \"key_events\": %d, \"key_events_sent\": %d,\n", nevents, next_event);
    fprintf(o, "  \"frames_run\": %ld, \"emulated_ms\": %.3f, \"video\": [%u, %u],\n", frame,
            now_ms, last_w, last_h);
    fprintf(o, "  \"outputs\": [");
    first = 1;
    for (int i = 0; i < nframes; i++) {
        fprintf(o, "%s\n    {\"requested_ms\": %.1f, \"path\": ", first ? "" : ",", frames[i].ms);
        json_str(o, frames[i].path);
        if (frames[i].done)
            fprintf(o, ", \"captured_ms\": %.3f, \"frame\": %ld}", frames[i].at_ms, frames[i].at_frame);
        else
            fprintf(o, ", \"captured_ms\": null}");
        first = 0;
    }
    if (final_png) {
        fprintf(o, "%s\n    {\"final\": true, \"path\": ", first ? "" : ",");
        json_str(o, final_png);
        fprintf(o, ", \"captured_ms\": %.3f, \"frame\": %ld}", now_ms, frame);
    }
    fprintf(o, "\n  ],\n  \"wav\": ");
    if (wav_path) { json_str(o, wav_path); fprintf(o, ", \"wav_frames\": %llu", (unsigned long long)wav_frames); }
    else fprintf(o, "null");
    fprintf(o, "\n}\n");
    fflush(o);
    _exit(0);   /* retro_deinit is skipped; all mounted media are private copies */
}
