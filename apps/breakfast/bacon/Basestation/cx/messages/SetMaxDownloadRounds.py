from cx.messages import SetSettingsStorageMsg

import cx.constants

class SetMaxDownloadRounds(SetSettingsStorageMsg.SetSettingsStorageMsg):
    def __init__(self, maxDownloadRounds):
        SetSettingsStorageMsg.SetSettingsStorageMsg.__init__(self )
        self.set_key(cx.constants.SS_KEY_MAX_DOWNLOAD_ROUNDS)
        self.set_len(1)
        self.setUIntElement(self.offsetBits_val(0), 8,
        maxDownloadRounds, 1)

