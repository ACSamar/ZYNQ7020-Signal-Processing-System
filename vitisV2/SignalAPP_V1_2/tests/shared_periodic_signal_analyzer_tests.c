#include "periodic_signal_analyzer.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define TEST_PI 3.14159265358979323846

static u32 g_input[ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U];
static s32 g_waveform[641U];

static u32 absolute_difference(u32 left, u32 right)
{
    return (left > right) ? (left - right) : (right - left);
}

static u32 expected_thd_ppm(const AcmV2PeriodicResult *result)
{
    double harmonic_square_sum = 0.0;
    u32 component;

    if ((result->component_count == 0U) ||
        (result->component[0].peak_uv == 0U)) {
        return 0U;
    }

    for (component = 1U;
         component < result->component_count;
         component++) {
        double harmonic_peak_uv =
            (double)result->component[component].peak_uv;

        harmonic_square_sum +=
            harmonic_peak_uv * harmonic_peak_uv;
    }

    return (u32)floor(
        (1000000.0 * sqrt(harmonic_square_sum) /
         (double)result->component[0].peak_uv) +
        0.5);
}

static u32 pack_sample(int adc0, int adc1)
{
    if (adc0 < 0) {
        adc0 = 0;
    }
    if (adc0 > 255) {
        adc0 = 255;
    }
    if (adc1 < 0) {
        adc1 = 0;
    }
    if (adc1 > 255) {
        adc1 = 255;
    }
    return (u32)adc0 | ((u32)adc1 << 16);
}

static void generate_three_tone(u32 sample_rate_hz,
                                double fundamental_hz,
                                double amplitude0_codes,
                                double amplitude1_codes,
                                double amplitude2_codes,
                                double interferer_hz,
                                double interferer_codes)
{
    u32 index;

    for (index = 0U;
         index < ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U;
         index++) {
        double time = (double)index / (double)sample_rate_hz;
        double signal =
            amplitude0_codes * sin(2.0 * TEST_PI * fundamental_hz * time) +
            amplitude1_codes * sin(2.0 * TEST_PI *
                                   (3.0 * fundamental_hz) * time) +
            amplitude2_codes * sin(2.0 * TEST_PI *
                                   (4.0 * fundamental_hz) * time) +
            interferer_codes * sin(2.0 * TEST_PI * interferer_hz * time);
        int adc0 = (int)floor(128.0 + signal + 0.5);

        g_input[index] = pack_sample(adc0, 128);
    }
}

static void generate_g_problem_interference_case(void)
{
    u32 index;

    for (index = 0U;
         index < ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U;
         index++) {
        double time = (double)index / 35000000.0;
        double signal =
            30.0 * sin(2.0 * TEST_PI * 100000.0 * time) +
            15.0 * sin(2.0 * TEST_PI * 200000.0 * time) +
             8.0 * sin(2.0 * TEST_PI * 500000.0 * time) +
            50.0 * sin(2.0 * TEST_PI * 1000000.0 * time);
        int adc0 = (int)floor(128.0 + signal + 0.5);

        g_input[index] = pack_sample(adc0, 128);
    }
}

static void generate_high_harmonic_case(void)
{
    u32 index;

    for (index = 0U;
         index < ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U;
         index++) {
        double time = (double)index / 35000000.0;
        double signal =
            30.0 * sin(2.0 * TEST_PI * 5000.0 * time) +
            12.0 * sin(2.0 * TEST_PI * 250000.0 * time) +
             8.0 * sin(2.0 * TEST_PI * 800000.0 * time);
        int adc0 = (int)floor(128.0 + signal + 0.5);

        g_input[index] = pack_sample(adc0, 128);
    }
}

