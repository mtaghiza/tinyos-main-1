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


 #include "TLVStorage.h"
 #include "InternalFlashFunctions.h"
 

generic module TLVStorageP(uint16_t tlv_start, 
    uint16_t tlv_copy, 
    uint8_t tlv_len){
  provides interface TLVStorage;
  provides interface Init;
  uses interface TLVUtils;
} implementation {
  int16_t computeChecksum(void* tlvs);

//  void debugTLV(void* tlvs_){
//    tlv_entry_t* e;
//    uint8_t offset = 0;
//    uint8_t i;
//    printf("======== %p =====\n\r", tlvs_);
//    printf("Stored checksum: %d (%x)\n\r", 
//      *(uint16_t*)tlvs_, *(uint16_t*)tlvs_);
//    printf("Computed checksum: %d (%x)\n\r", 
//      computeChecksum(tlvs_),
//      computeChecksum(tlvs_));
//    do{
//      offset = call TLVUtils.findEntry(TAG_ANY, offset+1, &e, tlvs_);
//      if (e != NULL){
//        printf("------------\n\r");
//        printf(" Offset: %d\n\r", offset);
//        printf(" Tag:\t[%d]\t%x\n\r", offset, e->tag);
//        printf(" Len:\t[%d]\t%x\n\r", offset+1, e->len);
//        if (e->tag != TAG_EMPTY){
//        printf(" Data:\n\r");
//        for (i = 0; i < e->len; i++){
//          printf("  [%d]\t(%d)\t%x\n\r", offset+2+i, i, e->data.b[i]);
//        }
//        }else{
//          printf("  [%d]->[%d] (empty)\n\r", offset+2,
//          offset+2+e->len-1);
//        }
//      }
//    } while( offset != 0);
//  }

  int16_t computeChecksum(void* tlvs){
    int16_t* wa = (int16_t*) tlvs;
    int16_t crc = 0x00;
    uint8_t i;
    for (i = 1; i < tlv_len / sizeof(uint16_t); i++){
      crc ^= wa[i];
    }
    return crc;
  }

  bool verifyChecksum(void* tlvs){
    int16_t* wa = (int16_t*) tlvs;
    return 0 == (wa[0] + computeChecksum(tlvs));
  }

  command error_t TLVStorage.loadTLVStorage(void* tlvs){
    uint8_t* ba = (uint8_t*) tlvs;
    version_entry_t e;
//    printf("Load %u from %p to %p\n", 
//      tlv_len,
//      (void*)tlv_start, 
//      tlvs);
    memcpy((void*)tlvs, (void*)tlv_start, tlv_len);
    if (!verifyChecksum(tlvs)){
//      printf("invalid TLV checksum in A, clearing\n\r");
//      printf("In A:\n\r");
//      debugTLV(tlv_start);
//      printf("In buffer:\n\r");
//      debugTLV(tlvs);
      memset(tlvs, 0xff, tlv_len);
      e.version = 0;
      //to account for the 2-byte checksum and the 2 header bytes on
      //the TAG_EMPTY
      ba[TLV_CHECKSUM_LENGTH] = TAG_EMPTY;
      ba[TLV_CHECKSUM_LENGTH+1] = tlv_len - 2 - 2; 

      call TLVUtils.addEntry(TAG_VERSION, 2, (tlv_entry_t*)&e, tlvs,0);
      //TODO: better return code? 
      return SUCCESS;
    }
    return SUCCESS;
  }
  
  void copyIfDirty(){
    void* tlvsA = (void*)tlv_start;
    void* tlvsB = (void*)tlv_copy;
    tlv_entry_t* va;
    tlv_entry_t* vb;
    call TLVUtils.findEntry(TAG_VERSION, 0, &va, tlvsA);
    call TLVUtils.findEntry(TAG_VERSION, 0, &vb, tlvsB);
//    printf("copy if dirty\n\r");
//    printf("TLV in A\n\r");
//    debugTLV(tlvsA);
//    printf("TLV in B\n\r");
//    debugTLV(tlvsB);
    //check 
    if (vb == NULL){
      //TODO: error condition
      return;
    }
    //copy if any holds:
    //B has version tag, A doesn't
    //B's version = A's version + 1
    if ((va == NULL && vb != NULL) 
      || (vb->data.w[0]  == 1 + va->data.w[0])){
//      printf("copying from B to A\n\r");
      unlockInternalFlash((void*)tlv_start);
      FCTL1 = FWKEY+ERASE;
      *((uint8_t*)tlv_start) = 0;
      FCTL1 = FWKEY + WRT;
      memcpy((void*)tlv_start, (void*)tlv_copy, tlv_len);
      FCTL1 = FWKEY;
      lockInternalFlash((void*)tlv_start);
//      printf("copy done\n\r");
    }else{
//      printf("no copy needed: va %p vb %p.\n\r", va, vb);
//      if (vb != NULL && va != NULL){ 
//        printf("vb: %d, va: %d\n\r", vb->data.w[0], va->data.w[0]);
//      }
    }
  }

  command error_t Init.init(){
    copyIfDirty();
  }

  void writeToB(void* tlvs){
    unlockInternalFlash((void*)tlv_copy);

    FCTL1 = FWKEY + ERASE;
    *((uint8_t*)tlv_copy) = 0;
    FCTL1 = FWKEY+WRT;
    memcpy((void*)tlv_copy, tlvs, tlv_len);
    FCTL1 = FWKEY;
    lockInternalFlash((void*)tlv_copy);
//    printf("Done. Now in B:\n\r");
//    debugTLV(tlv_copy);
  }

  //persist TLV structure (to internal flash)
  command error_t TLVStorage.persistTLVStorage(void* tlvs){
    tlv_entry_t* versionTag;
    int16_t* wa = (int16_t*)tlvs;
    uint8_t versionOffset = call TLVUtils.findEntry(TAG_VERSION, 0,
      &versionTag, tlvs);
    if (0 == versionOffset ){
//      printf("No TAG_VERSION found, not persisting\n\r");
      //there should always be a TAG_VERSION in here if tlvs was
      //loaded via this component.
      return FAIL; 
    } else {
//      printf("Persisting version (offset %d) %d (pre)\n\r",
//        versionOffset,
//        ((version_entry_t*)versionTag)->version);
//      printf("tlv start %p version start %p version %p\n\r", tlvs,
//        versionTag, &(((version_entry_t*)versionTag)->version));
      //increment version
      ((version_entry_t*)versionTag)->version ++;
    }
    //checksum: bitwise XOR of the data, stored as -1*checksum (see
    //24.3 in user guide: verification is done by xoring the data,
    //then adding the result to the checksum-to-be-verified. if the
    //result is NOT 0, then it is flagged as bad.
    wa[0] = -1*computeChecksum(tlvs);
    writeToB(tlvs);

    copyIfDirty();
    return SUCCESS;
  }

}
