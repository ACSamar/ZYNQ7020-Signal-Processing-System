#include "uart_io.h"

#include <stdio.h>

#include "xil_io.h"
#include "xparameters.h"
#include "xuartps_hw.h"

#if defined(XPAR_XUARTPS_0_BASEADDR)
#define CONSOLE_BASE_ADDRESS ((u32)XPAR_XUARTPS_0_BASEADDR)
#elif defined(XPAR_UART1_BASEADDR)
#define CONSOLE_BASE_ADDRESS ((u32)XPAR_UART1_BASEADDR)
#else
#error "PS UART1 must be enabled for the recording shield console"
#endif

#define SCREEN_BASE_ADDRESS       0x42C00000U
#define UART_RX_FIFO_OFFSET       0x00000000U
#define UART_TX_FIFO_OFFSET       0x00000004U
#define UART_STATUS_OFFSET        0x00000008U
#define UART_CONTROL_OFFSET       0x0000000CU
#define UART_STATUS_RX_VALID      0x00000001U
#define UART_STATUS_TX_FULL       0x00000008U
#define UART_CONTROL_RESET_TX     0x00000001U
#define UART_CONTROL_RESET_RX     0x00000002U
#define UART_TX_TIMEOUT_LOOPS     1000000U
#define UART_RX_TIMEOUT_LOOPS    10000000U
#define TJC_TRANSPARENT_READY          0xFEU
#define TJC_TRANSPARENT_FINISHED       0xFDU
#define SCREEN_RX_PENDING_CAPACITY      64U

static u8 g_screen_rx_pending[SCREEN_RX_PENDING_CAPACITY];
static u32 g_screen_rx_pending_read;
static u32 g_screen_rx_pending_write;
static u32 g_screen_rx_pending_count;

static int screen_read_hw_byte(const SerialScreen *screen, u8 *byte)
{
    if ((screen == 0) || (byte == 0)) {
        return -1;
    }
    if ((Xil_In32((UINTPTR)screen->base_address +
                  UART_STATUS_OFFSET) &
         UART_STATUS_RX_VALID) == 0U) {
        return 0;
    }
    *byte = (u8)(Xil_In32((UINTPTR)screen->base_address +
                          UART_RX_FIFO_OFFSET) & 0xFFU);
    return 1;
}

static int screen_preserve_rx_byte(u8 byte)
{
    if (g_screen_rx_pending_count >= SCREEN_RX_PENDING_CAPACITY) {
        return -1;
    }
    g_screen_rx_pending[g_screen_rx_pending_write] = byte;
    g_screen_rx_pending_write =
        (g_screen_rx_pending_write + 1U) %
        SCREEN_RX_PENDING_CAPACITY;
    g_screen_rx_pending_count++;
    return 0;
}

static int screen_write_byte(const SerialScreen *screen, u8 byte)
{
    u32 remaining = UART_TX_TIMEOUT_LOOPS;

    while ((Xil_In32((UINTPTR)screen->base_address +
                     UART_STATUS_OFFSET) &
            UART_STATUS_TX_FULL) != 0U) {
        if (remaining-- == 0U) {
            return -1;
        }
    }
    Xil_Out32((UINTPTR)screen->base_address + UART_TX_FIFO_OFFSET,
              (u32)byte);
    return 0;
}

static int screen_write_text(const SerialScreen *screen, const char *text)
{
    if ((screen == 0) || (text == 0)) {
        return -1;
    }
    while (*text != '\0') {
        if (screen_write_byte(screen, (u8)*text) != 0) {
            return -1;
        }
        text++;
    }
    return 0;
}

static int screen_end_command(const SerialScreen *screen)
{
    if ((screen_write_byte(screen, 0xFFU) != 0) ||
        (screen_write_byte(screen, 0xFFU) != 0) ||
        (screen_write_byte(screen, 0xFFU) != 0)) {
        return -1;
    }
    return 0;
}

