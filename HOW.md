# How this mod works
I've been asked several times how this mod works. To answer that question, I'm
compiling a step-by-step process that this mod generator takes to generate
items.

## Step one: Generate a name.
The first step to generating any item is to generate a name for it. The name is
not only the name of the item, but it also serves as the seed for that item. A
seed basically determines the RNG that will be used to generate the rest of the
item, so an item will with a given name will always have the same effects and
sprite.

In the folder 'generators/name', you will find five files, each with its own
purpose:
 * name_adj.txt which contains a list of adjectives
 * name_end.txt which contains a list of name endings (very end of name)
 * name_nouns.txt which contains a list of nouns
 * name_post.txt which contains a list of words that occur between adjectives
and the noun.
 * name_pre.txt which contains a list of words that are placed at the beginning
of the name.

A name will always have a noun. The name generator may also add up to two
adjectives, a name ending, a name post-adjective, and/or a name beginning.

The order of these can be visualized like this:

`{name_pre} {name_adj} {name_adj} {name_post} {NAME_NOUN} {name_end}`
Where anything in all-caps is guaranteed to appear.

After this, a random, unique number between 1 and 700000 will be selected. This
number is added to the start of the name and has no effect on the seed.

## Step two: Hints
Every item abides by a hint system. In essence, the name of an item plays a role
in the effects and sprites that an item will have. This is so that names and
descriptions of items are *slightly* more accurate to what the item actually
does and looks like.

Every hint have two parts: A match, and a hint. The 'match' is a word what will
be searched for in the item's name, and the hint itself will influence later
RNG.

In 'generators', there should be a file named 'hints.txt'. The syntax for this
file is very simple; any line starting with ":" will search the item's name for
the following string, and any line not starting with a colon will add that hint
if the string is found. For example, the following would search for the word
'sacred' or 'holy' in the item's name, and make it more likely to appear in the
angel room pool.
```
:sacred|holy
    pool-angel+4
```
Here, "sacred" and "holy" are matches, and "pool-angel" is the hint.

## Step three: Add item to item pools
This is pretty self-explanatory. The item is added to one of many of the game's
item pools. If an item gets added to a pool, then it is also added to the
corresponding greed pool, if one exists. The generator will choose between 1 and
5 item pools to add the item to; using the hint system, of course.

In the hints.txt, you can also see name matches with names such as
':pool-angel'. This simply means that this hint will be used if an item is added
to the given item pool.

## Step four: Create item sprite
This part is going to be a little more in-depth.

#### The File Picker
To start off, I need to discuss the _FilePicker_. Essentially, it is a method of
picking random files from a folder. The first thing the FilePicker will do when
requesting a file is to get all of the folders in the given directory. You can
look at 'generators/graphics/body' for an example of a folder that the
FilePicker would choose from.

The second thing the FilePicker will do is parse the hints and weights of each
file in the given folder. The hints and weights are given as part of the name
of the file. The name of the file itself is anything that appears before the
colon, and has no effect on the outcome. The same goes for the file extension.
The hints themselves are between the colon and the file extension. It is a
comma-separated list of numbers and strings. Any numbers will be used as a
weight, while everything else is a hint. If a hint starts with 'name-', it will
search the name of the item for a given word instead. A hint can also be given a
weight to give sprites higher precedent in certain cases, e.g. 'name-book=120'
is used to make sure that items with 'book' in the name are much more likely.

Finally, the FilePicker will determine the weight of each file using the hint
system, and pick a random file out of the folder given these weights.

#### Creating images
Now that the FilePicker is out of the way, how does this tie into item sprites?

To generate a sprite, the first thing that needs to be done is to pull a random
file from the 'generators/graphics/body' directory. Simple enough so far.

Any image that is requested needs to be processed a little before it gets used,
however. If you look at the sprites in the 'generators/graphics' directory, they
may look a little... odd. Why are they blue? What's with those random pixels?

The blue portion of the sprite is not actually blue! Well, not after processing.
Any color in a sprite that is completely blue and has no green nor red will
become a different color. A random color from a set palette of colors is chosen,
and has its shade changed based on the shade of blue. Lighter shades of blue =
brighter, and darker shades of blue = darker.

That's only half of the story though. What about those random pixels? It turns
out, they aren't random; rather, they are strategically placed. Specific colors
of pixels are actually replaced with yet more sprites! And these sprites are
processed using the same process as the body of the sprite!

Specifically, the following colors correspond to the following folders to pull
sprites from:
 * Red(0xFF0000FF): 'generators/graphics/symbol'
 * Green(0x00FF00FF): 'generators/graphics/face'
 * Yellow(0xFFFF00FF): 'generators/graphics/accessory'

