#
# This class is automatically generated by mig. DO NOT EDIT THIS FILE.
# This class implements a Python interface to the 'WriteToastAssignmentsCmdMsg'
# message type.
#

from apps.breakfast.tools.Life.tools import Message

# The default size of this message type in bytes.
DEFAULT_MESSAGE_SIZE = 26

# The Active Message type associated with this message.
AM_TYPE = 166

class WriteToastAssignmentsCmdMsg(Message):
    # Create a new WriteToastAssignmentsCmdMsg of size 26.
    def __init__(self, data="", addr=None, gid=None, base_offset=0, data_length=26):
        Message.__init__(self, data, addr, gid, base_offset, data_length)
        self.amTypeSet(AM_TYPE)
        self.set_tag(0x05)
        self.set_len(self.totalSize_assignments_sensorType() +
          self.totalSize_assignments_sensorId())
    
    # Get AM_TYPE
    def get_amType(cls):
        return AM_TYPE
    
    get_amType = classmethod(get_amType)
    
    #
    # Return a String representation of this message. Includes the
    # message type name and the non-indexed field values.
    #
    def __str__(self):
        s = "Message <WriteToastAssignmentsCmdMsg> \n"
        try:
            s += "  [tag=0x%x]\n" % (self.get_tag())
        except:
            pass
        try:
            s += "  [len=0x%x]\n" % (self.get_len())
        except:
            pass
        try:
            s += "  [assignments.sensorType=";
            for i in range(0, 8):
                s += "0x%x " % (self.getElement_assignments_sensorType(i) & 0xff)
            s += "]\n";
        except:
            pass
        try:
            s += "  [assignments.sensorId=";
            for i in range(0, 8):
                s += "0x%x " % (self.getElement_assignments_sensorId(i) & 0xffff)
            s += "]\n";
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
    
    #
    # Accessor methods for field: len
    #   Field type: short
    #   Offset (bits): 8
    #   Size (bits): 8
    #

    #
    # Return whether the field 'len' is signed (False).
    #
    def isSigned_len(self):
        return False
    
    #
    # Return whether the field 'len' is an array (False).
    #
    def isArray_len(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'len'
    #
    def offset_len(self):
        return (8 / 8)
    
    #
    # Return the offset (in bits) of the field 'len'
    #
    def offsetBits_len(self):
        return 8
    
    #
    # Return the value (as a short) of the field 'len'
    #
    def get_len(self):
        return self.getUIntElement(self.offsetBits_len(), 8, 1)
    
    #
    # Set the value of the field 'len'
    #
    def set_len(self, value):
        self.setUIntElement(self.offsetBits_len(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'len'
    #
    def size_len(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'len'
    #
    def sizeBits_len(self):
        return 8
    
    #
    # Accessor methods for field: assignments.sensorType
    #   Field type: short[]
    #   Offset (bits): 0
    #   Size of each element (bits): 8
    #

    #
    # Return whether the field 'assignments.sensorType' is signed (False).
    #
    def isSigned_assignments_sensorType(self):
        return False
    
    #
    # Return whether the field 'assignments.sensorType' is an array (True).
    #
    def isArray_assignments_sensorType(self):
        return True
    
    #
    # Return the offset (in bytes) of the field 'assignments.sensorType'
    #
    def offset_assignments_sensorType(self, index1):
        offset = 0
        if index1 < 0 or index1 >= 8:
            raise IndexError
        offset += 16 + index1 * 24
        return (offset / 8)
    
    #
    # Return the offset (in bits) of the field 'assignments.sensorType'
    #
    def offsetBits_assignments_sensorType(self, index1):
        offset = 0
        if index1 < 0 or index1 >= 8:
            raise IndexError
        offset += 16 + index1 * 24
        return offset
    
    #
    # Return the entire array 'assignments.sensorType' as a short[]
    #
    def get_assignments_sensorType(self):
        tmp = [None]*8
        for index0 in range (0, self.numElements_assignments_sensorType(0)):
                tmp[index0] = self.getElement_assignments_sensorType(index0)
        return tmp
    
    #
    # Set the contents of the array 'assignments.sensorType' from the given short[]
    #
    def set_assignments_sensorType(self, value):
        for index0 in range(0, len(value)):
            self.setElement_assignments_sensorType(index0, value[index0])

    #
    # Return an element (as a short) of the array 'assignments.sensorType'
    #
    def getElement_assignments_sensorType(self, index1):
        return self.getUIntElement(self.offsetBits_assignments_sensorType(index1), 8, 1)
    
    #
    # Set an element of the array 'assignments.sensorType'
    #
    def setElement_assignments_sensorType(self, index1, value):
        self.setUIntElement(self.offsetBits_assignments_sensorType(index1), 8, value, 1)
    
    #
    # Return the total size, in bytes, of the array 'assignments.sensorType'
    #
    def totalSize_assignments_sensorType(self):
        return (192 / 8)
    
    #
    # Return the total size, in bits, of the array 'assignments.sensorType'
    #
    def totalSizeBits_assignments_sensorType(self):
        return 192
    
    #
    # Return the size, in bytes, of each element of the array 'assignments.sensorType'
    #
    def elementSize_assignments_sensorType(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of each element of the array 'assignments.sensorType'
    #
    def elementSizeBits_assignments_sensorType(self):
        return 8
    
    #
    # Return the number of dimensions in the array 'assignments.sensorType'
    #
    def numDimensions_assignments_sensorType(self):
        return 1
    
    #
    # Return the number of elements in the array 'assignments.sensorType'
    #
    def numElements_assignments_sensorType():
        return 8
    
    #
    # Return the number of elements in the array 'assignments.sensorType'
    # for the given dimension.
    #
    def numElements_assignments_sensorType(self, dimension):
        array_dims = [ 8,  ]
        if dimension < 0 or dimension >= 1:
            raise IndexException
        if array_dims[dimension] == 0:
            raise IndexError
        return array_dims[dimension]
    
    #
    # Fill in the array 'assignments.sensorType' with a String
    #
    def setString_assignments_sensorType(self, s):
         l = len(s)
         for i in range(0, l):
             self.setElement_assignments_sensorType(i, ord(s[i]));
         self.setElement_assignments_sensorType(l, 0) #null terminate
    
    #
    # Read the array 'assignments.sensorType' as a String
    #
    def getString_assignments_sensorType(self):
        carr = "";
        for i in range(0, 4000):
            if self.getElement_assignments_sensorType(i) == chr(0):
                break
            carr += self.getElement_assignments_sensorType(i)
        return carr
    
    #
    # Accessor methods for field: assignments.sensorId
    #   Field type: int[]
    #   Offset (bits): 8
    #   Size of each element (bits): 16
    #

    #
    # Return whether the field 'assignments.sensorId' is signed (False).
    #
    def isSigned_assignments_sensorId(self):
        return False
    
    #
    # Return whether the field 'assignments.sensorId' is an array (True).
    #
    def isArray_assignments_sensorId(self):
        return True
    
    #
    # Return the offset (in bytes) of the field 'assignments.sensorId'
    #
    def offset_assignments_sensorId(self, index1):
        offset = 8
        if index1 < 0 or index1 >= 8:
            raise IndexError
        offset += 16 + index1 * 24
        return (offset / 8)
    
    #
    # Return the offset (in bits) of the field 'assignments.sensorId'
    #
    def offsetBits_assignments_sensorId(self, index1):
        offset = 8
        if index1 < 0 or index1 >= 8:
            raise IndexError
        offset += 16 + index1 * 24
        return offset
    
    #
    # Return the entire array 'assignments.sensorId' as a int[]
    #
    def get_assignments_sensorId(self):
        tmp = [None]*8
        for index0 in range (0, self.numElements_assignments_sensorId(0)):
                tmp[index0] = self.getElement_assignments_sensorId(index0)
        return tmp
    
    #
    # Set the contents of the array 'assignments.sensorId' from the given int[]
    #
    def set_assignments_sensorId(self, value):
        for index0 in range(0, len(value)):
            self.setElement_assignments_sensorId(index0, value[index0])

    #
    # Return an element (as a int) of the array 'assignments.sensorId'
    #
    def getElement_assignments_sensorId(self, index1):
        return self.getUIntElement(self.offsetBits_assignments_sensorId(index1), 16, 1)
    
    #
    # Set an element of the array 'assignments.sensorId'
    #
    def setElement_assignments_sensorId(self, index1, value):
        self.setUIntElement(self.offsetBits_assignments_sensorId(index1), 16, value, 1)
    
    #
    # Return the total size, in bytes, of the array 'assignments.sensorId'
    #
    def totalSize_assignments_sensorId(self):
        return (192 / 8)
    
    #
    # Return the total size, in bits, of the array 'assignments.sensorId'
    #
    def totalSizeBits_assignments_sensorId(self):
        return 192
    
    #
    # Return the size, in bytes, of each element of the array 'assignments.sensorId'
    #
    def elementSize_assignments_sensorId(self):
        return (16 / 8)
    
    #
    # Return the size, in bits, of each element of the array 'assignments.sensorId'
    #
    def elementSizeBits_assignments_sensorId(self):
        return 16
    
    #
    # Return the number of dimensions in the array 'assignments.sensorId'
    #
    def numDimensions_assignments_sensorId(self):
        return 1
    
    #
    # Return the number of elements in the array 'assignments.sensorId'
    #
    def numElements_assignments_sensorId():
        return 8
    
    #
    # Return the number of elements in the array 'assignments.sensorId'
    # for the given dimension.
    #
    def numElements_assignments_sensorId(self, dimension):
        array_dims = [ 8,  ]
        if dimension < 0 or dimension >= 1:
            raise IndexException
        if array_dims[dimension] == 0:
            raise IndexError
        return array_dims[dimension]
    
