#include "npu_graph.h"
#include "xtime_l.h"
npu_desc npu_dma_job(uint32_t address,uint32_t scratch,uint32_t elements,int store,int packed,uint32_t tag) {
 npu_desc d={{0}};
 d.word[0]=0x10u+(store!=0)+((packed!=0)<<8);
 d.word[1]=address; d.word[2]=scratch; d.word[3]=elements; d.word[14]=tag;
 return d;
}
int npu_graph_begin(npu_graph_context *g,npu_device *n,const npu_desc *jobs,uint32_t count,uint32_t timeout_us) {
 if(!g || !jobs || !count || count>65535 || !npu_idle(n)) return -1;
 g->device=n; g->jobs=jobs; g->count=count; g->submitted=0;
 g->start_count=npu_read(n,12); g->initial_errors=npu_read(n,0x20);
 g->timeout_us=timeout_us; g->failed=0; g->active=1;
 npu_write(n,4,npu_read(n,4)|1);
 XTime_GetTime(&g->begin);
 return npu_graph_poll(g);
}
int npu_graph_poll(npu_graph_context *g) {
 uint32_t finished; XTime now; npu_device *n;
 if(!g || !g->active) return -1;
 n=g->device;
 if(npu_read(n,0x20)!=g->initial_errors) g->failed=1;
 while(!g->failed && g->submitted<g->count && !(npu_read(n,8)&2)) {
  if(npu_submit(n,&g->jobs[g->submitted])) break;
  g->submitted++;
  if(npu_read(n,0x20)!=g->initial_errors) g->failed=1;
 }
 finished=npu_read(n,12)-g->start_count;
 if(finished>g->submitted) {g->active=0; return -4;}
 if(finished==g->submitted && npu_idle(n)) {
  if(g->failed) {g->active=0; return -2;}
  if(g->submitted==g->count) {g->active=0; return 0;}
 }
 XTime_GetTime(&now);
 if((now-g->begin)*1000000>=(uint64_t)g->timeout_us*COUNTS_PER_SECOND) {g->active=0; return -3;}
 return 1;
}
int npu_graph_run(npu_device *n,const npu_desc *jobs,uint32_t count,uint32_t timeout_us) {
 npu_graph_context g; int status=npu_graph_begin(&g,n,jobs,count,timeout_us);
 while(status==1) status=npu_graph_poll(&g);
 return status;
}
