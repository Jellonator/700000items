# 700000items
Do you like The Binding of Isaac? Are you bored of the currently existing items
and wish there were more of them? Like, a lot more? Maybe even 700,000 more?

Well, then this mod is for you!

Featuring at least 1000 randomly generated bootleg items with random stats,
effects, names, and sprites!


## What is this?
This is a mod that adds randomly generated items to The Binding of Isaac
Afterbirth+. It's not yet complete, but it's getting there.

This is not actually a mod. This is a Python program that will procedurally
generate a mod.

## How to use
If you are downloading through the Steam Workshop, items should already be
generated, and you can ignore this (You also won't be seeing this readme).

If you are downloading from Github, there will be no items generated by default.
You must generate them yourself using `./main.py`. The mod generator depends on
Python 3, so make sure that you have it installed when generating items with
this mod. After that you simply copy the generated mod folder into your AB+ mod
folder, run Isaac, enable mods, and you are good to go.

Please note that this is NOT THE MOD FOLDER! Do not place this folder in with
your AB+ mods!

## Generating more items
This mod will generate 1,000 items by default. To generate a custom number of
items, simply run `./main.py number_of_items`. The more items you generate, the
longer the generation process will take, and the longer Isaac will take to boot
up. I would not recommend generating a full 700,000 items unless you have
patience and a fairly beefy computer.

## Notes
All items generated with this mod are seeded. Items with the same name will have
the same stats and effects.

There is not actually 700,000 items. Currently, the name generator can not even
generate 700,000 item names. Beyond that, Having 700,000 items in the game would
likely have huge performance repercussions(as noted above).

Due to name collisions, this mod may not generate all of the items that are
requested.

## Todo

* Random item effects
* Random active items
* Random item pools
* Hint system for stats
* Random trinkets? cards? pills?