static int screen_wait_response(const SerialScreen *screen, u8 code)
{
    u32 remaining = UART_RX_TIMEOUT_LOOPS;
    u32 state = 0U;

    while (remaining-- != 0U) {
        u8 byte;
        int status = screen_read_hw_byte(screen, &byte);

        if (status < 0) {
            return -1;
        }
        if (status == 0) {
            continue;
        }
        if (state == 0U) {
            if (byte == code) {
                state = 1U;
            } else if (screen_preserve_rx_byte(byte) != 0) {
                return -1;
            }
        } else if (byte == 0xFFU) {
            state++;
            if (state == 4U) {
                return 0;
            }
        } else {
            if (byte == code) {
                state = 1U;
            } else {
                state = 0U;
                if (screen_preserve_rx_byte(byte) != 0) {
                    return -1;
                }
            }
        }
    }
    return -1;
}

int Console_Init(Console *console)
{
    if (console == 0) {
        return -1;
    }
    console->base_address = CONSOLE_BASE_ADDRESS;
    return 0;
}

int Console_TryReadByte(const Console *console, u8 *byte)
{
    if ((console == 0) || (byte == 0)) {
        return -1;
    }
    if (XUartPs_IsReceiveData((UINTPTR)console->base_address) == 0U) {
        return 0;
    }
    *byte = XUartPs_RecvByte((UINTPTR)console->base_address);
    return 1;
}

int SerialScreen_Init(SerialScreen *screen)
{
    if (screen == 0) {
        return -1;
    }
    screen->base_address = SCREEN_BASE_ADDRESS;
    g_screen_rx_pending_read = 0U;
    g_screen_rx_pending_write = 0U;
    g_screen_rx_pending_count = 0U;
    Xil_Out32((UINTPTR)screen->base_address + UART_CONTROL_OFFSET,
              UART_CONTROL_RESET_TX | UART_CONTROL_RESET_RX);
    return 0;
}

int SerialScreen_TryReadByte(const SerialScreen *screen, u8 *byte)
{
    if ((screen == 0) || (byte == 0)) {
        return -1;
    }
    if (g_screen_rx_pending_count != 0U) {
        *byte = g_screen_rx_pending[g_screen_rx_pending_read];
        g_screen_rx_pending_read =
            (g_screen_rx_pending_read + 1U) %
            SCREEN_RX_PENDING_CAPACITY;
        g_screen_rx_pending_count--;
        return 1;
    }
    return screen_read_hw_byte(screen, byte);
}

int SerialScreen_SendCommand(const SerialScreen *screen,
                             const char *command)
{
    if (screen_write_text(screen, command) != 0) {
        return -1;
    }
    return screen_end_command(screen);
}

int SerialScreen_SendCurveData(const SerialScreen *screen,
                               u32 component_id,
                               u32 channel,
                               const u8 *data,
                               u32 points)
{
    char command[32];
    u32 point;

    if ((screen == 0) || (data == 0) || (points == 0U)) {
        return -1;
    }
    (void)snprintf(command,
                   sizeof(command),
                   "addt %u,%u,%u",
                   (unsigned int)component_id,
                   (unsigned int)channel,
                   (unsigned int)points);
    if (SerialScreen_SendCommand(screen, command) != 0) {
        return -1;
    }
    if (screen_wait_response(screen, TJC_TRANSPARENT_READY) != 0) {
        return -1;
    }
    for (point = 0U; point < points; point++) {
        if (screen_write_byte(screen, data[point]) != 0) {
            return -1;
        }
    }
    return screen_wait_response(screen, TJC_TRANSPARENT_FINISHED);
}

int SerialScreen_SetText(const SerialScreen *screen,
                         const char *component,
                         const char *value)
{
    if ((screen_write_text(screen, component) != 0) ||
        (screen_write_text(screen, ".txt=\"") != 0) ||
        (screen_write_text(screen, value) != 0) ||
        (screen_write_text(screen, "\"") != 0)) {
        return -1;
    }
    return screen_end_command(screen);
}
