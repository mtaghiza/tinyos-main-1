from tools.cx.messages import SetSettingsStorageMsg

import tools.cx.constants

class SetDownloadInterval(SetSettingsStorageMsg.SetSettingsStorageMsg):
    def __init__(self, downloadInterval):
        SetSettingsStorageMsg.SetSettingsStorageMsg.__init__(self )
        self.set_key(tools.cx.constants.SS_KEY_DOWNLOAD_INTERVAL)
        self.set_len(4)
        self.setUIntElement(self.offsetBits_val(0), 32, downloadInterval, 1)


