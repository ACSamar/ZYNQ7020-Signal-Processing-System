#ifndef TEST_SLEEP_H
#define TEST_SLEEP_H

static inline int usleep(unsigned int useconds)
{
    (void)useconds;
    return 0;
}

#endif
