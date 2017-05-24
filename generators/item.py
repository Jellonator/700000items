from .stat import IsaacStats
from .state import IsaacGenState
from .stat import STAT_SPECIAL_VALUE
from . import image
from . import scriptgen
from . import util
import random
import os
import string
import json
from xml.etree import ElementTree

CONST_VALID_PATH_CHARACTERS = "_" + string.ascii_letters + string.digits
CHARGE_VALUES = [2, 3, 4, 6]
OUTPUT_IMAGE_PATH = "700000items/resources/gfx/items/collectibles"
TRINKET_IMAGE_PATH = "700000items/resources/gfx/items/trinkets"
FAMILIAR_IMAGE_PATH = "700000items/resources/gfx/familiar"
ANIM_IMAGE_PATH = "700000items/resources/gfx"
ANIM_BASE_XML_PATH = "generators/script/baseanim.xml"
POTENTIAL_COSTUMES = [int(x) for x in json.load(open("costumenames.json"))]

def get_random_costume():
    return random.choice(POTENTIAL_COSTUMES)

anim_base_xml = open(ANIM_BASE_XML_PATH, 'r').read()

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
    description = "It's a mystery!"
    collision_damage = 0
    costume = None
    familiar_base_hp = 0
    def __init__(self, name, seed, trinket=False, description=None):
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
        self.genstate = IsaacGenState(self.name)
        self.pools = {}
        self.effect = ""
        self.costume = get_random_costume()
        if trinket:
            self.type = "trinket"
        else:
            self.type = "passive"
        # Seeding
        rand_state = random.getstate()
        if self.seed:
            random.seed(self.seed)
        # Hints
        self.genstate.parse_hints_from_name(self.name)
        hint_good = self.genstate.get_hint("good")
        hint_bad = self.genstate.get_hint("bad")
        name_lower = self.name.lower()
        # Init pools
        self._init_pools()
        # Create image
        self._init_image()
        # Start to add stats and effects
        minimum_value = 2
        maximum_value = 4
        if trinket:
            maximum_value = 3
            minimum_value = 1
        self.good_value = random.randint(minimum_value, maximum_value) +\
                          random.randint(0, hint_good)
        self.bad_value = random.randint(0, hint_bad)
        # Randomly add bad things to item heh heh heh
        for i in range(0, self.good_value - 2):
            if random.random() < 0.12:
                self.bad_value += 1
        # Potentially add effect to item
        self._init_effect()
        # If is an active item, remove stats usually
        if self.type == "active" and random.random() < 0.9:
            self.good_value = 0
            self.bad_value = 0
        # Create stats
        self._init_stats()
        # Generate description
        self._init_description(description)
        # Reset random state
        if self.seed:
            random.setstate(rand_state)
    def _init_stats(self):
        value = self.good_value
        negative_value = self.bad_value
        # Maybe add flying
        if value >= FLYING_VALUE and random.random() < 0.01:
            self.stats.flying = True
            value -= FLYING_VALUE
        # Apply up to two health upgrades (passives only)
        if self.type == "passive":
            hp_chance = self.genstate.get_hint("stat-special")
            for i in range(0, 2):
                if value >= STAT_SPECIAL_VALUE:
                    if random.random() < 0.1 * (1 + hp_chance):
                        value -= self.stats.add_random_stat_special(self.genstate)
        # Add benefits from value
        self.stats.add_random_stats(value, 1, self.genstate)
        # Add bad stuff
        self.stats.add_random_stats(negative_value, -1, self.genstate)
    def _init_effect(self):
        # Apply effect to item maybe?
        is_trinket = self.type == "trinket"
        chance = 0.75
        if is_trinket:
            chance = 0.85
        if random.random() < chance:
            effect_value = self.add_effect()
            self.good_value -= effect_value
            self.bad_value //= 2
            if is_trinket:#trinkets are one or the other!
                self.good_value = 0
                self.bad_value = 0
    def _init_pools(self):
        # Add to pools
        if self.type != "trinket":
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
        for pool_name in self.pools:
            self.genstate.parse_hints_from_name("pool-{}".format(pool_name))
    def _init_image(self):
        """
        Generate and save a random sprite for this item
        """
        path = TRINKET_IMAGE_PATH if self.type == "trinket" else OUTPUT_IMAGE_PATH
        image.generate_image(os.path.join(path,self.get_image_name()), self.genstate)
    def _init_description(self, description=None):
        if description:
            self.description = description
        else:
            self.genstate.add_descriptors(self.stats.get_descriptors())
            self.genstate.add_descriptors(self.name.split()[1:])
            self.description = self.genstate.gen_description()
    def get_image_name(self):
        """
        Get the name of the image for this item
        """
        name = "".join((c if c in CONST_VALID_PATH_CHARACTERS else "_") for c in self.name.lower())
        base = "trinket" if self.type == "trinket" else "collectible"
        return "{}_{}.png".format(base, name)
    def add_effect(self):
        """
        Add a random effect to this item
        Returns the value of the item
        """
        # Determine active or passive
        # Default 1/10 chance
        if self.type == "passive":
            # Chance for active
            active_hint = self.genstate.get_hint("active")+0.15
            active_denom = 1 + active_hint
            active_chance = active_hint / active_denom
            # Chance for familiar
            familiar_hint = self.genstate.get_hint("familiar")+0.25
            familiar_denom = 1 + familiar_hint
            familiar_chance = familiar_hint / familiar_denom
            # Set type
            if random.random() < active_chance:
                self.type = "active"
            elif random.random() < familiar_chance:
                self.type = "familiar"
        # Generate script
        script = None
        if self.type == "passive":
            script = scriptgen.generate_item_passive(self.genstate)
        elif self.type == "trinket":
            script = scriptgen.generate_trinket(self.genstate)
        elif self.type == "familiar":
            script = scriptgen.generate_item_familiar(self.genstate)
            self.collision_damage = script.get_var_default("collision_damage", 0)
            self.familiar_base_hp = script.get_var_default("familiar_base_hp", 0)
        else:
            script = scriptgen.generate_item_active(self.genstate)
        self.effect += ','
        self.effect += script.get_output()
        value = script.get_var_default("value", 0)

        # Determine charge value
        expected_id = max(min(value, len(CHARGE_VALUES)), 1)-1
        possible_values = [x for x in CHARGE_VALUES]
        possible_values += [CHARGE_VALUES[expected_id]]*3
        if expected_id-1 >= 0:
            possible_values += [CHARGE_VALUES[expected_id-1]]
        if expected_id+1 < len(CHARGE_VALUES):
            possible_values += [CHARGE_VALUES[expected_id+1]]
        self.chargeval = random.choice(possible_values)
        return value

    def get_cacheflags(self):
        """
        Get a list of cacheflags for this item
        """
        return self.stats.get_cacheflags()
    def gen_xml(self):
        """
        Generate the XML definition for this item
        """
        ret = ElementTree.Element(self.type)
        ret.set("description", self.description)
        ret.set("name", self.name)
        ret.set("gfx", self.get_image_name())
        self.stats.gen_xml(ret)
        if self.type == "active":
            ret.set("maxcharges", str(self.chargeval))
            ret.set("cooldown", "180")
        return ret
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
        "\tevaluate_cache = function(self, player, flag)\n{}\nend\n".format(\
            self.stats.gen_eval_cache()) + self.effect +\
        "}\n"
    def gen_familiar_xml(self):
        if self.type == "familiar":
            path = ANIM_IMAGE_PATH
            image_name = self.get_image_name()
            anim_name = "anim_" + image_name +".anm2"
            anim_path = os.path.join(ANIM_IMAGE_PATH, anim_name)
            with open(anim_path, 'w') as anim_write:
                local_path = os.path.join("items/collectibles", image_name)
                anim_write.write(anim_base_xml.replace("$IMAGEPATH", local_path))
            xml = ElementTree.Element("entity")
            xml.set("anm2path", anim_name)
            xml.set("baseHP", str(self.familiar_base_hp))
            xml.set("boss", "0")
            xml.set("champion", "0")
            xml.set("collisionDamage", str(self.collision_damage))
            xml.set("collisionMass", "3")
            xml.set("collisionRadius", "13")
            xml.set("friction", "1")
            xml.set("id", "3")
            xml.set("name", self.name)
            xml.set("numGridCollisionPoints", "12")
            xml.set("shadowSize", "14")
            xml.set("stageHP", "0")
            gibsxml = ElementTree.Element("gibs")
            gibsxml.set("amount", "0")
            gibsxml.set("blood", "0")
            gibsxml.set("bone", "0")
            gibsxml.set("eye", "0")
            gibsxml.set("gut", "0")
            gibsxml.set("large", "0")
            xml.append(gibsxml)
            return xml
        else:
            return None
