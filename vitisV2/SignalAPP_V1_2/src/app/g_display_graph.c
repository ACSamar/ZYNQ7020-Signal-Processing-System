#include "g_display_graph.h"

#include <stdio.h>

#define G_SCREEN_CURVE_COMPONENT_ID       1U
#define G_SCREEN_CURVE_CHANNEL            0U
#define G_SCREEN_CURVE_X                112U
#define G_SCREEN_CURVE_Y                 30U
#define G_SCREEN_CURVE_WIDTH            800U
#define G_SCREEN_CURVE_HEIGHT           300U
#define G_SCREEN_CURVE_VALUE_MAX        255U
#define G_SCREEN_VERTICAL_AXIS_BOTTOM_Y \
    (G_SCREEN_CURVE_Y + G_SCREEN_CURVE_HEIGHT)
#define G_SCREEN_VERTICAL_AXIS_TOP_Y     50U
#define G_SCREEN_VERTICAL_AXIS_SPAN     \
    (G_SCREEN_VERTICAL_AXIS_BOTTOM_Y - G_SCREEN_VERTICAL_AXIS_TOP_Y)
#define G_SCREEN_WAVEFORM_ZERO_VALUE    \
    (G_SCREEN_VERTICAL_AXIS_SPAN / 2U)
#define G_SCREEN_WAVEFORM_POSITIVE_CAPACITY \
    (G_SCREEN_CURVE_VALUE_MAX - G_SCREEN_WAVEFORM_ZERO_VALUE)
#define G_SCREEN_HORIZONTAL_DIVISIONS    20U
#define G_SCREEN_VERTICAL_DIVISIONS       7U
#define G_SCREEN_AXIS_FONT_ID             0U
#define G_SCREEN_AXIS_TEXT_COLOR          0U
#define G_SCREEN_AXIS_BACKGROUND      65535U
#define G_SCREEN_HORIZONTAL_LABEL_Y     332U
#define G_SCREEN_HORIZONTAL_LABEL_WIDTH  70U
#define G_SCREEN_HORIZONTAL_LABEL_HEIGHT 28U
#define G_SCREEN_HORIZONTAL_LABEL_STRIDE  2U
#define G_SCREEN_VERTICAL_LABEL_X        40U
#define G_SCREEN_VERTICAL_LABEL_WIDTH    70U
#define G_SCREEN_VERTICAL_LABEL_HEIGHT   28U
#define G_SCREEN_HORIZONTAL_UNIT_X      952U
#define G_SCREEN_HORIZONTAL_UNIT_WIDTH   60U
#define G_SCREEN_VERTICAL_UNIT_X          0U
#define G_SCREEN_VERTICAL_UNIT_Y         16U
#define G_SCREEN_VERTICAL_UNIT_WIDTH     38U
#define G_SCREEN_VERTICAL_UNIT_HEIGHT    28U
#define G_GRAPH_FREQUENCY_CHANGE_HZ_X100 10000U
#define G_GRAPH_AMPLITUDE_CHANGE_UV        500U
#define G_GRAPH_PHASE_CHANGE_MDEG          5000

static u32 absolute_difference_u32(u32 first_value,
                                   u32 second_value)
{
    return (first_value > second_value) ?
        (first_value - second_value) :
        (second_value - first_value);
}

static s32 wrap_phase_mdeg(s64 phase_mdeg)
{
    while (phase_mdeg > 180000LL) {
        phase_mdeg -= 360000LL;
    }
    while (phase_mdeg < -180000LL) {
        phase_mdeg += 360000LL;
    }
    return (s32)phase_mdeg;
}

static s32 component_relative_phase_mdeg(
    const AcmV2PeriodicResult *result,
    u32 component_index)
{
    u32 fundamental_hz_x100 =
        result->component[0].frequency_hz_x100;
    u32 harmonic_order;
    s64 relative_phase;

    if ((component_index == 0U) ||
        (fundamental_hz_x100 == 0U)) {
        return 0;
    }
    harmonic_order =
        (result->component[component_index].frequency_hz_x100 +
         (fundamental_hz_x100 / 2U)) / fundamental_hz_x100;
    relative_phase =
        (s64)result->component[component_index].phase_mdeg -
        (s64)harmonic_order *
        (s64)result->component[0].phase_mdeg;
    return wrap_phase_mdeg(relative_phase);
}

