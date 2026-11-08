#ifndef NPU_GRAPH_H
#define NPU_GRAPH_H
#include "npu.h"
#include "xtime_l.h"
typedef struct {
 npu_device *device; const npu_desc *jobs;
 uint32_t count,submitted,start_count,initial_errors,timeout_us;
 XTime begin; int failed,active;
} npu_graph_context;
/* poll: 1=pending, 0=complete, negative=failed. A timeout does not cancel DMA;
 * keep buffers owned until npu_idle() or an explicit system reset. */
int npu_graph_begin(npu_graph_context *g,npu_device *n,const npu_desc *jobs,uint32_t count,uint32_t timeout_us);
int npu_graph_poll(npu_graph_context *g);
/* Exclusive caller. Timeout preserves buffer ownership until the engine is quiescent.
 * A failed graph invalidates every result; accepted jobs are drained, not abandoned. */
int npu_graph_run(npu_device *n,const npu_desc *jobs,uint32_t count,uint32_t timeout_us);
npu_desc npu_dma_job(uint32_t address,uint32_t scratch,uint32_t elements,int store,int packed,uint32_t tag);
#endif
