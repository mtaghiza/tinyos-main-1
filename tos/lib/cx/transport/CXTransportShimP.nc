module CXTransportShimP {
  provides interface Send;
  provides interface Receive;
  uses interface Send as BroadcastSend;
  uses interface Receive as BroadcastReceive;
  uses interface Send as UnicastSend;
  uses interface Receive as UnicastReceive;
} implementation {
}
