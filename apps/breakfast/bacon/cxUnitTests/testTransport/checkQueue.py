#!/usr/bin/env python
import sys


def checkQueue(f):
    queue = set([])
    for line in f:
        [op, garbage, ptr] = line.split()
        if op == 'push':
            if ptr in queue:
                return False
            else:
                queue.add(ptr)
        if op == 'pop':
            if ptr not in queue:
                return False
            else:
                queue.remove(ptr)
        if op == 'clr' and ptr in queue:
            return False
    return True


if __name__ == '__main__':
    f = sys.stdin
    if len(sys.argv) > 1:
        f = open(sys.argv[1])

    print checkQueue(f)
