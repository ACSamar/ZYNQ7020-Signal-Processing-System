#include "driver.h"

#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xparameters.h"

#define DMA_S2MM_DMACR          0x30U
#define DMA_S2MM_DMASR          0x34U
#define DMA_S2MM_DA             0x48U
#define DMA_S2MM_LENGTH         0x58U

#define DMA_DMACR_RS            0x00000001U
#define DMA_DMACR_RESET         0x00000004U
#define DMA_DMASR_DMA_INT_ERR   0x00000010U
#define DMA_DMASR_DMA_SLV_ERR   0x00000020U
#define DMA_DMASR_DMA_DEC_ERR   0x00000040U
#define DMA_DMASR_IOC_IRQ       0x00001000U
#define DMA_DMASR_DLY_IRQ       0x00002000U
#define DMA_DMASR_ERR_IRQ       0x00004000U
#define DMA_DMASR_IRQ_MASK      (DMA_DMASR_IOC_IRQ | \
                                 DMA_DMASR_DLY_IRQ | \
                                 DMA_DMASR_ERR_IRQ)
#define DMA_DMASR_ERR_MASK      (DMA_DMASR_DMA_INT_ERR | \
                                 DMA_DMASR_DMA_SLV_ERR | \
                                 DMA_DMASR_DMA_DEC_ERR | \
                                 DMA_DMASR_ERR_IRQ)

#if !defined(XPAR_AXI_DMA_0_BASEADDR) && defined(XPAR_XAXIDMA_0_BASEADDR)
#define XPAR_AXI_DMA_0_BASEADDR XPAR_XAXIDMA_0_BASEADDR
#endif

#ifndef XPAR_AXI_DMA_0_BASEADDR
#error "XPAR_AXI_DMA_0_BASEADDR is missing from xparameters.h"
#endif

#if (XPAR_AXI_DMA_0_BASEADDR != 0x40400000U) || \
    (XPAR_AXI_DMA_0_HIGHADDR != 0x4040FFFFU)
#error "ADC AXI DMA address does not match the hardware platform"
#endif

typedef struct {
    UINTPTR base_address;
    const char *name;
} Dma;

static const Dma dma0 = {
    (UINTPTR)XPAR_AXI_DMA_0_BASEADDR,
    "axi_dma_0"
};

static u32 dma_read(const Dma *dma, u32 offset)
{
    return Xil_In32(dma->base_address + (UINTPTR)offset);
}

static void dma_write(const Dma *dma, u32 offset, u32 value)
{
    Xil_Out32(dma->base_address + (UINTPTR)offset, value);
}

static u32 dma_status(const Dma *dma)
{
    return dma_read(dma, DMA_S2MM_DMASR);
}

static int dma_reset(const Dma *dma)
{
    u32 timeout = 1000000U;

    dma_write(dma, DMA_S2MM_DMACR, DMA_DMACR_RESET);
    while ((dma_read(dma, DMA_S2MM_DMACR) & DMA_DMACR_RESET) != 0U) {
        if (timeout == 0U) {
            xil_printf("%s reset timeout\r\n", dma->name);
            return -1;
        }
        timeout--;
    }

    dma_write(dma, DMA_S2MM_DMASR, DMA_DMASR_IRQ_MASK);
    return 0;
}

static int dma_start_s2mm(const Dma *dma, void *buffer, u32 bytes)
{
    u32 status;

    if ((buffer == 0) || (bytes == 0U)) {
        return -1;
    }

    Xil_DCacheFlushRange((INTPTR)buffer, bytes);
    if (dma_reset(dma) != 0) {
        return -2;
    }

    dma_write(dma, DMA_S2MM_DMACR, DMA_DMACR_RS);
    status = dma_status(dma);
    if ((status & DMA_DMASR_ERR_MASK) != 0U) {
        xil_printf("%s S2MM status before start 0x%08x\r\n",
                   dma->name,
                   status);
        return -3;
    }

    dma_write(dma, DMA_S2MM_DA, (u32)((UINTPTR)buffer));
    dma_write(dma, DMA_S2MM_LENGTH, bytes);
    return 0;
}

static int dma_wait(const Dma *dma, u32 timeout)
{
    u32 status = 0U;

    while (timeout > 0U) {
        status = dma_status(dma);
        if ((status & DMA_DMASR_ERR_MASK) != 0U) {
            xil_printf("%s DMA error status 0x%08x\r\n",
                       dma->name,
                       status);
            return -1;
        }
        if ((status & DMA_DMASR_IOC_IRQ) != 0U) {
            dma_write(dma, DMA_S2MM_DMASR, DMA_DMASR_IRQ_MASK);
            return 0;
        }
        timeout--;
    }

    xil_printf("%s DMA wait timeout status 0x%08x\r\n",
               dma->name,
               status);
    return -2;
}

int Driver_Init(u32 capture_words)
{
    int status;

    if (capture_words == 0U) {
        return -1;
    }

    status = Board_CheckId();
    if (status != 0) {
        return status;
    }
    Board_WriteReg(REG_IRQ_STATUS, 0xFFFFFFFFU);
    Board_WriteReg(REG_IRQ_ENABLE,
                   IRQ_CAPTURE_DONE | IRQ_MEAS_DONE | IRQ_ADC_FIFO_FULL);
    Board_SetClockOutputs(1000000U, 2000000U, 4000000U);
    Board_SetMeasurementWindow(capture_words);
    Board_WriteReg(REG_DMA_FRAME_LEN, capture_words);
    Board_SetAdcDspMode(ADC_CTRL_DSP_BYPASS, 16U);
    Board_WriteReg(REG_CTRL, 0U);

    return 0;
}

int Driver_CaptureAdc(u32 *buf, u32 words, u32 timeout, DriverCaptureInfo *info)
{
    u32 bytes;
    int status;

    if ((buf == 0) || (words == 0U)) {
        return -1;
    }

    bytes = words * sizeof(u32);
    buf[0] = 0xDEADBEEFU;
    buf[words - 1U] = 0xDEADBEEFU;

    Board_StopStream();
    Board_SetAdcEnable(0U);
    Board_ResetAdcFifo();
    Board_WriteReg(REG_DMA_FRAME_LEN, words);
    Board_WriteReg(REG_ADC_CTRL, ADC_CTRL_SINGLE_SHOT |
                                      ADC_CTRL_MEAS_EN |
                                      ADC_CTRL_DSP_BYPASS);

    status = dma_start_s2mm(&dma0, buf, bytes);
    if (status == 0) {
        Board_SetAdcEnable(1U);
        Board_StartStream();
        status = dma_wait(&dma0, timeout);
        Board_StopStream();
        Board_SetAdcEnable(0U);
        Xil_DCacheInvalidateRange((INTPTR)buf, bytes);
    }

    if (info != 0) {
        info->status = status;
        info->first_word = buf[0];
        info->last_word = buf[words - 1U];
    }

    return status;
}
