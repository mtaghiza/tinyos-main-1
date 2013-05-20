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

#ifndef DL_GLOBAL
#define DL_GLOBAL DL_DEBUG
#endif

#ifndef ENABLE_PRINTF
#define ENABLE_PRINTF 0
#endif

#if ENABLE_PRINTF == 0
#define printf(...)
#else
#include <stdio.h>
#endif

#define cdbg_cond(level, channel, fmt, ...) if ( DL_ ## channel <= level && DL_GLOBAL <= level){printf(fmt, ##__VA_ARGS__);}
#define cdbg(channel, fmt, ...) cdbg_cond(DL_DEBUG, channel, fmt, ##__VA_ARGS__)
#define cinfo(channel, fmt, ...) cdbg_cond(DL_INFO, channel, fmt, ##__VA_ARGS__)
#define cwarn(channel, fmt, ...) cdbg_cond(DL_WARN, channel, "~" fmt, ##__VA_ARGS__)
#define cwarnclr(channel, fmt, ...) cdbg_cond(DL_WARN, channel,  fmt, ##__VA_ARGS__)
#define cerror(channel, fmt, ...) cdbg_cond(DL_ERROR, channel, "!" fmt, ##__VA_ARGS__)
#define cerrorclr(channel, fmt, ...) cdbg_cond(DL_ERROR, channel, fmt, ##__VA_ARGS__)


#endif
