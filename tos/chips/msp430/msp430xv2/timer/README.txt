Breakfast Notes

Defining the symbol XT2_SMCLK will source the sub-main clock from
XT2/4 (26/4 = 6.5 decimal MHz). Please note that to minimize other
code changes, this still uses the microsecond data type (though each
tick is 1/6.5th of a microsecond).

There is a chip erratum (UCS7) which is worked-around at the expense of
one of the capture/compare modules. See Msp430XV2ClockControlP.nc for
details.
