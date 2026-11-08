#include <stdint.h>
#include "xil_io.h"
#include "xtime_l.h"
#include "xil_cache.h"
#include "xaxivdma_hw.h"
typedef struct {uint32_t state, intervals, elapsed_us, min_us, max_us, missed_steps, vdma_errors;} rate_record;
volatile rate_record camera_rate_evidence;
static unsigned writer(void) {return (Xil_In32(0x43000028)>>24)&31;}
void camera_measure_rate(void) {
 unsigned previous=writer(),next,events=0; XTime start=0,last=0,now,timeout; uint64_t shortest=~(uint64_t)0,longest=0;
 camera_rate_evidence.state=1; XTime_GetTime(&timeout);
 while(events<129) {
  next=writer(); XTime_GetTime(&now);
  if(now-timeout>COUNTS_PER_SECOND*2) {camera_rate_evidence.state=3; break;}
  if(next!=previous) {
   if((next+3-previous)%3!=1) camera_rate_evidence.missed_steps++;
   if(events==0) start=now;
   else {
    uint64_t period=now-last;
    if(period<shortest) shortest=period;
    if(period>longest) longest=period;
   }
   previous=next; last=now; timeout=now; events++;
  }
 }
 if(events==129) {
  camera_rate_evidence.intervals=128;
  camera_rate_evidence.elapsed_us=(uint32_t)((last-start)*1000000/COUNTS_PER_SECOND);
  camera_rate_evidence.min_us=(uint32_t)(shortest*1000000/COUNTS_PER_SECOND);
  camera_rate_evidence.max_us=(uint32_t)(longest*1000000/COUNTS_PER_SECOND);
  camera_rate_evidence.vdma_errors=(Xil_In32(0x43000004)|Xil_In32(0x43000034))&0x4ff1;
  camera_rate_evidence.state=2;
 }
 Xil_DCacheFlush();
}
