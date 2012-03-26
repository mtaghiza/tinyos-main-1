/* RF settings SoC: CC430 */
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_IOCFG2       0x29 // gdo2 output configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_IOCFG1       0x06 // gdo0 output configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_IOCFG0       0x06 // gdo0 output configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FIFOTHR      0x47 // rx fifo and tx fifo thresholds
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_SYNC1        0xD3 // sync word, high byte
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_SYNC0        0x91 // sync word, low byte
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_PKTLEN       0xFF // packet length
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_PKTCTRL1     0x04 // packet automation control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_PKTCTRL0     0x05 // packet automation control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_ADDR         0x00 // device address
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_CHANNR       0x00 // channel number

//#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FSCTRL1      0x06 // frequency synthesizer control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FSCTRL1      0x08 // frequency synthesizer control

#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FSCTRL0      0x00 // frequency synthesizer control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FREQ2        0x23 // frequency control word, high byte
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FREQ1        0x31 // frequency control word, middle byte
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FREQ0        0x3B // frequency control word, low byte
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MDMCFG4      0xCA // modem configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MDMCFG3      0x83 // modem configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MDMCFG2      0x13 // modem configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MDMCFG1      0x22 // modem configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MDMCFG0      0xF8 // modem configuration

//#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_DEVIATN      0x35 // modem deviation setting
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_DEVIATN      0x34 // modem deviation setting

#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MCSM2        0x07 // main radio control state machine configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MCSM1        0x30 // main radio control state machine configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MCSM0        0x00 // main radio control state machine configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FOCCFG       0x16 // frequency offset compensation configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_BSCFG        0x6C // bit synchronization configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_AGCCTRL2     0x43 // agc control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_AGCCTRL1     0x40 // agc control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_AGCCTRL0     0x91 // agc control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_WOREVT1      0x80 // high byte event0 timeout
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_WOREVT0      0x00 // low byte event0 timeout
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_WORCTRL      0xFB // wake on radio control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FREND1       0x56 // front end rx configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FREND0       0x10 // front end tx configuration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FSCAL3       0xE9 // frequency synthesizer calibration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FSCAL2       0x2A // frequency synthesizer calibration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FSCAL1       0x00 // frequency synthesizer calibration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FSCAL0       0x1F // frequency synthesizer calibration
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FSTEST       0x59 // frequency synthesizer calibration control
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_PTEST        0x7F // production test
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_AGCTEST      0x3F // agc test
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_TEST2        0x81 // various test settings
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_TEST1        0x35 // various test settings
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_TEST0        0x09 // various test settings
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_PARTNUM      0x00 // chip id
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_VERSION      0x06 // chip id
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_FREQEST      0x00 // frequency offset estimate from demodulator
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_LQI          0x00 // demodulator estimate for link quality
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RSSI         0x00 // received signal strength indication
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_MARCSTATE    0x00 // main radio control state machine state
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_WORTIME1     0x00 // high byte of wor time
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_WORTIME0     0x00 // low byte of wor time
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_PKTSTATUS    0x00 // current gdox status and packet status
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_VCO_VC_DAC   0x00 // current setting from pll calibration module
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_TXBYTES      0x00 // underflow and number of bytes
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RXBYTES      0x00 // overflow and number of bytes
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIFCTL0   0x00 // radio interface control register 0
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIFCTL1   0x00 // radio interface control register 1
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIFCTL2   0x00 // reserved
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIFERR    0x00 // radio interface error flag register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIFERRV   0x00 // radio interface error vector word register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIFIV     0x00 // radio interface interrupt vector word register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AINSTRW   0x00 // radio instruction word register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AINSTR1W  0x00 // radio instruction word register with 1-byte auto-read (low-byte ignored)
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AINSTR2W  0x00 // radio instruction word register with 2-byte auto-read (low-byte ignored)
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ADINW     0x00 // radio word data in register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ASTAT0W   0x00 // radio status word register without auto-read
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ASTAT1W   0x00 // radio status word register with 1-byte auto-read
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ASTAT2W   0x00 // radio status word register with 2-byte auto-read
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ADOUT0W   0x00 // radio core word data out register without auto-read
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ADOUT1W   0x00 // radio core word data out register with 1-byte auto-read
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ADOUT2W   0x00 // radio core word data out register with 2-byte auto-read
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIN       0x00 // radio core signal input register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIFG      0x00 // radio core interrupt flag register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIES      0x00 // radio core interrupt edge select register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIE       0x00 // radio core interrupt enable register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1AIV       0x00 // radio core interrupt vector word register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ARXFIFO   0x00 // direct receive fifo access register
#define SRFS7_915_GFSK_38P4K_SENS_H_SMARTRF_SETTING_RF1ATXFIFO   0x00 // direct transmit fifo access register
#define SRFS7_915_GFSK_38P4K_SENS_H_GLOBAL_ID 9
