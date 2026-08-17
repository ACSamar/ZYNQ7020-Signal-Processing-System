#ifndef G_QUESTION_MODE_H
#define G_QUESTION_MODE_H

#include "g_amplitude_calibration.h"

#include <string.h>

typedef enum {
    G_QUESTION_1 = 0,
    G_QUESTION_2 = 1,
    G_QUESTION_3 = 2
} GQuestionMode;

static inline u32 GQuestionMode_IsValid(GQuestionMode mode)
{
    return (mode <= G_QUESTION_3) ? 1U : 0U;
}

static inline int GQuestionMode_ParseCommand(const char *command,
                                             GQuestionMode *mode)
{
    if ((command == NULL) || (mode == NULL)) {
        return -1;
    }
    if (strcmp(command, "MODE Q1") == 0) {
        *mode = G_QUESTION_1;
        return 0;
    }
    if (strcmp(command, "MODE Q2") == 0) {
        *mode = G_QUESTION_2;
        return 0;
    }
    if (strcmp(command, "MODE Q3") == 0) {
        *mode = G_QUESTION_3;
        return 0;
    }
    return -1;
}

static inline GAmplitudeGainMode GQuestionMode_GainMode(
    GQuestionMode mode)
{
    return (mode == G_QUESTION_3) ?
        G_AMPLITUDE_GAIN_10P4X :
        G_AMPLITUDE_GAIN_20P4X;
}

static inline const char *GQuestionMode_PageName(GQuestionMode mode)
{
    static const char *page_name[3] = {
        "q1", "q2", "q3"
    };

    if (GQuestionMode_IsValid(mode) == 0U) {
        return "q1";
    }
    return page_name[(u32)mode];
}

static inline const char *GQuestionMode_Name(GQuestionMode mode)
{
    static const char *name[3] = {
        "Q1", "Q2", "Q3"
    };

    if (GQuestionMode_IsValid(mode) == 0U) {
        return "UNKNOWN";
    }
    return name[(u32)mode];
}

#endif
