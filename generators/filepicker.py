from .state import IsaacGenState
from . import util
import os
import random
import glob

CONST_HINTS_PRE = ":"
CONST_WEIGHT_INC = 20.0

cached_filepickers = {}

def get_path(path):
    if path in cached_filepickers:
        return cached_filepickers[path]
    ret = PickFolder(path)
    cached_filepickers[path] = ret
    return ret

class PickFile:
    weight = 1.0
    def __init__(self, path):
        self.hints = []
        self.path = path
        if CONST_HINTS_PRE in path:
            pos = path.find(CONST_HINTS_PRE)
            ext_pos = path.rfind(".")
            hint_txt = path[pos+1:ext_pos]
            weight = 0.0
            for hint in hint_txt.split(','):
                try:
                    weight += float(hint)
                except ValueError:
                    self.hints.append(hint)
            if weight > 0:
                self.weight = weight
    def get_weight(self, hints):
        weight = self.weight
        for hint, value in hints.items():
            if hint in self.hints:
                weight += value
        return weight
    def get_path(self):
        return self.path

class PickFolder:
    def __init__(self, path):
        self.path = path
        selection = os.path.join(path, "**/*.*")
        self.files = [PickFile(x) for x in glob.glob(selection, recursive=True)]
    def choose_random(self):
        return random.choice(self.files)
    def choose_random_with_name(self, name, hint_def):
        words = [x.lower() for x in name.split()]
        hints = {}
        for key, value in hint_def.items():
            hints[key] = value
        for name in words:
            if not name in hints:
                hints[name] = 0
            hints[name] += CONST_WEIGHT_INC
        weights = {}
        for filedef in self.files:
            weight = filedef.get_weight(hints)
            if weight > 0:
                weights[filedef] = weight
        (list_items, list_weights) = util.dict_to_lists(weights)
        ret = util.choice_weights(list_items, list_weights)
        if ret == None:
            print("backupfunc")
            return self.choose_random()
        else:
            return ret
