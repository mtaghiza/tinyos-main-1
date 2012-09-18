#ifndef CX_AVERAGE_ROUTING_H
#define CX_AVERAGE_ROUTING_H

typedef struct cx_avg_route_entry_t{
  am_addr_t n0;
  am_addr_t n1;
  uint32_t distanceTotal;
  uint32_t measureCount;
  bool used;
  bool pinned;
} cx_avg_route_entry_t;

#ifndef CX_ROUTING_TABLE_ENTRIES
#define CX_ROUTING_TABLE_ENTRIES 16
#endif

#endif
