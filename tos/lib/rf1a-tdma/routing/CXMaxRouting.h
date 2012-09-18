#ifndef CX_MAX_ROUTING_H
#define CX_MAX_ROUTING_H

typedef struct cx_max_route_entry_t{
  am_addr_t n0;
  am_addr_t n1;
  uint8_t distance;
  uint32_t lastSeen;
  bool used;
  bool pinned;
} cx_max_route_entry_t;


#ifndef CX_ROUTING_TABLE_TIMEOUT
#define CX_ROUTING_TABLE_TIMEOUT (10UL * 60UL * 1024UL)
#endif

#ifndef CX_ROUTING_TABLE_ENTRIES
#define CX_ROUTING_TABLE_ENTRIES 16
#endif

#endif

