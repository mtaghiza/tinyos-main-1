from tools.cx.messages import SetSettingsStorageMsg

import tools.cx.constants

class SetBaconSampleInterval(SetSettingsStorageMsg.SetSettingsStorageMsg):
    def __init__(self, sampleInterval):
        SetSettingsStorageMsg.SetSettingsStorageMsg.__init__(self )
        self.set_key(tools.cx.constants.SS_KEY_BACON_SAMPLE_INTERVAL)
        self.set_len(4)
        self.setUIntElement(self.offsetBits_val(0), 32, sampleInterval, 1)
