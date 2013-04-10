module CXTransportDispatchP {
  provides interface CXRequestQueue[uint8_t tp];
  uses interface CXRequestQueue as SubCXRQ;

  provides interface SplitControl;
  uses interface SplitControl as SubSplitControl;

  uses interface CXTransportPacket;
} implementation {
  //splitcontrol:
  // - commands and events should be passed through
  // - at SubSplitControl.startDone, notify CXRequestQueue clients
  //   that we're up 

  //CXRequestQueue: 
  // - pass them on down
  
  //SubCXRQ:
  // - txHandled: dispatch based on transport protocol
  // - rxHandled, SUCCESS
  //   - didReceive = TRUE:  dispatch based on tp, set next to
  //     (tp + 1 )% tp_range
  //   - didReceive = FALSE: set next to (next+1)%tp_range
  // - rxHandled, EBUSY
  //   - dispatch to next, set next to (next+1)%tp_range
}