static u32 phase_difference_mdeg(s32 first_phase,
                                 s32 second_phase)
{
    s32 difference =
        wrap_phase_mdeg((s64)first_phase - (s64)second_phase);

    return (u32)((difference < 0) ? -difference : difference);
}

u32 GDisplayGraph_HasResultChanged(
    const GDisplay *display,
    const AcmV2PeriodicResult *result)
{
    u32 component_index;

    if ((display->graph.previous_result_valid == 0U) ||
        (display->graph.previous_result.component_count !=
         result->component_count)) {
        return 1U;
    }

    for (component_index = 0U;
         component_index < result->component_count;
         component_index++) {
        if (absolute_difference_u32(
                display->graph.previous_result.component[component_index].
                    frequency_hz_x100,
                result->component[component_index].frequency_hz_x100) >=
            G_GRAPH_FREQUENCY_CHANGE_HZ_X100) {
            return 1U;
        }
        if (absolute_difference_u32(
                display->graph.previous_result.component[component_index].
                    peak_uv,
                result->component[component_index].peak_uv) >=
            G_GRAPH_AMPLITUDE_CHANGE_UV) {
            return 1U;
        }
        if (phase_difference_mdeg(
                component_relative_phase_mdeg(
                    &display->graph.previous_result,
                    component_index),
                component_relative_phase_mdeg(result,
                                               component_index)) >=
            G_GRAPH_PHASE_CHANGE_MDEG) {
            return 1U;
        }
    }
    return 0U;
}

static void format_axis_time(char *axis_label,
                             u32 label_length,
                             u64 time_us_x1000)
{
    u64 rounded_time;

    if (time_us_x1000 == 0ULL) {
        (void)snprintf(axis_label, label_length, "0");
    } else if (time_us_x1000 >= 100000ULL) {
        rounded_time = (time_us_x1000 + 500ULL) / 1000ULL;
        (void)snprintf(axis_label,
                       label_length,
                       "%llu",
                       rounded_time);
    } else if (time_us_x1000 >= 10000ULL) {
        rounded_time = (time_us_x1000 + 50ULL) / 100ULL;
        (void)snprintf(axis_label,
                       label_length,
                       "%llu.%llu",
                       rounded_time / 10ULL,
                       rounded_time % 10ULL);
    } else if (time_us_x1000 >= 1000ULL) {
        rounded_time = (time_us_x1000 + 5ULL) / 10ULL;
        (void)snprintf(axis_label,
                       label_length,
                       "%llu.%02llu",
                       rounded_time / 100ULL,
                       rounded_time % 100ULL);
    } else {
        (void)snprintf(axis_label,
                       label_length,
                       "%llu.%03llu",
                       time_us_x1000 / 1000ULL,
                       time_us_x1000 % 1000ULL);
    }
}

static void format_axis_voltage(char *axis_label,
                                u32 label_length,
                                s64 voltage_uv)
{
    const char *sign = "";
    u64 magnitude_uv;

    if (voltage_uv < 0) {
        sign = "-";
        magnitude_uv = (u64)(-voltage_uv);
    } else {
        magnitude_uv = (u64)voltage_uv;
    }
    if ((magnitude_uv % 1000ULL) == 0ULL) {
        (void)snprintf(axis_label,
                       label_length,
                       "%s%llu",
                       sign,
                       magnitude_uv / 1000ULL);
    } else {
        (void)snprintf(axis_label,
                       label_length,
                       "%s%llu.%llu",
                       sign,
                       magnitude_uv / 1000ULL,
                       (magnitude_uv % 1000ULL) / 100ULL);
    }
}

static int send_axis_label(GDisplay *display,
                           u32 x,
                           u32 y,
                           u32 width,
                           u32 height,
                           const char *axis_label)
{
    char command[96];

    (void)snprintf(command,
                   sizeof(command),
                   "xstr %u,%u,%u,%u,%u,%u,%u,1,1,1,\"%s\"",
                   (unsigned int)x,
                   (unsigned int)y,
                   (unsigned int)width,
                   (unsigned int)height,
                   (unsigned int)G_SCREEN_AXIS_FONT_ID,
                   (unsigned int)G_SCREEN_AXIS_TEXT_COLOR,
                   (unsigned int)G_SCREEN_AXIS_BACKGROUND,
                   axis_label);
    return SerialScreen_SendCommand(&display->screen, command);
}

