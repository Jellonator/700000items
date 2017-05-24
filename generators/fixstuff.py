#!/usr/bin/python3

import json
import sys
import glob
import os

# This is a helper script for converting old-style of putting tags and weights
# in filenames into the new-style of defining tags and weights in a json meta
# file.

META_FILE = "meta.json"

def get_path_info(path):
    tags = {}
    weight = None
    # directory, base = os.path.split(path)
    root, ext = os.path.splitext(path)
    if not ":" in root:
        return (path, 1, tags)
    pre, post = root.split(":")
    for tag in post.split(","):
        try:
            value = float(tag)
            if weight == None:
                weight = 0
            weight += value
        except ValueError:
            value = 1
            if "=" in tag:
                tag, valuetxt = tag.split("=")
                value = float(valuetxt)
            tags[tag] = value
    return (pre + ext, weight, tags)

def main(args):
    if len(args) == 0:
        print("no arguments")
        sys.exit()
    path = args[0]
    if not os.path.isdir(path):
        print("not a valid path: {}".format(path))
        sys.exit()
    metapath = os.path.join(path, META_FILE)
    metadata = None
    try:
        with open(metapath) as metafile:
            print("Loading existing metadata: {}".format(metapath))
            metadata = json.load(metafile)
    except FileNotFoundError:
        print("Creating a new json file for metadata: {}".format(metapath))
        metadata = {}
    for k, v in metadata.items():
        if not "weight" in v:
            v["weight"] = 1
        if not "tags" in v:
            v["tags"] = {}
    searchdir = os.path.join(path, "*.*")
    print(searchdir)
    for pathname in glob.glob(searchdir, recursive=False):
        if pathname == metapath:
            continue
        newname, newweight, newtags = get_path_info(pathname)
        basename = os.path.basename(newname)
        if not basename in metadata:
            metadata[basename] = {
                "weight": 1,
                "tags": {}
            }
        if newweight != None:
            metadata[basename]["weight"] = newweight
        for tag, val in newtags.items():
            metadata[basename]["tags"][tag] = val
        os.rename(pathname, newname)
        print("Old Name: {}".format(pathname))
        print("New Name: {}".format(newname))
        print("")
    with open(metapath, "w") as metafile:
        json.dump(metadata, metafile, ensure_ascii=False, indent=4, sort_keys=True)

main(sys.argv[1:])
