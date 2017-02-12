#!/usr/bin/python3
from generators import namegen
from generators.item import IsaacItem
from generators.item import POOL_NAMES
from generators.state import IsaacGenState
from generators import scriptgen
from generators import util
import os
import sys
import shutil
import random

# Generate X number of items
# Used to be 700,000 but its really not good to have that many items
MAGIC_NUMBER = 500
NUM_PILLS = 25
NUM_TRINKETS = 100
HARDCODED_ITEMS = {
    1101: ("Mr. Box", "Seen Is I've Near Meh"),
    700000: ("Last Item", "Fold"),
    91: ("True last item", "Isn't a hidden object clone!"),
}
HARDCODED_ITEM_NAMES = [x for (x, _) in HARDCODED_ITEMS.values()]

# Utility functions
def generate_pocket_effect(name):
    # tempitem = IsaacItem(name, None)
    state = IsaacGenState(name)
    effect = scriptgen.generate_card_effect(state)
    return ("""function()
{}
end""".format(effect.get_output()), state.gen_description())

# Parse arguments
if len(sys.argv) > 1:
    arg = sys.argv[1]
    if arg == "release":
        arg = "2500"
    MAGIC_NUMBER = int(arg)

# Remove previous mod folder
if os.path.exists(util.TARGET_FOLDER):
    print("Removing previous mod folder...")
    shutil.rmtree(util.TARGET_FOLDER)

# Confirm number of items
print("{} items will be generated.".format(MAGIC_NUMBER))
if MAGIC_NUMBER > 10000:
    print("This is a lot of items, generating these may be a slow process.")
while True:
    value = input("Do you wish to continue? Y/n: ").lower().strip()
    if value in ['y', 'yes', '']:
        break
    if value in ['n', 'no', 'quit', 'q', 'stop']:
        print("abort")
        quit()
    print("Not a valid yes or no answer")

# Make sure folders exist
util.check_folder(util.get_output_path('content'))
util.check_folder(util.get_output_path('resources/gfx/items/collectibles'))
util.check_folder(util.get_output_path('resources/gfx/items/trinkets'))

# XML definition of item pool entry
ITEMPOOL_DEF = "\t\t<Item Name=\"{}\" Weight=\"1\" DecreaseBy=\"1\" RemoveOn=\"0.1\"/>\n"

# Write out items to xml files
items = {}
trinkets = {}
trinket_number = 1
xml_items_name = util.get_output_path('content/items.xml')
xml_pools_name = util.get_output_path('content/itempools.xml')
xml_pocketitems_name = util.get_output_path('content/pocketitems.xml')
with open(xml_items_name, 'w') as xml_items,\
open(xml_pools_name, 'w') as xml_pools,\
open(util.get_output_path("main.lua"), 'w') as script:
    # header
    with open("generators/script/header.lua", 'r') as header:
        script.write(header.read())

    pools = {}
    for name in POOL_NAMES:
        pools[name] = []

    # Generate items
    xml_items.write("<items gfxroot=\"gfx/items/\" version=\"1\">\n");
    max_failed_tries = MAGIC_NUMBER
    ITEM_NUMBERS = random.sample([x for x in range(1, 700000+1) if x not in HARDCODED_ITEMS], MAGIC_NUMBER)
    while len(items) < MAGIC_NUMBER and max_failed_tries > 0:
        name = namegen.generate_name()
        if name in items or name in HARDCODED_ITEM_NAMES:
            max_failed_tries -= 1
            # print("Item name already exists, retrying: {}".format(name))
            continue
        seed = hash(name)
        full_name = str(ITEM_NUMBERS.pop()) + " " + name
        item = IsaacItem(full_name, seed)
        items[name] = item.name
        xml_items.write("\t{}\n".format(item.gen_xml()))
        for pool in item.get_pools():
            pools[pool].append(item.name)
        script.write("Mod.items[\"{}\"] = {}\n".format(\
            item.name, item.get_definition()))
    for num, (name, desc) in HARDCODED_ITEMS.items():
        seed = hash(name)
        full_name = str(num) + " " + name
        item = IsaacItem(full_name, seed, description=desc)
        items[name] = item.name
        xml_items.write("\t{}\n".format(item.gen_xml()))
        for pool in item.get_pools():
            pools[pool].append(item.name)
        script.write("Mod.items[\"{}\"] = {}\n".format(\
            item.name, item.get_definition()))
    # Generate trinkets
    max_failed_tries = NUM_TRINKETS
    while len(trinkets) < NUM_TRINKETS and max_failed_tries > 0:
        name = namegen.generate_name()
        if name in trinkets:
            max_failed_tries -= 1
            continue
        seed = hash(name)
        trinket = IsaacItem(name, seed, True)
        trinkets[name] = trinket.name
        trinket_number += 1
        xml_items.write("\t{}\n".format(trinket.gen_xml()))
        script.write("Mod.trinkets[\"{}\"] = {}\n".format(\
            trinket.name, item.get_definition()))
    xml_items.write("</items>\n");

    # write out item names to script
    script.write("Mod.item_names = {\n")
    for name, item_name in items.items():
        script.write("\t\"{}\",\n".format(item_name))
    script.write("}\n")

    # Add items to pools
    xml_pools.write("<ItemPools>\n")
    for pool_name, pool_items in pools.items():
        xml_pools.write("\t<Pool Name=\"{}\">\n".format(pool_name))
        for name in pool_items:
            xml_pools.write(ITEMPOOL_DEF.format(name));
        xml_pools.write("\t</Pool>\n")
    xml_pools.write("</ItemPools>\n")

    # generate pills and cards
    with open(xml_pocketitems_name, 'w') as xml_pocketitems:
        xml_pocketitems.write("<pocketitems>\n");

        # generate pill names
        pill_names = {}
        for i in range(0, NUM_PILLS):
            rand_name = namegen.generate_name()
            (pill_script, pill_name) = generate_pocket_effect(rand_name)
            pill_names[pill_name] = pill_script
        # write out pills
        for pill_name, pill_script in pill_names.items():
            xml_pocketitems.write("\t<pilleffect name=\"{}\" />\n".format(pill_name))
            script.write("Mod.pills[\"{}\"] = {}\n".format(pill_name, pill_script))

        # generate cards
        # Nothing here yet, cards seem to be bugged?
        xml_pocketitems.write("</pocketitems>\n");

    # footer
    with open("generators/script/footer.lua", 'r') as footer:
        script.write(footer.read())

# Output metadata
shutil.copy("metadata.xml", util.TARGET_FOLDER)
shutil.copy("preview.jpg", util.TARGET_FOLDER)

# Final prints
print("Done!")
print("Generated {} items.".format(len(items)))
