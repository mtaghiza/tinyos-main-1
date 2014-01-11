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

#ifndef SCHEDULER_DEBUG_H
#define SCHEDULER_DEBUG_H

#if DEBUG_TESTBED_SCHED_NEW == 1
#define printf_TESTBED_SCHED_NEW(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED_NEW(...)
#endif

#if DEBUG_TESTBED_SCHED_ALL == 1
#define printf_TESTBED_SCHED_ALL(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED_ALL(...)
#endif

#if DEBUG_TESTBED_SCHED == 1
#define printf_TESTBED_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_SCHED(...)
#endif

#if DEBUG_TESTBED == 1
#define printf_TESTBED(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED(...)
#endif

#if DEBUG_TESTBED_CRC == 1
#define printf_TESTBED_CRC(...) printf(__VA_ARGS__)
#else
#define printf_TESTBED_CRC(...)
#endif

#if DEBUG_SCHED == 1
#define printf_SCHED(...) printf(__VA_ARGS__)
#else
#define printf_SCHED(...)
#endif

#if DEBUG_SCHED_IO == 1
#define printf_SCHED_IO(...) printf(__VA_ARGS__)
#else
#define printf_SCHED_IO(...)
#endif

#if DEBUG_SCHED_SR == 1
#define printf_SCHED_SR(...) printf(__VA_ARGS__)
#else
#define printf_SCHED_SR(...)
#endif

#if DEBUG_TIMING == 1
#define printf_TIMING(...) printf(__VA_ARGS__)
#else
#define printf_TIMING(...)
#endif

#if DEBUG_SCHED_RXTX == 1
#define printf_SCHED_RXTX(...) printf(__VA_ARGS__)
#else
#define printf_SCHED_RXTX(...)
#endif

#endif
