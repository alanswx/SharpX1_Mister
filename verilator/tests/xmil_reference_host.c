/* Original read-only reference observer. No third-party source or assets.
 * Build against the exact staged X Millennium headers used for its dylib.
 * Run only with disposable disks and a private system/config/output folder.
 */
#include "compiler.h"
#include "libretro.h"
#include "z80core.h"
#define IOOUTCALL
#define IOINPCALL
#include "ctc.h"
#include "pccore.h"
#include <dlfcn.h>
#include <stdint.h>

static const char *system_dir, *output_dir;
static unsigned frame;
static Z80CORE *cpu;
static CTC *timer;
static PCCORE *machine;

static void fail(const char *message) {
    fprintf(stderr, "%s\n", message);
    exit(1);
}

static bool environment(unsigned command, void *data) {
    switch (command) {
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
    case RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY:
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
        *(const char **)data = system_dir;
        return true;
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
        return *(enum retro_pixel_format *)data == RETRO_PIXEL_FORMAT_RGB565;
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
        *(bool *)data = false;
        return true;
    case RETRO_ENVIRONMENT_SET_VARIABLES:
    case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
    case RETRO_ENVIRONMENT_SET_GEOMETRY:
        return true;
    default:
        return false;
    }
}

static bool checkpoint(void) {
    return frame == 120 || frame == 480 || frame == 960 ||
           frame == 1920 || frame == 3000;
}

static void video(const void *data, unsigned width, unsigned height, size_t pitch) {
    if (!checkpoint()) return;
    if (!data || !width || !height || pitch < width * 2 || width > 640 || height > 400)
        fail("invalid reference video frame");
    char path[1024];
    int length = snprintf(path, sizeof(path), "%s/frame-%04u.ppm", output_dir, frame);
    if (length < 0 || (size_t)length >= sizeof(path))
        fail("output path too long");
    FILE *file = fopen(path, "wb");
    if (!file) fail("cannot open frame output");
    fprintf(file, "P6\n%u %u\n255\n", width, height);
    uint64_t nonzero = 0;
    for (unsigned y = 0; y < height; ++y) {
        const uint8_t *row = (const uint8_t *)data + y * pitch;
        for (unsigned x = 0; x < width; ++x) {
            uint16_t pixel;
            memcpy(&pixel, row + x * 2, sizeof(pixel));
            unsigned r = pixel >> 11, g = (pixel >> 5) & 63, b = pixel & 31;
            uint8_t rgb[3] = {(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)};
            nonzero += pixel != 0;
            if (fwrite(rgb, 1, 3, file) != 3) fail("frame write failed");
        }
    }
    if (fclose(file)) fail("frame close failed");
    printf("CHECKPOINT frame=%u frontend_seconds=%.6f cpu_cycles=%u PC=%04X SP=%04X I=%02X IM=%u IFF_RAW=%u nonzero=%llu width=%u height=%u\n",
           frame, frame / 60.0, cpu->s.clock + cpu->s.baseclock - cpu->s.remainclock,
           cpu->s.pc, cpu->s.sp, cpu->s.i, cpu->s.im, cpu->s.iff,
           (unsigned long long)nonzero, width, height);
    const CTCCHST *ctc = &timer->ch[1].s;
    printf("CTC_STATE frame=%u cmd1=%02X scale1=%u basecnt1=%u count1=%d countmax1=%d range1=%d pending=%u service=%u\n",
           frame, ctc->cmd[1], ctc->scale[1], ctc->basecnt[1], ctc->count[1],
           ctc->countmax[1], ctc->range[1], ctc->intr, ctc->irq);
}