static int draw_axis_units(GDisplay *display,
                           const char *horizontal_unit)
{
    if (send_axis_label(display,
                        G_SCREEN_HORIZONTAL_UNIT_X,
                        G_SCREEN_HORIZONTAL_LABEL_Y,
                        G_SCREEN_HORIZONTAL_UNIT_WIDTH,
                        G_SCREEN_HORIZONTAL_LABEL_HEIGHT,
                        horizontal_unit) != 0) {
        return -1;
    }
    return send_axis_label(display,
                           G_SCREEN_VERTICAL_UNIT_X,
                           G_SCREEN_VERTICAL_UNIT_Y,
                           G_SCREEN_VERTICAL_UNIT_WIDTH,
                           G_SCREEN_VERTICAL_UNIT_HEIGHT,
                           "mV");
}

static u32 horizontal_label_x(u32 division_index)
{
    return G_SCREEN_CURVE_X +
        (division_index * G_SCREEN_CURVE_WIDTH +
         (G_SCREEN_HORIZONTAL_DIVISIONS / 2U)) /
        G_SCREEN_HORIZONTAL_DIVISIONS -
        (G_SCREEN_HORIZONTAL_LABEL_WIDTH / 2U);
}

static u32 vertical_grid_y(u32 division_index)
{
    return G_SCREEN_VERTICAL_AXIS_TOP_Y +
        (division_index * G_SCREEN_VERTICAL_AXIS_SPAN +
         (G_SCREEN_VERTICAL_DIVISIONS / 2U)) /
        G_SCREEN_VERTICAL_DIVISIONS;
}

static int draw_spectrum_axes(GDisplay *display,
                              u32 harmonic_label_step,
                              u32 voltage_step_uv)
{
    char axis_label[20];
    u32 division_index;

    for (division_index = G_SCREEN_HORIZONTAL_LABEL_STRIDE;
         division_index <= G_SCREEN_HORIZONTAL_DIVISIONS;
         division_index += G_SCREEN_HORIZONTAL_LABEL_STRIDE) {
        u32 label_x = horizontal_label_x(division_index);

        (void)snprintf(axis_label,
                       sizeof(axis_label),
                       "%u",
                       (unsigned int)((division_index /
                           G_SCREEN_HORIZONTAL_LABEL_STRIDE) *
                           harmonic_label_step));
        if (send_axis_label(display,
                            label_x,
                            G_SCREEN_HORIZONTAL_LABEL_Y,
                            G_SCREEN_HORIZONTAL_LABEL_WIDTH,
                            G_SCREEN_HORIZONTAL_LABEL_HEIGHT,
                            axis_label) != 0) {
            return -1;
        }
    }
    for (division_index = 0U;
         division_index <= G_SCREEN_VERTICAL_DIVISIONS;
         division_index++) {
        u32 grid_center_y = vertical_grid_y(division_index);
        u32 label_y =
            (grid_center_y > (G_SCREEN_VERTICAL_LABEL_HEIGHT / 2U)) ?
            (grid_center_y - (G_SCREEN_VERTICAL_LABEL_HEIGHT / 2U)) :
            0U;
        u32 voltage_uv =
            (G_SCREEN_VERTICAL_DIVISIONS - division_index) *
            voltage_step_uv;

        format_axis_voltage(axis_label,
                            sizeof(axis_label),
                            (s64)voltage_uv);
        if (send_axis_label(display,
                            G_SCREEN_VERTICAL_LABEL_X,
                            label_y,
                            G_SCREEN_VERTICAL_LABEL_WIDTH,
                            G_SCREEN_VERTICAL_LABEL_HEIGHT,
                            axis_label) != 0) {
            return -1;
        }
    }
    return draw_axis_units(display, "n");
}

