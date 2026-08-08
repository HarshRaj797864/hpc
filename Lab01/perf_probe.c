#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/perf_event.h>

static int po(struct perf_event_attr *a){ return syscall(__NR_perf_event_open,a,0,-1,-1,0); }

static void try1(const char*name, unsigned type, unsigned long long cfg){
    struct perf_event_attr a; memset(&a,0,sizeof a);
    a.size=sizeof a; a.type=type; a.config=cfg;
    a.disabled=1; a.exclude_kernel=1; a.exclude_hv=1;
    int fd=po(&a);
    printf("%-22s : %s\n", name, fd<0 ? strerror(errno) : "OK");
    if(fd>=0) close(fd);
}
int main(void){
    try1("HW cpu-cycles",   PERF_TYPE_HARDWARE, PERF_COUNT_HW_CPU_CYCLES);
    try1("HW instructions", PERF_TYPE_HARDWARE, PERF_COUNT_HW_INSTRUCTIONS);
    try1("HW cache-refs",   PERF_TYPE_HARDWARE, PERF_COUNT_HW_CACHE_REFERENCES);
    try1("HW branch-misses",PERF_TYPE_HARDWARE, PERF_COUNT_HW_BRANCH_MISSES);
    try1("SW task-clock",   PERF_TYPE_SOFTWARE, PERF_COUNT_SW_TASK_CLOCK);
    try1("SW page-faults",  PERF_TYPE_SOFTWARE, PERF_COUNT_SW_PAGE_FAULTS);
    return 0;
}
