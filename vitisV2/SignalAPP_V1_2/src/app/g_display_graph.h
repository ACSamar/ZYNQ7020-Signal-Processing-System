#ifndef G_DISPLAY_GRAPH_H
#define G_DISPLAY_GRAPH_H

#include "g_display.h"

u32 GDisplayGraph_HasResultChanged(
    const GDisplay *display,
    const AcmV2PeriodicResult *result);
u32 GDisplayGraph_ComponentOrder(
    const AcmV2PeriodicResult *result,
    u32 component_index);
int GDisplayGraph_DrawWaveform(
    GDisplay *display,
    const AcmV2PeriodicResult *result,
    u32 cycle_count);
int GDisplayGraph_DrawSpectrum(
    GDisplay *display,
    const AcmV2PeriodicResult *result);
void GDisplayGraph_Reset(GDisplay *display);
void GDisplayGraph_InvalidateAxis(GDisplay *display);

#endif
