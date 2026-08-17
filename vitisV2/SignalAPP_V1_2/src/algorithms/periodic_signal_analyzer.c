#include "periodic_signal_analyzer.h"

#include <math.h>
#include <stddef.h>

#define PERIODIC_PI                 3.14159265358979323846
#define PERIODIC_TWO_PI             (2.0 * PERIODIC_PI)
#define PERIODIC_FILTER_CUTOFF_HZ    900000.0
#define PERIODIC_PEAK_GUARD_BINS          6U
#define PERIODIC_PEAK_CANDIDATES          8U
#define PERIODIC_GRID_PULL_RATIO          0.5
#define PERIODIC_GRID_PULL_LIMIT_HZ     100.0
#define PERIODIC_GRID_ENABLE_HZ         125.0
#define PERIODIC_FIT_COLUMNS \
    (1U + (2U * ACMV2_PERIODIC_MAX_COMPONENTS))

typedef struct {
    u32 bin;
    double magnitude;
    double frequency_hz;
} PeriodicPeak;

static float g_fir[ACMV2_PERIODIC_FIR_TAPS];
static float g_real[ACMV2_PERIODIC_FFT_SIZE];
static float g_imag[ACMV2_PERIODIC_FFT_SIZE];
static float g_samples[ACMV2_PERIODIC_FFT_SIZE];
static u32 g_initialized;

static double periodic_abs(double value)
{
    return (value < 0.0) ? -value : value;
}

static u32 round_u32(double value)
{
    if (value <= 0.0) {
        return 0U;
    }
    if (value >= 4294967295.0) {
        return 0xFFFFFFFFU;
    }
    return (u32)(value + 0.5);
}

static s32 round_s32(double value)
{
    if (value >= 2147483647.0) {
        return 2147483647;
    }
    if (value <= -2147483648.0) {
        return (-2147483647 - 1);
    }
    return (value >= 0.0) ? (s32)(value + 0.5) : (s32)(value - 0.5);
}

static u32 pull_frequency_to_grid_hz_x100(double frequency_hz)
{
    double step_hz = (double)ACMV2_PERIODIC_FREQUENCY_STEP_HZ;
    double reference_hz = floor((frequency_hz / step_hz) + 0.5) *
                          step_hz;
    double correction_hz =
        (reference_hz - frequency_hz) * PERIODIC_GRID_PULL_RATIO;

    if (periodic_abs(reference_hz - frequency_hz) >
        PERIODIC_GRID_ENABLE_HZ) {
        return round_u32(frequency_hz * 100.0);
    }
    if (correction_hz > PERIODIC_GRID_PULL_LIMIT_HZ) {
        correction_hz = PERIODIC_GRID_PULL_LIMIT_HZ;
    } else if (correction_hz < -PERIODIC_GRID_PULL_LIMIT_HZ) {
        correction_hz = -PERIODIC_GRID_PULL_LIMIT_HZ;
    }
    return round_u32((frequency_hz + correction_hz) * 100.0);
}

static int unpack_adc(u32 word, u32 channel)
{
    return (channel == 0U) ?
        (int)(word & 0xFFU) :
        (int)((word >> 16) & 0xFFU);
}

static void initialize_fir(u32 sample_rate_hz)
{
    const int midpoint = (int)(ACMV2_PERIODIC_FIR_TAPS / 2U);
    double sum = 0.0;
    u32 i;

    for (i = 0U; i < ACMV2_PERIODIC_FIR_TAPS; i++) {
        int offset = (int)i - midpoint;
        double sinc;
        double window;

        if (offset == 0) {
            sinc = 2.0 * PERIODIC_FILTER_CUTOFF_HZ /
                   (double)sample_rate_hz;
        } else {
            double angle = PERIODIC_TWO_PI *
                           PERIODIC_FILTER_CUTOFF_HZ *
                           (double)offset /
                           (double)sample_rate_hz;
            sinc = sin(angle) / (PERIODIC_PI * (double)offset);
        }

        window = 0.54 -
                 (0.46 * cos(PERIODIC_TWO_PI * (double)i /
                             (double)(ACMV2_PERIODIC_FIR_TAPS - 1U)));
        g_fir[i] = (float)(sinc * window);
        sum += (double)g_fir[i];
    }

    for (i = 0U; i < ACMV2_PERIODIC_FIR_TAPS; i++) {
        g_fir[i] = (float)((double)g_fir[i] / sum);
    }
    g_initialized = sample_rate_hz;
}

