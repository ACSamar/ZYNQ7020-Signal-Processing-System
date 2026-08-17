#include "slot.h"

#include "xil_io.h"

static u32 slot_read(const slot_t *slot, u32 offset)
{
    if (slot == 0) {
        return 0U;
    }

    return Xil_In32(slot->base + offset);
}

static void slot_write(const slot_t *slot, u32 offset, u32 value)
{
    if (slot != 0) {
        Xil_Out32(slot->base + offset, value);
    }
}

void slot_init(slot_t *slot, UINTPTR base)
{
    if (slot != 0) {
        slot->base = base;
    }
}

void slot_run(const slot_t *slot)
{
    slot_write(slot, SLOT_REG_CTRL, SLOT_CTRL_ENABLE);
}

void slot_bypass(const slot_t *slot)
{
    slot_write(slot, SLOT_REG_CTRL, SLOT_CTRL_ENABLE | SLOT_CTRL_BYPASS);
}

void slot_reset(const slot_t *slot)
{
    u32 ctrl = slot_read(slot, SLOT_REG_CTRL);

    slot_write(slot, SLOT_REG_CTRL, ctrl | SLOT_CTRL_RESET);
    slot_write(slot, SLOT_REG_CTRL, ctrl & ~SLOT_CTRL_RESET);
}

void slot_set(const slot_t *slot, u32 index, u32 value)
{
    if (index < 8U) {
        slot_write(slot, SLOT_REG_CFG0 + (index * sizeof(u32)), value);
    }
}

u32 slot_get(const slot_t *slot, u32 index)
{
    if (index >= 8U) {
        return 0U;
    }

    return slot_read(slot, SLOT_REG_CFG0 + (index * sizeof(u32)));
}

u32 slot_status(const slot_t *slot)
{
    return slot_read(slot, SLOT_REG_STATUS);
}

u32 slot_samples(const slot_t *slot)
{
    return slot_read(slot, SLOT_REG_SAMPLES);
}

u32 slot_frames(const slot_t *slot)
{
    return slot_read(slot, SLOT_REG_FRAMES);
}
