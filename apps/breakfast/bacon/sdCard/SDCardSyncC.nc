// $Id: SDCardC.nc,v 1.0 2008/11/10 22:23:00 vlahan Exp $


/**
 * Configuration du module SD
 *
 *  @author Gwenhaël GOAVEC-MEROU
 *  
 *  @version 1.0
 *  @date   Nov 10 2008
 *
 **/

configuration SDCardSyncC {
	provides {
    		interface Resource;
        interface SDCard;
  	}
}

implementation {
	components SDCardSyncP as SDCardP;
  SDCardP.Resource = Resource;
  SDCardP.SDCard = SDCard;
	
  components new Msp430UsciSpiB0C() as SpiC; 
  SDCardP.SpiResource -> SpiC;
  SDCardP.SpiByte -> SpiC;
  SDCardP.SpiPacket -> SpiC;

  components HplMsp430GeneralIOC;
  SDCardP.CardDetect -> HplMsp430GeneralIOC.Port24;

  components new Msp430GpioC() as Select;
  Select -> HplMsp430GeneralIOC.Port11;
  SDCardP.Select -> Select;

  components new Msp430GpioC() as Power;
  Power -> HplMsp430GeneralIOC.Port21;
  SDCardP.Power -> Power;
      
}
