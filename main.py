#!/usr/bin/python3
from generators import namegen
from generators.item import IsaacItem
import os
import sys

# Generate X number of items
# Used to be 700,000 but its really not good to have that many items
MAGIC_NUMBER = 5000
if len(sys.argv) > 1:
    MAGIC_NUMBER = int(sys.argv[1])

print("Generating {} items!".format(MAGIC_NUMBER))

# Make sure folders exists
def check_folder(dir):
    if not os.path.isdir(dir):
        os.makedirs(dir)
check_folder('content')
check_folder('resources/gfx/items/collectibles')

# List of all pools
POOL_NAMES = ["treasure", "shop", "boss", "devil", "angel", "secret", "library",\
    "challenge", "goldenChest", "redChest", "beggar", "demonBeggar", "curse",\
    "keyMaster", "bossrush", "dungeon", "bombBum", "greedTreasure", "greedBoss",\
    "greedShop", "greedCurse", "greedDevil", "greedAngel", "greedLibrary",\
    "greedSecret", "greedGoldenChest"]

# XML definition of item pool entry
ITEMPOOL_DEF = "\t\t<Item Name=\"{}\" Weight=\"1\" DecreaseBy=\"1\" RemoveOn=\"0.1\"/>\n"

# Generate a metric crap-tonne of items
items = {}
max_failed_tries = MAGIC_NUMBER
item_number = 1
while len(items) < MAGIC_NUMBER and max_failed_tries > 0:
    name = namegen.generate_name()
    if name in items:
        max_failed_tries -= 1
        continue
    seed = hash(name)
    full_name = str(item_number) + " " + name
    item = IsaacItem(full_name, seed)
    items[name] = item
    item_number += 1

# Write out items to xml files
xml_items_name = 'content/items.xml'
xml_pools_name = 'content/itempools.xml'
with open(xml_items_name, 'w') as xml_items,\
open(xml_pools_name, 'w') as xml_pools:
    pools = {}
    for name in POOL_NAMES:
        pools[name] = []

    # Add items to definition
    xml_items.write("<items gfxroot=\"gfx/items/\" version=\"1\">\n");
    for name, item in items.items():
        xml_items.write("\t{}\n".format(item.gen_xml()))
        for pool in item.get_pools():
            pools[pool].append(item.name)
    xml_items.write("</items>\n");

    # Add items to pools
    xml_pools.write("<ItemPools>\n")
    for pool_name, pool_items in pools.items():
        xml_pools.write("\t<Pool Name=\"{}\">\n".format(pool_name))
        for name in pool_items:
            xml_pools.write(ITEMPOOL_DEF.format(name));
        xml_pools.write("\t</Pool>\n")
    xml_pools.write("</ItemPools>\n")

# Generate Lua script
with open("main.lua", 'w') as script:
    # header
    with open("generators/script/header.lua", 'r') as header:
        script.write(header.read())

    # export item names
    script.write("Mod.item_names = {\n")
    for name, item in items.items():
        script.write("\t\"{}\",\n".format(item.name))
    script.write("}\n")

    # export item definitions
    for name, item in items.items():
        script.write("Mod.items[\"{}\"] = {}\n".format(item.name, item.gen_definition()))

    # footer
    with open("generators/script/footer.lua", 'r') as footer:
        script.write(footer.read())

print("Done!")
print("Generated {} items.".format(len(items)))
