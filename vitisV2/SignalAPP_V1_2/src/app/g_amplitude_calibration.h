#ifndef G_AMPLITUDE_CALIBRATION_H
#define G_AMPLITUDE_CALIBRATION_H

#include "xil_types.h"

#include <string.h>

typedef enum {
    G_AMPLITUDE_GAIN_20P4X = 0,
    G_AMPLITUDE_GAIN_10P4X = 1
} GAmplitudeGainMode;

/*
 * End-to-end input-referred calibration from the 2026-07-30 MATLAB fit.
 *
 * Signal-generator component settings are Vpp. Spectrum amplitudes are
 * component peaks, so each reference peak is one half of its Vpp setting.
 *
 * 20.4x level, DAC0 at 0 V:
 *   Six clean-signal components from 30 kHz through 440 kHz.
 *   Minimax fit: 1896.361 uV/code, maximum peak error 0.174 mV.
 * 10.4x level, DAC0 high:
 *   Same clean signal measured 50.411 mV in Q1/Q2 and 55.650 mV in Q3.
 *   RMS measured 36.960 mV in Q1/Q2 and 40.783 mV in Q3.
 *   Joint cross-mode least-squares correction: 3785.262 uV/code.
 * True RMS:
 *   Least-squares fit from the 30 kHz and 40 kHz clean recordings only.
 *   Interference recordings do not participate in the RMS fit.
 *   Post-amplitude correction: 1.001379715, RMSE 0.088 mV.
 */
#define G_AMPLITUDE_CAL_20P4X_UV_PER_CODE 1896U
#define G_AMPLITUDE_CAL_10P4X_UV_PER_CODE 3785U
#define G_TRUE_RMS_CLEAN_SCALE_PPM        1001380U
#define G_AMPLITUDE_DAC0_ZERO_CODE         128U
#define G_AMPLITUDE_DAC0_HIGH_CODE         255U

/* Source compatibility for code written before the 20.4x measurement. */
#define G_AMPLITUDE_GAIN_20P8X G_AMPLITUDE_GAIN_20P4X
#define G_AMPLITUDE_CAL_20P8X_UV_PER_CODE \
    G_AMPLITUDE_CAL_20P4X_UV_PER_CODE

static inline u32 GAmplitudeCalibration_MicrovoltsPerCode(
    GAmplitudeGainMode mode)
{
    return (mode == G_AMPLITUDE_GAIN_10P4X) ?
        G_AMPLITUDE_CAL_10P4X_UV_PER_CODE :
        G_AMPLITUDE_CAL_20P4X_UV_PER_CODE;
}

static inline u32 GAmplitudeCalibration_GainX10(
    GAmplitudeGainMode mode)
{
    return (mode == G_AMPLITUDE_GAIN_10P4X) ? 104U : 204U;
}

static inline u32 GAmplitudeCalibration_Dac0Code(
    GAmplitudeGainMode mode)
{
    return (mode == G_AMPLITUDE_GAIN_10P4X) ?
        G_AMPLITUDE_DAC0_HIGH_CODE :
        G_AMPLITUDE_DAC0_ZERO_CODE;
}

static inline u32 GAmplitudeCalibration_CorrectTrueRms(u32 rms_uv)
{
    u64 scaled = (u64)rms_uv *
                 (u64)G_TRUE_RMS_CLEAN_SCALE_PPM;

    return (u32)((scaled + 500000U) / 1000000U);
}

static inline int GAmplitudeCalibration_ParseGainCommand(
    const char *command,
    GAmplitudeGainMode *mode)
{
    if ((command == NULL) || (mode == NULL)) {
        return -1;
    }
    if ((strcmp(command, "GAIN 20.4") == 0) ||
        (strcmp(command, "GAIN 20.4X") == 0) ||
        (strcmp(command, "GAIN 20.8") == 0) ||
        (strcmp(command, "GAIN 20.8X") == 0)) {
        *mode = G_AMPLITUDE_GAIN_20P4X;
        return 0;
    }
    if ((strcmp(command, "GAIN 10.4") == 0) ||
        (strcmp(command, "GAIN 10.4X") == 0)) {
        *mode = G_AMPLITUDE_GAIN_10P4X;
        return 0;
    }
    return -2;
}

#endif
