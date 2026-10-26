/*
 * SPDX-License-Identifier: GPL-2.0-only
 * Forced-include overlay for the SharpX1_Mister X Millennium reference build
 * (tools/xmil-cli/build.sh).  Original project code; no X Millennium source.
 *
 * The pinned xmil-libretro port defines SUPPORT_OPM in libretro/compiler.h but
 * not SUPPORT_TURBOZ or SUPPORT_BANKMEM, so its libretro core only offers the
 * X1 and X1 turbo IPL types.  These flags enable the existing upstream Turbo Z
 * (64/4096-colour palette, Z registers) and bank-memory code paths.
 */
#ifndef XMIL_CLI_OVERLAY_H
#define XMIL_CLI_OVERLAY_H

#if defined(XMIL_CLI_TURBOZ)
#define SUPPORT_TURBOZ
/*
 * pccore_reset() calls scrnmng_setcolormode() when SUPPORT_TURBOZ is set.
 * Other ports switch the host display depth there; the libretro port has
 * no such function and always renders through its 16-bpp RGB565 surface
 * (scrnmng_getbpp() is the constant 16), which already has 4096-colour
 * palette entries (vram/palettes.c XMILPAL_4096*).  Report success so the
 * Turbo Z model is kept instead of falling back to ROM_TYPE 2.
 */
#define scrnmng_setcolormode(enable) ((void)(enable), 0 /* SUCCESS */)
#endif

#if defined(XMIL_CLI_BANKMEM)
#define SUPPORT_BANKMEM
#endif

#endif
