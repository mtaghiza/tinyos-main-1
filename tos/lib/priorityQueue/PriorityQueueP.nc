/*
 * Copyright (c) 2014 Johns Hopkins University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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
