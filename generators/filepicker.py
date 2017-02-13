from .state import IsaacGenState
from . import util
import os
import random
import glob

CONST_HINTS_PRE = ":"

cached_filepickers = {}

def path_to_name(path):
    name = os.path.splitext(os.path.basename(path))[0]
    if CONST_HINTS_PRE in path:
        name = name[:name.find(CONST_HINTS_PRE)]
    return name

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
        self.name = path_to_name(path)
        if CONST_HINTS_PRE in path:
            (name, hint_a) = path.rsplit(CONST_HINTS_PRE)
            (hint_txt, _ext) = hint_a.rsplit(".", 1)
            weight = 0.0
            for hint in hint_txt.split(','):
                try:
                    weight += float(hint)
                except ValueError:
                    value = 1
                    if "=" in hint:
                        (hint_txt, value_txt) = hint.split("=", 1)
                        hint = hint_txt
                        value = float(value_txt)
                    self.hints.append((hint, value))
            if weight > 0:
                self.weight = weight
        print(self.name + ": " + ", ".join(["{}={}".format(x[0],x[1]) for x in self.hints]))
    def get_weight(self, genstate):
        weight = self.weight
        mult = 1
        for (hint_name, hint_value) in self.hints:
            mult += genstate.get_hint(hint_name)*hint_value
        return weight*mult
    def get_path(self):
        return self.path

class PickFolder:
    def __init__(self, path):
        self.path = path
        selection = os.path.join(path, "**/*.*")
        self.files = [PickFile(x) for x in glob.glob(selection, recursive=True)]
    def choose_random(self):
        return random.choice(self.files)
    def choose_random_with_hint(self, genstate, base_weight=3, exclude=[]):
        weights = {}
        for filedef in self.files:
            weight = filedef.get_weight(genstate)
            if weight > 0 and filedef.name not in exclude:
                weights[filedef] = weight
        (list_items, list_weights) = util.dict_to_lists(weights)
        ret = util.choice_weights(list_items, list_weights)
        if ret == None:
            print("backupfunc")
            return self.choose_random()
        else:
            return ret
