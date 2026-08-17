#define main shared_periodic_tests_main
#include "shared_periodic_signal_analyzer_tests.c"
#undef main

static void generate_single_tone(double frequency_hz,
                                 double peak_codes)
{
    u32 index;

    for (index = 0U;
         index < ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U;
         index++) {
        double time = (double)index / 35000000.0;
        double signal =
            peak_codes * sin(2.0 * TEST_PI * frequency_hz * time);
        int adc0 = (int)floor(128.0 + signal + 0.5);

        g_input[index] = pack_sample(adc0, 128);
    }
}

static void test_initial_single_tones(void)
{
    const u32 frequencies_hz[6] = {
        5000U, 10000U, 20000U, 50000U, 40000U, 800000U
    };
    AcmV2PeriodicConfig config;
    u32 index;

    AcmV2Periodic_DefaultConfig(&config);
    config.microvolts_per_code = 2000U;
    config.minimum_component_uv = 3000U;

    for (index = 0U; index < 6U; index++) {
        AcmV2PeriodicResult result;

        generate_single_tone((double)frequencies_hz[index], 20.0);
        assert(AcmV2Periodic_AnalyzePacked(
                   g_input,
                   ACMV2_PERIODIC_MIN_INPUT_WORDS + 64U,
                   &config,
                   &result) == 0);
        assert(result.component_count == 1U);
        assert(absolute_difference(result.fundamental_hz_x100,
                                   frequencies_hz[index] * 100U) <=
               100000U);
        assert(absolute_difference(result.component[0].peak_uv,
                                   40000U) <= 5000U);
        assert(absolute_difference(result.true_rms_uv,
                                   28284U) <= 4000U);
        assert(result.thd_ppm == 0U);
    }
}

int main(void)
{
    assert(shared_periodic_tests_main() == 0);
    test_initial_single_tones();
    puts("SignalAPP_V1_2 initial single-tone tests passed");
    return 0;
}
