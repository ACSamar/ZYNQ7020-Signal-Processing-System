#include "g_display.h"
#include "g_display_graph.h"

#include <stdio.h>

#define G_SCREEN_PARAMETER_REFRESH_FRAMES 4U

static void format_frequency(char *text_value,
                             u32 text_length,
                             u32 frequency_hz_x100)
{
    (void)snprintf(text_value,
                   text_length,
                   "%u.%03u kHz",
                   (unsigned int)(frequency_hz_x100 / 100000U),
                   (unsigned int)((frequency_hz_x100 % 100000U) /
                                  100U));
}

static void format_voltage(char *text_value,
                           u32 text_length,
                           u32 voltage_uv)
{
    (void)snprintf(text_value,
                   text_length,
                   "%u.%03u mV",
                   (unsigned int)(voltage_uv / 1000U),
                   (unsigned int)(voltage_uv % 1000U));
}

static void format_thd(char *text_value,
                       u32 text_length,
                       u32 thd_ppm)
{
    (void)snprintf(text_value,
                   text_length,
                   "%u.%04u %%",
                   (unsigned int)(thd_ppm / 10000U),
                   (unsigned int)(thd_ppm % 10000U));
}

static void set_component_text(
    GDisplay *display,
    const AcmV2PeriodicResult *result,
    u32 component_index)
{
    static const char *frequency_text_component[3] = {
        "tF1", "tF2", "tF3"
    };
    static const char *amplitude_text_component[3] = {
        "tA1", "tA2", "tA3"
    };
    static const char *harmonic_order_text_component[3] = {
        "tT0", "tT1", "tT2"
    };
    char text_value[32];
    u32 harmonic_order;

    if (component_index >= result->component_count) {
        (void)SerialScreen_SetText(
            &display->screen,
            frequency_text_component[component_index],
            "--");
        (void)SerialScreen_SetText(
            &display->screen,
            amplitude_text_component[component_index],
            "--");
        (void)SerialScreen_SetText(
            &display->screen,
            harmonic_order_text_component[component_index],
            "--");
        return;
    }

    format_frequency(
        text_value,
        sizeof(text_value),
        result->component[component_index].frequency_hz_x100);
    (void)SerialScreen_SetText(
        &display->screen,
        frequency_text_component[component_index],
        text_value);
    format_voltage(text_value,
                   sizeof(text_value),
                   result->component[component_index].peak_uv);
    (void)SerialScreen_SetText(
        &display->screen,
        amplitude_text_component[component_index],
        text_value);
    harmonic_order =
        GDisplayGraph_ComponentOrder(result, component_index);
    if (harmonic_order == 0U) {
        (void)SerialScreen_SetText(
            &display->screen,
            harmonic_order_text_component[component_index],
            "--");
    } else {
        (void)snprintf(text_value,
                       sizeof(text_value),
                       "%u",
                       (unsigned int)harmonic_order);
        (void)SerialScreen_SetText(
            &display->screen,
            harmonic_order_text_component[component_index],
            text_value);
    }
}

static void update_parameter_text(
    GDisplay *display,
    const AcmV2PeriodicResult *result,
    u32 measurement_held)
{
    char text_value[32];
    u32 component_index;

    format_frequency(text_value,
                     sizeof(text_value),
                     result->fundamental_hz_x100);
    (void)SerialScreen_SetText(&display->screen,
                               "tF0",
                               text_value);
    format_voltage(text_value,
                   sizeof(text_value),
                   result->peak_to_peak_uv);
    (void)SerialScreen_SetText(&display->screen,
                               "tVpp",
                               text_value);
    format_voltage(text_value,
                   sizeof(text_value),
                   result->true_rms_uv);
    (void)SerialScreen_SetText(&display->screen,
                               "tVrms",
                               text_value);
    format_thd(text_value,
               sizeof(text_value),
               result->thd_ppm);
    (void)SerialScreen_SetText(&display->screen,
                               "tTHD",
                               text_value);
    for (component_index = 0U;
         component_index < ACMV2_PERIODIC_MAX_COMPONENTS;
         component_index++) {
        set_component_text(display, result, component_index);
    }
    (void)SerialScreen_SetText(
        &display->screen,
        "tStatus",
        (measurement_held != 0U) ? "HOLD" : "OK");
}

static void reset_display_refresh_state(GDisplay *display)
{
    display->view_refresh_pending = 1U;
    display->parameter_refresh_frame_count = 0U;
    display->hold_state_valid = 0U;
    display->last_hold_state = 0U;
    GDisplayGraph_Reset(display);
}

static int draw_selected_graph(
    GDisplay *display,
    const AcmV2PeriodicResult *result)
{
    if (display->view == G_DISPLAY_WAVEFORM_1) {
        return GDisplayGraph_DrawWaveform(display, result, 1U);
    }
    if (display->view == G_DISPLAY_WAVEFORM_3) {
        return GDisplayGraph_DrawWaveform(display, result, 3U);
    }
    if (display->view == G_DISPLAY_WAVEFORM_5) {
        return GDisplayGraph_DrawWaveform(display, result, 5U);
    }
    return GDisplayGraph_DrawSpectrum(display, result);
}

