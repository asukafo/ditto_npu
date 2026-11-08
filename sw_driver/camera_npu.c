#include "npu.h"
#include "xaxivdma.h"
#include "xaxivdma_hw.h"
#include "xil_cache.h"
#include "xtime_l.h"

typedef struct {
 uint32_t state, failure, frames_verified, mismatches, retries;
 uint32_t input_checksum, output_checksum, elapsed_us, last_cycles;
} camera_evidence;
volatile camera_evidence npu_camera_evidence;
static int32_t reference_ram[16384];
static unsigned write_frame(XAxiVdma *v) {
 return (Xil_In32(v->BaseAddr+XAXIVDMA_PARKPTR_OFFSET)&XAXIVDMA_PARKPTR_WRTSTR_MASK)>>XAXIVDMA_WRTSTR_SHIFT;
}
/* Capture from the preceding completed frame. Require unchanged writer index and
 * <500 us copying so the ring cannot wrap during the copy at this video size.
 * With 720p RGB888, even the 64-bit 150 MHz HP0 bus takes >2 ms per full frame.
 * Cache invalidation is per sampled line. No HDMI frame buffer is written. */
static int snapshot(XAxiVdma *v,UINTPTR framebuffer) {
 unsigned attempt,y,x,current,previous; XTime begin,end;
 if(v->MaxNumFrames<2) return -1;
 for(attempt=0;attempt<32;attempt++) {
  current=write_frame(v); if(current>=(unsigned)v->MaxNumFrames) return -1;
  previous=(current+v->MaxNumFrames-1)%v->MaxNumFrames;
  XTime_GetTime(&begin);
  for(y=0;y<16;y++) {
   UINTPTR line=framebuffer+previous*1280*720*3+(y*720/16)*1280*3;
   Xil_DCacheInvalidateRange(line,1280*3);
   for(x=0;x<16;x++) {
    volatile uint8_t *p=(volatile uint8_t *)(line+(x*1280/16)*3);
    reference_ram[y*16+x]=((int)p[0]+p[1]+p[2])/3-128;
   }
  }
  XTime_GetTime(&end);
  if(write_frame(v)==current && end-begin<COUNTS_PER_SECOND/2000) return 0;
  npu_camera_evidence.retries++;
 }
 return -1;
}
int npu_camera_test(npu_device *n,XAxiVdma *v,UINTPTR framebuffer) {
 static const int32_t weights[9]={-1,-1,-1,-1,8,-1,-1,-1,-1};
 npu_desc conv={{257,0,512,256,0xffffffff,16,16,1,1,3,3,1,1,3,10,0}};
 npu_desc pool={{3,512,1024,0,0xffffffff,16,16,1,1,2,2,2,0,0,11,0}};
 unsigned current,changes=0,i,frame; uint32_t completed,errors; XTime begin,end;
 npu_camera_evidence.state=1;
 current=write_frame(v); XTime_GetTime(&begin);
 while(changes<2) {
  unsigned next=write_frame(v); XTime_GetTime(&end);
  if(next!=current) {current=next; changes++;}
  if(end-begin>COUNTS_PER_SECOND*2) return 1;
 }
 for(frame=0;frame<3;frame++) {
  current=write_frame(v); XTime_GetTime(&begin);
  while(write_frame(v)==current) {
   XTime_GetTime(&end); if(end-begin>COUNTS_PER_SECOND*2) return 1;
  }
  if(snapshot(v,framebuffer)) return 2;
  npu_camera_evidence.input_checksum=0;
  for(i=0;i<256;i++) npu_camera_evidence.input_checksum=npu_camera_evidence.input_checksum*33+(uint32_t)reference_ram[i];
  if(npu_load(n,0,reference_ram,256) || npu_load(n,256,weights,9)) return 3;
  for(i=0;i<9;i++) reference_ram[256+i]=weights[i];
  npu_reference(&conv,reference_ram); npu_reference(&pool,reference_ram);
  completed=npu_read(n,12); errors=npu_read(n,0x20); XTime_GetTime(&begin);
  if(npu_submit(n,&conv) || npu_submit(n,&pool) || npu_wait(n,completed+2,1000000)) return 4;
  XTime_GetTime(&end);
  if(npu_read(n,0x20)!=errors) return 5;
  npu_camera_evidence.elapsed_us=(uint32_t)((end-begin)*1000000/COUNTS_PER_SECOND);
  npu_camera_evidence.last_cycles=npu_read(n,0x1c);
  npu_camera_evidence.output_checksum=0;
  for(i=0;i<256;i++) if((int32_t)npu_read(n,0x10800+4*i)!=reference_ram[512+i]) npu_camera_evidence.mismatches++;
  for(i=0;i<64;i++) {
   int32_t value=(int32_t)npu_read(n,0x11000+4*i);
   if(value!=reference_ram[1024+i]) npu_camera_evidence.mismatches++;
   npu_camera_evidence.output_checksum=npu_camera_evidence.output_checksum*33+(uint32_t)value;
  }
  if(npu_camera_evidence.mismatches) return 6;
  npu_camera_evidence.frames_verified++;
 }
 npu_camera_evidence.state=2; return 0;
}

