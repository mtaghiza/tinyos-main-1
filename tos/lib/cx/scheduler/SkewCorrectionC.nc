
 #include "fixedPointUtils.h"
 #include "CXSchedulerDebug.h"
 #include "CXNetwork.h"
 #include "SkewCorrection.h"
module SkewCorrectionC {
  provides interface SkewCorrection;
} implementation {

  am_addr_t other = AM_BROADCAST_ADDR;

  uint32_t lastTimestamp = 0;
  uint32_t lastCapture = 0;
  uint32_t lastOriginFrame = 0;
  int32_t cumulativeTpf = 0;

  int32_t alpha = FP_1 / SKEW_EWMA_ALPHA_INVERSE;
  int32_t lastDelta;
  uint32_t lastFramesElapsed;

  uint32_t selfReferenceFrame = INVALID_TIMESTAMP;
  uint32_t selfReferenceTime = INVALID_FRAME;

  task void printResults(){
    printf_SKEW(" Cumulative TPF: 0x%lx last delta: %li over %lu\r\n", 
      cumulativeTpf, lastDelta, lastFramesElapsed);
    printf_SKEW("  @50 %li @51 %li @100 %li @200 %li @300 %li @320 %li @400 %li @500 %li @1000 %li\r\n",
      stoInt(cumulativeTpf*50),
      stoInt(cumulativeTpf*51),
      stoInt(cumulativeTpf*100),
      stoInt(cumulativeTpf*200),
      stoInt(cumulativeTpf*300),
      stoInt(cumulativeTpf*320),
      stoInt(cumulativeTpf*400),
      stoInt(cumulativeTpf*500),
      stoInt(cumulativeTpf*1000));
  }


  command error_t SkewCorrection.addMeasurement(am_addr_t otherId, 
      bool isSynched, uint32_t otherTS, uint32_t originFrame, 
      uint32_t myTS){
    if (otherId == TOS_NODE_ID){
      selfReferenceTime = otherTS;
      selfReferenceFrame = originFrame;
      return SUCCESS;
    }else if (otherTS == INVALID_TIMESTAMP || myTS == INVALID_TIMESTAMP){
      return SUCCESS;
    }else{
      if (otherId != other){
        //we only track one master: if we switch masters for whatever
        //reason, need to clear it out and start over again.
        other = otherId;
        lastTimestamp = 0;
        lastCapture = 0;
        lastOriginFrame = 0;
        cumulativeTpf = 0;
      }
      if (lastTimestamp != 0 && lastCapture != 0 && lastOriginFrame != 0 && isSynched){
        int32_t remoteElapsed = otherTS - lastTimestamp;
        int32_t localElapsed = myTS - lastCapture;
        int32_t framesElapsed = originFrame - lastOriginFrame;
        //positive = we are fast = require shift back = add to wakeup
        //time. Otherwise, we need to negate the result before
        //applying it.
        int32_t delta = localElapsed - remoteElapsed;
        //this is fixed point, TPF_DECIMAL_PLACES bits after decimal
        int32_t deltaFP = (delta << TPF_DECIMAL_PLACES);
  
        int32_t tpf = deltaFP / framesElapsed;
  
        //next EWMA step
        //n.b. we let TPF = 0 initially to keep things simple. In
        //general, we should be reasonably close to this. 
        cumulativeTpf = sfpMult(cumulativeTpf, (FP_1 - alpha)) 
          + sfpMult(tpf, alpha);
        //TODO: DEBUG remove
        lastDelta = delta;
        lastFramesElapsed = framesElapsed;
        post printResults();
      }
      lastTimestamp = otherTS;
      lastCapture = myTS;
      lastOriginFrame = originFrame;
      return SUCCESS;
    }
  }

  command uint32_t SkewCorrection.referenceFrame(am_addr_t otherId){
    if (otherId == other && lastOriginFrame != INVALID_FRAME)
    {
      return lastOriginFrame;
    }else if (otherId == TOS_NODE_ID){
      return selfReferenceFrame;
    } else {
      return INVALID_FRAME;
    }
  }

  command uint32_t SkewCorrection.referenceTime(am_addr_t otherId){
    if (otherId == other && lastCapture != INVALID_TIMESTAMP)
    {
      return lastCapture;
    } else if (otherId == TOS_NODE_ID){
      return selfReferenceTime;
    }else{
      return INVALID_TIMESTAMP;
    }
  }

  command int32_t SkewCorrection.getCorrection(am_addr_t otherId, 
      uint32_t framesElapsed){
    if (otherId == other){
      return stoInt(cumulativeTpf*framesElapsed);
    } else {
      return 0;
    }
  }
  
}
