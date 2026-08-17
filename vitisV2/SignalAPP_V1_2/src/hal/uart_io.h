#ifndef UART_IO_H
#define UART_IO_H

#include "xil_types.h"

typedef struct {
    u32 base_address;
} Console;

typedef struct {
    u32 base_address;
} SerialScreen;

int Console_Init(Console *console);
int Console_TryReadByte(const Console *console, u8 *byte);

int SerialScreen_Init(SerialScreen *screen);
int SerialScreen_TryReadByte(const SerialScreen *screen, u8 *byte);
int SerialScreen_SendCommand(const SerialScreen *screen,
                             const char *command);
int SerialScreen_SendCurveData(const SerialScreen *screen,
                               u32 component_id,
                               u32 channel,
                               const u8 *data,
                               u32 points);
int SerialScreen_SetText(const SerialScreen *screen,
                         const char *component,
                         const char *value);

#endif
