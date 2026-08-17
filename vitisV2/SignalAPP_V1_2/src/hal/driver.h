#ifndef DRIVER_H
#define DRIVER_H

#include "board.h"
#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define DRIVER_WAIT_TIMEOUT        20000000U

typedef struct {
    int status;
    u32 first_word;
    u32 last_word;
} DriverCaptureInfo;

int Driver_Init(u32 capture_words);
int Driver_CaptureAdc(u32 *buf, u32 words, u32 timeout, DriverCaptureInfo *info);

#ifdef __cplusplus
}
#endif

#endif
