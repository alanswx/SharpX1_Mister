/* Original counterfactual reference-build adapter, not machine RTL.
 * Compile instead of io/ctc.c in a separate disposable X Millennium build.
 * Include the exact reference source and preserve its notices unchanged.
 * This replaces only end-of-service phase coalescing with pending retention;
 * it does not assert that either behavior matches physical X1 hardware.
 */
#define ieeoi_ctc x1_reference_phase_coalescing_eoi
#include "ctc.c"
#undef ieeoi_ctc

void ieeoi_ctc(UINT id) {
    CTCCH *channel = &ctc.ch[id - IEVENT_CTC0];
    channel->s.intr |= ctcwork(channel);
    if (channel->s.intr)
        ievent_set(id);
    else
        ctcnextevent(channel);
}