static void clear_result(AcmV2PeriodicResult *result)
{
    u32 i;

    result->valid = 0U;
    result->clipped = 0U;
    result->input_words = 0U;
    result->input_sample_rate_hz = 0U;
    result->analysis_sample_rate_hz = 0U;
    result->fft_bin_width_hz_x100 = 0U;
    result->processing_samples = 0U;
    result->component_count = 0U;
    result->fundamental_hz_x100 = 0U;
    result->peak_to_peak_uv = 0U;
    result->true_rms_uv = 0U;
    result->thd_ppm = 0U;

    for (i = 0U; i < ACMV2_PERIODIC_MAX_COMPONENTS; i++) {
        result->component[i].frequency_hz_x100 = 0U;
        result->component[i].peak_uv = 0U;
        result->component[i].phase_mdeg = 0;
    }
}

static void filter_and_decimate(const u32 *packed_words,
                                u32 channel,
                                AcmV2PeriodicResult *result)
{
    u32 output_index;

    for (output_index = 0U;
         output_index < ACMV2_PERIODIC_FFT_SIZE;
         output_index++) {
        u32 input_index = (ACMV2_PERIODIC_FIR_TAPS - 1U) +
                          (output_index * ACMV2_PERIODIC_DECIMATION);
        double accumulator = 0.0;
        u32 tap;

        for (tap = 0U; tap < ACMV2_PERIODIC_FIR_TAPS; tap++) {
            int sample = unpack_adc(packed_words[input_index - tap],
                                    channel);
            accumulator += (double)g_fir[tap] * (double)sample;
        }
        g_samples[output_index] = (float)accumulator;
    }

    for (output_index = 0U;
         output_index < ACMV2_PERIODIC_MIN_INPUT_WORDS;
         output_index++) {
        int sample = unpack_adc(packed_words[output_index], channel);

        if ((sample <= 1) || (sample >= 254)) {
            result->clipped = 1U;
            break;
        }
    }
}

static void prepare_fft(void)
{
    double mean = 0.0;
    u32 i;

    for (i = 0U; i < ACMV2_PERIODIC_FFT_SIZE; i++) {
        mean += (double)g_samples[i];
    }
    mean /= (double)ACMV2_PERIODIC_FFT_SIZE;

    for (i = 0U; i < ACMV2_PERIODIC_FFT_SIZE; i++) {
        double window = 0.5 -
            (0.5 * cos(PERIODIC_TWO_PI * (double)i /
                       (double)(ACMV2_PERIODIC_FFT_SIZE - 1U)));
        g_real[i] = (float)(((double)g_samples[i] - mean) * window);
        g_imag[i] = 0.0F;
    }
}

static void fft_in_place(void)
{
    u32 i;
    u32 j = 0U;
    u32 length;

    for (i = 1U; i < ACMV2_PERIODIC_FFT_SIZE; i++) {
        u32 bit = ACMV2_PERIODIC_FFT_SIZE >> 1U;
        float swap;

        while ((j & bit) != 0U) {
            j ^= bit;
            bit >>= 1U;
        }
        j ^= bit;
        if (i < j) {
            swap = g_real[i];
            g_real[i] = g_real[j];
            g_real[j] = swap;
            swap = g_imag[i];
            g_imag[i] = g_imag[j];
            g_imag[j] = swap;
        }
    }

    for (length = 2U;
         length <= ACMV2_PERIODIC_FFT_SIZE;
         length <<= 1U) {
        u32 half = length >> 1U;
        double angle_step = -PERIODIC_TWO_PI / (double)length;
        u32 base;

        for (base = 0U; base < ACMV2_PERIODIC_FFT_SIZE; base += length) {
            u32 k;
            for (k = 0U; k < half; k++) {
                double angle = angle_step * (double)k;
                double wr = cos(angle);
                double wi = sin(angle);
                u32 even = base + k;
                u32 odd = even + half;
                double odd_r = ((double)g_real[odd] * wr) -
                               ((double)g_imag[odd] * wi);
                double odd_i = ((double)g_real[odd] * wi) +
                               ((double)g_imag[odd] * wr);
                double even_r = (double)g_real[even];
                double even_i = (double)g_imag[even];

                g_real[even] = (float)(even_r + odd_r);
                g_imag[even] = (float)(even_i + odd_i);
                g_real[odd] = (float)(even_r - odd_r);
                g_imag[odd] = (float)(even_i - odd_i);
            }
        }
    }
}

