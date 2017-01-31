from .stat import IsaacStats
from .state import IsaacGenState
from . import image
import random

STAT_RANGES = {
    'speed': 0.1,
    'luck': 1,
    'tears': 1,
    'shot_speed': 0.1,
    'damage': 0.6,
    'range': 3.0
}

STAT_RANGES_SPECIAL = {
    'health': (1, 1),
    'soul': (3, 5),
    'black': (2, 4)
}

def choice_weights(choices, weights):
    total = sum(weights)
    rng = random.random() * total
    i = 0
    for i in range(0, len(choices)):
        weight = weights[i]
        name = choices[i]
        rng -= weight
        if rng <= 0:
            return name
        i += 1

STAT_NAMES   = ['speed', 'luck', 'tears', 'shot_speed', 'damage', 'range']
STAT_WEIGHTS = [      8,      2,       7,            5,        7,       8]
STAT_NAMES_SPECIAL =   ['health', 'soul', 'black']
STAT_WEIGHTS_SPECIAL = [      10,      5,       3]
STAT_CHOICES = []
STAT_CHOICES_SPECIAL = []
for i in range(0, len(STAT_NAMES)):
    STAT_CHOICES += [STAT_NAMES[i]]*STAT_WEIGHTS[i]
for i in range(0, len(STAT_NAMES_SPECIAL)):
    STAT_CHOICES_SPECIAL += [STAT_NAMES_SPECIAL[i]]*STAT_WEIGHTS_SPECIAL[i]

STAT_SPECIAL_VALUE = 2

def generate_random_stat_special(statname):
    values = STAT_RANGES_SPECIAL[statname]
    a = values[0]
    b = values[1]
    if statname == "health":
        return 2
    return random.randint(a, b)

def generate_random_stat(statname, value):
    a_value = STAT_RANGES[statname] * value
    b_value = STAT_RANGES[statname] * (value+1)
    if a_value > b_value:
        a_value, b_value = b_value, a_value
    if statname == "luck":
        return a_value
    elif isinstance(a_value, int):
        return random.randint(a_value, b_value)
    else:
        return round(random.uniform(a_value, b_value), 2)
class IsaacItem:
    name = "XX - No Name"
    seed = 0x42069420
    type = "passive"
    def __init__(self, name, seed):
        # Initialize variables
        self.name = name
        self.seed = seed
        self.stats = IsaacStats()
        self.genstate = IsaacGenState()

        # Seeding
        rand_state = random.getstate()
        random.seed(self.seed)

        # Hints
        self.genstate.parse_hints_from_name(self.name)
        hint_good = self.genstate.get_hint("good")
        hint_bad = self.genstate.get_hint("bad")
        name_lower = self.name.lower()

        # Start to add stats and effects
        value = random.randint(1, 5) + random.randint(0, hint_good)
        negative_value = random.randint(0, hint_bad)
        # Randomly add bad things to item heh heh heh
        for i in range(0, 2):
            if random.random() < 0.20:
                negative_value += 2
                value += random.randint(1, 2)
        # Add benefits from value
        while value > 0:
            take_value = random.randint(1, value)
            # Random special value (health)
            if take_value >= STAT_SPECIAL_VALUE and random.randint(0, take_value) >= STAT_SPECIAL_VALUE:
                value -= self.add_random_stat_special()
            # Random stat upgrade
            else:
                value -= self.add_random_stat(value, 1)
        # Add bad stuff
        while negative_value > 0:
            negative_value -= self.add_random_stat(negative_value, -1)
        # Create image
        self.gen_image()
        random.setstate(rand_state)
    def get_image_name(self):
        name = self.name.replace(" ", "_").lower()
        return "collectibles_{}.png".format(name)
    def add_random_stat_special(self):
        stat_name = random.choice(STAT_NAMES_SPECIAL)
        stat_inc = generate_random_stat_special(stat_name)
        self.stats.increment_stat(stat_name, stat_inc)
        return STAT_SPECIAL_VALUE
    def add_random_stat(self, maxvalue, multiplier):
        stat_name = random.choice(STAT_NAMES)
        if stat_name == "luck":
            maxvalue = min(2, maxvalue)
        take_value = random.randint(1, maxvalue)
        stat_inc = generate_random_stat(stat_name, take_value)*multiplier
        self.stats.increment_stat(stat_name, stat_inc)
        return take_value
    def get_cacheflags(self):
        return self.stats.get_cacheflags()
    def gen_xml(self):
        ret = "<{} description=\"It's an Item!\" ".format(self.type)
        ret = ret + " name=\"{}\" ".format(self.name)
        ret = ret + " gfx=\"{}\" ".format(self.get_image_name())
        ret = ret + self.stats.gen_xml()
        return ret + " />"
    def gen_image(self):
        image.generate_image(self.get_image_name())
    def get_pools(self):
        return ['boss', 'treasure']
    def gen_definition(self):
        return """{{
\tevaluate_cache = {},
}}""".format(self.stats.gen_eval_cache())