static void test_g_problem_interference_rejection(void)
{
    static const u32 expected_frequency_hz[3] = {
        100000U, 200000U, 500000U
    };
    static const u32 expected_peak_uv[3] = {
        60000U, 30000U, 16000U
    };
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;
    u32 index;

    generate_g_problem_interference_case();
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 2000U;
    config.minimum_component_uv = 3000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.valid == 1U);
    assert(result.component_count == 3U);

    for (index = 0U; index < 3U; index++) {
        assert(absolute_difference(
                   result.component[index].frequency_hz_x100,
                   expected_frequency_hz[index] * 100U) <= 100000U);
        assert(absolute_difference(result.component[index].peak_uv,
                                   expected_peak_uv[index]) <= 5000U);
    }
}

static void test_measurement_with_interference(void)
{
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;
    const u32 uv_per_code = 2000U;
    const u32 expected_frequency_hz[3] = {120000U, 360000U, 480000U};
    const u32 expected_peak_uv[3] = {60000U, 24000U, 16000U};
    const u32 expected_rms_uv = 47032U;
    u32 index;

    generate_three_tone(35000000U,
                        120000.0,
                        30.0,
                        12.0,
                        8.0,
                        1050000.0,
                        50.0);
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = uv_per_code;
    config.minimum_component_uv = 6000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.valid == 1U);
    assert(result.clipped == 0U);
    assert(result.analysis_sample_rate_hz == 5000000U);
    assert(result.fft_bin_width_hz_x100 == 30518U);
    assert(result.component_count == 3U);
    assert(absolute_difference(result.fundamental_hz_x100,
                               12000000U) <= 100000U);

    for (index = 0U; index < 3U; index++) {
        assert(absolute_difference(
                   result.component[index].frequency_hz_x100,
                   expected_frequency_hz[index] * 100U) <= 100000U);
        assert(absolute_difference(result.component[index].peak_uv,
                                   expected_peak_uv[index]) <= 5000U);
    }

    printf("measurement f0=%u vpp=%u rms=%u thd=%u "
           "peaks=%u,%u,%u\n",
           result.fundamental_hz_x100,
           result.peak_to_peak_uv,
           result.true_rms_uv,
           result.thd_ppm,
           result.component[0].peak_uv,
           result.component[1].peak_uv,
           result.component[2].peak_uv);
    assert(absolute_difference(result.true_rms_uv,
                               expected_rms_uv) <= 5000U);
    assert(result.peak_to_peak_uv >= 134000U);
    assert(result.peak_to_peak_uv <= 144000U);
    assert(absolute_difference(result.thd_ppm,
                               expected_thd_ppm(&result)) <= 1U);
    assert(absolute_difference(result.thd_ppm,
                               480740U) <= 50000U);
}

static void test_interferer_is_excluded_from_true_rms(void)
{
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult clean;
    AcmV2PeriodicResult interfered;

    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 2000U;
    config.minimum_component_uv = 6000U;

    generate_three_tone(35000000U,
                        120000.0,
                        30.0,
                        12.0,
                        8.0,
                        2000000.0,
                        0.0);
    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &clean) == 0);

    generate_three_tone(35000000U,
                        120000.0,
                        30.0,
                        12.0,
                        8.0,
                        2000000.0,
                        50.0);
    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &interfered) == 0);

    assert(clean.component_count == 3U);
    assert(interfered.component_count == 3U);
    assert(absolute_difference(clean.true_rms_uv,
                               interfered.true_rms_uv) <= 1000U);
    assert(absolute_difference(clean.thd_ppm,
                               interfered.thd_ppm) <= 10000U);
}

static void test_true_rms_uses_corrected_components(void)
{
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;
    u32 expected_rms_uv;

    /*
     * Set the reporting threshold above the 30 mV fourth harmonic. The RMS
     * must use only the accepted signal components, whose peak values have
     * already received their individual FIR response compensation.
     */
    generate_three_tone(35000000U,
                        100000.0,
                        30.0,
                        20.0,
                        15.0,
                        2000000.0,
                        0.0);
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 2000U;
    config.minimum_component_uv = 31000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.component_count == 2U);
    expected_rms_uv = (u32)floor(
        sqrt(0.5 *
             (((double)result.component[0].peak_uv *
               (double)result.component[0].peak_uv) +
              ((double)result.component[1].peak_uv *
               (double)result.component[1].peak_uv))) +
        0.5);
    assert(absolute_difference(result.true_rms_uv,
                               expected_rms_uv) <= 1U);
    assert(absolute_difference(result.thd_ppm,
                               expected_thd_ppm(&result)) <= 1U);
    assert(result.true_rms_uv < 53000U);
}

