#include "g_display.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static u32 g_command_count;
static u32 g_text_count;
static u32 g_curve_clear_count;
static u32 g_curve_transfer_count;
static u32 g_axis_text_command_count;
static u32 g_saw_time_unit;
static u32 g_saw_order_unit;
static u32 g_saw_10_label;
static u32 g_saw_56_label;
static u32 g_saw_x_axis_region;
static u32 g_saw_x_axis_zero_label;
static u32 g_saw_x_axis_right_center;
static u32 g_saw_y_axis_top;
static u32 g_saw_y_axis_bottom;
static char g_last_command[96];
static char g_last_text_component[32];
static char g_last_text_value[64];
static char g_harmonic_text[3][64];
static char g_thd_text[64];
static u8 g_last_curve_data[G_DISPLAY_CURVE_POINTS];
static u8 g_question_1_curve_data[G_DISPLAY_CURVE_POINTS];

static u32 count_curve_lines(const u8 *data)
{
    u32 count = 0U;
    u32 inside = 0U;
    u32 index;

    for (index = 0U; index < G_DISPLAY_CURVE_POINTS; index++) {
        if (data[index] > 10U) {
            if (inside == 0U) {
                count++;
                inside = 1U;
            }
        } else {
            inside = 0U;
        }
    }
    return count;
}

static u8 maximum_curve_value(const u8 *data)
{
    u8 maximum = 0U;
    u32 index;

    for (index = 0U; index < G_DISPLAY_CURVE_POINTS; index++) {
        if (data[index] > maximum) {
            maximum = data[index];
        }
    }
    return maximum;
}

int SerialScreen_Init(SerialScreen *screen)
{
    if (screen == NULL) {
        return -1;
    }
    screen->base_address = 0U;
    return 0;
}

int SerialScreen_TryReadByte(const SerialScreen *screen, u8 *byte)
{
    (void)screen;
    (void)byte;
    return 0;
}

int SerialScreen_SendCommand(const SerialScreen *screen,
                             const char *command)
{
    assert(screen != NULL);
    assert(command != NULL);
    assert(strncmp(command, "fill ", 5U) != 0);
    assert(strncmp(command, "line ", 5U) != 0);
    assert(strncmp(command, "page ", 5U) != 0);
    if (strncmp(command, "cle ", 4U) == 0) {
        g_curve_clear_count++;
    }
    if (strncmp(command, "xstr ", 5U) == 0) {
        g_axis_text_command_count++;
        if (strstr(command, "\"us\"") != NULL) {
            g_saw_time_unit = 1U;
        }
        if (strstr(command, "\"n\"") != NULL) {
            g_saw_order_unit = 1U;
        }
        if (strstr(command, ",\"10\"") != NULL) {
            g_saw_10_label = 1U;
        }
        if (strstr(command, ",\"56\"") != NULL) {
            g_saw_56_label = 1U;
        }
        if (strstr(command, ",332,70,28,") != NULL) {
            g_saw_x_axis_region = 1U;
            if (strstr(command, ",\"0\"") != NULL) {
                g_saw_x_axis_zero_label = 1U;
            }
        }
        if (strstr(command, "xstr 877,332,70,28,") != NULL) {
            g_saw_x_axis_right_center = 1U;
        }
        if (strstr(command, "xstr 40,36,70,28,") != NULL) {
            g_saw_y_axis_top = 1U;
        }
        if (strstr(command, "xstr 40,316,70,28,") != NULL) {
            g_saw_y_axis_bottom = 1U;
        }
    }
    (void)snprintf(g_last_command,
                   sizeof(g_last_command),
                   "%s",
                   command);
    g_command_count++;
    return 0;
}

int SerialScreen_SendCurveData(const SerialScreen *screen,
                               u32 component_id,
                               u32 channel,
                               const u8 *data,
                               u32 points)
{
    assert(screen != NULL);
    assert(component_id == 1U);
    assert(channel == 0U);
    assert(data != NULL);
    assert(points == G_DISPLAY_CURVE_POINTS);
    memcpy(g_last_curve_data, data, points);
    g_curve_transfer_count++;
    return 0;
}

