#ifndef BOARD_H
#define BOARD_H

#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define AXI_CLK_HZ               50000000U
#define ADC_CLK_HZ               35000000U
#define DAC_CLK_HZ              125000000U

#define REG_ID                  0x000U
#define REG_CTRL                0x004U
#define REG_CLK_CTRL            0x010U
#define REG_CLK_STEP_CH1        0x014U
#define REG_CLK_STEP_CH2        0x018U
#define REG_CLK_STEP_CH3        0x01CU
#define REG_CLK_LOAD            0x020U
#define REG_DAC_SRC             0x030U
#define REG_DMA_FRAME_LEN       0x034U
#define REG_ADC_CTRL            0x038U
#define REG_DAC0_PHASE_INC      0x040U
#define REG_DAC0_AMP_OFFSET     0x044U
#define REG_DAC1_PHASE_INC      0x048U
#define REG_DAC1_AMP_OFFSET     0x04CU
#define REG_MEAS_WINDOW         0x050U
#define REG_IRQ_STATUS          0x068U
#define REG_IRQ_ENABLE          0x06CU
#define REG_DAC0_PHASE_OFFSET   0x070U
#define REG_DAC1_PHASE_OFFSET   0x074U
#define REG_FIFO_CTRL           0x078U
#define REG_DAC_PHASE_LOAD      0x07CU

#define ID_EXPECTED             0x21080003U

#define CTRL_ADC_EN             0x00000001U
#define CTRL_DAC0_EN            0x00000002U
#define CTRL_DAC1_EN            0x00000004U
#define CTRL_STREAM_EN          0x00000008U
#define CTRL_GAIN_10P4X         0x00000010U

#define ADC_CTRL_SINGLE_SHOT    0x00000001U
#define ADC_CTRL_MEAS_EN        0x00000002U
#define ADC_CTRL_DSP_BYPASS     0x00000000U
#define ADC_CTRL_LMS_MU_SHIFT   8U

#define DAC_SRC_WAVE            2U

#define WAVE_SINE               0U

#define IRQ_CAPTURE_DONE        0x00000001U
#define IRQ_MEAS_DONE           0x00000002U
#define IRQ_ADC_FIFO_FULL       0x00000004U

#define FIFO_CTRL_ADC_RESET     0x00000001U

void Board_WriteReg(u32 offset, u32 value);
u32 Board_MakeDacAmpOffset(u32 amplitude, u32 offset);

int Board_CheckId(void);
void Board_SetClockOutputs(u32 ch1_hz, u32 ch2_hz, u32 ch3_hz);
void Board_SetDacWaveFull(u32 dac0_hz, u32 dac1_hz,
                          u32 dac0_wave, u32 dac1_wave,
                          u32 dac0_phase_deg_x100, u32 dac1_phase_deg_x100);
void Board_SetAdcDspMode(u32 mode, u32 lms_mu);
void Board_SetMeasurementWindow(u32 sample_count);
void Board_StartStream(void);
void Board_StopStream(void);
void Board_SetAdcEnable(u32 enable);
void Board_SetDacEnable(u32 dac0_enable, u32 dac1_enable);
void Board_SetDac0Constant(u32 code);
void Board_ResetAdcFifo(void);
void Board_LoadDacPhase(void);

#ifdef __cplusplus
}
#endif

#endif
