#!/usr/bin/env python
########################################################################
### Serial Bootstrap Loader software for the cc430 embedded proccessor
###
### (C) 2001-2003 Chris Liechti <cliechti@gmx.net>
### this is distributed under a free software license, see license.txt
###
### fixes from Colin Domoney
###
### cc430 port by Mark Hays 2010-04-11
###   Based on tos-bsl version 1.39-telos-8
###

import os, sys
import getopt
import threading
import time

from tools.serial import SerialException 

from tools.labeler.BreakfastError import *
from tools.CC430bsl.BootStrapLoader import BootStrapLoader
from tools.CC430bsl.Memory import Memory
from tools.CC430bsl.Debug import Debug
from tools.CC430bsl.BSLExceptions import *
from tools.CC430bsl.hexl import hexl
from tools.CC430bsl.Progress import Progress

# Maximum number of times to retry programming until we fail permanently
MAXIMUM_ATTEMPTS = 20
VERSION = "ppc-surf v1.01 2010-04-11"

class CC430bsl(threading.Thread):
    """Version: ppc-surf v1.01 2010-04-11

    If "-" is specified as file the data is read from the stdinput.
    A file ending with ".txt" is considered to be in TIText format,
    '.a43' and '.hex' as IntelHex and all other filenames are
    considered as ELF files.

    General options:
      -h, --help            Show this help screen.
      -c, --comport=port    Specify the communication port to be used.
                            (Default is 0)
                                    0->COM1 / ttyS0
                                    1->COM2 / ttyS1
                                    etc.
      -P, --password=file   Specify a file with the interrupt vectors that
                            are used as password. This can be any file that
                            has previously been used to program the device.
                            (e.g. -P INT_VECT.TXT).
      -f, --framesize=num   Max. number of data bytes within one transmitted
                            frame (16 to 240 in steps of 16) (e.g. -f 240).
      -D, --debug           Increase level of debug messages. This won't be
                            very useful for the average user...
      -I, --intelhex        Force fileformat to IntelHex
      -T, --titext          Force fileformat to be TIText
      -N, --notimeout       Don't use timeout on serial port (use with care)
      -S, --speed=baud      Reconfigure speed, only possible with newer
                            MSP403-BSL versions (>1.5, read slaa089a.pdf for
                            details). If the --bsl option is not used, an
                            internal BSL replacement will be loaded.
                            Needs a target with at least 2kB RAM!
                            Possible values are 9600, 19200, 38400, 57600, 115200
                            (default 9600)
      --surf                Assume SuRF hardware, currently same as --max-baud
      --fastrx              Program without verify (use with caution)
      --max-baud            Use the fastest supported baud rate (115200)
      --wipe-info=(abcd)    Wipe the specified info sections, abcd
      --infoerase           Erase info segments as well as program memory (JHU)
      --noadg715            No I2C switch controlling RST/TCK pins 
                            (bare access from DTR/CTS of serial)
      --invert-reset        Invert signal on RSTn pin (used by some BSL
                            hardware)
      --invert-test         Invert signal on TEST pin (used by some BSL
                            hardware)
      --invert-TCK          Invert signal on TCK pin (used by some BSL
                            hardware) (should be the same as invert-test,
                            but labeling is different on different chips)
      --errataJTAG20Resolved No need to use the bsl exit sequence described 
                            in cc430 errata. (JHU)
      --dedicatedJTAG       Use BSL entry sequence for devices with dedicated 
                            JTAG pins in accordance with MSP430 memory 
                            programming guide. This seems to work, for example,
                            with the cc430f6137 (from TI's CC430 EM)
      --enterbsl            Force entry to BSL, even if no other tasks given.
      --nospeed             Do not issue BSL command to set speed. 
      --pauseBSLEntry       This works around an intermittently-occurring 
                            case where the normal BSL entry sequence fails
                            (seems to occur when a mote is spamming a lot
                            of serial messages, not sure of exact cause).
                            It puts a breakpoint right before the BSL
                            entry, step through it slowly and it seems to
                            work it out sometimes.
      --bslRetries=n        Attempt entering the BSL n times before 
                            closing/re-opening the serial port. Default 1

    Program Flow Specifiers:
      -e, --masserase       Mass Erase (clear all flash memory)
      -p, --program         Program file

    Data retreiving:
      -u, --upload=addr     Upload a datablock (see also: -s).
      -s, --size=num        Size of the data block do upload. (Default is 2)
      -x, --hex             Show a hexadecimal display of the uploaded data.
                            (Default)
      -b, --bin             Get binary uploaded data. This can be used
                            to redirect the output into a file.

    Do before exit:
      -g, --go=address      Start programm execution at specified address.
                            This implies option --wait.
      -r, --reset           Reset connected MSP430. Starts application.
                            This is a normal device reset and will start
                            the programm that is specified in the reset
                            vector. (see also -g)
      -w, --wait            Wait for <ENTER> before closing serial port.
    """

    def __init__(self, arguments, callback):
        threading.Thread.__init__(self)

        self.arguments = arguments.split()
        self.attempts = MAXIMUM_ATTEMPTS
        self.callback = callback
    
    
    def main(self):
        comPort     = 0     # Default setting.
        wait        = False
        reset       = False
        goaddr      = None
        startaddr   = None
        size        = 2
        hexoutput   = True
        filetype    = None
        notimeout   = False
        massErase   = False
        infoErase   = ""
        # DC: changed default behavior to NOT erase info (as MSP430 memory programming guide specifies)
        eraseInfo   = False
        todo        = []
        bsl         = BootStrapLoader()
        bsl.passwd  = None
        bsl.adg715  = True
        bsl.errataJTAG20Resolved = False
        bsl.dedicatedJTAG = False
        bsl.pauseBSLEntry = False
        bsl.invertReset = False
        bsl.invertTest = False
        bsl.invertTCK = False
        bsl.bslRetries = 1
        # bsl.maxData
        # bsl.fastrx
        # bsl.speed
        #DC: for testing bsl entry sequence
        enterbsl = False
        
        filename    = None

        #sys.stderr.write("MSP430 Bootstrap Loader Version: %s\n" % VERSION)
        
        try:
            opts, args = getopt.getopt(self.arguments,
                "hc:P:f:DITNS:epu:s:xbg:rw",
                ["help", "comport=", "password=", "framesize=", "debug",
                 "intelhex", "titext", "notimeout", "speed=",
                 "surf", "fastrx", "max-baud", "masserase", "program",
                 "bslversion", "wipe-info=", "infoerase", "upload=", "size=", "hex", "bin",
                 "noadg715", "errataJTAG20Resolved", "dedicatedJTAG",
                 "pauseBSLEntry", "go=","reset", "wait", "enterbsl",
                 "nospeed", "invert-reset", "invert-TCK",
                 "invert-test", "bslRetries="]
            )
        except getopt.GetoptError:
            raise InvalidInputError

        for o, a in opts:
            if o in ("-c", "--comport"):
                try:
                    comPort = int(a)                    #try to convert decimal
                except ValueError:
                    comPort = a                         #take the string and let serial driver decide
            elif o in ("-P", "--password"):
                #extract password from file
                bsl.passwd = Memory(a).getMemrange(0xffe0, 0xffff)
            elif o in ("-f", "--framesize"):
                try:
                    maxData = int(a)                    #try to convert decimal
                except ValueError:
                    sys.stderr.write("framesize must be a valid number\n")
                    raise InvalidInputError
                #Make sure that conditions for maxData are met:
                #( >= 16 and == n*16 and <= MAX_DATA_BYTES!)
                if maxData > BootStrapLoader.MAX_DATA_BYTES:
                    maxData = BootStrapLoader.MAX_DATA_BYTES
                elif maxData < 16:
                    maxData = 16
                bsl.maxData = maxData & 0xfffff0
                sys.stderr.write( "Max. number of data bytes within one frame set to %i.\n" % maxData)
            elif o in ("-D", "--debug"):
                Debug.DEBUG = Debug.DEBUG + 1
            elif o in ("-I", "--intelhex"):
                filetype = 0
            elif o in ("-T", "--titext"):
                filetype = 1
            elif o in ("-N", "--notimeout"):
                notimeout = True
            elif o in ("-S", "--speed"):
                try:
                    bsl.speed = int(a, 0)
                except ValueError:
                    sys.stderr.write("speed must be decimal number\n")
                    raise InvalidInputError
            elif o in ("--surf", ):
                bsl.speed = 0
            elif o in ("--fastrx", ):
                bsl.fastrx = True
            elif o in ("--max-baud", ):
                pass
            elif o in ("-e", "--masserase"):
                massErase = True
            elif o in ("--wipe-info", ):
                sys.stderr.write("Erasing info sections (%s)\n" % a);
                infoErase = a
            elif o in ("--infoerase"):
                sys.stderr.write("INFO ERASE")
                eraseInfo = True
            elif o in ("-p", "--program"):
                todo.append(bsl.actionProgram)
            elif o in ("-u", "--upload"):
                try:
                    startaddr = int(a, 0)
                except ValueError:
                    sys.stderr.write("upload address must be a valid number\n")
                    raise InvalidInputError
            elif o in ("-s", "--size"):
                try:
                    size = int(a, 0)
                except ValueError:
                    sys.stderr.write("size must be a valid number\n")
                    raise InvalidInputError
            elif o in ("-x", "--hex"):
                hexoutput = True
            elif o in ("-b", "--bin"):
                hexoutput = False
            elif o in ("-g", "--go"):
                try:
                    goaddr = int(a, 0)
                except ValueError:
                    sys.stderr.write("go address must be a valid number\n")
                    raise InvalidInputError
                wait = True
            elif o in ("-r", "--reset"):
                reset = True
            elif o in ("-w", "--wait"):
                wait = True
            elif o in ("--noadg715"):
                bsl.adg715 = False
            elif o in ("--errataJTAG20Resolved"):
                bsl.errataJTAG20Resolved = True
            elif o in ("--dedicatedJTAG"):
                bsl.dedicatedJTAG = True
            elif o in ("--pauseBSLEntry"):
                bsl.pauseBSLEntry = True
            elif o in ("--enterbsl"):
                enterbsl = True
            elif o in ("--invert-reset"):
                bsl.invertReset = True
            elif o in ("--invert-TCK"):
                bsl.invertTCK = True
            elif o in ("--invert-test"):
                bsl.invertTest = True
            elif o in ("--nospeed"):
                bsl.speed = None
            elif o in ("--bslRetries"):
                bsl.bslRetries = int(a)
            else:
                raise InvalidInputError

        if len(args) == 1:
            if not todo:                                # if there are no actions
                todo.extend([                           # add some useful actions...
                    bsl.actionProgram,
                ])
            filename = args[0]
        elif reset:
            pass
        else:                                           #number of args is wrong
            raise InvalidInputError

        Debug.debug(1, "Debug level set to %d", Debug.DEBUG)
        Debug.debug(1, "Python version: %s", sys.version)

        #sanity check of options
        if notimeout and goaddr is not None and startaddr is not None:
            raise InvalidInputError, "Option --notimeout can not be used together with both --upload and --go"

        if notimeout:
            print >>sys.stderr, "Warning: option --notimeout can cause improper function in some cases!"
            bsl.timeout = 0

        if goaddr and reset:
            print >>sys.stderr, "Warning: --reset ignored as --go is specified"
            reset = False

        if startaddr and goaddr:
            print >>sys.stderr, "Warning: --go ignored as --upload is specified"
            goaddr = None

        if startaddr and reset:
            print >>sys.stderr, "Warning: --reset ignored as --upload is specified"
            reset = False

        if startaddr and wait:
            print >>sys.stderr, "Warning: --wait ignored as --upload specified"
            wait = False

        # prepare data to download
        bsl.data = Memory()                             # prepare downloaded data
        if filetype is not None:                        # if filetype is given...
            if filename is None:
                raise ValueError, "no filename but filetype specified"
            if filename == '-':                         # get data from stdin
                file = sys.stdin
            else:
                file = open(filename, "rb")             # or from a file
            if filetype == 0:                           # select load function
                bsl.data.loadIHex(file)                 # intel hex
            elif filetype == 1:
                bsl.data.loadTIText(file)               # TI's format
            else:
                raise InvalidInputError, "illegal filetype specified"
        else:                                           # no filetype given...
            if filename == '-':                         # for stdin:
                bsl.data.loadIHex(sys.stdin)            # assume intel hex
            elif filename:
                bsl.data.loadFile(filename)             # autodetect otherwise

        Debug.debug(3, "File: %s", filename)

        bsl.comInit(comPort)                            # init port

        # get BSL running
        if todo or massErase or goaddr or startaddr or enterbsl:
            bsl.actionStartBSL()

        # initialization list
        if massErase:
            Debug.debug(1, "Preparing device ...")
            bsl.actionMassErase(infoErase)

        # send password
        if todo or goaddr or startaddr:
            bsl.actionTxPassword()
            bsl.actionReadBSLVersion()

        # work list
        if todo:
            # show a nice list of sheduled actions
            Debug.debug(2, "TODO list:")
            for f in todo:
                try:
                    Debug.debug(2, "   %s", f.func_name)
                except AttributeError:
                    Debug.debug(2, "   %s", f)
            for f in todo: 
                if bsl.passwd:
                    bsl.actionTxPassword()
                f()                          # work through todo list

        if reset:
            bsl.actionReset()

        if goaddr is not None:
            bsl.actionRun(goaddr)                       # load PC and execute

        # upload datablock and output
        if startaddr is not None:
            data = bsl.uploadData(startaddr, size)      # upload data
            if hexoutput:                               # depending on output format
                while data:
                    print "%06x %s" % (startaddr, hexl(data[:16]))
                    startaddr += 16
                    data = data[16:]
            else:
                sys.stdout.write(data)                  # binary output w/o newline!

        if wait:                                        # wait at the end if desired
            sys.stderr.write("Press <ENTER> ...\n")     # display a prompt
            sys.stderr.flush()
            raw_input()                                 # wait for newline

        bsl.close()           #Release serial communication port


    def run(self):
        result = False
        
        for n in range(1, self.attempts):
            try:
                #BUG: if ihex comes from stdin and an exception occurs ever,
                # main will try to read the file from stdin twice (second time it's
                # empty)
                
                self.main()
                result = True
                # no exceptions thrown, program successful
                break
            except InvalidInputError:
                break
            except SerialException:
                time.sleep(1)
                print "serial exception, wait"
                pass
            except Exception:
                print "CC430bsl exception"
                pass
        
        self.callback(result)


if __name__ == '__main__':

    def callme(status):
        print status

    input = "-S 115200 -c COM26 -r -e -I -p ..\\build\\bacon2\\main.ihex"
    reset = "-S 115200 -c /dev/ttyUSB0 -r"

    #cc430 = CC430bsl(input, callme)
    cc430 = CC430bsl(reset, callme)
    cc430.start()

    print "done"

