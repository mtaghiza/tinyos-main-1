
 #include "fixedPointUtils.h"
 #include "CXSchedulerDebug.h"
 #include "CXNetwork.h"
 #include "CXScheduler.h"
 #include "SkewCorrection.h"
module SimpleSkewCorrectionP {
  provides interface SkewCorrection;
} implementation {

  am_addr_t other = AM_BROADCAST_ADDR;

  uint32_t lastTimestamp = 0;
  uint32_t lastCapture = 0;
  uint32_t lastOriginFrame = 0;

  #define TICK_SCALE 1024L
  //1024 ticks in a frame
  //50ppm error max
  //0.0512 ticks/per frame max
  //*1024 = 52.5 ticks_scaled/per frame
  #define MAX_SKEW 53
  int32_t cumulativeTpf_s = 0;

  int32_t lastDelta;
  uint32_t lastFramesElapsed;

  uint32_t selfReferenceFrame = INVALID_TIMESTAMP;
  uint32_t selfReferenceTime = INVALID_FRAME;

  task void printResults(){
    cdbg(SKEW, " Cumulative TPF_s: %li last delta: %li over %lu\r\n", 
      cumulativeTpf_s, lastDelta, lastFramesElapsed);
//    cdbg(SKEW, " @32 %li @64 %li @128 %li @256 %li @512 %li @1024 %li\r\n",
//      call SkewCorrection.getCorrection(other, 32L),
//      call SkewCorrection.getCorrection(other, 64L),
//      call SkewCorrection.getCorrection(other, 128L),
//      call SkewCorrection.getCorrection(other, 256L),
//      call SkewCorrection.getCorrection(other, 512L),
//      call SkewCorrection.getCorrection(other, 1024L));

    call SkewCorrection.getCorrection(other, 256L);
//    printf("%li * %li = %li (%lx) -> %li (%li)\r\n", 
//      -2L, 32L, 
//      -2L*32L, -2L*32L,
//      (-2L*32L)/TICK_SCALE, (-2L*32L)/TICK_SCALE);
  }


  command error_t SkewCorrection.addMeasurement(am_addr_t otherId, 
      bool isSynched, uint32_t otherTS, uint32_t originFrame, 
      uint32_t myTS){
    printf("add\r\n");
    if (otherId == TOS_NODE_ID){
      printf("self\r\n");
      selfReferenceTime = otherTS;
      selfReferenceFrame = originFrame;
      return SUCCESS;
    }else if (otherTS == INVALID_TIMESTAMP || myTS == INVALID_TIMESTAMP 
        || originFrame == INVALID_FRAME || otherTS == lastTimestamp 
        || myTS == lastCapture ){
      printf("inval\r\n");
      return EINVAL;
    }else{
      printf("other\r\n");
      if (otherId != other){
        printf("new\r\n");
        //we only track one master: if we switch masters for whatever
        //reason, need to clear it out and start over again.
        other = otherId;
        lastTimestamp = 0;
        lastCapture = 0;
        lastOriginFrame = 0;
        cumulativeTpf_s = 0;
      }
      if (lastTimestamp != 0 && lastCapture != 0 
          && lastOriginFrame != 0 
          && isSynched && otherTS > lastTimestamp){
        int32_t remoteElapsed_t = (otherTS - lastTimestamp);
        int32_t localElapsed_t = (myTS - lastCapture);
        int32_t framesElapsed = originFrame - lastOriginFrame;
        //positive = we are fast = require shift back = add to wakeup
        //time. Otherwise, we need to negate the result before
        //applying it.
        int32_t delta_s = (localElapsed_t - remoteElapsed_t)*TICK_SCALE;
  
        int32_t tpf_s = delta_s / framesElapsed;
        if ( tpf_s > MAX_SKEW || tpf_s < (-1* MAX_SKEW)){
          cwarn(SKEW, "SKEW EXCEEDED\r\n");
        } else {
//          int32_t c_r = (cumulativeTpf_s > 0? 1L: -1L)*(BIT0 & cumulativeTpf_s);
//          int32_t m_r = (tpf_s > 0? 1L: -1L)*(BIT0 & tpf_s);
//          int32_t c_r = (cumulativeTpf_s + (1L << 0))>>1; 
//          int32_t m_r = (tpf_s + (1L << 0))>>1; 
//          //next EWMA step
//          //n.b. we let TPF = 0 initially to keep things simple. In
//          //general, we should be reasonably close to this. 
//          
//          //this doesn't do rounding very nicely: e.g. if you givethe
//          //same tpf_s many times, it never quite reaches it.
//          printf("c %li m %li: %li + %li\r\n",
//            cumulativeTpf_s, tpf_s,
//            cumulativeTpf_s >>1, tpf_s>>1);
//          
//          printf("c_r %li m_r %li\r\n",
//            cumulativeTpf_s & BIT0,
//            tpf_s & BIT0);
//
//          printf("c_r' %li m_r' %li\r\n",
//            c_r, m_r);
//          cumulativeTpf_s = (c_r >> 1) + (m_r >> 1);
//          printf(" = %li\r\n", cumulativeTpf_s);
          cumulativeTpf_s = ((cumulativeTpf_s) >> 1) + ((tpf_s) >>1) ;
        }
        //TODO: DEBUG remove
        lastDelta = delta_s;
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
      int32_t framesElapsed){
    if (otherId == other){
      int32_t c_s = (cumulativeTpf_s * framesElapsed);
      int32_t c_t = c_s / TICK_SCALE;
      int32_t c_r = c_s / (TICK_SCALE/2);
//      printf("c(%li, %li)= %li (%lx) -t-> %li (%lx) r: %li (%lx)\r\n",
//        cumulativeTpf_s, framesElapsed,
//        c_s, c_s,
//        c_t, c_t,
//        c_r, c_r);
      return c_t;
    } else {
      return 0;
    }
  }
  
}
