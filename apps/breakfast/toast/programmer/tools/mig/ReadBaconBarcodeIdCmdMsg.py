#
# This class is automatically generated by mig. DO NOT EDIT THIS FILE.
# This class implements a Python interface to the 'ReadBaconBarcodeIdCmdMsg'
# message type.
#

from apps.breakfast.tools.Life.tools import Message

# The default size of this message type in bytes.
DEFAULT_MESSAGE_SIZE = 1

# The Active Message type associated with this message.
AM_TYPE = 170

class ReadBaconBarcodeIdCmdMsg(Message):
    # Create a new ReadBaconBarcodeIdCmdMsg of size 1.
    def __init__(self, data="", addr=None, gid=None, base_offset=0, data_length=1):
        Message.__init__(self, data, addr, gid, base_offset, data_length)
        self.amTypeSet(AM_TYPE)
        self.set_tag(0x04)
    
    # Get AM_TYPE
    def get_amType(cls):
        return AM_TYPE
    
    get_amType = classmethod(get_amType)
    
    #
    # Return a String representation of this message. Includes the
    # message type name and the non-indexed field values.
    #
    def __str__(self):
        s = "Message <ReadBaconBarcodeIdCmdMsg> \n"
        try:
            s += "  [tag=0x%x]\n" % (self.get_tag())
        except:
            pass
        return s

    # Message-type-specific access methods appear below.

    #
    # Accessor methods for field: tag
    #   Field type: short
    #   Offset (bits): 0
    #   Size (bits): 8
    #

    #
    # Return whether the field 'tag' is signed (False).
    #
    def isSigned_tag(self):
        return False
    
    #
    # Return whether the field 'tag' is an array (False).
    #
    def isArray_tag(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'tag'
    #
    def offset_tag(self):
        return (0 / 8)
    
    #
    # Return the offset (in bits) of the field 'tag'
    #
    def offsetBits_tag(self):
        return 0
    
    #
    # Return the value (as a short) of the field 'tag'
    #
    def get_tag(self):
        return self.getUIntElement(self.offsetBits_tag(), 8, 1)
    
    #
    # Set the value of the field 'tag'
    #
    def set_tag(self, value):
        self.setUIntElement(self.offsetBits_tag(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'tag'
    #
    def size_tag(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'tag'
    #
    def sizeBits_tag(self):
        return 8
    
