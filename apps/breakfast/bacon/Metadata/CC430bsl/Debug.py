import sys

class Debug(object):

    DEBUG = 0

    @staticmethod
    def debug(level, fmt, *rest):
        "print debugging message"
        if Debug.DEBUG < level:
            return
        if rest:
            fmt = fmt % rest
        print >>sys.stderr, fmt.rstrip()
        sys.stderr.flush()