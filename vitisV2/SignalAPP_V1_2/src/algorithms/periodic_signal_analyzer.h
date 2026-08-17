#ifndef ACM2108V2_PERIODIC_SIGNAL_ANALYZER_H
#define ACM2108V2_PERIODIC_SIGNAL_ANALYZER_H

#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ACMV2_PERIODIC_FFT_SIZE              16384U
#define ACMV2_PERIODIC_DECIMATION                7U
#define ACMV2_PERIODIC_FIR_TAPS                511U
#define ACMV2_PERIODIC_MIN_COMPONENTS            1U
#define ACMV2_PERIODIC_MAX_COMPONENTS            3U
#define ACMV2_PERIODIC_DEFAULT_FS_HZ       35000000U
#define ACMV2_PERIODIC_MIN_FREQ_HZ             5000U
#define ACMV2_PERIODIC_MAX_FREQ_HZ           800000U
#define ACMV2_PERIODIC_FREQUENCY_STEP_HZ         500U
#define ACMV2_PERIODIC_MAX_HARMONIC_ORDER         160U
#define ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES       3U
#define ACMV2_PERIODIC_MAX_THIRD_ERROR_HZ       1000U
#define ACMV2_PERIODIC_MIN_INPUT_WORDS \
    (ACMV2_PERIODIC_FIR_TAPS + \
     ((ACMV2_PERIODIC_FFT_SIZE - 1U) * ACMV2_PERIODIC_DECIMATION))

typedef struct {
    u32 sample_rate_hz;
    u32 channel;
    u32 microvolts_per_code;
    u32 minimum_component_uv;
} AcmV2PeriodicConfig;

typedef struct {
    u32 frequency_hz_x100;
    u32 peak_uv;
    s32 phase_mdeg;
} AcmV2PeriodicComponent;

typedef struct {
    u32 valid;
    u32 clipped;
    u32 input_words;
    u32 input_sample_rate_hz;
    u32 analysis_sample_rate_hz;
    u32 fft_bin_width_hz_x100;
    u32 processing_samples;
    u32 component_count;
    u32 fundamental_hz_x100;
    u32 peak_to_peak_uv;
    u32 true_rms_uv;
    u32 thd_ppm;
    AcmV2PeriodicComponent component[ACMV2_PERIODIC_MAX_COMPONENTS];
} AcmV2PeriodicResult;

typedef struct {
    AcmV2PeriodicResult stable;
    AcmV2PeriodicResult pending;
    u32 stable_valid;
    u32 pending_count;
} AcmV2PeriodicTracker;

void AcmV2Periodic_DefaultConfig(AcmV2PeriodicConfig *config);

int AcmV2Periodic_AnalyzePacked(const u32 *packed_words,
                                u32 words,
                                const AcmV2PeriodicConfig *config,
                                AcmV2PeriodicResult *result);

void AcmV2PeriodicTracker_Init(AcmV2PeriodicTracker *tracker);

int AcmV2PeriodicTracker_Update(AcmV2PeriodicTracker *tracker,
                                const AcmV2PeriodicResult *candidate,
                                AcmV2PeriodicResult *output,
                                u32 *held);

int AcmV2Periodic_BuildWaveform(const AcmV2PeriodicResult *result,
                                u32 cycles,
                                s32 *waveform_uv,
                                u32 points);

#ifdef __cplusplus
}
#endif

#endif
