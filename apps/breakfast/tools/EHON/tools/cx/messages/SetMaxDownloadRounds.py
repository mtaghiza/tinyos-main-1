from tools.cx.messages import SetSettingsStorageMsg

import tools.cx.constants

class SetMaxDownloadRounds(SetSettingsStorageMsg.SetSettingsStorageMsg):
    def __init__(self, maxDownloadRounds):
        SetSettingsStorageMsg.SetSettingsStorageMsg.__init__(self )
        self.set_key(tools.cx.constants.SS_KEY_MAX_DOWNLOAD_ROUNDS)
        self.set_len(2)
        self.setUIntElement(self.offsetBits_val(0), 16,
          maxDownloadRounds, 1)

