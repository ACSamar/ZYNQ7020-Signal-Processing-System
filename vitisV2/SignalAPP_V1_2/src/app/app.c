#include "app.h"
#include "g_display.h"
#include "g_measurement_config.h"

#include "board.h"
#include "driver.h"
#include "periodic_signal_analyzer.h"
#include "uart_io.h"

#include "sleep.h"
#include "xil_printf.h"
#include "xiltimer.h"

#include <string.h>

typedef struct {
    u32 minimum_code;
    u32 maximum_code;
    u32 mean_code_x1000;
    u32 clipped;
} AdcCaptureStatistics;

typedef struct {
    char text[32];
    u32 length;
} SerialCommandParser;

static Console g_console;
static GDisplay g_display;
static SerialCommandParser g_console_command_parser;
static SerialCommandParser g_screen_command_parser;
static AcmV2PeriodicConfig g_analyzer_config;
static AcmV2PeriodicResult g_analyzer_candidate;
static AcmV2PeriodicResult g_stable_result;
static AcmV2PeriodicTracker g_result_tracker;
static GAmplitudeGainMode g_amplitude_gain_mode;
static GQuestionMode g_question_mode;
static u32 g_last_measurement_held;
static u32 g_adc_capture_words[G_CAPTURE_WORDS]
    __attribute__((aligned(G_CAPTURE_ALIGNMENT_BYTES)));

static u32 unpack_input_sample(u32 packed_word)
{
    if (G_INPUT_CHANNEL == 0U) {
        return packed_word & 0xFFU;
    }
    return (packed_word >> 16) & 0xFFU;
}

static void calculate_capture_statistics(
    AdcCaptureStatistics *statistics)
{
    u64 sum = 0ULL;
    u32 index;

    statistics->minimum_code = 255U;
    statistics->maximum_code = 0U;
    statistics->mean_code_x1000 = 0U;
    statistics->clipped = 0U;

    for (index = 0U; index < G_CAPTURE_WORDS; index++) {
        u32 sample = unpack_input_sample(g_adc_capture_words[index]);

        if (sample < statistics->minimum_code) {
            statistics->minimum_code = sample;
        }
        if (sample > statistics->maximum_code) {
            statistics->maximum_code = sample;
        }
        if ((sample <= 1U) || (sample >= 254U)) {
            statistics->clipped = 1U;
        }
        sum += sample;
    }
    statistics->mean_code_x1000 =
        (u32)((sum * 1000ULL) / (u64)G_CAPTURE_WORDS);
}

static u32 elapsed_microseconds(XTime start, XTime end)
{
    if (end < start) {
        return 0U;
    }

    u64 counts = (u64)(end - start);
    u64 microseconds =
        (counts * 1000000ULL) / (u64)COUNTS_PER_SECOND;

    if (microseconds > 0xFFFFFFFFULL) {
        return 0xFFFFFFFFU;
    }
    return (u32)microseconds;
}

static void print_frequency_khz(u32 frequency_hz_x100)
{
    xil_printf("%u.%03u",
               (unsigned int)(frequency_hz_x100 / 100000U),
               (unsigned int)((frequency_hz_x100 % 100000U) / 100U));
}

static void print_voltage_mv(u32 voltage_uv)
{
    xil_printf("%u.%03u",
               (unsigned int)(voltage_uv / 1000U),
               (unsigned int)(voltage_uv % 1000U));
}

static void print_thd_percent(u32 thd_ppm)
{
    xil_printf("%u.%04u",
               (unsigned int)(thd_ppm / 10000U),
               (unsigned int)(thd_ppm % 10000U));
}

static void print_ui_help(void)
{
    xil_printf("UI MODE Q1 | MODE Q2 | MODE Q3 | "
               "PARAM | WAVE1 | WAVE3 | WAVE5 | SPECTRUM | "
               "GAIN 20.4 | GAIN 10.4\r\n");
}

