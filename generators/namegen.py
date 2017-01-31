import random

genname_adj = []
genname_pre = []
genname_post = []
genname_noun = []
genname_end = []

def load_names_to_list(fname, ls):
    """
    Load every line in a fine to a list
    -- fname: Name of the file to load
    -- ls: List to load lines to
    """
    with open(fname, 'r') as fh:
        for line in fh:
            data = line.strip()
            if data != "":
                ls.append(data)

load_names_to_list("generators/name/name_adj.txt", genname_adj);
load_names_to_list("generators/name/name_nouns.txt", genname_noun);
load_names_to_list("generators/name/name_post.txt", genname_post);
load_names_to_list("generators/name/name_pre.txt", genname_pre);
load_names_to_list("generators/name/name_end.txt", genname_end);

possible_item_num = len(genname_adj) * len(genname_noun) * len(genname_post) *\
    len(genname_pre) * len(genname_end)
print("{} possible items".format(possible_item_num))

def generate_name():
    """
    Generate a random name for an item
    """
    flags = random.randint(1, 7)
    do_end = random.randint(1, 3) == 1
    do_adj2 = random.randint(1, 3) == 1
    ret = random.choice(genname_noun)
    if flags & 0x4: # Post
        post = random.choice(genname_post)
        ret = post + " " + ret
    if flags & 0x2: # Adj
        adj = random.choice(genname_adj)
        ret = adj + " " + ret
    if do_adj2: # Adj
        adj = random.choice(genname_adj)
        ret = adj + " " + ret
    if flags & 0x1: # Pre
        pre = random.choice(genname_pre)
        ret = pre + " " + ret
    if do_end: # End
        ret = ret + " " + random.choice(genname_end)
    return ret
