#ifndef TEST_XIL_IO_H
#define TEST_XIL_IO_H

#include "xil_types.h"

u32 Xil_In32(UINTPTR address);
void Xil_Out32(UINTPTR address, u32 value);

#endif