int SerialScreen_SetText(const SerialScreen *screen,
                         const char *component,
                         const char *value)
{
    assert(screen != NULL);
    assert(component != NULL);
    assert(value != NULL);
    (void)snprintf(g_last_text_component,
                   sizeof(g_last_text_component),
                   "%s",
                   component);
    (void)snprintf(g_last_text_value,
                   sizeof(g_last_text_value),
                   "%s",
                   value);
    if (strcmp(component, "tT0") == 0) {
        (void)snprintf(g_harmonic_text[0],
                       sizeof(g_harmonic_text[0]),
                       "%s",
                       value);
    } else if (strcmp(component, "tT1") == 0) {
        (void)snprintf(g_harmonic_text[1],
                       sizeof(g_harmonic_text[1]),
                       "%s",
                       value);
    } else if (strcmp(component, "tT2") == 0) {
        (void)snprintf(g_harmonic_text[2],
                       sizeof(g_harmonic_text[2]),
                       "%s",
                       value);
    } else if (strcmp(component, "tTHD") == 0) {
        (void)snprintf(g_thd_text,
                       sizeof(g_thd_text),
                       "%s",
                       value);
    }
    g_text_count++;
    return 0;
}

static AcmV2PeriodicResult make_result(void)
{
    AcmV2PeriodicResult result;

    memset(&result, 0, sizeof(result));
    result.valid = 1U;
    result.component_count = 2U;
    result.fundamental_hz_x100 = 3000000U;
    result.peak_to_peak_uv = 120000U;
    result.true_rms_uv = 38000U;
    result.thd_ppm = 400000U;
    result.component[0].frequency_hz_x100 = 3000000U;
    result.component[0].peak_uv = 50000U;
    result.component[0].phase_mdeg = 30000;
    result.component[1].frequency_hz_x100 = 6000000U;
    result.component[1].peak_uv = 20000U;
    result.component[1].phase_mdeg = 80000;
    return result;
}

