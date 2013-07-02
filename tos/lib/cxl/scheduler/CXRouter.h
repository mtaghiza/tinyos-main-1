#ifndef CX_ROUTER_H
#define CX_ROUTER_H

typedef struct contact_entry{
  am_addr_t nodeId;
  bool attempted;
  bool contacted;
  bool dataPending;
} contact_entry_t;
#endif
