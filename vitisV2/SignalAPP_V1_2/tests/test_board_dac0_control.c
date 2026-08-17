#include "board.h"
#include "xparameters.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

#define TEST_BASE_ADDRESS XPAR_ACM2108_0_BASEADDR
#define TEST_REGISTER_COUNT 64U

static u32 g_registers[TEST_REGISTER_COUNT];

u32 Xil_In32(UINTPTR address)
{
    u32 offset;

    assert(address >= TEST_BASE_ADDRESS);
    offset = (u32)(address - TEST_BASE_ADDRESS);
    assert((offset & 0x3U) == 0U);
    assert((offset / 4U) < TEST_REGISTER_COUNT);
    return g_registers[offset / 4U];
}

void Xil_Out32(UINTPTR address, u32 value)
{
    u32 offset;

    assert(address >= TEST_BASE_ADDRESS);
    offset = (u32)(address - TEST_BASE_ADDRESS);
    assert((offset & 0x3U) == 0U);
    assert((offset / 4U) < TEST_REGISTER_COUNT);
    g_registers[offset / 4U] = value;
}

static u32 register_value(u32 offset)
{
    return g_registers[offset / 4U];
}

int main(void)
{
    u32 initial_dac_src = 0x00000A0DU;
    u32 expected_dac_src =
        (initial_dac_src & ~0x000000F3U) | DAC_SRC_WAVE;

    memset(g_registers, 0, sizeof(g_registers));
    g_registers[REG_CTRL / 4U] = CTRL_ADC_EN | CTRL_STREAM_EN;
    g_registers[REG_DAC_SRC / 4U] = initial_dac_src;

    Board_SetDac0Constant(128U);
    assert(register_value(REG_DAC0_PHASE_INC) == 0U);
    assert(register_value(REG_DAC0_PHASE_OFFSET) == 0U);
    assert(register_value(REG_DAC0_AMP_OFFSET) ==
           Board_MakeDacAmpOffset(0U, 128U));
    assert(register_value(REG_DAC_SRC) == expected_dac_src);
    assert(register_value(REG_CTRL) ==
           (CTRL_ADC_EN | CTRL_STREAM_EN | CTRL_DAC0_EN));

    Board_SetDac0Constant(255U);
    assert(register_value(REG_DAC0_AMP_OFFSET) ==
           Board_MakeDacAmpOffset(0U, 255U));

    Board_SetDac0Constant(300U);
    assert(register_value(REG_DAC0_AMP_OFFSET) ==
           Board_MakeDacAmpOffset(0U, 255U));

    puts("board DAC0 control tests passed");
    return 0;
}