int GDisplay_Init(GDisplay *display)
{
    if (display == 0) {
        return -1;
    }
    if (SerialScreen_Init(&display->screen) != 0) {
        return -1;
    }

    display->question = G_QUESTION_1;
    display->view = G_DISPLAY_WAVEFORM_1;
    reset_display_refresh_state(display);
    (void)SerialScreen_SendCommand(&display->screen, "bkcmd=0");
    (void)SerialScreen_SetText(&display->screen,
                               "tView",
                               "WAVE 1");
    (void)SerialScreen_SetText(&display->screen,
                               "tStatus",
                               "LOCKING");
    return 0;
}

int GDisplay_SetQuestion(GDisplay *display,
                         GQuestionMode question)
{
    if ((display == 0) ||
        (GQuestionMode_IsValid(question) == 0U)) {
        return -1;
    }
    display->question = question;
    display->view = G_DISPLAY_WAVEFORM_1;
    reset_display_refresh_state(display);
    (void)SerialScreen_SetText(&display->screen,
                               "tView",
                               "WAVE 1");
    (void)SerialScreen_SetText(&display->screen,
                               "tStatus",
                               "LOCKING");
    return 0;
}

int GDisplay_SetView(GDisplay *display, GDisplayView view)
{
    static const char *view_text[5] = {
        "PARAM", "WAVE 1", "WAVE 3", "WAVE 5", "SPECTRUM"
    };

    if ((display == 0) || (view > G_DISPLAY_SPECTRUM)) {
        return -1;
    }
    display->view = view;
    display->view_refresh_pending = 1U;
    display->parameter_refresh_frame_count = 0U;
    GDisplayGraph_InvalidateAxis(display);
    return SerialScreen_SetText(&display->screen,
                                "tView",
                                view_text[(u32)view]);
}

int GDisplay_Update(GDisplay *display,
                    const AcmV2PeriodicResult *result,
                    u32 measurement_held)
{
    u32 view_refresh_required;
    u32 parameters_need_refresh;
    u32 graph_needs_refresh;
    u32 hold_state_changed;
    int update_status = 0;

    if ((display == 0) ||
        (result == 0) ||
        (result->valid == 0U)) {
        return -1;
    }

    view_refresh_required = display->view_refresh_pending;
    parameters_need_refresh = view_refresh_required;
    hold_state_changed =
        ((display->hold_state_valid == 0U) ||
         (display->last_hold_state != measurement_held)) ? 1U : 0U;
    if (view_refresh_required == 0U) {
        display->parameter_refresh_frame_count++;
        if (display->parameter_refresh_frame_count >=
            G_SCREEN_PARAMETER_REFRESH_FRAMES) {
            parameters_need_refresh = 1U;
        }
    }
    if (hold_state_changed != 0U) {
        parameters_need_refresh = 1U;
    }
    graph_needs_refresh =
        ((display->view != G_DISPLAY_PARAMETERS) &&
         ((view_refresh_required != 0U) ||
          (GDisplayGraph_HasResultChanged(display, result) != 0U))) ?
        1U : 0U;

    if ((measurement_held != 0U) &&
        (view_refresh_required == 0U)) {
        graph_needs_refresh = 0U;
    }
    if (graph_needs_refresh != 0U) {
        parameters_need_refresh = 1U;
    }
    if ((parameters_need_refresh == 0U) &&
        (graph_needs_refresh == 0U)) {
        return 0;
    }

    if (parameters_need_refresh != 0U) {
        display->parameter_refresh_frame_count = 0U;
        update_parameter_text(display, result, measurement_held);
        display->last_hold_state = measurement_held;
        display->hold_state_valid = 1U;
    }
    if (graph_needs_refresh != 0U) {
        update_status = draw_selected_graph(display, result);
        if (update_status == 0) {
            display->graph.previous_result = *result;
            display->graph.previous_result_valid = 1U;
        }
    }
    display->view_refresh_pending =
        (update_status == 0) ? 0U : 1U;
    return update_status;
}

void GDisplay_ShowLock(GDisplay *display,
                       u32 current_frame_count,
                       u32 required_frame_count)
{
    char status_text[24];

    if (display == 0) {
        return;
    }
    (void)snprintf(status_text,
                   sizeof(status_text),
                   "LOCK %u/%u",
                   (unsigned int)current_frame_count,
                   (unsigned int)required_frame_count);
    (void)SerialScreen_SetText(&display->screen,
                               "tStatus",
                               status_text);
}

void GDisplay_ShowError(GDisplay *display,
                        const char *error_message)
{
    if ((display == 0) || (error_message == 0)) {
        return;
    }
    (void)SerialScreen_SetText(&display->screen,
                               "tStatus",
                               error_message);
}

const char *GDisplay_ViewName(GDisplayView view)
{
    static const char *view_name[5] = {
        "PARAM", "WAVE1", "WAVE3", "WAVE5", "SPECTRUM"
    };

    if (view > G_DISPLAY_SPECTRUM) {
        return "UNKNOWN";
    }
    return view_name[(u32)view];
}