static double magnitude_at(u32 bin)
{
    double real = (double)g_real[bin];
    double imag = (double)g_imag[bin];

    return sqrt((real * real) + (imag * imag));
}

static void insert_peak(PeriodicPeak *peaks,
                        u32 *peak_count,
                        u32 bin,
                        double magnitude)
{
    u32 count = *peak_count;
    u32 index;

    if (count < PERIODIC_PEAK_CANDIDATES) {
        peaks[count].bin = bin;
        peaks[count].magnitude = magnitude;
        peaks[count].frequency_hz = 0.0;
        count++;
    } else if (magnitude <= peaks[count - 1U].magnitude) {
        return;
    } else {
        peaks[count - 1U].bin = bin;
        peaks[count - 1U].magnitude = magnitude;
        peaks[count - 1U].frequency_hz = 0.0;
    }

    for (index = count - 1U; index > 0U; index--) {
        if (peaks[index].magnitude <= peaks[index - 1U].magnitude) {
            break;
        }
        {
            PeriodicPeak swap = peaks[index];
            peaks[index] = peaks[index - 1U];
            peaks[index - 1U] = swap;
        }
    }
    *peak_count = count;
}

static u32 peaks_are_separated(const PeriodicPeak *peaks,
                               u32 peak_count,
                               u32 bin)
{
    u32 i;

    for (i = 0U; i < peak_count; i++) {
        u32 distance = (peaks[i].bin > bin) ?
            (peaks[i].bin - bin) : (bin - peaks[i].bin);
        if (distance <= PERIODIC_PEAK_GUARD_BINS) {
            return 0U;
        }
    }
    return 1U;
}

static u32 detect_peaks(u32 analysis_sample_rate_hz, PeriodicPeak *peaks)
{
    u32 min_bin = (u32)(((u64)ACMV2_PERIODIC_MIN_FREQ_HZ *
                         ACMV2_PERIODIC_FFT_SIZE) /
                        analysis_sample_rate_hz);
    u32 max_bin = (u32)(((u64)ACMV2_PERIODIC_MAX_FREQ_HZ *
                         ACMV2_PERIODIC_FFT_SIZE) /
                        analysis_sample_rate_hz);
    u32 peak_count = 0U;
    u32 bin;

    if (min_bin < 2U) {
        min_bin = 2U;
    }
    if (max_bin >= (ACMV2_PERIODIC_FFT_SIZE / 2U) - 1U) {
        max_bin = (ACMV2_PERIODIC_FFT_SIZE / 2U) - 2U;
    }

    for (bin = min_bin; bin <= max_bin; bin++) {
        double magnitude = magnitude_at(bin);

        if ((magnitude > magnitude_at(bin - 1U)) &&
            (magnitude >= magnitude_at(bin + 1U)) &&
            (peaks_are_separated(peaks, peak_count, bin) != 0U)) {
            insert_peak(peaks, &peak_count, bin, magnitude);
        }
    }

    if (peak_count != 0U) {
        double minimum = peaks[0].magnitude * 0.02;
        u32 kept = 0U;

        while ((kept < peak_count) &&
               (peaks[kept].magnitude >= minimum)) {
            kept++;
        }
        peak_count = kept;
    }

    for (bin = 0U; bin < peak_count; bin++) {
        u32 center = peaks[bin].bin;
        double left = log(magnitude_at(center - 1U) + 1.0e-20);
        double middle = log(magnitude_at(center) + 1.0e-20);
        double right = log(magnitude_at(center + 1U) + 1.0e-20);
        double denominator = left - (2.0 * middle) + right;
        double offset = 0.0;

        if (periodic_abs(denominator) > 1.0e-12) {
            offset = 0.5 * (left - right) / denominator;
        }
        if (offset > 0.5) {
            offset = 0.5;
        }
        if (offset < -0.5) {
            offset = -0.5;
        }
        peaks[bin].frequency_hz =
            ((double)center + offset) *
            (double)analysis_sample_rate_hz /
            (double)ACMV2_PERIODIC_FFT_SIZE;
    }

    return peak_count;
}

static void sort_peaks_by_frequency(PeriodicPeak *peaks, u32 count)
{
    u32 i;

    for (i = 1U; i < count; i++) {
        PeriodicPeak value = peaks[i];
        u32 index = i;

        while ((index > 0U) &&
               (peaks[index - 1U].frequency_hz > value.frequency_hz)) {
            peaks[index] = peaks[index - 1U];
            index--;
        }
        peaks[index] = value;
    }
}

