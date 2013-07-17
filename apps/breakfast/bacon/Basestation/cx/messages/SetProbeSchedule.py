from cx.messages import SetSettingsStorageMsg

import cx.constants

class SetProbeSchedule(SetSettingsStorageMsg.SetSettingsStorageMsg):
    def __init__(self, probeInterval, channel, invFrequency, bw,
          maxDepth):
        SetSettingsStorageMsg.SetSettingsStorageMsg.__init__(self )
        self.set_key(cx.constants.SS_KEY_PROBE_SCHEDULE)
        #wish this wasn't hardcoded, but I don't see a better way to
        # subclass this. 
        self.set_len(16)
        self.setUIntElement(self.offsetBits_val(0), 32, probeInterval, 1)
        self.setUIntElement(self.offsetBits_val(4), 8, channel[0], 1)
        self.setUIntElement(self.offsetBits_val(5), 8, channel[1], 1)
        self.setUIntElement(self.offsetBits_val(6), 8, channel[2], 1)
        self.setUIntElement(self.offsetBits_val(7), 8, invFrequency[0], 1)
        self.setUIntElement(self.offsetBits_val(8), 8, invFrequency[1], 1)
        self.setUIntElement(self.offsetBits_val(9), 8, invFrequency[2], 1)
        self.setUIntElement(self.offsetBits_val(10), 8, bw[0], 1)
        self.setUIntElement(self.offsetBits_val(11), 8, bw[1], 1)
        self.setUIntElement(self.offsetBits_val(12), 8, bw[2], 1)
        self.setUIntElement(self.offsetBits_val(13), 8, maxDepth[0], 1)
        self.setUIntElement(self.offsetBits_val(14), 8, maxDepth[1], 1)
        self.setUIntElement(self.offsetBits_val(15), 8, maxDepth[2], 1)