static void test_complete_cycle_waveforms(void)
{
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;

    generate_three_tone(35000000U,
                        10500.0,
                        40.0,
                        20.0,
                        10.0,
                        1200000.0,
                        35.0);
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 1000U;
    config.minimum_component_uv = 4000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.component_count == 3U);
    assert(absolute_difference(result.fundamental_hz_x100,
                               1050000U) <= 100000U);

    assert(AcmV2Periodic_BuildWaveform(&result,
                                      1U,
                                      g_waveform,
                                      641U) == 0);
    assert(abs(g_waveform[0] - g_waveform[640]) <= 2);
    assert(AcmV2Periodic_BuildWaveform(&result,
                                      3U,
                                      g_waveform,
                                      641U) == 0);
    assert(abs(g_waveform[0] - g_waveform[640]) <= 2);
    assert(AcmV2Periodic_BuildWaveform(&result,
                                      5U,
                                      g_waveform,
                                      641U) == 0);
    assert(abs(g_waveform[0] - g_waveform[640]) <= 2);
    assert(AcmV2Periodic_BuildWaveform(&result,
                                      2U,
                                      g_waveform,
                                      641U) != 0);
}

static void test_500khz_boundary(void)
{
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;
    const u32 expected_frequency_hz[3] = {125000U, 375000U, 500000U};
    const u32 expected_peak_uv[3] = {25000U, 10000U, 6000U};
    u32 index;

    generate_three_tone(35000000U,
                        125000.0,
                        12.5,
                        5.0,
                        3.0,
                        1000000.0,
                        50.0);
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 2000U;
    config.minimum_component_uv = 3000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.component_count == 3U);
    for (index = 0U; index < 3U; index++) {
        assert(absolute_difference(
                   result.component[index].frequency_hz_x100,
                   expected_frequency_hz[index] * 100U) <= 100000U);
        assert(absolute_difference(result.component[index].peak_uv,
                                   expected_peak_uv[index]) <= 5000U);
    }
}

static void test_high_harmonic_orders(void)
{
    static const u32 expected_frequency_hz[3] = {
        5000U, 250000U, 800000U
    };
    static const u32 expected_peak_uv[3] = {
        60000U, 24000U, 16000U
    };
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;
    u32 index;

    generate_high_harmonic_case();
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 2000U;
    config.minimum_component_uv = 5000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.component_count == 3U);
    for (index = 0U; index < 3U; index++) {
        assert(absolute_difference(
                   result.component[index].frequency_hz_x100,
                   expected_frequency_hz[index] * 100U) <= 100000U);
        assert(absolute_difference(result.component[index].peak_uv,
                                   expected_peak_uv[index]) <= 5000U);
    }
    assert(absolute_difference(result.true_rms_uv, 47074U) <= 6000U);
}

static void test_frequency_grid_soft_pull(void)
{
    static const u32 expected_frequency_hz[3] = {
        100200U, 300600U, 400800U
    };
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;
    u32 index;

    generate_three_tone(35000000U,
                        100200.0,
                        30.0,
                        12.0,
                        8.0,
                        0.0,
                        0.0);
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 2000U;
    config.minimum_component_uv = 5000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.component_count == 3U);
    assert(absolute_difference(
               result.component[0].frequency_hz_x100,
               expected_frequency_hz[0] * 100U) <= 7500U);
    assert(result.component[0].frequency_hz_x100 > 10015000U);
    assert(result.component[1].frequency_hz_x100 >= 30050000U);
    assert(result.component[1].frequency_hz_x100 <= 30057500U);
    assert(absolute_difference(
               result.component[2].frequency_hz_x100,
               expected_frequency_hz[2] * 100U) <= 7500U);
    assert(result.component[2].frequency_hz_x100 < 40085000U);
    for (index = 0U; index < 3U; index++) {
        assert((result.component[index].frequency_hz_x100 %
                (ACMV2_PERIODIC_FREQUENCY_STEP_HZ * 100U)) != 0U);
    }
}