int main(void)
{
    AcmV2PeriodicResult result = make_result();
    GDisplay display;
    u32 commands_after_draw;
    u32 axis_commands_after_draw;

    assert(GDisplay_Init(&display) == 0);
    assert(display.question == G_QUESTION_1);
    assert(display.view == G_DISPLAY_WAVEFORM_1);
    assert(strcmp(g_last_command, "bkcmd=0") == 0);
    assert(GDisplay_SetView(&display, G_DISPLAY_WAVEFORM_1) == 0);
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    commands_after_draw = g_command_count;
    assert(commands_after_draw >= 2U);
    assert(g_curve_clear_count == 1U);
    assert(g_curve_transfer_count == 1U);
    assert(g_axis_text_command_count == 20U);
    assert(g_saw_time_unit != 0U);
    assert(g_saw_x_axis_region != 0U);
    assert(g_saw_x_axis_zero_label == 0U);
    assert(g_saw_x_axis_right_center != 0U);
    assert(g_saw_y_axis_top != 0U);
    assert(g_saw_y_axis_bottom != 0U);
    axis_commands_after_draw = g_axis_text_command_count;
    assert(strcmp(g_harmonic_text[0], "1") == 0);
    assert(strcmp(g_harmonic_text[1], "2") == 0);
    assert(strcmp(g_harmonic_text[2], "--") == 0);
    assert(strcmp(g_thd_text, "40.0000 %") == 0);

    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_command_count == commands_after_draw);

    assert(GDisplay_Update(&display, &result, 1U) == 0);
    assert(g_command_count == commands_after_draw);
    assert(strcmp(g_last_text_component, "tStatus") == 0);
    assert(strcmp(g_last_text_value, "HOLD") == 0);
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_command_count == commands_after_draw);
    assert(strcmp(g_last_text_component, "tStatus") == 0);
    assert(strcmp(g_last_text_value, "OK") == 0);

    result.component[1].frequency_hz_x100 += 50000U;
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_command_count > commands_after_draw);
    assert(g_curve_clear_count == 2U);
    assert(g_curve_transfer_count == 2U);
    assert(g_axis_text_command_count == axis_commands_after_draw);
    commands_after_draw = g_command_count;

    result.component[1].peak_uv += 499U;
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_command_count == commands_after_draw);
    result.component[1].peak_uv += 1U;
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_command_count > commands_after_draw);
    commands_after_draw = g_command_count;

    result.component[1].phase_mdeg += 5000;
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_command_count > commands_after_draw);

    assert(GDisplay_SetView(&display, G_DISPLAY_WAVEFORM_5) == 0);
    commands_after_draw = g_command_count;
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_command_count > commands_after_draw);

    assert(GDisplay_SetView(&display, G_DISPLAY_SPECTRUM) == 0);
    commands_after_draw = g_command_count;
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_command_count == commands_after_draw + 21U);
    assert(g_curve_transfer_count == 6U);
    assert(g_saw_order_unit != 0U);

    assert(strcmp(GDisplay_ViewName(G_DISPLAY_WAVEFORM_5),
                  "WAVE5") == 0);

    result.component[0].frequency_hz_x100 = 10000000U;
    result.component[0].peak_uv = 20000U;
    result.component[1].frequency_hz_x100 = 20000000U;
    result.component[1].peak_uv = 50000U;
    result.component[2].frequency_hz_x100 = 70000000U;
    result.component[2].peak_uv = 30000U;
    result.component_count = 3U;
    result.fundamental_hz_x100 =
        result.component[0].frequency_hz_x100;

    assert(GDisplay_SetQuestion(&display, G_QUESTION_1) == 0);
    assert(display.view == G_DISPLAY_WAVEFORM_1);
    assert(GDisplay_SetView(&display, G_DISPLAY_SPECTRUM) == 0);
    g_saw_10_label = 0U;
    g_saw_56_label = 0U;
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(g_last_curve_data[0U] == 0U);
    assert(g_last_curve_data[G_DISPLAY_CURVE_POINTS - 1U] == 0U);
    assert(count_curve_lines(g_last_curve_data) == 3U);
    assert(maximum_curve_value(g_last_curve_data) == 250U);
    assert(g_last_curve_data[720U] == 100U);
    assert(g_last_curve_data[640U] == 250U);
    assert(g_last_curve_data[240U] == 150U);
    assert(g_saw_10_label != 0U);
    assert(g_saw_56_label != 0U);
    assert(strcmp(g_harmonic_text[0], "1") == 0);
    assert(strcmp(g_harmonic_text[1], "2") == 0);
    assert(strcmp(g_harmonic_text[2], "7") == 0);
    memcpy(g_question_1_curve_data,
           g_last_curve_data,
           G_DISPLAY_CURVE_POINTS);

    assert(GDisplay_SetQuestion(&display, G_QUESTION_2) == 0);
    assert(GDisplay_SetView(&display, G_DISPLAY_SPECTRUM) == 0);
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(memcmp(g_last_curve_data,
                  g_question_1_curve_data,
                  G_DISPLAY_CURVE_POINTS) == 0);

    assert(GDisplay_SetQuestion(&display, G_QUESTION_3) == 0);
    assert(GDisplay_SetView(&display, G_DISPLAY_SPECTRUM) == 0);
    assert(GDisplay_Update(&display, &result, 0U) == 0);
    assert(memcmp(g_last_curve_data,
                  g_question_1_curve_data,
                  G_DISPLAY_CURVE_POINTS) == 0);
    {
        u32 transfers_before_change = g_curve_transfer_count;

        result.component[0].frequency_hz_x100 = 15000000U;
        result.component[1].frequency_hz_x100 = 30000000U;
        result.component[2].frequency_hz_x100 = 45000000U;
        result.fundamental_hz_x100 =
            result.component[0].frequency_hz_x100;
        assert(GDisplay_Update(&display, &result, 0U) == 0);
        assert(strcmp(g_harmonic_text[0], "1") == 0);
        assert(strcmp(g_harmonic_text[1], "2") == 0);
        assert(strcmp(g_harmonic_text[2], "3") == 0);
        assert(g_curve_transfer_count ==
               transfers_before_change + 1U);
        assert(count_curve_lines(g_last_curve_data) == 3U);
        transfers_before_change = g_curve_transfer_count;
        assert(GDisplay_Update(&display, &result, 0U) == 0);
        assert(GDisplay_Update(&display, &result, 0U) == 0);
        assert(GDisplay_Update(&display, &result, 0U) == 0);
        assert(GDisplay_Update(&display, &result, 0U) == 0);
        assert(GDisplay_Update(&display, &result, 0U) == 0);
        assert(g_curve_transfer_count == transfers_before_change);
    }
    GDisplay_ShowLock(&display, 1U, 3U);
    assert(strcmp(g_last_text_component, "tStatus") == 0);
    assert(strcmp(g_last_text_value, "LOCK 1/3") == 0);
    assert(g_text_count >= 1U);
    puts("g_display refresh tests passed");
    return 0;
}
