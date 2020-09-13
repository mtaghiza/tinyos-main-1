class Deployment(object):
    def __init__(self, db=None, develop=False):
        if develop:
            self.data = {}
        else:
            # TODO Add code for real database
            pass
