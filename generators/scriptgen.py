from . import filepicker
from .stat import IsaacStats
import os
import random
import glob

CONST_ACTIVE_ITEM_IDS = [
    # Only relevant items which wouldn't suck as an effect (e.g. no kamikaze)
    507, 486, 484, 421, 383, 394, 288, 287, 192, 175, 171,
    160, 145, 137, 123, 111, 107, 56, 45, 41, 39, 36, 35, 34
]

CONST_BASE_FILE = "generators/script/base.lua"

CONST_EFFECT_TYPES_COMMON = [
    "EffectVariant.PLAYER_CREEP_WHITE",
    "EffectVariant.PLAYER_CREEP_BLACK",
    "EffectVariant.PLAYER_CREEP_RED",
    "EffectVariant.PLAYER_CREEP_GREEN",
]

CONST_EFFECT_TYPES_RARE = [
    "EffectVariant.HOT_BOMB_FIRE",
    "EffectVariant.MONSTROS_TOOTH",
    "EffectVariant.MOM_FOOT_STOMP",
    "EffectVariant.PLAYER_CREEP_LEMON_MISHAP",
    "EffectVariant.SHOCKWAVE",
    "EffectVariant.SHOCKWAVE_DIRECTIONAL",
    "EffectVariant.FIREWORKS",#Useless but kek
]

CONST_ENTITY_PICKUP = "EntityType.ENTITY_PICKUP"
CONST_PICKUP_VARIANTS = {
    "any": "PickupVariant.PICKUP_NULL",
    "heart": "PickupVariant.PICKUP_HEART",
    "coin": "PickupVariant.PICKUP_COIN",
    "key": "PickupVariant.PICKUP_KEY",
    "bomb": "PickupVariant.PICKUP_BOMB",
    "chest": "PickupVariant.PICKUP_CHEST",
    "sack": "PickupVariant.PICKUP_GRAB_BAG",
    "pill": "PickupVariant.PICKUP_PILL",
    "battery": "PickupVariant.PICKUP_LIL_BATTERY",
    "card": "PickupVariant.PICKUP_TAROTCARD",
    "trinket": "PickupVariant.PICKUP_TRINKET",
}
CONST_PICKUP_VARIANTS_LIST = list(CONST_PICKUP_VARIANTS.keys())
CONST_PICKUP_SUBTYPES = {
    # NOT a list of all subtypes!
    # This is only a selection of specific drops
    # "0" represents null sub-type, which spawns random drops
    "any": ["0"],
    "heart": ["0", "HeartSubType.HEART_FULL", "HeartSubType.HEART_SOUL",
        "HeartSubType.HEART_ETERNAL", "HeartSubType.HEART_BLACK",
        "HeartSubType.HEART_GOLDEN"],
    "coin": ["0", "CoinSubType.COIN_PENNY", "CoinSubType.COIN_STICKYNICKEL"],
    "key": ["0", "KeySubType.KEY_NORMAL", "KeySubType.KEY_CHARGED"],
    "bomb": ["0", "BombSubType.BOMB_NORMAL", "BombSubType.BOMB_TROLL"],
    "chest": ["0"],
    "sack": ["0"],
    "pill": ["0"],
    "battery": ["0"],
    "card": ["0"],
    "trinket": ["0"],
}

def choose_random_active():
    return random.choice(CONST_ACTIVE_ITEM_IDS)

def choose_random_effect_common():
    return random.choice(CONST_EFFECT_TYPES_COMMON)

def choose_random_effect_rare():
    return random.choice(CONST_EFFECT_TYPES_RARE)

def does_effect_need_velocity(name):
    return name == "EffectVariant.SHOCKWAVE_DIRECTIONAL"

def choose_random_pickup_subtype(name):
    if name in CONST_PICKUP_SUBTYPES:
        if random.random() < 0.50:
            return "0"
        else:
            return random.choice(CONST_PICKUP_SUBTYPES[name])
    else:
        return "0"

def choose_random_pickup():
    return random.choice(CONST_PICKUP_VARIANTS_LIST)

def get_pickup_name(name):
    return CONST_PICKUP_VARIANTS[name]

def load_file(fname, item):
    with open(fname, 'r') as fh:
        return load_string(fh.read(), item, fname)

def load_string(string, item, fname):
    sb = ScriptBuilder(item);
    sb.parse(string, fname);
    return sb

def generate_effect(item):
    return load_file(CONST_BASE_FILE, item)

CONST_PYTHON_BEGIN = "python[["
CONST_PYTHON_END = "]]"
CONST_PYTHON_BEGIN_LEN = len(CONST_PYTHON_BEGIN)
CONST_PYTHON_END_LEN = len(CONST_PYTHON_END)
CONST_GEN_PATH = "generators/script/"

class ScriptBuilder:
    def __init__(self, item):
        self.output = ""
        self.data = {}
        self.item = item
        self.genstate = item.genstate
        self.allow_random = True
    def set_allow_random(self, value):
        self.allow_random = value
    def inc_var(self, name, acc):
        if not name in self.data:
            self.data[name] = 0
        self.data[name] += acc
    def set_var(self, name, value):
        self.data[name] = value
    def get_var(self, name):
        if name in self.data:
            return self.data[name]
    def get_var_default(self, name, other):
        if name in self.data:
            return self.data[name]
        else:
            return other
    def parse(self, string, fname):
        while len(string) > 0:
            if CONST_PYTHON_BEGIN in string and CONST_PYTHON_END in string:
                # Find positions
                python_pos_start = string.find(CONST_PYTHON_BEGIN)
                python_pos_end = string.find(CONST_PYTHON_END)
                # Get string splits
                append_string = string[:python_pos_start]
                python_string = string[python_pos_start+CONST_PYTHON_BEGIN_LEN:python_pos_end]
                string = string[python_pos_end+CONST_PYTHON_END_LEN:]
                # Append strings
                self.write(append_string)
                try:
                    exec(python_string, globals(), {
                        "gen": self
                    })
                except Exception as err:
                    print(err)
                    print("Occurred in file {}!".format(fname))
            else:
                self.write(string)
                string = ""
    def write(self, string):
        self.output += str(string)
    def get_hint(self, name):
        return self.item.genstate.get_hint(name)
    def add_hint(self, name, value):
        self.item.genstate.add_hint(name, value)
    def writeln(self, string):
        self.output += str(string) + "\n"
    def write_effect(self, string):
        self.item.write_effect(string)
    def include(self, fname):
        if os.path.isfile(fname):
            result = load_file(fname, self.item)
            self.writeln(result.get_output())
            for key, value in result.data.items():
                self.set_var(key, value)
        elif os.path.isdir(fname):
            picker = filepicker.get_path(fname)
            filedef = picker.choose_random_with_name(self.item.name, self.item.genstate.hints)
            path = filedef.get_path()
            self.include(path)
        else:
            base_dir = os.path.dirname(fname)
            if not base_dir.startswith(CONST_GEN_PATH):
                self.include(os.path.join(CONST_GEN_PATH, fname))
            else:
                raise Exception("Not a file or directory!" + fname)
    def chance(self, base_chance, luck_scale, min_chance):
        if self.allow_random:
            self.writeln("if math.random()*math.max({}, {}-{}*player.Luck) > 1 then return end".format(\
                min_chance, base_chance, luck_scale));
    def get_output(self):
        return self.output
