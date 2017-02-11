#!/usr/bin/python3
from generators import namegen
from generators.item import IsaacItem
from generators.item import POOL_NAMES
from generators import scriptgen
import os
import sys
import shutil
import random

# Generate X number of items
# Used to be 700,000 but its really not good to have that many items
MAGIC_NUMBER = 500
TARGET_FOLDER = "700000items"

# Utility functions
def get_output_path(dir):
    """
    Get a path under the output path
    """
    return os.path.join(TARGET_FOLDER, dir)

def check_folder(dir):
    """
    Ensures that a folder exists
    """
    if not os.path.isdir(dir):
        os.makedirs(dir)


def generate_pocket_effect(name):
    tempitem = IsaacItem(name, None)
    effect = scriptgen.generate_card_effect(tempitem)
    return """function()
{}
end""".format(effect.get_output())

# Parse arguments
if len(sys.argv) > 1:
    arg = sys.argv[1]
    if arg == "release":
        arg = "2500"
    MAGIC_NUMBER = int(arg)

# Remove previous mod folder
if os.path.exists(TARGET_FOLDER):
    print("Removing previous mod folder...")
    shutil.rmtree(TARGET_FOLDER)

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
check_folder(get_output_path('content'))
check_folder(get_output_path('resources/gfx/items/collectibles'))

# XML definition of item pool entry
ITEMPOOL_DEF = "\t\t<Item Name=\"{}\" Weight=\"1\" DecreaseBy=\"1\" RemoveOn=\"0.1\"/>\n"

# Write out items to xml files
items = {}
item_number = 1
xml_items_name = get_output_path('content/items.xml')
xml_pools_name = get_output_path('content/itempools.xml')
xml_pocketitems_name = get_output_path('content/pocketitems.xml')
with open(xml_items_name, 'w') as xml_items,\
open(xml_pools_name, 'w') as xml_pools,\
open(get_output_path("main.lua"), 'w') as script:
    # header
    with open("generators/script/header.lua", 'r') as header:
        script.write(header.read())

    pools = {}
    for name in POOL_NAMES:
        pools[name] = []

    # Actual item generation here
    xml_items.write("<items gfxroot=\"gfx/items/\" version=\"1\">\n");
    max_failed_tries = MAGIC_NUMBER
    while len(items) < MAGIC_NUMBER and max_failed_tries > 0:
        name = namegen.generate_name()
        if name in items:
            max_failed_tries -= 1
            continue
        seed = hash(name)
        full_name = str(item_number) + " " + name
        item = IsaacItem(full_name, seed)
        items[name] = item.name
        item_number += 1
        xml_items.write("\t{}\n".format(item.gen_xml()))
        for pool in item.get_pools():
            pools[pool].append(item.name)
        script.write("Mod.items[\"{}\"] = {}\n".format(\
            item.name, item.get_definition()))
    xml_items.write("</items>\n");

    # write out item names
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
        for i in range(0, 25):
            name = namegen.generate_name()
            pill_names[name] = name
        # generate pills
        for pill_name in pill_names.keys():
            xml_pocketitems.write("\t<pilleffect name=\"{}\" />\n".format(pill_name))
            pill_script = generate_pocket_effect(pill_name)
            script.write("Mod.pills[\"{}\"] = {}\n".format(pill_name, pill_script))

        # generate card names
        # There is currently something wrong with card generation, so it is
        # disabled. Seems to be an issue with the API though.
        card_names = {}
        # for i in range(0, 25):
        #     name = namegen.generate_name()
        #     card_names[name] = name
        # generate cards
        for card_name in card_names.keys():
            card_type = random.choice(['card', 'card', 'rune'])
            description = "It's a {}!".format(card_type)
            hud = "".join(card_name.split()).replace(".", "").replace("\'", "")
            xml_pocketitems.write("\t<{} name=\"{}\" hud=\"{}\" description=\"{}\"/>\n".format(\
                card_type, card_name, hud, description))
            card_script = generate_pocket_effect(card_name)
            script.write("Mod.cards[\"{}\"] = {}\n".format(card_name, card_script))

        xml_pocketitems.write("</pocketitems>\n");

    # footer
    with open("generators/script/footer.lua", 'r') as footer:
        script.write(footer.read())

# Output metadata
shutil.copy("metadata.xml", TARGET_FOLDER)
shutil.copy("preview.jpg", TARGET_FOLDER)

# Final prints
print("Done!")
print("Generated {} items.".format(len(items)))
