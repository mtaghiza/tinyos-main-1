class MessageListener(object):
    def __init__(self, db, wrapped):
        self.db = db
        self.wrapped = wrapped

    def receive(self, src, msg):
        self.db.insertRaw(src, msg)
        wrapped.receive(src, msg)
