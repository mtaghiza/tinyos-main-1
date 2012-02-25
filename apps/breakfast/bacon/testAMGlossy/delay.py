#!/usr/bin/env python
import sys

def delay(ticks, f_src=26000000.0, clk_div=4, timer_div=4):
    return (ticks * clk_div * timer_div)/f_src

if __name__== '__main__':
    if len(sys.argv) > 1:
        print delay(float(sys.argv[1]))
