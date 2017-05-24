from .state import IsaacGenState
from . import util
import os
import random
import glob
import math
import json
import sys

cached_filepickers = {}

list_of_hints = []

def path_to_name(path):
    name = os.path.splitext(os.path.basename(path))[0]
    return name

def get_path(path):
    if path in cached_filepickers:
        return cached_filepickers[path]
    ret = PickFolder(path)
    cached_filepickers[path] = ret
    return ret

class PickFile:
    weight = 1.0
    def __init__(self, path, tags):
        self.hints = tags["tags"]
        self.weight = tags["weight"]
        self.path = path
        self.name = path_to_name(path)
        if not os.path.isfile(path):
            print("Error: No such file {}".format(path))
            sys.exit()
    def get_weight(self, genstate, total_files):
        weight = self.weight
        mult = 1
        for (hint_name, hint_value) in self.hints.items():
            hint_mult = hint_value*math.log(total_files+1, 1.25)
            mult += genstate.get_hint(hint_name)*hint_mult
        return weight*mult
    def get_path(self):
        return self.path

class PickFolder:
    def __init__(self, path):
        self.path = path
        metafile = os.path.join(path, "meta.json")
        if not os.path.isfile(metafile):
            print("Error: no such metafile {}".format(metafile))
            sys.exit()
        with open(metafile) as fh:
            meta = json.loads(fh.read())
            self.files = [PickFile(os.path.join(path, name),tags)\
                          for name, tags in meta.items()]
            filenames = [x.path for x in self.files]
            for x in glob.glob(os.path.join(path, "*.*"), recursive=False):
                if x != metafile and x not in filenames:
                    print("Warning: file {} not defined in metadata.".format(x))

    def choose_random(self):
        return random.choice(self.files)
    def choose_random_with_hint(self, genstate, base_weight=3, exclude=[]):
        weights = {}
        for filedef in self.files:
            weight = filedef.get_weight(genstate, len(self.files)-len(exclude))
            if weight > 0 and filedef.name not in exclude:
                weights[filedef] = weight
        (list_items, list_weights) = util.dict_to_lists(weights)
        ret = util.choice_weights(list_items, list_weights)
        if ret == None:
            print("backupfunc")
            return self.choose_random()
        else:
            return ret
