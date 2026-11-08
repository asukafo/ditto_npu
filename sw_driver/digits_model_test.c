#include "npu.h"
#include "digits_model.h"
#include "xtime_l.h"
#include "xil_cache.h"
typedef struct {uint32_t state, tested, correct, mismatch, errors, elapsed_us, max_us;} digit_record;
volatile digit_record digits_evidence;
static int32_t converted[1280];
static int load_i8(npu_device *n,uint32_t base,const int8_t *src,unsigned count) {
 unsigned i; for(i=0;i<count;i++) converted[i]=src[i];
 return npu_load(n,base,converted,count);
}
void digits_test_model(npu_device *n) {
 npu_desc conv={{257,0,2048,64,144,8,8,1,8,3,3,1,1,DIGITS_CONV_SHIFT,1,0}};
 npu_desc pool={{3,2048,2560,0,0xffffffff,8,8,8,0,2,2,2,0,0,2,0}};
 npu_desc fc={{1,2560,2816,160,1440,4,4,8,10,4,4,1,0,DIGITS_FC_SHIFT,3,0}};
 unsigned t,i; XTime first,begin,end; uint32_t completion;
 digits_evidence.state=1;
 if(!npu_idle(n) || load_i8(n,64,digits_conv_weights,72) || npu_load(n,144,digits_conv_bias,8) ||
    load_i8(n,160,digits_fc_weights,1280) || npu_load(n,1440,digits_fc_bias,10)) {
  digits_evidence.errors=1; goto failed;
 }
 XTime_GetTime(&first);
 for(t=0;t<DIGITS_TEST_COUNT;t++) {
  int best=-129; unsigned predicted=0; uint32_t duration;
  if(load_i8(n,0,digits_test_inputs+t*64,64)) {digits_evidence.errors++; goto failed;}
  completion=npu_read(n,12); XTime_GetTime(&begin);
  if(npu_submit(n,&conv) || npu_submit(n,&pool) || npu_submit(n,&fc) || npu_wait(n,completion+3,1000000)) {
   digits_evidence.errors++; goto failed;
  }
  XTime_GetTime(&end); duration=(uint32_t)((end-begin)*1000000/COUNTS_PER_SECOND);
  if(duration>digits_evidence.max_us) digits_evidence.max_us=duration;
  for(i=0;i<10;i++) {
   int value=(int32_t)npu_read(n,0x10000+2816*4+i*4);
   if(value!=digits_test_logits[t*10+i]) digits_evidence.mismatch++;
   if(value>best) {best=value; predicted=i;}
  }
  if(predicted==digits_test_labels[t]) digits_evidence.correct++;
  digits_evidence.tested++;
 }
 XTime_GetTime(&end); digits_evidence.elapsed_us=(uint32_t)((end-first)*1000000/COUNTS_PER_SECOND);
 digits_evidence.state=digits_evidence.mismatch ? 3 : 2;
 Xil_DCacheFlush(); return;
failed:
 digits_evidence.state=3; Xil_DCacheFlush();
}
