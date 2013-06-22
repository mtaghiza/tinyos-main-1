### base exc
class BSLException(Exception):     pass

### serial port timeout
class BSLTimeout(BSLException):    pass

### BSL responses for txFrame
class BadHeader(BSLException):     pass
class BadChecksum(BSLException):   pass
class EmptyPacket(BSLException):   pass
class PacketTooLong(BSLException): pass
class UnknownError(BSLException):  pass
class BadBaudRate(BSLException):   pass
class BadResponse(BSLException):   pass # default for garbage resp

### serial proto errors for rxFrame
class BadRespHdr(BSLException):    pass
class BadRespLen(BSLException):    pass
class BadRespSum(BSLException):    pass
class BadRespCode(BSLException):   pass
class GarbledResp(BSLException):   pass

### BSL response messages for rxFrame
class BadFlashWrite(BSLException): pass
class FlashFail(BSLException):     pass
class VoltageChange(BSLException): pass
class Locked(BSLException):        pass
class BadPassword(BSLException):   pass
class BadByteWrite(BSLException):  pass
class UnknownCmd(BSLException):    pass
class Overrun(BSLException):       pass
class BadMessage(BSLException):    pass # default for garbage resp
