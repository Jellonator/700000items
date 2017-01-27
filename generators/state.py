hint_def = {}
_current_hint_names = []

def add_hint_def(name):
    if not name in hint_def:
        hint_def[name] = {}

def add_hint_value(name, key, value):
    add_hint_def(name)
    if not key in hint_def[name]:
        hint_def[name][key] = 0
    hint_def[name][key] += value

def clip_line(text):
    if '#' in text:
        pos = text.find('#')
        text = text[:pos]
    return text.strip()

with open('generators/hints.txt') as fh:
    for line in fh:
        line = clip_line(line)
        if line == "":
            continue
        if line[0] == ":":
            names = line[1:]
            name_list = [x.strip() for x in names.split('|')]
            _current_hint_names = name_list
        else:
            hint_name = line
            hint_value = 1
            if '+' in line:
                pos = line.find('+')
                hint_name = line[:pos]
                hint_value = int(line[pos+1:])

            for name in name_list:
                add_hint_value(name, hint_name, hint_value)
def debug_hints():
    for match_name, hints in hint_def.items():
        print(":"+match_name)
        for hint_name, hint_value in hints.items():
            print("\t{}+{}".format(hint_name, hint_value))

class IsaacGenState:
    def __init__(self, hints=None):
        if hints == None:
            hints = {}
        self.hints = hints
    def _check_hint(self, name):
        if not name in self.hints:
            self.hints[name] = 0
    def get_hint(self, name):
        self._check_hint(name)
        return self.hints[name]
    def add_hint(self, name, value):
        self._check_hint(name)
        self.hints[name] += value
    def parse_hints_from_name(self, name):
        for match_name, hint_list in hint_def.items():
            if match_name in name.lower():
                for hint_name, hint_value in hint_list.items():
                    self.add_hint(hint_name, hint_value)
    # def parse_hints(fname, )
