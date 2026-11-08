#ifndef NPU_H
#define NPU_H
#include <stdint.h>
#include "xil_io.h"
/* MMIO mapping must be Device/non-cacheable. All RAM offsets are WORD indices. */
typedef struct { uint32_t word[16]; } npu_desc;
typedef struct { UINTPTR base; } npu_device;
static inline uint32_t npu_read(npu_device *n, uint32_t off) { return Xil_In32(n->base+off); }
static inline void npu_write(npu_device *n, uint32_t off,uint32_t v) { Xil_Out32(n->base+off,v); }
/* Caller owns the device exclusively; load RAM only when busy=0 and queued=0. */
static inline int npu_idle(npu_device *n) { return !(npu_read(n,8)&1) && !npu_read(n,0x24); }
static inline int npu_load(npu_device *n,uint32_t offset,const int32_t *data,uint32_t count) {
 uint32_t i;
 if(offset>16384 || count>16384-offset || !npu_idle(n)) return -1;
 for(i=0;i<count;i++) npu_write(n,0x10000+4*(offset+i),(uint32_t)data[i]);
 return 0;
}
static inline int npu_submit(npu_device *n,const npu_desc *d) {
 uint32_t i;
 if(npu_read(n,8)&2) return -1;
 for(i=0;i<16;i++) npu_write(n,0x100+i*4,d->word[i]);
 npu_write(n,0x10,1); return 0;
}
/* Bounded poll; limit counts MMIO polls, not time. Completion counter wraps mod 2^32. */
static inline int npu_wait(npu_device *n,uint32_t completed,uint32_t limit) {
 while(limit--) if(npu_read(n,12)==completed) return npu_read(n,0x18) ? -2 : 0;
 return -1;
}
int npu_selftest(npu_device *n);
/* Valid descriptors only; reference operates on a software scratch RAM image. */
uint32_t npu_reference(const npu_desc *desc, int32_t *ram);
#endif