static void audio(int16_t left, int16_t right) { (void)left; (void)right; }
static size_t audio_batch(const int16_t *data, size_t frames) { (void)data; return frames; }
static void poll_input(void) {}
static int16_t input(unsigned port, unsigned device, unsigned index, unsigned key) {
    (void)index;
    if (port || device != RETRO_DEVICE_KEYBOARD) return 0;
    if (key == RETROK_f) return frame >= 60 && frame < 72;
    if (key == RETROK_SPACE) return (frame >= 480 && frame < 498) || (frame >= 2910 && frame < 2925);
    if (key == RETROK_RETURN) return frame >= 2883 && frame < 2895;
    return 0;
}

static void *symbol(void *library, const char *name) {
    void *result = dlsym(library, name);
    if (!result) fail(dlerror());
    return result;
}

int main(int argc, char **argv) {
    if (argc != 6) fail("usage: xmil_reference_host DYLIB SYSTEM_DIR OUTPUT_DIR DISK_A DISK_B (all absolute paths)");
    for (int n = 1; n < argc; ++n) if (argv[n][0] != '/') fail("absolute paths required");
    system_dir = argv[2]; output_dir = argv[3];
    char work[1024];
    int length = snprintf(work, sizeof(work), "%s/xmil", system_dir);
    if (length < 0 || (size_t)length >= sizeof(work) || chdir(work))
        fail("cannot enter private system/xmil folder");
    void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!library) fail(dlerror());
    cpu = symbol(library, "z80core"); timer = symbol(library, "ctc");
    machine = symbol(library, "pccore");
#define CALL(name, type, value) ((void (*)(type))symbol(library, name))(value)
    CALL("retro_set_environment", retro_environment_t, environment);
    CALL("retro_set_video_refresh", retro_video_refresh_t, video);
    CALL("retro_set_audio_sample", retro_audio_sample_t, audio);
    CALL("retro_set_audio_sample_batch", retro_audio_sample_batch_t, audio_batch);
    CALL("retro_set_input_poll", retro_input_poll_t, poll_input);
    CALL("retro_set_input_state", retro_input_state_t, input);
    void (*init)(void) = symbol(library, "retro_init");
    void (*run)(void) = symbol(library, "retro_run");
    bool (*load)(const struct retro_game_info *) = symbol(library, "retro_load_game");
    void (*mount)(REG8, const OEMCHAR *, UINT32, int) = symbol(library, "diskdrv_setfddex");
    init();
    struct retro_game_info game = {.path = argv[4]};
    if (!load(&game)) fail("reference content load failed");
    run(); /* First call initializes the machine but does not execute a frame. */
    if (machine->ROM_TYPE != 2 || machine->DIP_SW != 0xF1)
        fail("reference configuration must be Turbo IPL_TYPE=2, Resolute=F1");
    printf("CONFIG ROM_TYPE=%u DIP=%02X baseclock=%u multiple=%u realclock=%u\n",
           machine->ROM_TYPE, machine->DIP_SW, machine->baseclock, machine->multiple, machine->realclock);
    uint8_t *bios = symbol(library, "biosmem");
    char ipl_path[1024];
    length = snprintf(ipl_path, sizeof(ipl_path), "%s/IPLROM.X1T", work);
    if (length < 0 || (size_t)length >= sizeof(ipl_path)) fail("IPL path too long");
    FILE *ipl = fopen(ipl_path, "rb");
    uint8_t expected[32768];
    if (!ipl || fread(expected, 1, sizeof(expected), ipl) != sizeof(expected) ||
        fgetc(ipl) != EOF || memcmp(expected, bios, sizeof(expected)))
        fail("loaded BIOS does not match supplied 32 KiB IPL");
    if (fclose(ipl)) fail("IPL close failed");
    printf("IPL_VERIFY loaded biosmem matches supplied 32768 bytes\n");
    mount(0, argv[4], 0, 1); mount(1, argv[5], 0, 1);
    printf("MOUNT A=%s B=%s readonly=1; frontend=60Hz, not assumed native seconds\n", argv[4], argv[5]);
    for (frame = 1; frame <= 3060; ++frame) run();
    ((void (*)(void))symbol(library, "retro_deinit"))();
    if (dlclose(library)) fail(dlerror());
    return 0;
}
