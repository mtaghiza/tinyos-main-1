
 #include "fixedPointUtils.h"
 #include "CXSchedulerDebug.h"
 #include "CXNetwork.h"
module SkewCorrectionC {
  provides interface SkewCorrection;
} implementation {
  am_addr_t other = AM_BROADCAST_ADDR;

  uint32_t lastTimestamp = 0;
  uint32_t lastCapture = 0;
  uint32_t lastOriginFrame = 0;
  int32_t cumulativeTpf = 0;
  #ifndef TPF_DECIMAL_PLACES 
  #define TPF_DECIMAL_PLACES 16
  #endif
  
  //alpha is also fixed point.
  #define FP_1 (1L << TPF_DECIMAL_PLACES)

  #ifndef SKEW_EWMA_ALPHA_INVERSE
  #define SKEW_EWMA_ALPHA_INVERSE 2
  #endif

  int32_t alpha = FP_1 / SKEW_EWMA_ALPHA_INVERSE;

  #ifndef TPF_DECIMAL_PLACES 
  #define TPF_DECIMAL_PLACES 16
  #endif

  #define sfpMult(a, b) fpMult(a, b, TPF_DECIMAL_PLACES)
  #define stoFP(a) toFP(a, TPF_DECIMAL_PLACES)
  #define stoInt(a) toInt(a, TPF_DECIMAL_PLACES)
  int32_t lastDelta;
  task void printResults(){
    printf_SKEW(" Cumulative TPF: 0x%lx last delta: %li\r\n", 
      cumulativeTpf, lastDelta);
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
      uint32_t otherTS, uint32_t originFrame, 
      uint32_t myTS){
    if (otherId == TOS_NODE_ID || otherTS == INVALID_TIMESTAMP || myTS == INVALID_TIMESTAMP){
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
      if (lastTimestamp != 0 && lastCapture != 0 && lastOriginFrame != 0){
        int32_t remoteElapsed = otherTS - lastTimestamp;
        int32_t localElapsed = myTS - lastCapture;
        int32_t framesElapsed = originFrame - lastOriginFrame;
        //positive = we are slow = require shift forward
        int32_t delta = remoteElapsed - localElapsed;
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
    }else{
      return INVALID_FRAME;
    }
  }

  command uint32_t SkewCorrection.referenceTime(am_addr_t otherId){
    if (otherId == other && lastCapture != INVALID_TIMESTAMP)
    {
      return lastCapture;
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
