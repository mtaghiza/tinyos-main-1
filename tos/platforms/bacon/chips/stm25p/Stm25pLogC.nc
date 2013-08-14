configuration Stm25pLogC {
  provides interface LogRead as Read[ uint8_t id ];
  provides interface LogWrite as Write[ uint8_t id ];
  
  uses interface Stm25pSector as Sector[ uint8_t id ];
  uses interface Resource as ClientResource[ uint8_t id ];
  uses interface Get<bool> as Circular[ uint8_t id ];
  provides interface Stm25pVolume as Volume[uint8_t id];

  //for informing other code when an append is completed (indicates
  //  how much data was appended)
  provides interface Notify<uint8_t>[uint8_t id];
} implementation{

  components Stm25pLogP as LogP;
  Read = LogP.Read;
  Write = LogP.Write;
  Sector = LogP.Sector;
  ClientResource = LogP.ClientResource;
  Circular = LogP.Circular;
  Volume = LogP.Volume;
  Notify = LogP.Notify;

  components MainC;
  MainC.SoftwareInit -> LogP;

  components CC430CRCC;
  LogP.Crc-> CC430CRCC;
}