static int draw_waveform_axes(GDisplay *display,
                              u64 total_time_us_x1000,
                              u32 voltage_step_uv)
{
    char axis_label[20];
    u32 division_index;

    for (division_index = G_SCREEN_HORIZONTAL_LABEL_STRIDE;
         division_index <= G_SCREEN_HORIZONTAL_DIVISIONS;
         division_index += G_SCREEN_HORIZONTAL_LABEL_STRIDE) {
        u32 label_x = horizontal_label_x(division_index);
        u64 time_us_x1000 =
            (total_time_us_x1000 * (u64)division_index +
             (G_SCREEN_HORIZONTAL_DIVISIONS / 2U)) /
            G_SCREEN_HORIZONTAL_DIVISIONS;

        format_axis_time(axis_label,
                         sizeof(axis_label),
                         time_us_x1000);
        if (send_axis_label(display,
                            label_x,
                            G_SCREEN_HORIZONTAL_LABEL_Y,
                            G_SCREEN_HORIZONTAL_LABEL_WIDTH,
                            G_SCREEN_HORIZONTAL_LABEL_HEIGHT,
                            axis_label) != 0) {
            return -1;
        }
    }
    for (division_index = 0U;
         division_index <= G_SCREEN_VERTICAL_DIVISIONS;
         division_index++) {
        u32 grid_center_y = vertical_grid_y(division_index);
        u32 label_y =
            (grid_center_y > (G_SCREEN_VERTICAL_LABEL_HEIGHT / 2U)) ?
            (grid_center_y - (G_SCREEN_VERTICAL_LABEL_HEIGHT / 2U)) :
            0U;
        s64 voltage_uv =
            ((s64)G_SCREEN_VERTICAL_DIVISIONS -
             ((s64)division_index * 2LL)) *
            (s64)voltage_step_uv / 2LL;

        format_axis_voltage(axis_label,
                            sizeof(axis_label),
                            voltage_uv);
        if (send_axis_label(display,
                            G_SCREEN_VERTICAL_LABEL_X,
                            label_y,
                            G_SCREEN_VERTICAL_LABEL_WIDTH,
                            G_SCREEN_VERTICAL_LABEL_HEIGHT,
                            axis_label) != 0) {
            return -1;
        }
    }
    return draw_axis_units(display, "us");
}

static u32 axis_scale_changed(const GDisplay *display,
                              u64 horizontal_scale,
                              u32 voltage_step_uv)
{
    return ((display->graph.axis_valid == 0U) ||
            (display->graph.axis_view != display->view) ||
            (display->graph.horizontal_scale != horizontal_scale) ||
            (display->graph.voltage_step_uv != voltage_step_uv)) ?
        1U : 0U;
}

static void remember_axis_scale(GDisplay *display,
                                u64 horizontal_scale,
                                u32 voltage_step_uv)
{
    display->graph.axis_valid = 1U;
    display->graph.axis_view = display->view;
    display->graph.horizontal_scale = horizontal_scale;
    display->graph.voltage_step_uv = voltage_step_uv;
}

u32 GDisplayGraph_ComponentOrder(
    const AcmV2PeriodicResult *result,
    u32 component_index)
{
    u32 fundamental_hz_x100;

    if ((result == 0) ||
        (component_index >= result->component_count)) {
        return 0U;
    }
    fundamental_hz_x100 = result->fundamental_hz_x100;
    if (fundamental_hz_x100 == 0U) {
        fundamental_hz_x100 =
            result->component[0].frequency_hz_x100;
    }
    if (fundamental_hz_x100 == 0U) {
        return 0U;
    }
    return (result->component[component_index].frequency_hz_x100 +
            (fundamental_hz_x100 / 2U)) /
        fundamental_hz_x100;
}

static u32 nice_harmonic_label_step(u32 maximum_harmonic_order)
{
    u32 required_step =
        (maximum_harmonic_order + 8U) / 9U;
    u32 decade = 1U;

    if (required_step <= 1U) {
        return 1U;
    }
    while ((decade <= 100000000U) &&
           (required_step > (10U * decade))) {
        decade *= 10U;
    }
    if (required_step <= decade) {
        return decade;
    }
    if (required_step <= (2U * decade)) {
        return 2U * decade;
    }
    if (required_step <= (5U * decade)) {
        return 5U * decade;
    }
    return 10U * decade;
}

static int send_curve_command(GDisplay *display,
                              const char *command_format,
                              u32 first_value,
                              u32 second_value,
                              u32 third_value)
{
    char command[32];

    (void)snprintf(command,
                   sizeof(command),
                   command_format,
                   (unsigned int)first_value,
                   (unsigned int)second_value,
                   (unsigned int)third_value);
    return SerialScreen_SendCommand(&display->screen, command);
}

static int clear_curve(GDisplay *display)
{
    return send_curve_command(display,
                              "cle %u,%u",
                              G_SCREEN_CURVE_COMPONENT_ID,
                              G_SCREEN_CURVE_CHANNEL,
                              0U);
}

