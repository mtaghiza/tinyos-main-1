from tools.cx.messages import SetSettingsStorageMsg

import tools.cx.constants

class SetHighPushThreshold(SetSettingsStorageMsg.SetSettingsStorageMsg):
    def __init__(self, highPushThreshold):
        SetSettingsStorageMsg.SetSettingsStorageMsg.__init__(self )
        self.set_key(tools.cx.constants.SS_KEY_HIGH_PUSH_THRESHOLD)
        self.set_len(1)
        self.setUIntElement(self.offsetBits_val(0), 8, highPushThreshold, 1 )


