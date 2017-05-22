from xml.etree import ElementTree

class Generator:
    def __init__(self, script):
        self.xml_item = ElementTree.Element("items")
        self.xml_item.set('gfxroot', 'gfx/items/')
        self.xml_item.set('version', '1')
        self.xml_pool = ElementTree.Element("ItemPools")
        self.xml_entity = ElementTree.Element("entities")
        self.xml_entity.set('anm2root', 'gfx/')
        self.xml_entity.set('version', '5')
        self.xml_pocket = ElementTree.Element("pocketitems")
        self.lua_script = script
        self.pools = {}
        self.items = {}
        self.itemnames = []
        self.trinkets = {}
        self.pills = {}

    def add_item(self, item, shortname=None):
        self.xml_item.append(item.gen_xml())
        familiar = item.gen_familiar_xml()
        if familiar != None:
            self.xml_entity.append(familiar)
        for pool in item.get_pools():
            if not pool in self.pools:
                xml_pool = ElementTree.Element("Pool")
                xml_pool.set("Name", pool)
                self.pools[pool] = xml_pool
                self.xml_pool.append(xml_pool)
            xml_pooldef = ElementTree.Element("Item")
            xml_pooldef.set("Weight", "1")
            xml_pooldef.set("Name", item.name)
            xml_pooldef.set("DecreaseBy", "1")
            xml_pooldef.set("RemoveOn", "0.1")
            self.pools[pool].append(xml_pooldef)
        self.lua_script.write("Mod.items[\"{}\"] = {}".format(
            item.name, item.get_definition()))
        self.items[item.name] = item.name
        if shortname != None:
            self.items[shortname] = item.name
        self.itemnames.append(item.name)

    def add_trinket(self, trinket):
        self.trinkets[trinket.name] = trinket.name
        self.xml_item.append(trinket.gen_xml())
        self.lua_script.write("Mod.trinkets[\"{}\"] = {}".format(
            trinket.name, trinket.get_definition()))

    def has_trinket(self, name):
        return name in self.trinkets

    def has_item(self, name):
        return name in self.items

    def script_generate_itemnames(self):
        self.lua_script.write("Mod.item_names = {\n")
        for name in self.itemnames:
            self.lua_script.write("\t\"{}\",\n".format(name))
        self.lua_script.write("}\n")

    def add_pocket_pill(self, name, script):
        xml = ElementTree.Element("pilleffect")
        xml.set("name", name)
        self.xml_pocket.append(xml)
        self.lua_script.write("Mod.pills[\"{}\"] = {}\n".format(name, script))

    def write_items(self, path):
        ElementTree.ElementTree(self.xml_item).write(path, "unicode")

    def write_entities(self, path):
        ElementTree.ElementTree(self.xml_entity).write(path, "unicode")

    def write_pools(self, path):
        ElementTree.ElementTree(self.xml_pool).write(path, "unicode")

    def write_pocketitems(self, path):
        ElementTree.ElementTree(self.xml_pocket).write(path, "unicode")