static void apply_amplitude_gain_mode(GAmplitudeGainMode mode,
                                      u32 announce)
{
    u32 gain_x10 = GAmplitudeCalibration_GainX10(mode);
    u32 dac0_code = GAmplitudeCalibration_Dac0Code(mode);

    Board_SetDac0Constant(dac0_code);
    g_amplitude_gain_mode = mode;
    g_analyzer_config.microvolts_per_code =
        GAmplitudeCalibration_MicrovoltsPerCode(mode);
    AcmV2PeriodicTracker_Init(&g_result_tracker);
    memset(&g_analyzer_candidate, 0, sizeof(g_analyzer_candidate));
    memset(&g_stable_result, 0, sizeof(g_stable_result));
    g_last_measurement_held = 0U;
    (void)GDisplay_SetView(&g_display, g_display.view);

    if (announce != 0U) {
        xil_printf("GAIN dac0_code=%u gain=%u.%ux cal=%uuV/code\r\n",
                   (unsigned int)dac0_code,
                   (unsigned int)(gain_x10 / 10U),
                   (unsigned int)(gain_x10 % 10U),
                   (unsigned int)
                       g_analyzer_config.microvolts_per_code);
        GDisplay_ShowLock(&g_display,
                          0U,
                          ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES);
    }
}

static int apply_question_mode(GQuestionMode question, u32 announce)
{
    GAmplitudeGainMode gain_mode;
    u32 gain_x10;

    if (GQuestionMode_IsValid(question) == 0U) {
        return -1;
    }

    gain_mode = GQuestionMode_GainMode(question);
    apply_amplitude_gain_mode(gain_mode, 0U);
    g_question_mode = question;
    if (GDisplay_SetQuestion(&g_display, question) != 0) {
        return -2;
    }
    GDisplay_ShowLock(&g_display,
                      0U,
                      ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES);

    if (announce != 0U) {
        gain_x10 = GAmplitudeCalibration_GainX10(gain_mode);
        xil_printf("MODE question=%s page=%s dac0_code=%u gain=%u.%ux "
                   "cal=%uuV/code spectrum=auto\r\n",
                   GQuestionMode_Name(question),
                   GQuestionMode_PageName(question),
                   (unsigned int)
                       GAmplitudeCalibration_Dac0Code(gain_mode),
                   (unsigned int)(gain_x10 / 10U),
                   (unsigned int)(gain_x10 % 10U),
                   (unsigned int)
                       g_analyzer_config.microvolts_per_code);
    }
    return 0;
}

static int apply_ui_command(const char *command)
{
    GAmplitudeGainMode gain_mode;
    GQuestionMode question;
    GDisplayView view;

    if (GQuestionMode_ParseCommand(command, &question) == 0) {
        return apply_question_mode(question, 1U);
    }
    if (GAmplitudeCalibration_ParseGainCommand(
            command, &gain_mode) == 0) {
        apply_amplitude_gain_mode(gain_mode, 1U);
        return 0;
    }
    if ((strcmp(command, "PARAM") == 0) ||
        (strcmp(command, "VIEW PARAM") == 0)) {
        view = G_DISPLAY_PARAMETERS;
    } else if ((strcmp(command, "WAVE1") == 0) ||
               (strcmp(command, "VIEW WAVE1") == 0)) {
        view = G_DISPLAY_WAVEFORM_1;
    } else if ((strcmp(command, "WAVE3") == 0) ||
               (strcmp(command, "VIEW WAVE3") == 0)) {
        view = G_DISPLAY_WAVEFORM_3;
    } else if ((strcmp(command, "WAVE5") == 0) ||
               (strcmp(command, "VIEW WAVE5") == 0)) {
        view = G_DISPLAY_WAVEFORM_5;
    } else if ((strcmp(command, "SPECTRUM") == 0) ||
               (strcmp(command, "VIEW SPECTRUM") == 0)) {
        view = G_DISPLAY_SPECTRUM;
    } else if (strcmp(command, "HELP") == 0) {
        print_ui_help();
        return 0;
    } else {
        return -1;
    }

    if (GDisplay_SetView(&g_display, view) != 0) {
        return -2;
    }
    if (g_stable_result.valid != 0U) {
        (void)GDisplay_Update(&g_display,
                              &g_stable_result,
                              g_last_measurement_held);
    }
    xil_printf("UI view=%s\r\n", GDisplay_ViewName(view));
    return 0;
}

