VERSION = "0.1.0"

import sys


# don't show stack traceback
def excepthook(exctype, value, traceback):
    print(value)


sys.excepthook = excepthook
