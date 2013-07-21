#include "I2CADCReader.h"

configuration I2CADCReaderMasterC {
  provides interface I2CADCReaderMaster;
} implementation {
  components new I2CComMasterClientC(I2C_COM_CLIENT_ID_ADCREADER);
  components new TimerMilliC();

  components I2CADCReaderMasterP;
  I2CADCReaderMasterP.I2CComMaster -> I2CComMasterClientC;
  I2CADCReaderMasterP.Timer -> TimerMilliC;

  I2CADCReaderMaster = I2CADCReaderMasterP;
}