static u32 select_harmonic_peaks(PeriodicPeak *peaks, u32 peak_count)
{
    PeriodicPeak selected[ACMV2_PERIODIC_MAX_COMPONENTS];
    double best_score = 0.0;
    u32 best_count = 0U;
    u32 fundamental_index;

    for (fundamental_index = 0U;
         fundamental_index < peak_count;
         fundamental_index++) {
        double fundamental = peaks[fundamental_index].frequency_hz;
        double score = peaks[fundamental_index].magnitude;
        u32 count = 1U;
        u32 candidate;
        PeriodicPeak local[ACMV2_PERIODIC_MAX_COMPONENTS];

        local[0] = peaks[fundamental_index];
        for (candidate = 0U; candidate < peak_count; candidate++) {
            double ratio;
            double nearest;
            double error;
            double expected;

            if ((candidate == fundamental_index) ||
                (count >= ACMV2_PERIODIC_MAX_COMPONENTS)) {
                continue;
            }
            ratio = peaks[candidate].frequency_hz / fundamental;
            nearest = floor(ratio + 0.5);
            expected = nearest * fundamental;
            error = periodic_abs(peaks[candidate].frequency_hz -
                                 expected);
            if ((nearest >= 2.0) &&
                (nearest <=
                 (double)ACMV2_PERIODIC_MAX_HARMONIC_ORDER) &&
                (error <=
                 (double)ACMV2_PERIODIC_MAX_THIRD_ERROR_HZ)) {
                local[count] = peaks[candidate];
                score += peaks[candidate].magnitude;
                count++;
            }
        }

        if ((count > best_count) ||
            ((count == best_count) && (score > best_score))) {
            u32 copy;
            best_count = count;
            best_score = score;
            for (copy = 0U; copy < count; copy++) {
                selected[copy] = local[copy];
            }
        }
    }

    if (best_count == 0U) {
        return 0U;
    }
    sort_peaks_by_frequency(selected, best_count);
    for (fundamental_index = 0U;
         fundamental_index < best_count;
         fundamental_index++) {
        peaks[fundamental_index] = selected[fundamental_index];
    }
    return best_count;
}

static int solve_linear(double matrix[PERIODIC_FIT_COLUMNS]
                                     [PERIODIC_FIT_COLUMNS + 1U],
                        u32 size,
                        double *solution)
{
    u32 pivot;

    for (pivot = 0U; pivot < size; pivot++) {
        u32 best = pivot;
        u32 row;
        u32 column;

        for (row = pivot + 1U; row < size; row++) {
            if (periodic_abs(matrix[row][pivot]) >
                periodic_abs(matrix[best][pivot])) {
                best = row;
            }
        }
        if (periodic_abs(matrix[best][pivot]) < 1.0e-9) {
            return -1;
        }
        if (best != pivot) {
            for (column = pivot; column <= size; column++) {
                double swap = matrix[pivot][column];
                matrix[pivot][column] = matrix[best][column];
                matrix[best][column] = swap;
            }
        }

        {
            double divisor = matrix[pivot][pivot];
            for (column = pivot; column <= size; column++) {
                matrix[pivot][column] /= divisor;
            }
        }

        for (row = 0U; row < size; row++) {
            double factor;
            if (row == pivot) {
                continue;
            }
            factor = matrix[row][pivot];
            for (column = pivot; column <= size; column++) {
                matrix[row][column] -= factor * matrix[pivot][column];
            }
        }
    }

    for (pivot = 0U; pivot < size; pivot++) {
        solution[pivot] = matrix[pivot][size];
    }
    return 0;
}

static double fir_gain(double frequency_hz, u32 sample_rate_hz)
{
    double real = 0.0;
    double imag = 0.0;
    u32 tap;

    for (tap = 0U; tap < ACMV2_PERIODIC_FIR_TAPS; tap++) {
        double angle = -PERIODIC_TWO_PI *
                       frequency_hz *
                       (double)tap /
                       (double)sample_rate_hz;
        real += (double)g_fir[tap] * cos(angle);
        imag += (double)g_fir[tap] * sin(angle);
    }
    return sqrt((real * real) + (imag * imag));
}

