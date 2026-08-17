#ifndef SLOT_H
#define SLOT_H

#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define SLOT_BASE             0x40030000U

#define SLOT_REG_ID           0x00U
#define SLOT_REG_CTRL         0x04U
#define SLOT_REG_STATUS       0x08U
#define SLOT_REG_SAMPLES      0x0CU
#define SLOT_REG_FRAMES       0x10U
#define SLOT_REG_CFG0         0x40U

#define SLOT_CTRL_ENABLE      0x01U
#define SLOT_CTRL_BYPASS      0x02U
#define SLOT_CTRL_RESET       0x04U

typedef struct {
    UINTPTR base;
} slot_t;

void slot_init(slot_t *slot, UINTPTR base);
void slot_run(const slot_t *slot);
void slot_bypass(const slot_t *slot);
void slot_reset(const slot_t *slot);
void slot_set(const slot_t *slot, u32 index, u32 value);
u32 slot_get(const slot_t *slot, u32 index);
u32 slot_status(const slot_t *slot);
u32 slot_samples(const slot_t *slot);
u32 slot_frames(const slot_t *slot);

#ifdef __cplusplus
}
#endif

#endif
