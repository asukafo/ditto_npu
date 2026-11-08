#include "npu_graph.h"
#include "digits_model.h"
#include "xil_cache.h"
#include "xtime_l.h"
#include <string.h>
extern void npu_overlay_initialize(uintptr_t,unsigned);
extern void npu_overlay_digit(uintptr_t,unsigned,unsigned);
#define PRE_BASE 0x43c40000u
#define DEADLINE_US 34980u
#define MIN_ACCEPTED_FRAMES 256u

typedef struct {
 uint32_t state,dataset_tested,dataset_correct,dataset_mismatch,graph_errors;
 uint32_t frames,skipped,feature_races,reference_mismatch,deadline_misses;
 uint32_t max_inference_us,max_end_to_end_us,last_sequence,predicted_digit;
 uint32_t top_score,margin,elapsed_us,last_pixels,preprocess_errors,overruns,npu_errors;
 uint32_t histogram[10];
 int32_t last_logits[10]; uint8_t last_input[64];
} live_record;
volatile live_record live_evidence;
static int8_t dma_input[64] __attribute__((aligned(64)));
static int8_t dma_output[64] __attribute__((aligned(64)));
static int32_t reference_ram[16384];
static npu_desc graph[5];
static uint32_t pre_read(uint32_t off) {return Xil_In32(PRE_BASE+off);}
static void pre_write(uint32_t off,uint32_t value) {Xil_Out32(PRE_BASE+off,value);}
static void cache_flush(const void *p,unsigned bytes) {Xil_DCacheFlushRange((INTPTR)p,bytes);}
static void build_compute_graph(void) {
 npu_desc conv={{257,0,2048,64,144,8,8,1,8,3,3,1,1,DIGITS_CONV_SHIFT,1,0}};
 npu_desc pool={{3,2048,2560,0,0xffffffff,8,8,8,0,2,2,2,0,0,2,0}};
 npu_desc fc={{1,2560,2816,160,1440,4,4,8,10,4,4,1,0,DIGITS_FC_SHIFT,3,0}};
 graph[0]=npu_dma_job((uint32_t)(UINTPTR)dma_input,0,64,0,1,0);
 graph[1]=conv; graph[2]=pool; graph[3]=fc;
 graph[4]=npu_dma_job((uint32_t)(UINTPTR)dma_output,2816,10,1,1,4);
}
static int initialize_model(npu_device *n) {
 npu_desc jobs[4]; unsigned i;
 if(npu_read(n,0)!=0x4e505532 || pre_read(0)!=0x50524532 || pre_read(40)!=0x04000000) return -1;
 cache_flush(digits_conv_weights,sizeof digits_conv_weights);
 cache_flush(digits_conv_bias,sizeof digits_conv_bias);
 cache_flush(digits_fc_weights,sizeof digits_fc_weights);
 cache_flush(digits_fc_bias,sizeof digits_fc_bias);
 jobs[0]=npu_dma_job((uint32_t)(UINTPTR)digits_conv_weights,64,72,0,1,100);
 jobs[1]=npu_dma_job((uint32_t)(UINTPTR)digits_conv_bias,144,8,0,0,101);
 jobs[2]=npu_dma_job((uint32_t)(UINTPTR)digits_fc_weights,160,1280,0,1,102);
 jobs[3]=npu_dma_job((uint32_t)(UINTPTR)digits_fc_bias,1440,10,0,0,103);
 if(npu_graph_run(n,jobs,4,100000)) return -2;
 for(i=0;i<72;i++) reference_ram[64+i]=digits_conv_weights[i];
 for(i=0;i<8;i++) reference_ram[144+i]=digits_conv_bias[i];
 for(i=0;i<1280;i++) reference_ram[160+i]=digits_fc_weights[i];
 for(i=0;i<10;i++) reference_ram[1440+i]=digits_fc_bias[i];
 build_compute_graph(); return 0;
}
static int infer(npu_device *n,const int8_t *input,uint32_t direct_ddr) {
 npu_graph_context context; int status;
 if(!direct_ddr) {
  if(input!=dma_input) memcpy(dma_input,input,64);
  cache_flush(dma_input,64);
 }
 graph[0].word[1]=direct_ddr ? direct_ddr : (uint32_t)(UINTPTR)dma_input;
 /* A private full cache line prevents invalidation from discarding other state. */
 memset(dma_output,0,64); cache_flush(dma_output,64);
 Xil_DCacheInvalidateRange((INTPTR)dma_output,64);
 status=npu_graph_begin(&context,n,graph,5,100000);
 if(direct_ddr && status>=0) {
  npu_reference(&graph[1],reference_ram); npu_reference(&graph[2],reference_ram); npu_reference(&graph[3],reference_ram);
 }
 while(status==1) status=npu_graph_poll(&context);
 if(status) return -1;
 Xil_DCacheInvalidateRange((INTPTR)dma_output,64);
 return 0;
}
static void publish(void) {Xil_DCacheFlushRange((INTPTR)&live_evidence,sizeof live_evidence);}
void npu_live_run(npu_device *n) {
 unsigned t,i,predicted; uint32_t seq,last_seq,base_pre_errors,base_overruns,base_npu_errors;
 XTime live_start,begin,end,now,wait_start;
 live_evidence.state=1;
 if(initialize_model(n)) {live_evidence.graph_errors++; goto failed;}
 // All held-out samples traverse DDR -> NPU graph -> DDR before live operation.
 for(t=0;t<DIGITS_TEST_COUNT;t++) {
  int best=-129; predicted=0;
  if(infer(n,digits_test_inputs+t*64,0)) {live_evidence.graph_errors++; goto failed;}
  for(i=0;i<10;i++) {
   if(dma_output[i]!=digits_test_logits[t*10+i]) live_evidence.dataset_mismatch++;
   if(dma_output[i]>best) {best=dma_output[i]; predicted=i;}
  }
  if(predicted==digits_test_labels[t]) live_evidence.dataset_correct++;
  live_evidence.dataset_tested++;
 }
 if(live_evidence.dataset_mismatch || live_evidence.dataset_correct<335) goto failed;
 npu_overlay_initialize(0x01000000,3);
 last_seq=pre_read(4); pre_write(24,last_seq);
 base_pre_errors=pre_read(12); base_overruns=pre_read(28); base_npu_errors=npu_read(n,0x20);
 XTime_GetTime(&live_start); wait_start=live_start;
 for(;;) {
  int best=-129,second=-129; uint32_t frontend_cycles,duration,end_to_end,bank;
  seq=pre_read(4);
  if(seq==last_seq) {
   XTime_GetTime(&now);
   if(now-wait_start>COUNTS_PER_SECOND*2) {live_evidence.graph_errors++; goto failed;}
   continue;
  }
  XTime_GetTime(&begin);
  if(seq-last_seq!=1) {live_evidence.skipped+=seq-last_seq-1; goto failed;}
  bank=(seq-1)&1;
  live_evidence.last_pixels=pre_read(8); frontend_cycles=pre_read(36);
  Xil_DCacheInvalidateRange(0x04000000+bank*64,64);
  for(i=0;i<64;i++) {
   uint8_t feature=(uint8_t)pre_read(0x100+bank*256+i*4);
   uint8_t from_ddr=*((volatile uint8_t *)(UINTPTR)(0x04000000+bank*64+i));
   if(feature!=from_ddr) live_evidence.reference_mismatch++;
   reference_ram[i]=from_ddr; live_evidence.last_input[i]=feature;
  }
  if(pre_read(4)!=seq) {live_evidence.feature_races++; goto failed;}
  if(infer(n,0,0x04000000+bank*64)) {live_evidence.graph_errors++; goto failed;}
  predicted=0;
  for(i=0;i<10;i++) {
   int v=dma_output[i]; live_evidence.last_logits[i]=v;
   if(v!=reference_ram[2816+i]) live_evidence.reference_mismatch++;
   if(v>best) {second=best; best=v; predicted=i;} else if(v>second) second=v;
  }
  npu_overlay_digit(0x01000000,3,predicted);
  XTime_GetTime(&end); duration=(uint32_t)((end-begin)*1000000/COUNTS_PER_SECOND);
  end_to_end=(frontend_cycles+99)/100+duration;
  if(duration>live_evidence.max_inference_us) live_evidence.max_inference_us=duration;
  if(end_to_end>live_evidence.max_end_to_end_us) live_evidence.max_end_to_end_us=end_to_end;
  if(end_to_end>DEADLINE_US) live_evidence.deadline_misses++;
  live_evidence.preprocess_errors=pre_read(12)-base_pre_errors;
  live_evidence.overruns=pre_read(28)-base_overruns;
  live_evidence.npu_errors=npu_read(n,0x20)-base_npu_errors;
  live_evidence.predicted_digit=predicted; live_evidence.top_score=(uint32_t)best;
  live_evidence.margin=(uint32_t)(best-second); live_evidence.histogram[predicted]++;
  live_evidence.frames++; live_evidence.last_sequence=seq;
  live_evidence.elapsed_us=(uint32_t)((end-live_start)*1000000/COUNTS_PER_SECOND);
  last_seq=seq; pre_write(24,seq); wait_start=end;
  if(live_evidence.last_pixels!=1280*720 || live_evidence.reference_mismatch ||
     live_evidence.preprocess_errors || live_evidence.overruns || live_evidence.npu_errors) goto failed;
  if(live_evidence.deadline_misses) live_evidence.state=3;
  else if(live_evidence.frames>=MIN_ACCEPTED_FRAMES) live_evidence.state=2;
  if((live_evidence.frames&15)==0) publish();
 }
failed:
 live_evidence.state=3; publish();
 // Preserve the video pipeline and failed evidence; do not reuse in-flight DMA buffers.
 for(;;) { }
}



