#include "uart_io.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

#define SCREEN_BASE_ADDRESS 0x42C00000U
#define UART_RX_FIFO_OFFSET  0x00000000U
#define UART_TX_FIFO_OFFSET  0x00000004U
#define UART_STATUS_OFFSET   0x00000008U
#define UART_CONTROL_OFFSET  0x0000000CU

static u8 g_rx_data[32];
static u32 g_rx_length;
static u32 g_rx_index;
static u8 g_tx_data[256];
static u32 g_tx_length;

u32 Xil_In32(UINTPTR address)
{
    if (address == SCREEN_BASE_ADDRESS + UART_STATUS_OFFSET) {
        return (g_rx_index < g_rx_length) ? 1U : 0U;
    }
    if (address == SCREEN_BASE_ADDRESS + UART_RX_FIFO_OFFSET) {
        assert(g_rx_index < g_rx_length);
        return g_rx_data[g_rx_index++];
    }
    return 0U;
}

void Xil_Out32(UINTPTR address, u32 value)
{
    if (address == SCREEN_BASE_ADDRESS + UART_TX_FIFO_OFFSET) {
        assert(g_tx_length < sizeof(g_tx_data));
        g_tx_data[g_tx_length++] = (u8)value;
    } else {
        assert(address == SCREEN_BASE_ADDRESS + UART_CONTROL_OFFSET);
    }
}

u32 XUartPs_IsReceiveData(UINTPTR base_address)
{
    (void)base_address;
    return 0U;
}

u8 XUartPs_RecvByte(UINTPTR base_address)
{
    (void)base_address;
    return 0U;
}

static void queue_response(u8 code)
{
    assert(g_rx_length + 4U <= sizeof(g_rx_data));
    g_rx_data[g_rx_length++] = code;
    g_rx_data[g_rx_length++] = 0xFFU;
    g_rx_data[g_rx_length++] = 0xFFU;
    g_rx_data[g_rx_length++] = 0xFFU;
}

static void queue_screen_command(const char *command)
{
    size_t length = strlen(command);

    assert(g_rx_length + length + 3U <= sizeof(g_rx_data));
    memcpy(&g_rx_data[g_rx_length], command, length);
    g_rx_length += (u32)length;
    g_rx_data[g_rx_length++] = 0xFFU;
    g_rx_data[g_rx_length++] = 0xFFU;
    g_rx_data[g_rx_length++] = 0xFFU;
}

int main(void)
{
    static const char command[] = "addt 1,0,5";
    static const u8 preserved_commands[] = {
        'M', 'O', 'D', 'E', ' ', 'Q', '3',
        0xFFU, 0xFFU, 0xFFU,
        'W', 'A', 'V', 'E', '1',
        0xFFU, 0xFFU, 0xFFU
    };
    static const u8 curve_data[5] = {
        0U, 1U, 128U, 254U, 255U
    };
    SerialScreen screen;
    u8 preserved_byte;
    u32 preserved_index;
    u32 command_length = (u32)strlen(command);

    assert(SerialScreen_Init(&screen) == 0);
    queue_screen_command("MODE Q3");
    queue_response(0xFEU);
    queue_screen_command("WAVE1");
    queue_response(0xFDU);
    assert(SerialScreen_SendCurveData(&screen,
                                      1U,
                                      0U,
                                      curve_data,
                                      5U) == 0);
    assert(g_rx_index == g_rx_length);
    assert(g_tx_length == command_length + 3U +
           sizeof(curve_data));
    assert(memcmp(g_tx_data, command, command_length) == 0);
    assert(g_tx_data[command_length] == 0xFFU);
    assert(g_tx_data[command_length + 1U] == 0xFFU);
    assert(g_tx_data[command_length + 2U] == 0xFFU);
    assert(memcmp(&g_tx_data[command_length + 3U],
                  curve_data,
                  sizeof(curve_data)) == 0);
    for (preserved_index = 0U;
         preserved_index < sizeof(preserved_commands);
         preserved_index++) {
        assert(SerialScreen_TryReadByte(&screen,
                                        &preserved_byte) == 1);
        assert(preserved_byte ==
               preserved_commands[preserved_index]);
    }
    assert(SerialScreen_TryReadByte(&screen,
                                    &preserved_byte) == 0);
    puts("TJC curve transfer tests passed");
    return 0;
}
