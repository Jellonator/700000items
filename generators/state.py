import random

hint_def = {}
_current_hint_names = []

# Brief rundown of hints:
# In order to add a semblence of sanity to this mod, item effects, stats, and
# pools are based loosely on the name of the item. In order to do this, we
# search the item name for keywords such as 'bomb' or 'sacred', and if such
# keywords are present, make certain events more likely.
# To do this, we have a dictionary named 'hint_def' which has pattern matches
# for keys and a set of hints as values. If said pattern is found in the name of
# an item, then the associated set of hints can be applied to that item.

def add_hint_def(name):
    """
    Add a hint to the global hint definition
    -- name: Name to match for this hint
    """
    if not name in hint_def:
        hint_def[name] = {}

def add_hint_value(name, key, value):
    """
    Add a value to a hint
    -- name: Name to match for this hint
    -- key: Name of the value that is modified by this hint
    -- value: How much the value is modified by this hint
    """
    add_hint_def(name)
    if not key in hint_def[name]:
        hint_def[name][key] = 0
    hint_def[name][key] += value

def clip_line(text):
    """
    Remove comments from string
    """
    if '#' in text:
        pos = text.find('#')
        text = text[:pos]
    return text.strip()

# Parse hints from a file which lists hints
with open('generators/hints.txt') as fh:
    for line in fh:
        line = clip_line(line)
        if line == "":
            # Line is empty, get outta here
            continue
        if line[0] == ":":
            # Line is a hint definition, add matches
            names = line[1:]
            name_list = [x.strip() for x in names.split('|')]
            _current_hint_names = name_list
        else:
            # Line is a modifier, add hint values
            hint_name = line
            hint_value = 1
            if '+' in line:
                pos = line.find('+')
                hint_name = line[:pos]
                hint_value = int(line[pos+1:])

            for name in name_list:
                add_hint_value(name, hint_name, hint_value)
def debug_hints():
    """
    Print out all hint values
    """
    for match_name, hints in hint_def.items():
        print(":"+match_name)
        for hint_name, hint_value in hints.items():
            print("\t{}+{}".format(hint_name, hint_value))

CONST_BASE_DESCRIPTORS = [
    "Up", "Down", "Is", "My", "More",
    "Gross", "You", "Feel"
]

CONST_RARE_DESCRIPTORS = [
    "Bootleg", "Ultimate", "Grand", "Supreme",

]

CONST_WEIRD_COMBINERS = [" + ", " / ", " = ", " and ", " or "]
CONST_ENDINGS = ["!", "?"]

class IsaacGenState:
    """
    Represents the state of an item generator
    Currently only deals with hints
    """
    def __init__(self, item_name, hints=None):
        """
        Create a new generator state
        """
        if hints == None:
            hints = {}
        self.hints = hints
        self.name = item_name
        self.effect = ""
        self.descriptors = CONST_BASE_DESCRIPTORS.copy()
        for value in CONST_RARE_DESCRIPTORS:
            if random.random() < 0.3:
                self.descriptors.append(value)
    def _check_hint(self, name):
        """
        make sure a hint exists
        -- name: name of the hint to check
        """
        if not name in self.hints:
            self.hints[name] = 0
    def get_hint(self, name):
        """
        Get the value of a given hint
        -- name: name of the hint
        """
        self._check_hint(name)
        return self.hints[name]
    def add_hint(self, name, value):
        """
        Add a value to a hint
        -- name: name of the hint
        -- value: value to add to the hint
        """
        self._check_hint(name)
        self.hints[name] += value
    def parse_hints_from_name(self, name):
        """
        Parse hints out of a name using hint matches
        -- name: name to search for hints
        """
        for match_name, hint_list in hint_def.items():
            if match_name in name.lower():
                for hint_name, hint_value in hint_list.items():
                    self.add_hint(hint_name, hint_value)
        for word in [x.lower() for x in name.split()]:
            self.add_hint("name-{}".format(word), 1)
    def add_descriptor(self, desc, value=1):
        self.descriptors += [desc] * value
    def add_descriptors(self, ls, value=1):
        self.descriptors += ls * value
    def gen_description(self):
        ls = random.sample(self.descriptors, random.randint(2, 6))
        ret = ls[0]
        for s in ls[1:]:
            space = " "
            if random.random() < 0.08:
                space = random.choice(CONST_WEIRD_COMBINERS)
            ret += "{}{}".format(space, s)
        if random.random() < 0.12:
            ret += random.choice(CONST_ENDINGS)
        return ret
