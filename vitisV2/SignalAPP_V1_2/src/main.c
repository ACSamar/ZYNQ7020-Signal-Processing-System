#include "app.h"

#include "sleep.h"
#include "xil_printf.h"

int main(void)
{
    int status = App_Init();

    if (status != 0) {
        xil_printf("Hardware initialization failed.\r\n");
        while (1) {
            sleep(1U);
        }
    }

    App_Run();
    return 0;
}
