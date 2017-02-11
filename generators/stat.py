import random
from . import util

# Common stats
STAT_RANGES = {
    'speed': 0.09,
    'luck': 1,
    'tears': 1,
    'shot_speed': 0.07,
    'damage': 0.7,
    'range': 1.5,
}

# Special, rarer stats (health) for items
STAT_RANGES_SPECIAL = {
    'health': (1, 1),
    'soul': (3, 5),
    'black': (2, 4)
}

CONST_WEAPONS = [
    "WeaponType.WEAPON_TEARS",
    "WeaponType.WEAPON_BRIMSTONE",
    "WeaponType.WEAPON_LASER",
    "WeaponType.WEAPON_KNIFE",
    "WeaponType.WEAPON_BOMBS",
    "WeaponType.WEAPON_ROCKETS",
    "WeaponType.WEAPON_MONSTROS_LUNGS",
    "WeaponType.WEAPON_LUDOVICO_TECHNIQUE",
    "WeaponType.WEAPON_TECH_X",
]

# Stats and their weights
STAT_NAMES       = ['speed', 'luck', 'tears', 'shot_speed', 'damage', 'range']
STAT_WEIGHTS     = [    3.4,    1.8,     4.0,          1.8,      4.3,     4.0]
STAT_WEIGHTS_BAD = [    3.2,    0.8,     4.0,          3.0,      2.4,     3.8]
STAT_NAMES_SPECIAL =   ['health', 'soul', 'black']
STAT_WEIGHTS_SPECIAL = [      8,      4,       2]

def genStatStr(flagstr, propertystr, op, value):
    """
    Generate Lua code for modifying stats
    -- flagstr: Name of the CacheFlag
    -- propertystr: Name of the property to modify
    -- op: Operator to use
    -- value: How much the stat will change
    """
    if isinstance(value, bool):
        value = "true" if value else "false"
    elif isinstance(value, float):
        value = "{:.2f}".format(value);
    operation = None
    if op == "=":
        operation = "player.{1} = {3}"
    else:
        operation = "player.{1} = player.{1} {2} {3}"

    return "\t\tif flag == CacheFlag.{0} then\n".format(flagstr)+\
    "\t\t\t" + operation.format(flagstr, propertystr, op, value) + "\n" +\
    "\t\tend\n"

def generate_random_stat_special(statname):
    """
    Generate a random value for a given special stat upgrade
    -- statname: Name of the stat to generate a value for
    """
    values = STAT_RANGES_SPECIAL[statname]
    a = values[0]
    b = values[1]
    if statname == "health":
        return 2
    return random.randint(a, b)

def pick_random_stat_special(state):
    weights = [x for x in STAT_WEIGHTS_SPECIAL]
    weights[0] += state.get_hint("stat-health") # HP
    weights[1] += state.get_hint("stat-spirit") # Spirit hearts
    weights[2] += state.get_hint("stat-black") # Black hearts
    return util.choice_weights(STAT_NAMES_SPECIAL, weights)

def pick_random_stat(is_good, state):
    weights = None
    if is_good:
        weights = [x for x in STAT_WEIGHTS]
        weights[0] += state.get_hint("stat-speed") # Speed
        weights[1] += state.get_hint("stat-luck") # Luck
        weights[2] += state.get_hint("stat-tears") # Tears
        weights[3] += state.get_hint("stat-shotspeed") # ShotSpeed
        weights[4] += state.get_hint("stat-damage") # Damage
        weights[5] += state.get_hint("stat-range") # Range
    else:
        weights = STAT_WEIGHTS_BAD
    return util.choice_weights(STAT_NAMES, weights)

def generate_random_stat(statname, value):
    """
    Generate a random value for a given stat upgrade
    -- statname: Name of the stat to generate a value for
    -- value: How highly valued the stat being generated is
    Higher value = higher returned stats
    """
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

def updown(value):
    return "Up" if value > 0 else "Down"

def maybe_append(ls, value, name):
    if value != 0:
        ls.append("{} {}".format(name, updown(value)))

# Value of a special stat
STAT_SPECIAL_VALUE = 2

