#include "../src/app/g_measurement_config.h"

#include <assert.h>
#include <stddef.h>
#include <stdio.h>

#define CAPTURE_LOG_CAL_UV_PER_CODE 5243U
#define MAXIMUM_COMPONENT_ERROR_UV  5000U
#define PREVIOUS_10P4X_CAL_UV_PER_CODE 4178U

static u32 absolute_difference(u32 left, u32 right)
{
    return (left > right) ? (left - right) : (right - left);
}

static u32 recalibrate_logged_uv(u32 logged_uv,
                                 GAmplitudeGainMode mode)
{
    u64 numerator =
        (u64)logged_uv *
        (u64)GAmplitudeCalibration_MicrovoltsPerCode(mode);

    return (u32)((numerator +
                  (CAPTURE_LOG_CAL_UV_PER_CODE / 2U)) /
                 CAPTURE_LOG_CAL_UV_PER_CODE);
}

static void verify_components(GAmplitudeGainMode mode,
                              const u32 *logged_uv,
                              const u32 *expected_peak_uv,
                              size_t count)
{
    size_t index;

    for (index = 0U; index < count; index++) {
        assert(absolute_difference(
                   recalibrate_logged_uv(logged_uv[index], mode),
                   expected_peak_uv[index]) <=
               MAXIMUM_COMPONENT_ERROR_UV);
    }
}

static void verify_clean_rms(u32 logged_rms_uv,
                       u32 expected_rms_uv)
{
    u32 amplitude_corrected_uv = recalibrate_logged_uv(
        logged_rms_uv, G_AMPLITUDE_GAIN_20P4X);

    assert(absolute_difference(
               GAmplitudeCalibration_CorrectTrueRms(
                   amplitude_corrected_uv),
               expected_rms_uv) <= MAXIMUM_COMPONENT_ERROR_UV);
}

static u32 correct_previous_q3_measurement(u32 measured_uv)
{
    u64 numerator =
        (u64)measured_uv *
        (u64)G_AMPLITUDE_CAL_10P4X_UV_PER_CODE;

    return (u32)((numerator +
                  (PREVIOUS_10P4X_CAL_UV_PER_CODE / 2U)) /
                 PREVIOUS_10P4X_CAL_UV_PER_CODE);
}

int main(void)
{
    GAmplitudeGainMode parsed_mode;
    static const u32 high_30k_logged_uv[3] = {
        69600U, 13850U, 27647U
    };
    static const u32 high_30k_expected_uv[3] = {
        25000U, 5000U, 10000U
    };
    static const u32 high_40k_logged_uv[3] = {
        297300U, 87221U, 69468U
    };
    static const u32 high_40k_expected_uv[3] = {
        107500U, 31600U, 25300U
    };

    assert(GAmplitudeCalibration_MicrovoltsPerCode(
               G_AMPLITUDE_GAIN_20P4X) ==
           G_AMPLITUDE_CAL_20P4X_UV_PER_CODE);
    assert(GAmplitudeCalibration_MicrovoltsPerCode(
               G_AMPLITUDE_GAIN_10P4X) ==
           G_AMPLITUDE_CAL_10P4X_UV_PER_CODE);
    assert(G_AMPLITUDE_CAL_20P4X_UV_PER_CODE == 1896U);
    assert(G_AMPLITUDE_CAL_10P4X_UV_PER_CODE == 3785U);
    assert(G_TRUE_RMS_CLEAN_SCALE_PPM == 1001380U);
    assert(G_MINIMUM_COMPONENT_UV == 2000U);
    assert(GAmplitudeCalibration_GainX10(
               G_AMPLITUDE_GAIN_20P4X) == 204U);
    assert(GAmplitudeCalibration_GainX10(
               G_AMPLITUDE_GAIN_10P4X) == 104U);
    assert(GAmplitudeCalibration_Dac0Code(
               G_AMPLITUDE_GAIN_20P4X) ==
           G_AMPLITUDE_DAC0_ZERO_CODE);
    assert(GAmplitudeCalibration_Dac0Code(
               G_AMPLITUDE_GAIN_10P4X) ==
           G_AMPLITUDE_DAC0_HIGH_CODE);
    assert(G_AMPLITUDE_DAC0_ZERO_CODE == 128U);
    assert(G_AMPLITUDE_DAC0_HIGH_CODE == 255U);

    assert(GAmplitudeCalibration_ParseGainCommand(
               "GAIN 20.4", &parsed_mode) == 0);
    assert(parsed_mode == G_AMPLITUDE_GAIN_20P4X);
    assert(GAmplitudeCalibration_ParseGainCommand(
               "GAIN 20.4X", &parsed_mode) == 0);
    assert(parsed_mode == G_AMPLITUDE_GAIN_20P4X);
    assert(GAmplitudeCalibration_ParseGainCommand(
               "GAIN 20.8", &parsed_mode) == 0);
    assert(parsed_mode == G_AMPLITUDE_GAIN_20P4X);
    assert(GAmplitudeCalibration_ParseGainCommand(
               "GAIN 10.4", &parsed_mode) == 0);
    assert(parsed_mode == G_AMPLITUDE_GAIN_10P4X);
    assert(GAmplitudeCalibration_ParseGainCommand(
               "GAIN 10.4X", &parsed_mode) == 0);
    assert(parsed_mode == G_AMPLITUDE_GAIN_10P4X);
    assert(GAmplitudeCalibration_ParseGainCommand(
               "GAIN 12.0", &parsed_mode) != 0);
    assert(GAmplitudeCalibration_ParseGainCommand(
               NULL, &parsed_mode) != 0);

    verify_components(G_AMPLITUDE_GAIN_20P4X,
                      high_30k_logged_uv,
                      high_30k_expected_uv,
                      3U);
    verify_components(G_AMPLITUDE_GAIN_20P4X,
                      high_40k_logged_uv,
                      high_40k_expected_uv,
                      3U);

    /* RMS fit uses only the 30 kHz and 40 kHz clean recordings. */
    verify_clean_rms(53770U, 19365U);
    verify_clean_rms(224174U, 81225U);

    assert(absolute_difference(
               correct_previous_q3_measurement(55650U),
               50411U) <= 20U);
    assert(absolute_difference(
               correct_previous_q3_measurement(40783U),
               36960U) <= 20U);

    puts("g_amplitude_calibration tests passed");
    return 0;
}
