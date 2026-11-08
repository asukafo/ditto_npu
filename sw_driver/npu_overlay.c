#include <stdint.h>
#include "xil_io.h"
#include "xil_cache.h"
#include "xil_mmu.h"
/* Latest prediction, drawn only on a completed camera buffer. The source tensors
 * come from the pre-overlay video tap, so this display annotation cannot feed back
 * into the classifier. RGB888 channel order is irrelevant for white/black glyphs. */
static int overlay_initialized=0;
void npu_overlay_initialize(uintptr_t frame_base,unsigned frames) {
 uintptr_t section,end=frame_base+frames*1280*720*3;
 if(overlay_initialized) return;
 for(section=frame_base;section<end;section+=0x100000) Xil_SetTlbAttributes(section,NORM_NONCACHE);
 overlay_initialized=1;
}
void npu_overlay_digit(uintptr_t frame_base,unsigned frames,unsigned digit) {
 static const uint8_t font[10][7]={
  {14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},
  {30,1,1,14,1,1,30},{2,6,10,18,31,2,2},{31,16,16,30,1,1,30},
  {14,16,16,30,17,17,14},{31,1,2,4,8,8,8},{14,17,17,14,17,17,14},
  {14,17,17,15,1,1,14}};
 unsigned writer=(Xil_In32(0x43000028)>>24)&31;
 unsigned slot,y,x;
 if(frames<2 || writer>=frames || digit>9) return;
 slot=(writer+frames-1)%frames;
 for(y=0;y<56;y++) {
  uintptr_t address=frame_base+slot*1280*720*3+(y+16)*1280*3+16*3;
  volatile uint32_t *row=(volatile uint32_t *)address;
  for(x=0;x<5;x++) {
   uint32_t v=(font[digit][y/8]>>(4-x))&1 ? 0xffffffffu : 0u;
   unsigned word;
   /* Eight RGB888 pixels = 24 aligned bytes = six 32-bit stores. */
   for(word=0;word<6;word++) row[x*6+word]=v;
  }
 }
}