static void test_low_amplitude_harmonics(void)
{
    static const u32 expected_frequency_hz[3] = {
        100000U, 300000U, 400000U
    };
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;
    u32 index;

    generate_three_tone(35000000U,
                        100000.0,
                        50.0,
                        3.0,
                        4.0,
                        0.0,
                        0.0);
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 1896U;
    config.minimum_component_uv = 5000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.component_count == 3U);
    for (index = 0U; index < 3U; index++) {
        assert(absolute_difference(
                   result.component[index].frequency_hz_x100,
                   expected_frequency_hz[index] * 100U) <= 100000U);
    }
    assert(result.component[1].peak_uv >= 5000U);
    assert(result.component[1].peak_uv < 10000U);
    assert(result.component[2].peak_uv >= 5000U);
    assert(result.component[2].peak_uv < 10000U);

    generate_three_tone(35000000U,
                        100000.0,
                        25.0,
                        0.6,
                        0.8,
                        2000000.0,
                        50.0);
    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 3785U;
    config.minimum_component_uv = 2000U;

    assert(AcmV2Periodic_AnalyzePacked(
               g_input,
               ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
               &config,
               &result) == 0);
    assert(result.component_count == 3U);
    for (index = 0U; index < 3U; index++) {
        assert(absolute_difference(
                   result.component[index].frequency_hz_x100,
                   expected_frequency_hz[index] * 100U) <= 100000U);
    }
    assert(result.component[1].peak_uv >= 2000U);
    assert(result.component[1].peak_uv < 5000U);
    assert(result.component[2].peak_uv >= 2000U);
    assert(result.component[2].peak_uv < 5000U);
}

static void test_argument_validation(void)
{
    AcmV2PeriodicConfig config;
    AcmV2PeriodicResult result;

    AcmV2Periodic_DefaultConfig(&config);
    assert(AcmV2Periodic_AnalyzePacked(NULL,
                                      ACMV2_PERIODIC_MIN_INPUT_WORDS,
                                      &config,
                                      &result) != 0);
    assert(AcmV2Periodic_AnalyzePacked(g_input,
                                      ACMV2_PERIODIC_MIN_INPUT_WORDS - 1U,
                                      &config,
                                      &result) != 0);
    config.sample_rate_hz = 34000000U;
    assert(AcmV2Periodic_AnalyzePacked(g_input,
                                      ACMV2_PERIODIC_MIN_INPUT_WORDS,
                                      &config,
                                      &result) != 0);
}

static AcmV2PeriodicResult make_tracker_result(u32 count,
                                               u32 frequency0_hz,
                                               u32 frequency1_hz,
                                               u32 frequency2_hz,
                                               u32 amplitude_uv)
{
    AcmV2PeriodicResult result = {0U};

    result.valid = 1U;
    result.component_count = count;
    result.fundamental_hz_x100 = frequency0_hz * 100U;
    result.component[0].frequency_hz_x100 = frequency0_hz * 100U;
    result.component[0].peak_uv = amplitude_uv;
    if (count > 1U) {
        result.component[1].frequency_hz_x100 = frequency1_hz * 100U;
        result.component[1].peak_uv = amplitude_uv / 2U;
    }
    if (count > 2U) {
        result.component[2].frequency_hz_x100 = frequency2_hz * 100U;
        result.component[2].peak_uv = amplitude_uv / 4U;
    }
    return result;
}

