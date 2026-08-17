#ifndef G_MEASUREMENT_CONFIG_H
#define G_MEASUREMENT_CONFIG_H

#include "g_amplitude_calibration.h"
#include "periodic_signal_analyzer.h"

#define G_CAPTURE_WORDS              ACMV2_PERIODIC_MIN_INPUT_WORDS
#define G_CAPTURE_ALIGNMENT_BYTES                                  64U
#define G_INPUT_CHANNEL                                               0U

#define G_DEFAULT_AMPLITUDE_GAIN_MODE        G_AMPLITUDE_GAIN_20P4X
#define G_MINIMUM_COMPONENT_UV                                     2000U

#define G_CAPTURE_TIMEOUT                           DRIVER_WAIT_TIMEOUT
#define G_RESULT_HOLD_US                                           10000U

#if G_INPUT_CHANNEL > 1U
#error "G_INPUT_CHANNEL must be 0 or 1"
#endif

#if (G_CAPTURE_ALIGNMENT_BYTES & (G_CAPTURE_ALIGNMENT_BYTES - 1U)) != 0U
#error "G_CAPTURE_ALIGNMENT_BYTES must be a power of two"
#endif

#endif
