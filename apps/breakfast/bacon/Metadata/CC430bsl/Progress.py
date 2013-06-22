import Queue

class Progress(object):

    queue = Queue.Queue()

    @staticmethod
    def update(input):
        Progress.queue.put(input)

    @staticmethod
    def wait(timeout):
        return Progress.queue.get(timeout)
