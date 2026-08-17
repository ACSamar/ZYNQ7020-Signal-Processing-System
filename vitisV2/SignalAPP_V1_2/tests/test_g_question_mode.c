#include "g_question_mode.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    GQuestionMode mode;

    assert(GQuestionMode_ParseCommand("MODE Q1", &mode) == 0);
    assert(mode == G_QUESTION_1);
    assert(GQuestionMode_GainMode(mode) ==
           G_AMPLITUDE_GAIN_20P4X);
    assert(strcmp(GQuestionMode_PageName(mode), "q1") == 0);

    assert(GQuestionMode_ParseCommand("MODE Q2", &mode) == 0);
    assert(mode == G_QUESTION_2);
    assert(GQuestionMode_GainMode(mode) ==
           G_AMPLITUDE_GAIN_20P4X);
    assert(strcmp(GQuestionMode_PageName(mode), "q2") == 0);

    assert(GQuestionMode_ParseCommand("MODE Q3", &mode) == 0);
    assert(mode == G_QUESTION_3);
    assert(GQuestionMode_GainMode(mode) ==
           G_AMPLITUDE_GAIN_10P4X);
    assert(strcmp(GQuestionMode_PageName(mode), "q3") == 0);

    assert(GQuestionMode_ParseCommand("MODE Q4", &mode) != 0);
    assert(GQuestionMode_ParseCommand(NULL, &mode) != 0);
    assert(GQuestionMode_ParseCommand("MODE Q1", NULL) != 0);

    puts("g_question_mode tests passed");
    return 0;
}