Using this, a random sprite can be generated with random bodies, random
colors, random faces, etc.

The final image may also have an outline added, or a random backdrop from the
'generators/graphics/back' directory placed in the background.

One the image is created, it is written out to the
'700000items/resources/gfx/items/collectibles' folder.

## Step five: Determine value of item
Next, an item will have its value determined.

An item has a positive value, and a negative value. By default, the positive
value will be a random number between 2 and 5, and the negative value is 0. The
positive value is increased by the 'good' hint, and the negative value is
increased by the 'bad' hint. The negative value is then increased by a random
number between 0 and the positive value - 2, weighted towards 0. Overall, the
negative value should generally be less than the positive value.

The value of the item will ultimately determine the stats of the item.

## Step six: Generate effect
Now the item may have an effect added to it! Note that not all items have
effects, but most do. This is also where an item is determined whether or not
it should be an active item (using the 'active' hint).

The process is similar to how it works in sprites, but now with code!
Instead of pixels denoting parts that should be loaded in, we now have macros
that load random scripts from other folders. The macro system is very simple:
Anywhere in a lua script that `python[[ #code goes here ]]` is found, the python
code contained inside the brackets will be executed. Code executed in these
blocks have access to a special object, named 'gen', as well as a few useful
functions that won't be mentioned here (But you can find them in
'generators/scriptgen.py').

The 'gen' object has a few *very* useful methods that can be used:
 * `gen.include(directory, exclude=[])`: Includes a random file from a given
directory using the FilePicker, excluding any specific file named given in the
'exclude' parameter.
 * `gen.write(string)`: Write out a string to the output. Any string written out
will be placed in-place of the `python[[]]` block.
 * `gen.writeln(string)`: Same as gen.write, but with a newline.
 * `gen.set_var(string, value)`: Set a variable in the generator
 * `gen.get_var(string)`: Get a variable from the generator
 * `gen.inc_var(string, value)`: Increase a variable in the generator by value.
This function is useful for reducing the stats an item may have if it has very
strong effects, i.e. `gen.inc_var("value", 1)`. The final value of "value" is
subtracted from the item's positive value.
 * `gen.genstate.add_descriptor(word)`: Adds a word that can potentially be
added to the description. We'll get there later.

For generating a passive item, the script 'generators/script/item_passive.lua'
is loaded. For active items, a similar script named
'generators/script/item_passive.lua' can be loaded as well.

Using this system of python macros, some very interesting item effects can be
generated.

## Step seven: Determine stats
The stats of an item are fairly straight-forward. There is a list of stats that
can be added, a random stat is chosen, a random number between 1 and the
positive value is chosen, that stat is increased, repeat until the positive
value is 0. The same goes for the negative value, except stats are decreased.
The stats chosen by this system are, of course, affected by hints as well.

Health is somewhat separate from the stat system. There are three chances to
have a health up, and a maximum of +3 health, +7 soul hearts, or +6 black
hearts. Each health up will take two from the positive value. Health ups too are
affected by hints.

## Step eight: Generate description
The description is literally just a random conglomeration of words. The words
in the description are pulled from multiple places, including the name of the
item, and the effects the item has (via `gen.genstate.add_descriptor(word)`).
You may or may not be able to kinda tell what an item does based on its
description. If you see the word 'trail' or 'creep', there's a good chance this
item has to do with creep.

## Step nine: Write out to files
Now that the item is generated, all that has to be done now is to add it to the
mod. All that needs to be done now is to write its script to
'700000items/main.lua', write its name, health ups, cache flags, etc. to
'700000items/content/items.xml', and write out its item pools to
'700000items/content/itempools.xml'.

## What about Pills? Trinkets? ...Familiars?
Trinkets and familiars use pretty much the exact same process as normal items! The
only difference is that where normal items generate scripts using 
'generators/script/item_passive.lua' or 'generators/script/item_active.lua',
trinkets generate scripts starting from 'generators/script/trinket.lua' and familiars
use 'generators/script/item_familiar.lua'.

Trinkets have very similar effects to passive items, but familiars are a bit different.
Each familiar has a different movement pattern and effect. Movement patterns include
following the player like Brother Bobby, orbiting the player, and moving around
randomly among other things. Familiar effects can be contact damage, shooting tears, etc.
If a familiar shoots a tear, it can have one of many tear effects, such as explosive tears
or parasitoid tears.

Pills use a bit of a different system since pills don't use the standard name generator
nor do they have sprites. Instead, their names are based on the description generator, and
their script is loading 'generators/script/pill.lua'. Pills, unlike a majority items, can have
negative effects.
