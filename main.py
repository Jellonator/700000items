#!/usr/bin/python3
from generators import namegen
from generators.item import IsaacItem
from generators.item import POOL_NAMES
from generators.state import IsaacGenState
from generators import scriptgen
from generators import util
from generators import filepicker
from generators import Generator
import os
import sys
import shutil
import random
import xml.etree.ElementTree

# Generate X number of items
# Used to be 700,000 but its really not good to have that many items
MAGIC_NUMBER = 400
NUM_PILLS = 30
NUM_TRINKETS = 100
RELEASE_NUM = 1500
HARDCODED_ITEMS = {
    1101: ("Mr. Box", "Seen Is I've Near Meh"),
    700000: ("Last Item", "Fold"),
    91: ("True last item", "Isn't a hidden object clone!"),
    0: ("This mod is absolutely garbage", "Can i have a opinion about something? Don't copy and paste my comment."),
    7: ("Grand Dad", "Press Start to Rich")
}
HARDCODED_ITEM_NAMES = [x for (x, _) in HARDCODED_ITEMS.values()]

# Utility functions
def generate_card_effect(name):
    # tempitem = IsaacItem(name, None)
    state = IsaacGenState(name)
    effect = scriptgen.generate_card_effect(state)
    return (util.generate_lua_function([], effect.get_output()),
            state.gen_description())

def generate_pill_effect(name):
    # tempitem = IsaacItem(name, None)
    state = IsaacGenState(name)
    effect = scriptgen.generate_pill_effect(state)
    return (util.generate_lua_function([], effect.get_output()),
            state.gen_description())

def generate_item(generator, name, full_name):
    seed = hash(name)
    item = IsaacItem(full_name, seed)
    generator.add_item(item, name)

def generate_items(generator, numitems):
    max_failed_tries = numitems
    valid_item_ids = [x for x in range(1, 700000+1) if x not in HARDCODED_ITEMS]
    numbers = random.sample(valid_item_ids, numitems)
    while len(numbers) > 0 and max_failed_tries > 0:
        name = namegen.generate_name()
        if generator.has_item(name) or name in HARDCODED_ITEM_NAMES:
            max_failed_tries -= 1
            # print("Item name already exists, retrying: {}".format(name))
            continue
        full_name = str(numbers.pop()) + " " + name
        generate_item(generator, name, full_name)
    for num, (name, desc) in HARDCODED_ITEMS.items():
        full_name = str(num) + " " + name
        generate_item(generator, name, full_name)

def generate_trinkets(generator, numtrinkets):
    max_failed_tries = numtrinkets
    while numtrinkets > 0 and max_failed_tries > 0:
        name = namegen.generate_name()
        if generator.has_trinket(name):
            max_failed_tries -= 1
            continue
        numtrinkets -= 1
        seed = hash(name)
        trinket = IsaacItem(name, seed, True)
        generator.add_trinket(trinket)

def generate_pills(generator, num):
    pill_names = {}
    for i in range(0, num):
        rand_name = namegen.generate_name()
        (pill_script, pill_name) = generate_pill_effect(rand_name)
        pill_names[pill_name] = pill_script
    # write out pills
    for pill_name, pill_script in pill_names.items():
        generator.add_pocket_pill(pill_name, pill_script)

def main(args):
    global MAGIC_NUMBER
    # Parse arguments
    if len(args) > 0:
        arg = args[0]
        if arg == "release":
            arg = RELEASE_NUM
        MAGIC_NUMBER = int(arg)

    # Remove previous mod folder
    if os.path.exists(util.TARGET_FOLDER):
        print("Removing previous mod folder...")
        shutil.rmtree(util.TARGET_FOLDER)

    # Make sure folders exist
    util.check_folder(util.get_output_path('content'))
    util.check_folder(util.get_output_path('resources/gfx/items/collectibles'))
    util.check_folder(util.get_output_path('resources/gfx/items/trinkets'))
    util.check_folder(util.get_output_path('resources/gfx/familiar'))

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

    # Create generator
    script = open(util.get_output_path("main.lua"), 'w')
    with open("generators/script/header.lua", 'r') as header:
        script.write(header.read())
    generator = Generator(script)

    # Generate a bunch of stuff
    generate_items(generator, MAGIC_NUMBER)
    generate_trinkets(generator, NUM_TRINKETS)
    generator.script_generate_itemnames()
    generate_pills(generator, NUM_PILLS)
    with open("generators/script/footer.lua", 'r') as footer:
        generator.lua_script.write(footer.read())

    # Write out created stuff
    xml_items_filename = util.get_output_path('content/items.xml')
    xml_pools_filename = util.get_output_path('content/itempools.xml')
    xml_pocketitems_filename = util.get_output_path('content/pocketitems.xml')
    xml_entities_filename = util.get_output_path('content/entities2.xml')
    generator.write_items(xml_items_filename)
    generator.write_entities(xml_entities_filename)
    generator.write_pools(xml_pools_filename)
    generator.write_pocketitems(xml_pocketitems_filename)

    # Output metadata
    shutil.copy("metadata.xml", util.TARGET_FOLDER)
    shutil.copy("preview.jpg", util.TARGET_FOLDER)

    # Final prints
    print("Done!")
    print("Generated {} items.".format(len(generator.itemnames)))

# Enter main function here
main(sys.argv[1:])
# print("\nHints:")
# filepicker.list_of_hints.sort()
# for hint in filepicker.list_of_hints:
#     print(hint)
