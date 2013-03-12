generic configuration PriorityQueueC(typedef queue_t, 
    uint8_t QUEUE_SIZE){
  provides interface Queue<queue_t>;
  uses interface Compare<queue_t>;
} implementation {
  components new QueueC(queue_t, QUEUE_SIZE);

  components new PriorityQueueP(queue_t);

  PriorityQueueP.SubQueue -> QueueC;
  Queue = PriorityQueueP;
  Compare = PriorityQueueP;
}