static int send_curve_data(GDisplay *display,
                           u8 *curve_data,
                           u32 point_count)
{
    u32 left_index;

    if ((curve_data == 0) || (point_count == 0U)) {
        return -1;
    }
    for (left_index = 0U;
         left_index < point_count / 2U;
         left_index++) {
        u32 right_index = point_count - 1U - left_index;
        u8 temporary_value = curve_data[left_index];

        curve_data[left_index] = curve_data[right_index];
        curve_data[right_index] = temporary_value;
    }
    if (clear_curve(display) != 0) {
        return -1;
    }
    return SerialScreen_SendCurveData(&display->screen,
                                      G_SCREEN_CURVE_COMPONENT_ID,
                                      G_SCREEN_CURVE_CHANNEL,
                                      curve_data,
                                      point_count);
}

int GDisplayGraph_DrawWaveform(
    GDisplay *display,
    const AcmV2PeriodicResult *result,
    u32 cycle_count)
{
    s32 maximum_absolute_uv = 1;
    u32 voltage_step_uv;
    u32 voltage_span_uv;
    u64 total_time_us_x1000;
    u32 sample_index;
    int draw_status;

    if (AcmV2Periodic_BuildWaveform(result,
                                    cycle_count,
                                    display->graph.waveform_uv,
                                    G_DISPLAY_CURVE_POINTS) != 0) {
        return -1;
    }
    if (result->fundamental_hz_x100 == 0U) {
        return -1;
    }
    total_time_us_x1000 =
        ((u64)cycle_count * 100000000000ULL) /
        (u64)result->fundamental_hz_x100;
    for (sample_index = 0U;
         sample_index < G_DISPLAY_CURVE_POINTS;
         sample_index++) {
        s32 sample_uv = display->graph.waveform_uv[sample_index];
        s32 absolute_uv =
            (sample_uv < 0) ? -sample_uv : sample_uv;

        if (absolute_uv > maximum_absolute_uv) {
            maximum_absolute_uv = absolute_uv;
        }
    }
    voltage_step_uv =
        (u32)(((u64)(u32)maximum_absolute_uv *
               (u64)G_SCREEN_VERTICAL_AXIS_SPAN +
               ((u64)G_SCREEN_VERTICAL_DIVISIONS *
                (u64)G_SCREEN_WAVEFORM_POSITIVE_CAPACITY * 1000ULL) - 1ULL) /
              ((u64)G_SCREEN_VERTICAL_DIVISIONS *
               (u64)G_SCREEN_WAVEFORM_POSITIVE_CAPACITY * 1000ULL)) * 1000U;
    if (voltage_step_uv == 0U) {
        voltage_step_uv = 1000U;
    }
    voltage_span_uv =
        G_SCREEN_VERTICAL_DIVISIONS * voltage_step_uv;
    for (sample_index = 0U;
         sample_index < G_DISPLAY_CURVE_POINTS;
         sample_index++) {
        s64 shifted_uv =
            (s64)display->graph.waveform_uv[sample_index] +
            ((s64)voltage_span_uv / 2LL);
        s32 curve_value = (s32)(
            (shifted_uv * (s64)G_SCREEN_VERTICAL_AXIS_SPAN +
             ((s64)voltage_span_uv / 2LL)) /
            (s64)voltage_span_uv);

        if (curve_value < 0) {
            curve_value = 0;
        }
        if (curve_value > (s32)G_SCREEN_CURVE_VALUE_MAX) {
            curve_value = (s32)G_SCREEN_CURVE_VALUE_MAX;
        }
        display->graph.curve_data[sample_index] = (u8)curve_value;
    }
    draw_status = send_curve_data(display,
                                  display->graph.curve_data,
                                  G_DISPLAY_CURVE_POINTS);
    if (draw_status != 0) {
        return draw_status;
    }
    if (axis_scale_changed(display,
                           total_time_us_x1000,
                           voltage_step_uv) == 0U) {
        return 0;
    }
    draw_status = draw_waveform_axes(display,
                                     total_time_us_x1000,
                                     voltage_step_uv);
    if (draw_status == 0) {
        remember_axis_scale(display,
                            total_time_us_x1000,
                            voltage_step_uv);
    }
    return draw_status;
}

