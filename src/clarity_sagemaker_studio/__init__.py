VERSION = "0.1.1"

import sys
from .utils import debug_job


# don't show stack traceback
def excepthook(exctype, value, traceback):
    print(value)


sys.excepthook = excepthook