static int fit_components(const PeriodicPeak *peaks,
                          u32 component_count,
                          const AcmV2PeriodicConfig *config,
                          AcmV2PeriodicResult *result)
{
    double matrix[PERIODIC_FIT_COLUMNS][PERIODIC_FIT_COLUMNS + 1U] = {{0.0}};
    double solution[PERIODIC_FIT_COLUMNS] = {0.0};
    u32 columns = 1U + (2U * component_count);
    u32 sample;
    u32 row;
    u32 column;

    for (sample = 0U; sample < ACMV2_PERIODIC_FFT_SIZE; sample++) {
        double basis[PERIODIC_FIT_COLUMNS];
        double value = (double)g_samples[sample];
        u32 component;

        basis[0] = 1.0;
        for (component = 0U; component < component_count; component++) {
            double angle = PERIODIC_TWO_PI *
                           peaks[component].frequency_hz *
                           (double)sample /
                           (double)result->analysis_sample_rate_hz;
            basis[1U + (2U * component)] = cos(angle);
            basis[2U + (2U * component)] = sin(angle);
        }

        for (row = 0U; row < columns; row++) {
            for (column = 0U; column < columns; column++) {
                matrix[row][column] += basis[row] * basis[column];
            }
            matrix[row][columns] += basis[row] * value;
        }
    }

    if (solve_linear(matrix, columns, solution) != 0) {
        return -1;
    }

    result->component_count = 0U;
    for (row = 0U; row < component_count; row++) {
        double cosine = solution[1U + (2U * row)];
        double sine = solution[2U + (2U * row)];
        double gain = fir_gain(peaks[row].frequency_hz,
                               config->sample_rate_hz);
        double amplitude_codes = sqrt((cosine * cosine) + (sine * sine));
        double phase = atan2(-sine, cosine);
        u32 amplitude_uv;

        if (gain > 1.0e-6) {
            amplitude_codes /= gain;
        }
        amplitude_uv = round_u32(amplitude_codes *
                                 (double)config->microvolts_per_code);
        if (amplitude_uv < config->minimum_component_uv) {
            continue;
        }

        result->component[result->component_count].frequency_hz_x100 =
            pull_frequency_to_grid_hz_x100(peaks[row].frequency_hz);
        result->component[result->component_count].peak_uv = amplitude_uv;
        result->component[result->component_count].phase_mdeg =
            round_s32(phase * 180000.0 / PERIODIC_PI);
        result->component_count++;
    }
    return (result->component_count == 0U) ? -2 : 0;
}

static u32 calculate_signal_true_rms_uv(
    const AcmV2PeriodicResult *result)
{
    double square_sum = 0.0;
    u32 component;

    /*
     * Distinct integer harmonics are orthogonal over a fundamental period.
     * Each peak value has already received its own FIR gain compensation.
     * Peak detection has already limited every fitted component to the
     * 5 kHz to 800 kHz signal band. Summing the accepted components avoids
     * dropping a 5 kHz or 800 kHz boundary tone when FFT interpolation
     * places its displayed frequency slightly outside the nominal boundary.
     * The G problem interferer starts at 1 MHz and never enters this list.
     */
    for (component = 0U;
         component < result->component_count;
         component++) {
        double peak_uv =
            (double)result->component[component].peak_uv;

        square_sum += peak_uv * peak_uv;
    }

    return round_u32(sqrt(0.5 * square_sum));
}