int GDisplayGraph_DrawSpectrum(
    GDisplay *display,
    const AcmV2PeriodicResult *result)
{
    u32 maximum_harmonic_order = 1U;
    u32 maximum_peak_uv = 1U;
    u32 harmonic_label_step;
    u32 harmonic_axis_limit;
    u32 voltage_step_uv;
    u32 voltage_axis_limit_uv;
    u32 component_index;
    int draw_status;

    for (component_index = 0U;
         component_index < G_DISPLAY_CURVE_POINTS;
         component_index++) {
        display->graph.curve_data[component_index] = 0U;
    }
    for (component_index = 0U;
         component_index < result->component_count;
         component_index++) {
        u32 harmonic_order =
            GDisplayGraph_ComponentOrder(result, component_index);

        if (harmonic_order > maximum_harmonic_order) {
            maximum_harmonic_order = harmonic_order;
        }
        if (result->component[component_index].peak_uv >
            maximum_peak_uv) {
            maximum_peak_uv =
                result->component[component_index].peak_uv;
        }
    }
    harmonic_label_step =
        nice_harmonic_label_step(maximum_harmonic_order);
    harmonic_axis_limit =
        (G_SCREEN_HORIZONTAL_DIVISIONS /
         G_SCREEN_HORIZONTAL_LABEL_STRIDE) *
        harmonic_label_step;
    voltage_step_uv =
        (u32)(((u64)maximum_peak_uv *
               (u64)G_SCREEN_VERTICAL_AXIS_SPAN +
               ((u64)G_SCREEN_VERTICAL_DIVISIONS *
                (u64)G_SCREEN_CURVE_VALUE_MAX * 1000ULL) - 1ULL) /
              ((u64)G_SCREEN_VERTICAL_DIVISIONS *
               (u64)G_SCREEN_CURVE_VALUE_MAX * 1000ULL) * 1000ULL);
    if (voltage_step_uv == 0U) {
        voltage_step_uv = 1000U;
    }
    voltage_axis_limit_uv =
        G_SCREEN_VERTICAL_DIVISIONS * voltage_step_uv;
    for (component_index = 0U;
         component_index < result->component_count;
         component_index++) {
        u32 harmonic_order =
            GDisplayGraph_ComponentOrder(result, component_index);
        u32 curve_index =
            (u32)(((u64)harmonic_order *
                   (u64)(G_DISPLAY_CURVE_POINTS - 1U)) /
                  harmonic_axis_limit);
        u32 curve_value =
            (u32)(((u64)result->component[component_index].peak_uv *
                   (u64)G_SCREEN_VERTICAL_AXIS_SPAN +
                   ((u64)voltage_axis_limit_uv / 2ULL)) /
                  (u64)voltage_axis_limit_uv);
        u32 left_index =
            (curve_index > 1U) ? (curve_index - 1U) : curve_index;
        u32 right_index =
            (curve_index + 1U < G_DISPLAY_CURVE_POINTS) ?
            (curve_index + 1U) : curve_index;

        if (curve_value > G_SCREEN_CURVE_VALUE_MAX) {
            curve_value = G_SCREEN_CURVE_VALUE_MAX;
        }
        display->graph.curve_data[left_index] = (u8)curve_value;
        display->graph.curve_data[curve_index] = (u8)curve_value;
        display->graph.curve_data[right_index] = (u8)curve_value;
        if (left_index > 0U) {
            display->graph.curve_data[left_index - 1U] = 0U;
        }
        if (right_index + 1U < G_DISPLAY_CURVE_POINTS) {
            display->graph.curve_data[right_index + 1U] = 0U;
        }
    }
    draw_status = send_curve_data(display,
                                  display->graph.curve_data,
                                  G_DISPLAY_CURVE_POINTS);
    if (draw_status != 0) {
        return draw_status;
    }
    if (axis_scale_changed(display,
                           (u64)harmonic_label_step,
                           voltage_step_uv) == 0U) {
        return 0;
    }
    draw_status = draw_spectrum_axes(display,
                                     harmonic_label_step,
                                     voltage_step_uv);
    if (draw_status == 0) {
        remember_axis_scale(display,
                            (u64)harmonic_label_step,
                            voltage_step_uv);
    }
    return draw_status;
}

void GDisplayGraph_Reset(GDisplay *display)
{
    if (display == 0) {
        return;
    }
    display->graph.previous_result_valid = 0U;
    display->graph.axis_valid = 0U;
}

void GDisplayGraph_InvalidateAxis(GDisplay *display)
{
    if (display != 0) {
        display->graph.axis_valid = 0U;
    }
}
