Radio module configuration
----------------
The RF1A core configuration generally consists of:
- Symbol rate and frequency settings (more-or-less magic, from TI's
  smart RF studio)
- Frequency Synthesizer Control settings (FSCTL*). These are either
  configured by the autocalibration feature OR provided by software.
  The former is easy to use and requires minimal code, the latter
  enables faster channel-hopping and better duty-cycling.

configs: radio module configurations for different symbol rates.
  CXLinkC uses SRFS7_915_GFSK_125K_SENS_HC.nc, a 125 kbps gaussian
  frequency-shift-keying encoding. This should be wired to 
  Rf1aPhysicalC's Rf1aConfigure interface.
Rf1aChannelCache*: For applications wishing to employ channel-hopping,
  wire an instance of Rf1aChannelCacheC to your radio configuration.
  This will cause the driver to use the radio auto-calibration if no
  cached frequency synthesizer settings are available for the desired
  channel, and will store FSCTL settings at the conclusion of an
  auto-calibration cycle.
