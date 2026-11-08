"""Train an offline digit CNN and export fixed-shift INT8 parameters for the NPU.
Data: sklearn's bundled UCI handwritten digits. Test set is isolated before training.
"""
from pathlib import Path
import json, hashlib, time
import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split

ROOT=Path(__file__).resolve().parent
rng=np.random.RandomState(20261108)

def patches(x):
    p=np.pad(x,((0,0),(1,1),(1,1)),mode='constant')
    s=p.strides
    return np.lib.stride_tricks.as_strided(p,shape=(len(x),8,8,3,3),strides=(s[0],s[1],s[2],s[1],s[2])).reshape(-1,9).copy()

def forward(x,params,cache=False):
    w,b,f,c=params
    a=patches(x)
    z=(a.dot(w)+b).reshape(-1,8,8,8)
    h=np.maximum(z,0)
    candidates=np.stack([h[:,dy::2,dx::2,:] for dy,dx in [(0,0),(0,1),(1,0),(1,1)]],axis=-1)
    pick=candidates.argmax(-1)
    pool=candidates.max(-1).reshape(len(x),128)
    scores=pool.dot(f)+c
    return (scores,(a,z,pick,pool)) if cache else scores

def gradient(x,y,params):
    scores,(a,z,pick,pool)=forward(x,params,True)
    prob=np.exp(scores-scores.max(1,keepdims=True)); prob/=prob.sum(1,keepdims=True)
    loss=-np.log(prob[np.arange(len(y)),y]+1e-30).mean()
    prob[np.arange(len(y)),y]-=1; prob/=len(y)
    gf=pool.T.dot(prob); gc=prob.sum(0)
    gp=prob.dot(params[2].T).reshape(-1,4,4,8)
    gh=np.zeros_like(z)
    for k,(dy,dx) in enumerate([(0,0),(0,1),(1,0),(1,1)]):
        gh[:,dy::2,dx::2,:]=gp*(pick==k)
    gh*=z>0
    gz=gh.reshape(-1,8)
    return float(loss), [a.T.dot(gz),gz.sum(0),gf,gc]

def quant_forward(x,model):
    # Integer-only functional model, arithmetic shifts, signed INT8 saturation.
    q=np.clip(np.rint(x*112),0,127).astype(np.int32)
    a=patches(q).astype(np.int32)
    acc=a.dot(model['conv_w'].astype(np.int32))+model['conv_b']
    h=np.clip(acc>>int(model['conv_shift']),0,127).reshape(-1,8,8,8)
    pool=np.stack([h[:,dy::2,dx::2,:] for dy,dx in [(0,0),(0,1),(1,0),(1,1)]],-1).max(-1).reshape(len(x),128)
    logits=pool.dot(model['fc_w'].astype(np.int32))+model['fc_b']
    return np.clip(logits>>int(model['fc_shift']),-128,127).astype(np.int8)

def evaluate(x,y,params):
    return float(np.mean(np.concatenate([forward(x[i:i+128],params).argmax(1) for i in range(0,len(x),128)])==y))