static void test_result_tracker(void)
{
    AcmV2PeriodicTracker tracker;
    AcmV2PeriodicResult candidate;
    AcmV2PeriodicResult output;
    u32 held;
    u32 attempt;

    AcmV2PeriodicTracker_Init(&tracker);
    candidate = make_tracker_result(3U, 30000U, 60000U, 150000U,
                                    79000U);
    for (attempt = 1U;
         attempt < ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES;
         attempt++) {
        assert(AcmV2PeriodicTracker_Update(&tracker,
                                           &candidate,
                                           &output,
                                           &held) == 0);
    }
    assert(AcmV2PeriodicTracker_Update(&tracker,
                                       &candidate,
                                       &output,
                                       &held) == 1);
    assert(held == 0U);
    assert(output.fundamental_hz_x100 == 3000000U);

    candidate = make_tracker_result(3U, 57000U, 171000U, 285000U,
                                    15000U);
    assert(AcmV2PeriodicTracker_Update(&tracker,
                                       &candidate,
                                       &output,
                                       &held) == 1);
    assert(held == 1U);
    assert(output.fundamental_hz_x100 == 3000000U);

    candidate = make_tracker_result(3U, 30010U, 59990U, 150020U,
                                    80000U);
    assert(AcmV2PeriodicTracker_Update(&tracker,
                                       &candidate,
                                       &output,
                                       &held) == 1);
    assert(held == 0U);
    assert(output.component[0].peak_uv == 80000U);

    candidate = make_tracker_result(3U, 100000U, 200000U, 500000U,
                                    60000U);
    for (attempt = 1U;
         attempt < ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES;
         attempt++) {
        assert(AcmV2PeriodicTracker_Update(&tracker,
                                           &candidate,
                                           &output,
                                           &held) == 1);
        assert(held == 1U);
        assert(output.fundamental_hz_x100 == 3001000U);
    }
    assert(AcmV2PeriodicTracker_Update(&tracker,
                                       &candidate,
                                       &output,
                                       &held) == 1);
    assert(held == 0U);
    assert(output.fundamental_hz_x100 == 10000000U);

    candidate = make_tracker_result(3U, 100000U, 200000U, 498400U,
                                    60000U);
    assert(AcmV2PeriodicTracker_Update(&tracker,
                                       &candidate,
                                       &output,
                                       &held) == 1);
    assert(held == 1U);
    assert(output.component[2].frequency_hz_x100 == 50000000U);

    candidate = make_tracker_result(3U, 100000U, 200000U, 499200U,
                                    60000U);
    assert(AcmV2PeriodicTracker_Update(&tracker,
                                       &candidate,
                                       &output,
                                       &held) == 1);
    assert(held == 0U);
    assert(output.component[2].frequency_hz_x100 == 49920000U);

    candidate = make_tracker_result(1U, 60000U, 0U, 0U, 40000U);
    for (attempt = 1U;
         attempt < ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES;
         attempt++) {
        assert(AcmV2PeriodicTracker_Update(&tracker,
                                           &candidate,
                                           &output,
                                           &held) == 1);
        assert(held == 1U);
        assert(output.component_count == 3U);
    }
    assert(AcmV2PeriodicTracker_Update(&tracker,
                                       &candidate,
                                       &output,
                                       &held) == 1);
    assert(held == 0U);
    assert(output.component_count == 1U);
    assert(output.fundamental_hz_x100 == 6000000U);

    candidate.valid = 0U;
    assert(AcmV2PeriodicTracker_Update(&tracker,
                                       &candidate,
                                       &output,
                                       &held) == 1);
    assert(held == 1U);
    assert(output.fundamental_hz_x100 == 6000000U);
}

int main(void)
{
    test_g_problem_interference_rejection();
    test_measurement_with_interference();
    test_interferer_is_excluded_from_true_rms();
    test_true_rms_uses_corrected_components();
    test_complete_cycle_waveforms();
    test_500khz_boundary();
    test_high_harmonic_orders();
    test_frequency_grid_soft_pull();
    test_low_amplitude_harmonics();
    test_argument_validation();
    test_result_tracker();
    puts("periodic_signal_analyzer tests passed");
    return 0;
}
