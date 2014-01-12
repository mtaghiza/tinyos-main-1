The autoPush component attempts to send newly-logged data up the
network hierarchy and handles requests for missing sections of the
log.

It can be found in apps/breakfast/bacon/autoPush: RecordPushRequestC/P
are the components you want to look at.

Requests to transmit newly-recorded data originate from the LogNotify
interface

RecordPushRequestP maintains “pushCookie,” “requestCookie,” and
“requestLength.” When there is no request for missing data pending, it
will read from log address pushCookie into a packet, send it, and then
repeat that process until it hits the end of the log. Likewise, when
it is given a request, it reads requestCookie and requestLength from
the request packet, then performs a series of reads starting at
requestCookie until the requested number of bytes have been read.

Requests take precedence over outstanding data pushes.

The TLV keys SS_KEY_LOW_PUSH_THRESHOLD and SS_KEY_HIGH_PUSH_THRESHOLD
control when the mote starts sending outstanding records
(HIGH_PUSH_THRESHOLD) and when it stops sending outstanding records
(LOW_PUSH_THRESHOLD). In practice, we have disabled the use of these
by defining ENABLE_CONFIGURABLE_LOG_NOTIFY to 0
  - This feature made more sense in a previous iteration of the
    networking code where the network was continuously active. Now
    that nodes are normally disconnected and only transfer data a few
    times per day, there’s no real need for this.

The log_record_data_msg_t struct and log_record_t (under
tos/platforms/bacon/chips/stm25p/RecordStorage.h ) are how we package
log records up for transmission.
 - The log_record_data_msg_t struct has short header that indicates
   how many bytes total are in the packet and what the *cookie
   following the last record* is.
 - A series of log_record_t’s are in the data field of this struct:
   their 4-byte cookie is included as well as a length field.
 - While this is a lot of address information, it makes it very simple
   to find gaps in the log: see
   apps/breakfast/tools/Life/tools/cx/db/DatabaseMissing.py for the
   relevant queries.

The python handler for log record messages splits them up into the
individual log records, makes a note of their
address/length/nextCookie in the database (cookie_table), and then
passes them off to a record-type-specific Decoder object for further
parsing.

