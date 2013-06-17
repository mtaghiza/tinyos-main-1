
class TLV(object):
    TAG_DCO_30  = 0x01              # Toast factory clock calibration, delete
    TAG_VERSION = 0x02              # Required by storage utility
    TAG_DCO_CUSTOM = 0x03           # Toast custom clock calibration, automatically generated on boot
    TAG_GLOBAL_ID = 0x04            # global barcode ID for toast/bacon devices
    TAG_TOAST_ASSIGNMENTS = 0x05    # Toast sensor assignments
    TAG_ADC12_1 = 0x08              # Toast ADC Calibration constants
