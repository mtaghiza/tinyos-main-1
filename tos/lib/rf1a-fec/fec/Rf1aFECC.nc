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

generic configuration Rf1aFECC () {
  provides interface Rf1aPhysical[uint8_t client];
  provides interface Rf1aPhysicalMetadata;

  uses interface Rf1aPhysical as SubRf1aPhysical[uint8_t client];
  uses interface Rf1aPhysicalMetadata as SubRf1aPhysicalMetadata;
} implementation {
  components new Rf1aFECP();
  components CC430CRCC;

  //TODO: switch between encodings
  #if RF1A_FEC_ENABLED == 1
  components Hamming74FECC as FEC;
  #else
  components DummyFECC as FEC;
  #endif

  Rf1aFECP.FEC -> FEC;

  Rf1aFECP.Crc -> CC430CRCC;
  Rf1aFECP.SubRf1aPhysical = SubRf1aPhysical;
  Rf1aPhysical = Rf1aFECP.Rf1aPhysical;
  Rf1aPhysicalMetadata = Rf1aFECP.Rf1aPhysicalMetadata;
  Rf1aFECP.SubRf1aPhysicalMetadata = SubRf1aPhysicalMetadata;
}
