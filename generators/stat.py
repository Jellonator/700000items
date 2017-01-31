import random

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
            ret +=\
            "\t\tif flag == CacheFlag.CACHE_RANGE then\n"+\
            "\t\t\tplayer.TearHeight = player.TearHeight + {:.2f}\n".format(self.shot_range)+\
            "\t\t\tplayer.TearFallingSpeed = player.TearFallingSpeed + 0.5\n"+\
            "\t\tend\n"
        if self.flying != None:
            ret += genStatStr("CACHE_FLYING", "CanFly", "=", self.flying)
        ret += "\tend"
        return ret
