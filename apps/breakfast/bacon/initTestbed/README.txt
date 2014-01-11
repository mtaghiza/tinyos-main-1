Nodes running this application will write their TOS_NODE_ID into their
TLV storage as the two least significant bytes of their barcode (the
rest will all be 0).

This is used, for example, to initialize the barcodes of a testbed:
program each node with its TOS_NODE_ID set as desired (e.g. with the
reinstall target) and it will record this as a barcode id.