static void push_ui_byte(SerialCommandParser *parser, u8 byte)
{
    if ((byte == '\r') || (byte == '\n') || (byte == 0xFFU)) {
        if (parser->length != 0U) {
            parser->text[parser->length] = '\0';
            if (apply_ui_command(parser->text) != 0) {
                xil_printf("E ui command=%s\r\n", parser->text);
            }
            parser->length = 0U;
        }
        return;
    }
    if ((byte < 0x20U) || (byte > 0x7EU)) {
        return;
    }
    if ((byte >= (u8)'a') && (byte <= (u8)'z')) {
        byte = (u8)(byte - ((u8)'a' - (u8)'A'));
    }
    if (parser->length >= (sizeof(parser->text) - 1U)) {
        parser->length = 0U;
        return;
    }
    parser->text[parser->length++] = (char)byte;
}

static void poll_ui_commands(void)
{
    u8 byte;
    int status;

    while ((status = Console_TryReadByte(&g_console, &byte)) > 0) {
        push_ui_byte(&g_console_command_parser, byte);
    }
    if (status < 0) {
        xil_printf("E console s%d\r\n", status);
    }

    while ((status = SerialScreen_TryReadByte(&g_display.screen,
                                               &byte)) > 0) {
        push_ui_byte(&g_screen_command_parser, byte);
    }
    if (status < 0) {
        xil_printf("E screen s%d\r\n", status);
    }
}

static void print_result(int analysis_status,
                         const AdcCaptureStatistics *statistics,
                         u32 measurement_held,
                         u32 elapsed_us)
{
    u32 index;

    xil_printf("M s%d v%u c%u h%u raw%u@%u.%03u n%u f",
                analysis_status,
                (unsigned int)g_stable_result.valid,
                (unsigned int)(statistics->clipped |
                               g_stable_result.clipped),
                (unsigned int)measurement_held,
                (unsigned int)(statistics->maximum_code -
                               statistics->minimum_code),
                (unsigned int)(statistics->mean_code_x1000 / 1000U),
                (unsigned int)(statistics->mean_code_x1000 % 1000U),
                (unsigned int)g_stable_result.component_count);

    for (index = 0U;
         index < g_stable_result.component_count;
         index++) {
        xil_printf((index == 0U) ? " " : ",");
        print_frequency_khz(
            g_stable_result.component[index].frequency_hz_x100);
    }
    xil_printf("k a");
    for (index = 0U;
         index < g_stable_result.component_count;
         index++) {
        xil_printf((index == 0U) ? " " : ",");
        print_voltage_mv(g_stable_result.component[index].peak_uv);
    }
    xil_printf("m pp");
    print_voltage_mv(g_stable_result.peak_to_peak_uv);
    xil_printf(" rms");
    print_voltage_mv(g_stable_result.true_rms_uv);
    xil_printf(" thd");
    print_thd_percent(g_stable_result.thd_ppm);
    xil_printf("%%");
    xil_printf(" t%ums\r\n", (unsigned int)(elapsed_us / 1000U));
}