def main():
    data=load_digits()
    x=(data.images/16).astype(np.float32); y=data.target.astype(np.int64)
    all_indices=np.arange(len(y))
    trainval,test=train_test_split(all_indices,test_size=0.2,random_state=20261108,stratify=y)
    train,val=train_test_split(trainval,test_size=0.15,random_state=20261109,stratify=y[trainval])
    params=[(rng.randn(9,8)*np.sqrt(2/9)).astype(np.float32),np.zeros(8,np.float32),
            (rng.randn(128,10)*0.08).astype(np.float32),np.zeros(10,np.float32)]
    velocity=[np.zeros_like(p) for p in params]
    best=0; best_params=None; history=[]; began=time.time()
    for epoch in range(160):
        order=rng.permutation(train); losses=[]
        lr=0.035*(0.35 if epoch>=90 else 1)*(0.35 if epoch>=130 else 1)
        for offset in range(0,len(order),64):
            idx=order[offset:offset+64]
            loss,grads=gradient(x[idx],y[idx],params); losses.append(loss)
            for i in range(4):
                grads[i]+=0.0001*params[i]
                velocity[i]*=0.9; velocity[i]-=lr*grads[i]; params[i]+=velocity[i]
        accuracy=evaluate(x[val],y[val],params)
        history.append(dict(epoch=epoch+1,loss=float(np.mean(losses)),validation_accuracy=accuracy))
        if accuracy>best:
            best=accuracy; best_params=[p.copy() for p in params]
        if epoch%10==0: print('TRAIN',epoch+1,'loss',history[-1]['loss'],'validation',accuracy,flush=True)
    params=best_params
    w,b,f,c=params
    conv_scale=120/max(abs(w.min()),abs(w.max()))
    conv_w=np.clip(np.rint(w*conv_scale),-127,127).astype(np.int8)
    conv_b=np.rint(b*112*conv_scale).astype(np.int32)
    # Calibration uses validation only, never the held-out test set.
    _,(_,z,_,_)=forward(x[val],params,True)
    max_activation=max(float(np.percentile(np.maximum(z,0),99.9)),0.01)
    conv_shift=max(0,int(np.ceil(np.log2(max_activation*112*conv_scale/120))))
    activation_scale=112*conv_scale/(2**conv_shift)
    fc_scale=120/max(abs(f.min()),abs(f.max()))
    fc_w=np.clip(np.rint(f*fc_scale),-127,127).astype(np.int8)
    fc_b=np.rint(c*activation_scale*fc_scale).astype(np.int32)
    scores=forward(x[val],params)
    fc_shift=max(0,int(np.ceil(np.log2(float(np.max(abs(scores)))*activation_scale*fc_scale/120))))
    model=dict(conv_w=conv_w,conv_b=conv_b,fc_w=fc_w,fc_b=fc_b,conv_shift=np.array(conv_shift),fc_shift=np.array(fc_shift))
    np.savez(ROOT/'digits_int8.npz',**model)
    np.savez(ROOT/'digits_float.npz',**dict(zip(['conv_w','conv_b','fc_w','fc_b'],params)))
    qpred=quant_forward(x[test],model).argmax(1)
    report=dict(dataset='sklearn bundled UCI optical handwritten digits',seed=20261108,
      input_shape=[8,8,1],architecture=['conv3x3/8/pad1','relu','maxpool2','conv4x4/10'],
      train_count=len(train),validation_count=len(val),test_count=len(test),
      validation_accuracy=best,float_test_accuracy=evaluate(x[test],y[test],params),
      int8_test_accuracy=float(np.mean(qpred==y[test])),conv_shift=conv_shift,fc_shift=fc_shift,
      macs_per_inference=8*8*8*9+10*4*4*8,seconds=time.time()-began,
      dataset_sha256=hashlib.sha256(data.images.tobytes()+data.target.tobytes()).hexdigest())
    # HWC output and O,KY,KX,IC weights; FC maps directly to 4x4 convolution.
    conv_weights=conv_w.T.reshape(-1)
    fc_weights=fc_w.T.reshape(-1)
    def c_array(name,values,ctype):
        return 'static const '+ctype+' '+name+'['+str(values.size)+'] __attribute__((aligned(64)))={'+','.join(str(int(v)) for v in values.reshape(-1))+'};\n'
    header='#ifndef DIGITS_MODEL_H\n#define DIGITS_MODEL_H\n#include <stdint.h>\n'
    header+='#define DIGITS_CONV_SHIFT '+str(conv_shift)+'\n#define DIGITS_FC_SHIFT '+str(fc_shift)+'\n'
    header+=c_array('digits_conv_weights',conv_weights,'int8_t')+c_array('digits_conv_bias',conv_b,'int32_t')
    header+=c_array('digits_fc_weights',fc_weights,'int8_t')+c_array('digits_fc_bias',fc_b,'int32_t')
    # All held-out test examples are exported for independent ARM/hardware verification.
    inputs=np.rint(x[test]*112).astype(np.int8)
    logits=quant_forward(x[test],model)
    np.savez(ROOT/'digits_test_vectors.npz',inputs=inputs,labels=y[test],logits=logits,test_indices=test)
    header+=c_array('digits_test_inputs',inputs,'int8_t')+c_array('digits_test_labels',y[test],'uint8_t')
    header+=c_array('digits_test_logits',logits,'int8_t')+'#define DIGITS_TEST_COUNT '+str(len(test))+'\n#endif\n'
    (ROOT/'digits_model.h').write_text(header)
    (ROOT/'training_report.json').write_text(json.dumps(report,indent=2))
    (ROOT/'training_history.json').write_text(json.dumps(history,indent=2))
    print('MODEL_REPORT',json.dumps(report),flush=True)
    if report['int8_test_accuracy']<0.93: raise RuntimeError('INT8 held-out accuracy below 93%; model not accepted')
if __name__=='__main__': main()

