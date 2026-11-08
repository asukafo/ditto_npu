#include "npu.h"
/* Run on an otherwise idle NPU. Nonzero return identifies the failing phase. */
int npu_selftest(npu_device *n) {
 int32_t input[9]={-4,-3,-2,-1,0,1,2,3,4};
 int32_t weights[4]={1,1,1,1};
 int32_t expected[4]={-8,-4,4,8};
 npu_desc d={{1,0,128,64,0xffffffff,3,3,1,1,2,2,1,0,0,0x1234,0}};
 uint32_t i,completed;
 if((npu_read(n,0)!=0x4e505531 && npu_read(n,0)!=0x4e505532) || !npu_idle(n)) return 1;
 npu_write(n,4,0);
 if(npu_load(n,0,input,9) || npu_load(n,64,weights,4)) return 2;
 completed=npu_read(n,12);
 if(npu_submit(n,&d)) return 3;
 npu_write(n,4,1);
 if(npu_wait(n,completed+1,1000000)) return 4;
 for(i=0;i<4;i++) if((int32_t)npu_read(n,0x10200+4*i)!=expected[i]) return 5;
 d.word[0]=2; d.word[1]=128; d.word[2]=256; d.word[5]=2; d.word[6]=2;
 if(npu_submit(n,&d) || npu_wait(n,completed+2,1000000)) return 6;
 for(i=0;i<4;i++) if((int32_t)npu_read(n,0x10400+4*i)!=(expected[i]<0 ? 0 : expected[i])) return 7;
 d.word[0]=3; d.word[1]=256; d.word[2]=384;
 if(npu_submit(n,&d) || npu_wait(n,completed+3,1000000)) return 8;
 if(npu_read(n,0x10600)!=8) return 9;
 return 0;
}

