#ifndef BREAKFAST_MEM_H
#define BREAKFAST_MEM_H

void*  memcpy(void *dest, const void *src, size_t n){
  uint8_t i;
  uint8_t* d =(uint8_t*)dest;
  uint8_t* s =(uint8_t*)src;
  for (i =0; i< n; i++){
    d[i]=s[i];
  }
  return dest;
}

void* memset(void *dest, int c, size_t n){
  uint8_t i;
  uint8_t* d = (uint8_t*)dest;
  for(i=0; i < n; i++){
    d[i] = c;
  }
  return dest;
}
#endif
