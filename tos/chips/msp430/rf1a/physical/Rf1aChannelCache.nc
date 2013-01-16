
/**
 * Maintains a cache of channel:FSCAL1/2/3 settings.
 * 
 * For Rf1aConfigure modules which don't want to support caching,
 * here's the stubs:

  async command const rf1a_fscal_t* Rf1aConfigure.getFSCAL(uint8_t channel){
    return call Rf1aChannelCache.getFSCAL(channel);
  }
  async command void Rf1aConfigure.setFSCAL(uint8_t channel,
      rf1a_fscal_t fscal){
    call Rf1aChannelCache.setFSCAL(channel, fscal);
  }
  default async command const rf1a_fscal_t* Rf1aChannelCache.getFSCAL(uint8_t channel){ return NULL; }
  default async command void Rf1aChannelCache.setFSCAL(uint8_t channel,
    rf1a_fscal_t fscal){ }

 */
interface Rf1aChannelCache{
  async command const rf1a_fscal_t* getFSCAL(uint8_t channel);
  async command void setFSCAL(uint8_t channel, rf1a_fscal_t fscal);
}
