#include <stdint.h>
#include "npu.h"
/* CPU reference for valid, disjoint, in-range descriptors. Returns output words. */
uint32_t npu_reference(const npu_desc *desc, int32_t *ram) {
 const uint32_t *d=desc->word;
 uint32_t op=d[0]&255,ow,oh,co,ox,oy,oc,kx,ky,ic,index=0;
 if(op==2) {
  for(index=0;index<d[5]*d[6]*d[7];index++) {
   int x=(int8_t)ram[d[1]+index]; ram[d[2]+index]=x<0 ? 0 : x;
  }
  return index;
 }
 ow=(d[5]+2*d[12]-d[9])/d[11]+1; oh=(d[6]+2*d[12]-d[10])/d[11]+1;
 co=op==1 ? d[8] : d[7];
 for(oy=0;oy<oh;oy++) for(ox=0;ox<ow;ox++) for(oc=0;oc<co;oc++) {
  uint32_t acc=(op==1 && d[4]!=0xffffffff) ? (uint32_t)ram[d[4]+oc] : 0;
  int peak=-128; int64_t value;
  for(ky=0;ky<d[10];ky++) for(kx=0;kx<d[9];kx++) {
   int px=(int)(ox*d[11]+kx)-(int)d[12],py=(int)(oy*d[11]+ky)-(int)d[12];
   if(px<0 || py<0 || px>=(int)d[5] || py>=(int)d[6]) continue;
   if(op==3) {
    int x=(int8_t)ram[d[1]+(py*d[5]+px)*d[7]+oc]; if(x>peak) peak=x;
   } else for(ic=0;ic<d[7];ic++) {
    int x=(int8_t)ram[d[1]+(py*d[5]+px)*d[7]+ic];
    int w=(int8_t)ram[d[3]+((oc*d[10]+ky)*d[9]+kx)*d[7]+ic];
    acc+=(uint32_t)(x*w);
   }
  }
  value=acc<=0x7fffffff ? (int64_t)acc : (int64_t)acc-4294967296LL;
  if(op==3) value=peak;
  else {
   int64_t divisor=1LL<<d[13];
   value=value>=0 ? value/divisor : -((-value+divisor-1)/divisor);
   if((d[0]&256) && value<0) value=0;
   if(value>127) value=127;
   if(value< -128) value=-128;
  }
  ram[d[2]+index++]=(int32_t)value;
 }
 return index;
}