static u32 calculate_signal_thd_ppm(
    const AcmV2PeriodicResult *result)
{
    double harmonic_square_sum = 0.0;
    double fundamental_peak_uv;
    u32 component;

    if (result->component_count == 0U) {
        return 0U;
    }

    fundamental_peak_uv =
        (double)result->component[0].peak_uv;
    if (fundamental_peak_uv < 1.0) {
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

    return round_u32(
        1000000.0 * sqrt(harmonic_square_sum) /
        fundamental_peak_uv);
}

static void calculate_summary(AcmV2PeriodicResult *result)
{
    const u32 reconstruction_points = 4096U;
    double minimum = 0.0;
    double maximum = 0.0;
    u32 point;
    u32 component;

    for (point = 0U; point < reconstruction_points; point++) {
        double value = 0.0;

        for (component = 0U;
             component < result->component_count;
             component++) {
            double measured_ratio =
                (double)result->component[component].frequency_hz_x100 /
                (double)result->fundamental_hz_x100;
            double ratio = floor(measured_ratio + 0.5);
            double phase =
                (double)result->component[component].phase_mdeg *
                PERIODIC_PI / 180000.0;
            double angle = PERIODIC_TWO_PI * ratio *
                           (double)point /
                           (double)reconstruction_points +
                           phase;
            value += (double)result->component[component].peak_uv *
                     cos(angle);
        }
        if ((point == 0U) || (value < minimum)) {
            minimum = value;
        }
        if ((point == 0U) || (value > maximum)) {
            maximum = value;
        }
    }

    result->peak_to_peak_uv = round_u32(maximum - minimum);
    result->true_rms_uv =
        calculate_signal_true_rms_uv(result);
    result->thd_ppm =
        calculate_signal_thd_ppm(result);
}

void AcmV2Periodic_DefaultConfig(AcmV2PeriodicConfig *config)
{
    if (config == NULL) {
        return;
    }

    config->sample_rate_hz = ACMV2_PERIODIC_DEFAULT_FS_HZ;
    config->channel = 0U;
    config->microvolts_per_code = 7813U;
    config->minimum_component_uv = 2000U;
}

static u32 tracker_frequencies_match(u32 left_hz_x100,
                                     u32 right_hz_x100)
{
    u32 difference = (left_hz_x100 > right_hz_x100) ?
        (left_hz_x100 - right_hz_x100) :
        (right_hz_x100 - left_hz_x100);
    u32 tolerance = (right_hz_x100 / 50U) + 100000U;

    return (difference <= tolerance) ? 1U : 0U;
}

static u32 tracker_signatures_match(const AcmV2PeriodicResult *left,
                                    const AcmV2PeriodicResult *right)
{
    u32 component;

    if ((left->valid == 0U) || (right->valid == 0U) ||
        (left->component_count == 0U) ||
        (left->component_count != right->component_count)) {
        return 0U;
    }
    for (component = 0U;
         component < left->component_count;
         component++) {
        if (tracker_frequencies_match(
                left->component[component].frequency_hz_x100,
                right->component[component].frequency_hz_x100) == 0U) {
            return 0U;
        }
    }
    return 1U;
}

static u32 tracker_third_frequency_valid(
    const AcmV2PeriodicResult *candidate)
{
    u32 fundamental;
    u32 third;
    u32 harmonic;
    u64 expected;
    u64 difference;

    if (candidate->component_count < 3U) {
        return 1U;
    }

    fundamental = candidate->component[0].frequency_hz_x100;
    third = candidate->component[2].frequency_hz_x100;
    if (fundamental == 0U) {
        return 0U;
    }

    harmonic = (third + (fundamental / 2U)) / fundamental;
    if ((harmonic < 2U) ||
        (harmonic > ACMV2_PERIODIC_MAX_HARMONIC_ORDER)) {
        return 0U;
    }

    expected = (u64)fundamental * (u64)harmonic;
    difference = ((u64)third > expected) ?
        ((u64)third - expected) : (expected - (u64)third);
    return (difference <=
            ((u64)ACMV2_PERIODIC_MAX_THIRD_ERROR_HZ * 100ULL)) ?
        1U : 0U;
}

void AcmV2PeriodicTracker_Init(AcmV2PeriodicTracker *tracker)
{
    if (tracker == NULL) {
        return;
    }

    tracker->stable_valid = 0U;
    tracker->pending_count = 0U;
    tracker->stable.valid = 0U;
    tracker->pending.valid = 0U;
}

int AcmV2PeriodicTracker_Update(AcmV2PeriodicTracker *tracker,
                                const AcmV2PeriodicResult *candidate,
                                AcmV2PeriodicResult *output,
                                u32 *held)
{
    if ((tracker == NULL) || (candidate == NULL) ||
        (output == NULL) || (held == NULL)) {
        return -1;
    }
    *held = 0U;

    if ((candidate->valid == 0U) ||
        (candidate->component_count <
         ACMV2_PERIODIC_MIN_COMPONENTS) ||
        (tracker_third_frequency_valid(candidate) == 0U)) {
        if (tracker->stable_valid != 0U) {
            *output = tracker->stable;
            *held = 1U;
            return 1;
        }
        clear_result(output);
        return 0;
    }

    if ((tracker->stable_valid != 0U) &&
        (tracker_signatures_match(candidate, &tracker->stable) != 0U)) {
        tracker->stable = *candidate;
        tracker->pending_count = 0U;
        *output = tracker->stable;
        return 1;
    }

    if ((tracker->pending_count != 0U) &&
        (tracker_signatures_match(candidate, &tracker->pending) != 0U)) {
        tracker->pending = *candidate;
        tracker->pending_count++;
    } else {
        tracker->pending = *candidate;
        tracker->pending_count = 1U;
    }

    if (tracker->pending_count >=
        ACMV2_PERIODIC_TRACK_CONFIRM_FRAMES) {
        tracker->stable = tracker->pending;
        tracker->stable_valid = 1U;
        tracker->pending_count = 0U;
        *output = tracker->stable;
        return 1;
    }

    if (tracker->stable_valid != 0U) {
        *output = tracker->stable;
        *held = 1U;
        return 1;
    }

    clear_result(output);
    return 0;
}

int AcmV2Periodic_AnalyzePacked(const u32 *packed_words,
                                u32 words,
                                const AcmV2PeriodicConfig *config,
                                AcmV2PeriodicResult *result)
{
    PeriodicPeak peaks[PERIODIC_PEAK_CANDIDATES] = {{0U, 0.0, 0.0}};
    u32 peak_count;

    if ((packed_words == NULL) || (config == NULL) || (result == NULL)) {
        return -1;
    }
    clear_result(result);
    if ((words < ACMV2_PERIODIC_MIN_INPUT_WORDS) ||
        (config->sample_rate_hz == 0U) ||
        (config->channel > 1U) ||
        (config->microvolts_per_code == 0U)) {
        return -2;
    }
    if ((config->sample_rate_hz % ACMV2_PERIODIC_DECIMATION) != 0U) {
        return -3;
    }

    if (g_initialized != config->sample_rate_hz) {
        initialize_fir(config->sample_rate_hz);
    }

    result->input_words = words;
    result->input_sample_rate_hz = config->sample_rate_hz;
    result->analysis_sample_rate_hz =
        config->sample_rate_hz / ACMV2_PERIODIC_DECIMATION;
    result->fft_bin_width_hz_x100 =
        round_u32((double)result->analysis_sample_rate_hz * 100.0 /
                  (double)ACMV2_PERIODIC_FFT_SIZE);
    result->processing_samples = ACMV2_PERIODIC_FFT_SIZE;

    filter_and_decimate(packed_words, config->channel, result);
    prepare_fft();
    fft_in_place();
    peak_count = detect_peaks(result->analysis_sample_rate_hz, peaks);
    if (peak_count == 0U) {
        return -4;
    }
    peak_count = select_harmonic_peaks(peaks, peak_count);
    if (peak_count == 0U) {
        return -5;
    }
    if (peak_count > ACMV2_PERIODIC_MAX_COMPONENTS) {
        peak_count = ACMV2_PERIODIC_MAX_COMPONENTS;
    }
    if (fit_components(peaks, peak_count, config, result) != 0) {
        return -6;
    }

    result->fundamental_hz_x100 =
        result->component[0].frequency_hz_x100;
    calculate_summary(result);
    result->valid = 1U;
    return 0;
}

int AcmV2Periodic_BuildWaveform(const AcmV2PeriodicResult *result,
                                u32 cycles,
                                s32 *waveform_uv,
                                u32 points)
{
    double fundamental_phase;
    u32 point;

    if ((result == NULL) || (waveform_uv == NULL) ||
        (result->valid == 0U) || (points < 2U) ||
        ((cycles != 1U) && (cycles != 3U) && (cycles != 5U))) {
        return -1;
    }

    fundamental_phase =
        (double)result->component[0].phase_mdeg *
        PERIODIC_PI / 180000.0;

    for (point = 0U; point < points; point++) {
        double value = 0.0;
        u32 component;

        for (component = 0U;
             component < result->component_count;
             component++) {
            double measured_ratio =
                (double)result->component[component].frequency_hz_x100 /
                (double)result->fundamental_hz_x100;
            double ratio = floor(measured_ratio + 0.5);
            double phase =
                (double)result->component[component].phase_mdeg *
                PERIODIC_PI / 180000.0 -
                ratio * fundamental_phase;
            double angle = PERIODIC_TWO_PI * (double)cycles * ratio *
                           (double)point / (double)(points - 1U) +
                           phase;
            value += (double)result->component[component].peak_uv *
                     cos(angle);
        }
        waveform_uv[point] = round_s32(value);
    }
    return 0;
}
