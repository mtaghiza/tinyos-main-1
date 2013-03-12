generic module PriorityQueueP(typedef queue_t){
  provides interface Queue<queue_t>;
  uses interface Queue<queue_t> as SubQueue;
  uses interface Compare<queue_t>;
} implementation {

  command bool Queue.empty(){
    return call SubQueue.empty();
  }

  command uint8_t Queue.size(){
    return call SubQueue.size();
  }

  command uint8_t Queue.maxSize(){
    return call SubQueue.maxSize();
  }

  command error_t Queue.enqueue(queue_t newVal){
    return call SubQueue.enqueue(newVal);
  }

  command queue_t Queue.head(){
    uint8_t i;
    queue_t minElement = call SubQueue.head();
    for (i = 0; i < call Queue.size(); i++){
      //leq(a,b) : a <= b
      if (call Compare.leq(call SubQueue.element(i), minElement)){
        minElement = call SubQueue.element(i);
      }
    }
    return minElement;
  }

  command queue_t Queue.dequeue(){
    uint8_t i;
    queue_t minElement = call Queue.head();
    //dequeue and check each item: if it equals head, return it.
    //otherwise, re-enqueue it.
    for (i = 0; i < call Queue.size(); i++){
      queue_t test = call SubQueue.dequeue();
      if (call Compare.leq(test, minElement)){
        return test;
      }else{
        call SubQueue.enqueue(test);
      }
    }
    //Should not happen if this is a valid implementation of compare!
    return minElement;
  }

  command queue_t Queue.element(uint8_t idx){
    uint8_t numEnqueued = 0;
    queue_t aux[call Queue.size()];
    queue_t ret;
    //pop first idx-1 elements from head of queue and push onto aux
    //stack
    while (numEnqueued < idx){
      aux[numEnqueued] = call Queue.dequeue();
    }
    //the head of the queue is now the idx'th element
    ret = call Queue.dequeue();
    //pop contents of aux stack  and re-enqueue.
    while(numEnqueued){
      call Queue.enqueue(aux[numEnqueued -1]);
      numEnqueued --;
    }
    return ret;
  }
}
