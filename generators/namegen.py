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

# Count number of possible item names
possible_item_num = 0
c_adj = len(genname_adj)
c_noun = len(genname_adj)
c_post = len(genname_adj)
c_pre = len(genname_adj)
c_end = len(genname_adj)
for i in range(0, 0x20+1):
    if i & 0x07 != 0:
        _end = i & 0x10 != 0
        _adj2 = i & 0x08 != 0
        _adj = i & 0x04 != 0
        _pre = i & 0x02 != 0
        _post = i & 0x01 != 0
        if _adj2 and not _adj:
            continue
        m = c_noun
        if _end:
            m *= c_end
        if _pre:
            m *= c_pre
        if _post:
            m *= c_post
        if _adj:
            m *= c_adj
        if _adj2:
            m *= c_adj
        possible_item_num += m

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
