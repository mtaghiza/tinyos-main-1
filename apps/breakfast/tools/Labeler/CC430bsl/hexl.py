def hexl(items):
    "convert binary data to hex bytes for display"
    if not items:
        return "<None>"
    c = items[0]
    if isinstance(c, str) and len(c) == 1:
        ### convert chars to hex
        items = ["%02x" % ord(x) for x in items]
    elif isinstance(c, int):
        ### convert ints to hex
        items = ["%02x" % x for x in items]
    else:
        assert isinstance(c, str) and len(c) > 1
    return " ".join(items)
