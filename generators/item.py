from .stat import IsaacStats
import random

STAT_RANGES = {
    'speed': 0.1,
    'luck': 1,
    'tears': 1,
    'shot_speed': 0.1,
    'damage': 1.0
}

STAT_RANGES_SPECIAL = {
    'health': (1, 1),
    'soul': (4, 6),
    'black': (2, 4)
}

STAT_NAMES   = ['speed', 'luck', 'tears', 'shot_speed', 'damage']
STAT_WEIGHTS = [     10,      3,      10,            7,        8]
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
    if isinstance(a_value, int):
        return random.randint(a_value, b_value)
    else:
        return round(random.uniform(a_value, b_value), 2)

class IsaacItem:
    name = ""
    def __init__(self, name, seed):
        rand_state = random.getstate()
        self.name = name
        self.seed = seed
        self.stats = IsaacStats()
        value = random.randint(2, 6)
        while value > 0:
            take_value = random.randint(1, value)
            if take_value >= STAT_SPECIAL_VALUE and random.randint(1, take_value) >= STAT_SPECIAL_VALUE:
                value -= STAT_SPECIAL_VALUE
                stat_name = random.choice(STAT_NAMES_SPECIAL)
                stat_inc = generate_random_stat_special(stat_name)
                self.stats.increment_stat(stat_name, stat_inc)
            else:
                value -= take_value
                stat_name = random.choice(STAT_NAMES)
                stat_inc = generate_random_stat(stat_name, take_value)
                self.stats.increment_stat(stat_name, stat_inc)

        random.seed(self.seed)
        random.setstate(rand_state)
    def get_cacheflags(self):
        return self.stats.get_cacheflags()
    def gen_xml(self):
        ret = "<passive description=\"It's an Item!\" "
        ret = ret + " name=\"{}\" ".format(self.name)
        ret = ret + " gfx=\"Collectibles_Default.png\" "
        ret = ret + self.stats.gen_xml()
        return ret + " />"
    def get_pools(self):
        return ['boss', 'treasure']
    def gen_definition(self):
        return """{{
\tevaluate_cache = {},
}}""".format(self.stats.gen_eval_cache())
