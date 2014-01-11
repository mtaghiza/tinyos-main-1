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

#ifndef CX_DEBUG_H
#define CX_DEBUG_H

/** These give us something roughly approximating the logging
 *  methodology in log4j or the tossim dbg() command.
 *  Each logical component has an output level associated with it, from
 *  DEBUG (most verbose) to NONE (no output). These can be set in the
 *  at compile time, and should be default'ed in the respective
 *  component's .h file.  There is also a global output level that
 *  caps how verbose messages can be. An output message must have a
 *  priority which is both greater than its component's output level
 *  and greater than the global output level (defaults to DEBUG).
 *
 *  For example:
 *  In CXLink.h:
 *  #ifndef DL_LINK
 *  #define DL_LINK DL_INFO
 *  #endif
 *  
 *  In CXLinkP.nc:
 *  cdbg(LINK, "push TX %p\r\n", msg)
 *  cinfo(LINK, "ql %u\r\n", call RequestQueue.length())
 *  cerror(LINK, "Queue full\r\n")
 *
 *  would output:
 *  ql 5
 *  !Queue full
 * 
 *  setting DL_GLOBAL to DL_ERROR would suppress the first message.
 *  Note that the cerror prepends '!' to the message and cwarn
 *  prepends '~' to facilitate grepping through logs.
 *
 **/

#define DL_DEBUG 0
#define DL_INFO  1
#define DL_WARN  2
#define DL_ERROR 3
#define DL_NONE  4


#ifndef ENABLE_PRINTF
#define ENABLE_PRINTF 0
#endif

#ifndef RAW_SERIAL_PRINTF
#define RAW_SERIAL_PRINTF 0
#endif

#if ENABLE_PRINTF == 0
#ifndef DL_GLOBAL
#define DL_GLOBAL DL_NONE
#endif
#define printf(...)
#define printfflush()
#else
#ifndef DL_GLOBAL
#define DL_GLOBAL DL_DEBUG
#endif
#if RAW_SERIAL_PRINTF == 1
#include <stdio.h>
#define printfflush()
#else
#include "printf.h"
#endif
#endif

#define cdbg_cond(level, channel, fmt, ...) if ( DL_ ## channel <= level && DL_GLOBAL <= level){printf(fmt, ##__VA_ARGS__);}
#define cdbg(channel, fmt, ...) cdbg_cond(DL_DEBUG, channel, fmt, ##__VA_ARGS__)
#define cinfo(channel, fmt, ...) cdbg_cond(DL_INFO, channel, fmt, ##__VA_ARGS__)
#define cwarn(channel, fmt, ...) cdbg_cond(DL_WARN, channel, "~" fmt, ##__VA_ARGS__)
#define cwarnclr(channel, fmt, ...) cdbg_cond(DL_WARN, channel,  fmt, ##__VA_ARGS__)
#define cerror(channel, fmt, ...) cdbg_cond(DL_ERROR, channel, "!" fmt, ##__VA_ARGS__)
#define cerrorclr(channel, fmt, ...) cdbg_cond(DL_ERROR, channel, fmt, ##__VA_ARGS__)


#define cflush_cond(level, channel) if ( DL_ ## channel <= level && DL_GLOBAL <= level){printfflush();}
#define cflushdbg(channel) cflush_cond(DL_DEBUG, channel)
#define cflushinfo(channel) cflush_cond(DL_INFO, channel)
#define cflushwarn(channel) cflush_cond(DL_WARN, channel)
#define cflusherror(channel) cflush_cond(DL_ERROR, channel)


#endif
