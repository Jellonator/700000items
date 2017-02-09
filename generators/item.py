from .stat import IsaacStats
from .state import IsaacGenState
from .stat import STAT_SPECIAL_VALUE
from . import image
from . import scriptgen
from . import util
import random

CHARGE_VALUES = [2, 3, 4, 6]

POOL_NAMES = ["treasure", "shop", "boss", "devil", "angel", "secret", "library",\
    "challenge", "goldenChest", "redChest", "beggar", "demonBeggar", "curse",\
    "keyMaster", "bossrush", "dungeon", "bombBum", "greedTreasure", "greedBoss",\
    "greedShop", "greedCurse", "greedDevil", "greedAngel", "greedLibrary",\
    "greedSecret", "greedGoldenChest"]

POOL_BASE_CHANCES = {
    "treasure": 2.5,
    "shop": 0.5,
    "boss": 1.0,
    "devil": 0.2,
    "angel": 0.2,
    "secret": 0.1,
    "library": 0.0,
    "challenge": 0.3,
    "goldenChest": 0,
    "redChest": 0.2,
    "beggar": 0.2,
    "demonBeggar": 0.2,
    "curse": 0.2,
    "keyMaster": 0.2,
    "bossrush": 1.0,
    "dungeon": 1.0,
    "bombBum": 0.2,
}

GREEDY_POOLS = [
    "greedTreasure",
    "greedBoss",
    "greedShop",
    "greedCurse",
    "greedDevil",
    "greedAngel",
    "greedLibrary",
    "greedSecret",
    "greedGoldenChest",
]

def get_greed_name(name):
    """
    Convert a pool name to a greedier name
    """
    ret = "greed" + name[0].upper() + name[1:]
    if ret in GREEDY_POOLS:
        return ret
    return None

def get_base_pool_chances():
    """
    Create a copy of pool chances
    """
    ret = {}
    for key, value in POOL_BASE_CHANCES.items():
        ret[key] = value
    return ret

def add_hints_to_poolchances(poolchances, state):
    """
    Add chances for pools based on hints
    """
    for key, value in poolchances.items():
        inc = state.get_hint("pool-"+key)
        poolchances[key] += inc

# Value of an item effect
EFFECT_VALUE = 3

FLYING_VALUE = 3

class IsaacItem:
    """
    A class which represents an item.
    Contains stats, effects, name of item, etc.
    """
    name = "XX - No Name"
    seed = 0x42069420
    type = "passive"
    effect = ""
    chargeval = 2
    def __init__(self, name, seed):
        """
        Create a new item
        -- name: The name of this item
        -- seed: Seed that will be used to generate this item
        In most cases, the seed should be the hash of the name
        """
        # Initialize variables
        self.name = name
        self.seed = seed
        self.stats = IsaacStats()
        self.genstate = IsaacGenState()
        self.pools = {}
        self.effect = ""

        # Seeding
        rand_state = random.getstate()
        random.seed(self.seed)

        # Hints
        self.genstate.parse_hints_from_name(self.name)
        hint_good = self.genstate.get_hint("good")
        hint_bad = self.genstate.get_hint("bad")
        name_lower = self.name.lower()

        # Start to add stats and effects
        value = random.randint(3, 5) + random.randint(0, hint_good)
        negative_value = random.randint(0, hint_bad)
        # Randomly add bad things to item heh heh heh
        for i in range(0, 3):
            if random.random() < 0.12:
                negative_value += 1
                value += 1
        # Apply effect to item maybe?
        if random.random() < 0.70:
            value -= self.add_effect()
        # Maybe add flying
        if value >= FLYING_VALUE and random.random() < 0.01:
            self.stats.flying = True
            value -= FLYING_VALUE
        # If is an active item, remove stats usually
        if self.type == "active" and random.random() < 0.9:
            value = 0
            negative_value = 0
        # Apply up to two health upgrades
        for i in range(0, 2):
            if value >= STAT_SPECIAL_VALUE:
                if random.random() < 0.13:
                    value -= self.stats.add_random_stat_special(self.genstate)
        # Add benefits from value
        self.stats.add_random_stats(value, 1, self.genstate)
        # Add bad stuff
        self.stats.add_random_stats(negative_value, -1, self.genstate)
        # Create image
        self.gen_image()
        # Add to pools
        pool_chances = get_base_pool_chances()
        add_hints_to_poolchances(pool_chances, self.genstate)
        (pool_names, pool_weights) = util.dict_to_lists(pool_chances)
        num_pools = max(random.randint(0, 4), random.randint(1, 5))
        for i in range(0, num_pools):
            pname = util.choice_weights(pool_names, pool_weights)
            gname = get_greed_name(pname)
            self.pools[pname] = True
            if gname != None:
                self.pools[gname] = True
        # Reset random state
        random.setstate(rand_state)
    def get_image_name(self):
        """
        Get the name of the image for this item
        """
        name = self.name.replace(" ", "_").lower()
        return "collectibles_{}.png".format(name)
    def add_effect(self):
        """
        Add a random effect to this item
        Returns the value of the item
        """
        script = scriptgen.generate_effect(self)
        self.effect += ','
        self.effect += script.get_output()
        value = script.get_var_default("value", 0) + 1

        expected_id = max(min(value, len(CHARGE_VALUES)), 1)-1
        possible_values = [x for x in CHARGE_VALUES]
        possible_values += [CHARGE_VALUES[expected_id]]*3
        if expected_id-1 >= 0:
            possible_values += [CHARGE_VALUES[expected_id-1]]
        if expected_id+1 < len(CHARGE_VALUES):
            possible_values += [CHARGE_VALUES[expected_id+1]]
        self.chargeval = random.choice(possible_values)

        return value
    def write_effect(self, string):
        self.effect += ','
        self.effect += string
    def get_cacheflags(self):
        """
        Get a list of cacheflags for this item
        """
        return self.stats.get_cacheflags()
    def gen_xml(self):
        """
        Generate the XML definition for this item
        """
        ret = "<{} description=\"It's an Item!\" ".format(self.type)
        ret = ret + " name=\"{}\" ".format(self.name)
        ret = ret + " gfx=\"{}\" ".format(self.get_image_name())
        ret = ret + self.stats.gen_xml()
        if self.type == "active":
            ret = ret + " maxcharges=\"{}\" cooldown=\"180\" ".format(self.chargeval)
        return ret + " />"
    def gen_image(self):
        """
        Generate and save a random sprite for this item
        """
        image.generate_image(self.get_image_name(), self.name, self.genstate.hints)
    def get_pools(self):
        """
        Get a list of item pools this item belongs to
        """
        return util.dict_to_lists(self.pools)[0]
    def get_definition(self):
        """
        Get the definition for the item
        """
        return "{\n" +\
        "\tevaluate_cache = {}\n".format(self.stats.gen_eval_cache()) +\
        self.effect +\
        "}\n"
