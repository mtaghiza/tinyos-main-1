#
# This class is automatically generated by mig. DO NOT EDIT THIS FILE.
# This class implements a Python interface to the 'SetBusPowerCmdMsg'
# message type.
#

from apps.breakfast.tools.Life.tools import Message

# The default size of this message type in bytes.
DEFAULT_MESSAGE_SIZE = 1

# The Active Message type associated with this message.
AM_TYPE = 150

class SetBusPowerCmdMsg(Message):
    # Create a new SetBusPowerCmdMsg of size 1.
    def __init__(self, data="", addr=None, gid=None, base_offset=0, data_length=1):
        Message.__init__(self, data, addr, gid, base_offset, data_length)
        self.amTypeSet(AM_TYPE)
    
    # Get AM_TYPE
    def get_amType(cls):
        return AM_TYPE
    
    get_amType = classmethod(get_amType)
    
    #
    # Return a String representation of this message. Includes the
    # message type name and the non-indexed field values.
    #
    def __str__(self):
        s = "Message <SetBusPowerCmdMsg> \n"
        try:
            s += "  [powerOn=0x%x]\n" % (self.get_powerOn())
        except:
            pass
        return s

    # Message-type-specific access methods appear below.

    #
    # Accessor methods for field: powerOn
    #   Field type: short
    #   Offset (bits): 0
    #   Size (bits): 8
    #

    #
    # Return whether the field 'powerOn' is signed (False).
    #
    def isSigned_powerOn(self):
        return False
    
    #
    # Return whether the field 'powerOn' is an array (False).
    #
    def isArray_powerOn(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'powerOn'
    #
    def offset_powerOn(self):
        return (0 / 8)
    
    #
    # Return the offset (in bits) of the field 'powerOn'
    #
    def offsetBits_powerOn(self):
        return 0
    
    #
    # Return the value (as a short) of the field 'powerOn'
    #
    def get_powerOn(self):
        return self.getUIntElement(self.offsetBits_powerOn(), 8, 1)
    
    #
    # Set the value of the field 'powerOn'
    #
    def set_powerOn(self, value):
        self.setUIntElement(self.offsetBits_powerOn(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'powerOn'
    #
    def size_powerOn(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'powerOn'
    #
    def sizeBits_powerOn(self):
        return 8
    