int App_Init(void)
{
    XTime timer_warmup;
    int status;

    status = Console_Init(&g_console);
    if (status != 0) {
        return status;
    }
    status = Driver_Init(G_CAPTURE_WORDS);
    if (status != 0) {
        return status;
    }
    status = GDisplay_Init(&g_display);
    if (status != 0) {
        return status;
    }

    Board_SetDacEnable(0U, 0U);
    XTime_GetTime(&timer_warmup);
    (void)timer_warmup;
    AcmV2Periodic_DefaultConfig(&g_analyzer_config);
    g_analyzer_config.sample_rate_hz = ADC_CLK_HZ;
    g_analyzer_config.channel = G_INPUT_CHANNEL;
    g_analyzer_config.minimum_component_uv =
        G_MINIMUM_COMPONENT_UV;
    g_question_mode = G_QUESTION_1;
    apply_amplitude_gain_mode(
        G_DEFAULT_AMPLITUDE_GAIN_MODE, 0U);
    g_console_command_parser.length = 0U;
    g_screen_command_parser.length = 0U;
    g_last_measurement_held = 0U;

    xil_printf("\r\n=== ACM2108V2 G Analyzer ===\r\n");
    xil_printf("CFG ADC%u raw=%uHz fs=%uHz fft=%u d=%u gain=%u.%ux "
               "cal=%uuV/code\r\n",
               (unsigned int)G_INPUT_CHANNEL,
               (unsigned int)ADC_CLK_HZ,
               (unsigned int)(ADC_CLK_HZ /
                              ACMV2_PERIODIC_DECIMATION),
               (unsigned int)ACMV2_PERIODIC_FFT_SIZE,
               (unsigned int)ACMV2_PERIODIC_DECIMATION,
               (unsigned int)
                   (GAmplitudeCalibration_GainX10(
                       g_amplitude_gain_mode) / 10U),
               (unsigned int)
                   (GAmplitudeCalibration_GainX10(
                       g_amplitude_gain_mode) % 10U),
               (unsigned int)
                   g_analyzer_config.microvolts_per_code);
    xil_printf("SCREEN UARTLite=42C00000 P14/P15 115200 8N1\r\n");
    xil_printf("MODE question=%s page=%s gain=20.4x "
               "dac0_code=%u default\r\n",
               GQuestionMode_Name(g_question_mode),
               GQuestionMode_PageName(g_question_mode),
               (unsigned int)
                   GAmplitudeCalibration_Dac0Code(
                       g_amplitude_gain_mode));
    print_ui_help();
    return 0;
}

void App_Run(void)
{
    while (1) {
        DriverCaptureInfo capture_info;
        AdcCaptureStatistics capture_statistics;
        XTime analysis_start_time;
        XTime analysis_end_time;
        u32 measurement_held;
        int analysis_status;
        int result_tracker_status;

        poll_ui_commands();
        XTime_GetTime(&analysis_start_time);
        analysis_status = Driver_CaptureAdc(g_adc_capture_words,
                                            G_CAPTURE_WORDS,
                                            G_CAPTURE_TIMEOUT,
                                            &capture_info);
        if (analysis_status != 0) {
            XTime_GetTime(&analysis_end_time);
            xil_printf("E adc s%d first=%08x last=%08x t%ums\r\n",
                       analysis_status,
                       (unsigned int)capture_info.first_word,
                       (unsigned int)capture_info.last_word,
                       (unsigned int)(elapsed_microseconds(
                                          analysis_start_time,
                                          analysis_end_time) /
                                      1000U));
            GDisplay_ShowError(&g_display, "ADC ERROR");
            usleep(G_RESULT_HOLD_US);
            continue;
        }

        calculate_capture_statistics(&capture_statistics);
        analysis_status = AcmV2Periodic_AnalyzePacked(
            g_adc_capture_words,
            G_CAPTURE_WORDS,
            &g_analyzer_config,
            &g_analyzer_candidate);
        if ((analysis_status == 0) &&
            (g_analyzer_candidate.valid != 0U)) {
            g_analyzer_candidate.true_rms_uv =
                GAmplitudeCalibration_CorrectTrueRms(
                    g_analyzer_candidate.true_rms_uv);
        }
        result_tracker_status = AcmV2PeriodicTracker_Update(
            &g_result_tracker,
            &g_analyzer_candidate,
            &g_stable_result,
            &measurement_held);
        XTime_GetTime(&analysis_end_time);
        if (result_tracker_status > 0) {
            g_last_measurement_held = measurement_held;
            print_result(analysis_status,
                         &capture_statistics,
                         measurement_held,
                         elapsed_microseconds(analysis_start_time,
                                              analysis_end_time));
            (void)GDisplay_Update(&g_display,
                                  &g_stable_result,
                                  measurement_held);
        } else {
            xil_printf("Q lock %u/%u\r\n",
                       (unsigned int)g_result_tracker.pending_count,
                       (unsigned int)
                           ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES);
            GDisplay_ShowLock(&g_display,
                              g_result_tracker.pending_count,
                              ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES);
        }
        usleep(G_RESULT_HOLD_US);
    }
}
