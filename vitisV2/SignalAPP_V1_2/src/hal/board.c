#include "board.h"

#include "sleep.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xparameters.h"

#ifndef XPAR_ACM2108_0_BASEADDR
#error "XPAR_ACM2108_0_BASEADDR is missing from xparameters.h"
#endif

#if (XPAR_ACM2108_0_BASEADDR != 0x40000000U) || \
    (XPAR_ACM2108_0_HIGHADDR != 0x4000FFFFU)
#error "ACM2108 AXI address does not match the TESTV1_7 hardware platform"
#endif

#define BASEADDR ((UINTPTR)XPAR_ACM2108_0_BASEADDR)

static u32 read_reg(u32 offset)
{
    return Xil_In32(BASEADDR + (UINTPTR)offset);
}

void Board_WriteReg(u32 offset, u32 value)
{
    Xil_Out32(BASEADDR + (UINTPTR)offset, value);
}

static u32 make_step(u32 target_hz, u32 clock_hz)
{
    u64 numerator;

    if (clock_hz == 0U) {
        return 0U;
    }

    numerator = ((u64)target_hz << 32) + ((u64)clock_hz / 2ULL);
    return (u32)(numerator / (u64)clock_hz);
}

u32 Board_MakeDacAmpOffset(u32 amplitude, u32 offset)
{
    if (amplitude > 255U) {
        amplitude = 255U;
    }
    if (offset > 255U) {
        offset = 255U;
    }

    return ((offset & 0xFFU) << 8) | (amplitude & 0xFFU);
}

static u32 make_dac_src(u32 dac0_src, u32 dac1_src, u32 dac0_wave, u32 dac1_wave)
{
    return ((dac0_src & 0x3U) << 0) |
           ((dac1_src & 0x3U) << 2) |
           ((dac0_wave & 0xFU) << 4) |
           ((dac1_wave & 0xFU) << 8);
}

static u32 make_phase_offset(u32 phase_deg_x100)
{
    u64 numerator;

    phase_deg_x100 = phase_deg_x100 % 36000U;
    numerator = ((u64)phase_deg_x100 << 32) / 36000ULL;
    return (u32)numerator;
}

int Board_CheckId(void)
{
    u32 id = read_reg(REG_ID);

    if (id != ID_EXPECTED) {
        xil_printf("ACM2108V2 ID mismatch: read 0x%08x expected 0x%08x\r\n",
                   id,
                   ID_EXPECTED);
        return -1;
    }

    return 0;
}

void Board_SetClockOutputs(u32 ch1_hz, u32 ch2_hz, u32 ch3_hz)
{
    Board_WriteReg(REG_CLK_STEP_CH1, make_step(ch1_hz, AXI_CLK_HZ));
    Board_WriteReg(REG_CLK_STEP_CH2, make_step(ch2_hz, AXI_CLK_HZ));
    Board_WriteReg(REG_CLK_STEP_CH3, make_step(ch3_hz, AXI_CLK_HZ));
    Board_WriteReg(REG_CLK_CTRL, 0x7U);
    Board_WriteReg(REG_CLK_LOAD, 0x7U);
}

static void set_dac_wave(u32 dac0_hz, u32 dac1_hz, u32 dac0_wave, u32 dac1_wave)
{
    Board_WriteReg(REG_DAC0_PHASE_INC, make_step(dac0_hz, DAC_CLK_HZ));
    Board_WriteReg(REG_DAC1_PHASE_INC, make_step(dac1_hz, DAC_CLK_HZ));
    Board_WriteReg(REG_DAC0_AMP_OFFSET, Board_MakeDacAmpOffset(96U, 128U));
    Board_WriteReg(REG_DAC1_AMP_OFFSET, Board_MakeDacAmpOffset(96U, 128U));
    Board_WriteReg(REG_DAC_SRC,
                   make_dac_src(DAC_SRC_WAVE,
                                DAC_SRC_WAVE,
                                dac0_wave,
                                dac1_wave));
}

void Board_SetDacWaveFull(u32 dac0_hz, u32 dac1_hz,
                          u32 dac0_wave, u32 dac1_wave,
                          u32 dac0_phase_deg_x100, u32 dac1_phase_deg_x100)
{
    Board_WriteReg(REG_DAC0_PHASE_OFFSET,
                   make_phase_offset(dac0_phase_deg_x100));
    Board_WriteReg(REG_DAC1_PHASE_OFFSET,
                   make_phase_offset(dac1_phase_deg_x100));
    set_dac_wave(dac0_hz, dac1_hz, dac0_wave, dac1_wave);
}

void Board_SetAdcDspMode(u32 mode, u32 lms_mu)
{
    u32 ctrl = ADC_CTRL_MEAS_EN;

    ctrl |= (mode & 0x30U);
    ctrl |= ((lms_mu & 0xFFU) << ADC_CTRL_LMS_MU_SHIFT);
    Board_WriteReg(REG_ADC_CTRL, ctrl);
}

void Board_SetMeasurementWindow(u32 sample_count)
{
    if (sample_count == 0U) {
        sample_count = 1U;
    }

    Board_WriteReg(REG_MEAS_WINDOW, sample_count);
}

void Board_StartStream(void)
{
    u32 ctrl = read_reg(REG_CTRL);

    Board_WriteReg(REG_CTRL, ctrl | CTRL_STREAM_EN);
}

void Board_StopStream(void)
{
    u32 ctrl = read_reg(REG_CTRL);

    Board_WriteReg(REG_CTRL, ctrl & ~CTRL_STREAM_EN);
}

void Board_SetAdcEnable(u32 enable)
{
    u32 ctrl = read_reg(REG_CTRL);

    if (enable != 0U) {
        ctrl |= CTRL_ADC_EN;
    } else {
        ctrl &= ~CTRL_ADC_EN;
    }
    Board_WriteReg(REG_CTRL, ctrl);
}

void Board_SetDacEnable(u32 dac0_enable, u32 dac1_enable)
{
    u32 ctrl = read_reg(REG_CTRL);

    ctrl &= ~(CTRL_DAC0_EN | CTRL_DAC1_EN);
    if (dac0_enable != 0U) {
        ctrl |= CTRL_DAC0_EN;
    }
    if (dac1_enable != 0U) {
        ctrl |= CTRL_DAC1_EN;
    }
    Board_WriteReg(REG_CTRL, ctrl);
}

void Board_SetDac0Constant(u32 code)
{
    u32 dac_src = read_reg(REG_DAC_SRC);

    if (code > 255U) {
        code = 255U;
    }

    dac_src &= ~0x000000F3U;
    dac_src |= DAC_SRC_WAVE;
    Board_WriteReg(REG_DAC0_PHASE_INC, 0U);
    Board_WriteReg(REG_DAC0_PHASE_OFFSET, 0U);
    Board_WriteReg(REG_DAC0_AMP_OFFSET,
                   Board_MakeDacAmpOffset(0U, code));
    Board_WriteReg(REG_DAC_SRC, dac_src);
    Board_SetDacEnable(1U, 0U);
}

void Board_ResetAdcFifo(void)
{
    Board_WriteReg(REG_FIFO_CTRL, FIFO_CTRL_ADC_RESET);
    usleep(1U);
}

void Board_LoadDacPhase(void)
{
    Board_WriteReg(REG_DAC_PHASE_LOAD, 1U);
    usleep(1U);
}
