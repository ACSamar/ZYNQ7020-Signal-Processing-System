#ifndef TEST_XUARTPS_HW_H
#define TEST_XUARTPS_HW_H

#include "xil_types.h"

u32 XUartPs_IsReceiveData(UINTPTR base_address);
u8 XUartPs_RecvByte(UINTPTR base_address);

#endif
