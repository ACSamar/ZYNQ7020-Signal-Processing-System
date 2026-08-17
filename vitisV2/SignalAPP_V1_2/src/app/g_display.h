#ifndef G_DISPLAY_H
#define G_DISPLAY_H

#include "g_question_mode.h"
#include "periodic_signal_analyzer.h"
#include "uart_io.h"

typedef enum {
    G_DISPLAY_PARAMETERS = 0,
    G_DISPLAY_WAVEFORM_1 = 1,
    G_DISPLAY_WAVEFORM_3 = 2,
    G_DISPLAY_WAVEFORM_5 = 3,
    G_DISPLAY_SPECTRUM = 4
} GDisplayView;

#define G_DISPLAY_CURVE_POINTS 800U

typedef struct {
    u32 previous_result_valid;
    AcmV2PeriodicResult previous_result;
    u32 axis_valid;
    GDisplayView axis_view;
    u64 horizontal_scale;
    u32 voltage_step_uv;
    s32 waveform_uv[G_DISPLAY_CURVE_POINTS];
    u8 curve_data[G_DISPLAY_CURVE_POINTS];
} GDisplayGraphState;

typedef struct {
    SerialScreen screen;
    GQuestionMode question;
    GDisplayView view;
    u32 view_refresh_pending;
    u32 parameter_refresh_frame_count;
    u32 hold_state_valid;
    u32 last_hold_state;
    GDisplayGraphState graph;
} GDisplay;

int GDisplay_Init(GDisplay *display);
int GDisplay_SetQuestion(GDisplay *display, GQuestionMode question);
int GDisplay_SetView(GDisplay *display, GDisplayView view);
int GDisplay_Update(GDisplay *display,
                    const AcmV2PeriodicResult *result,
                    u32 held);
void GDisplay_ShowLock(GDisplay *display, u32 current, u32 required);
void GDisplay_ShowError(GDisplay *display, const char *message);
const char *GDisplay_ViewName(GDisplayView view);

#endif