class IsaacStats:
    """
    Class which represents stat upgrades
    """
    tears = 0
    damage = 0
    speed = 0
    luck = 0
    shot_speed = 0
    shot_range = 0
    chance_devil = 0
    chance_angel = 0
    hearts = 0
    hearts_black = 0
    hearts_spirit = 0
    heal = 0
    flying = None
    weapon = None
    def add_random_stats(self, value, multiplier, genstate):
        """
        Add multiple stats to this item
        -- value: Total value of stats to add. Higher value = more stats
        -- multiplier: What the generated stat will be multiplied by
        -- genstate: Generator state for this item. Used for hints.
        """
        while value > 0:
            value -= self.add_random_stat(value, multiplier, genstate)
    def add_random_stat_special(self, genstate):
        """
        Add a random special stat to this item
        Returns how much of the maxvalue was taken
        """
        stat_name = pick_random_stat_special(genstate)
        stat_inc = generate_random_stat_special(stat_name)
        self.increment_stat(stat_name, stat_inc)
        return STAT_SPECIAL_VALUE
    def add_random_stat(self, maxvalue, multiplier, genstate):
        """
        Add a random stat
        -- maxvalue: The maximum value this random stat can have
        -- multiplier: What the generated stat will be multiplied by
        -- genstate: Generator state for this item. Used for hints.
        Returns how much of the maxvalue was taken
        """
        stat_name = pick_random_stat(multiplier > 0, genstate)
        if stat_name == "luck":
            maxvalue = min(2, maxvalue)
        take_value = random.randint(1, maxvalue)
        stat_inc = generate_random_stat(stat_name, take_value)*multiplier
        self.increment_stat(stat_name, stat_inc)
        return take_value
    def increment_stat(self, stat, value):
        """
        Add a value to a stat
        -- stat: Name of the stat to modify
        -- value: How much to modify the stat by
        """
        if stat == "speed":
            self.speed += value
        elif stat == "luck":
            self.luck += value
        elif stat == "shot_speed":
            self.shot_speed += value
        elif stat == "tears":
            self.tears += value
        elif stat == "damage":
            self.damage += value
        elif stat == "range":
            self.shot_range += value
        elif stat == "health":
            self.hearts += value
            for i in range(0, value):
                if random.randint(1, 6) != 1:
                    self.heal += 1
        elif stat == "soul":
            self.hearts_spirit += value
        elif stat == "black":
            self.hearts_black += value
        else:
            raise ValueError("{} is not a valid name for a stat!".format(stat))
    def get_cacheflags(self):
        """
        Get a list of cacheflags
        """
        ret = []
        if self.tears != 0:
            ret.append("firedelay")
        if self.damage != 0:
            ret.append("damage")
        if self.speed != 0:
            ret.append("speed")
        if self.shot_speed != 0:
            ret.append("shotspeed")
        if self.luck != 0:
            ret.append("luck")
        if self.shot_range != 0:
            ret.append("range")
        if self.flying != None:
            ret.append("flying")
        return ret
    def gen_xml(self):
        """
        Generate the XML definition for these stats
        """
        ret = ""
        if self.heal != 0:
            ret = ret + " hearts=\"{}\" ".format(self.heal)
        if self.hearts != 0:
            ret = ret + " maxhearts=\"{}\" ".format(self.hearts)
        if self.hearts_black != 0:
            ret = ret + " blackhearts=\"{}\" ".format(self.hearts_black)
        if self.hearts_spirit != 0:
            ret = ret + " soulhearts=\"{}\" ".format(self.hearts_spirit)
        flags = self.get_cacheflags()
        if len(flags) > 0:
            ret = ret + " cache=\"{}\" ".format(" ".join(flags))
        return ret
    def does_mod_stats(self):
        """
        Return whether or not stats are modified
        """
        return len(self.get_cacheflags()) > 0
    def gen_eval_cache(self):
        """
        generate Lua code for the evaluate_cache callback
        """
        if not self.does_mod_stats():
            return "nil"
        ret = "function (self, player, flag)\n"
        if self.tears != 0:
            ret += genStatStr("CACHE_FIREDELAY", "MaxFireDelay", "-", self.tears)
        if self.damage != 0:
            ret += genStatStr("CACHE_DAMAGE", "Damage", "+", self.damage)
        if self.speed != 0:
            ret += genStatStr("CACHE_SPEED", "MoveSpeed", "+", self.speed)
        if self.shot_speed != 0:
            ret += genStatStr("CACHE_SHOTSPEED", "ShotSpeed", "+", self.shot_speed)
        if self.luck != 0:
            ret += genStatStr("CACHE_LUCK", "Luck", "+", self.luck)
        if self.shot_range != 0:
            ret += genStatStr("CACHE_RANGE", "TearHeight", "-", self.shot_range)
            # ret +=\
            # "\t\tif flag == CacheFlag.CACHE_RANGE then\n"+\
            # "\t\t\tplayer.TearHeight = player.TearHeight - {:.2f}\n".format(self.shot_range)+\
            # "\t\t\tplayer.TearFallingSpeed = player.TearFallingSpeed - {:.2f}\n".format(self.shot_range/8)+\
            # "\t\tend\n"
        if self.flying != None:
            ret += genStatStr("CACHE_FLYING", "CanFly", "=", self.flying)
        if self.weapon != None:
            ret += genStatStr("CACHE_WEAPON", "")
        ret += "\tend"
        return ret
    def get_descriptors(self):
        ret = []
        maybe_append(ret, self.luck, "Luck")
        maybe_append(ret, self.hearts, "Health")
        maybe_append(ret, self.hearts_black, "Evil")
        maybe_append(ret, self.tears, "Tears")
        maybe_append(ret, self.damage, "Damage")
        maybe_append(ret, self.shot_speed, "Shot Speed")
        maybe_append(ret, self.shot_range, "Range")
        maybe_append(ret, self.speed, "Speed")
        if len(ret) >= 3:
            ret.append("All Stats Up")
        return ret
    def add_random_weapon(self):
        # Weapons are not implemented yet, this will come in the future
        # There is not currently a way to do this
        self.weapon = random.choice(CONST_WEAPONS)
