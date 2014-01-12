This sub-application handles periodic sampling of the bacon mote's
onboard sensors.  It defines the bacon_sample record type and
constants associated with the bacon sampler sub-application.

Define BACON_SAMPLER_DUMMY to be 1 if you wish to save some code space
(and just log dummy data to the flash). 

BaconSamplerHighC uses high level (splitcontrol/read) interfaces for
each of the onboard sensors. We abandoned this due to its large size
and replaced it with BaconSamplerLow, which uses direct register
access to do the same thing.
