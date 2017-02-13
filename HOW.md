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

A name will always have a noun and at least one adjective. The name generator
may also add another adjective, a name ending, a name post-adjective, and/or a
name beginning.

The order of these can be visualized like this:

`{name_pre} {name_adj} {NAME_ADJ} {name_post} {NAME_NOUN} {name_end}`
Where anything in all-caps is guaranteed to appear.

After this, a random, unique number between 1 and 700000 will be selected. This
number is added to the start of the name and has no effect on the seed.

## Step two: Hints
Every item abides by a hint system. In essence, the name of an item plays a role
in the effects and sprites that an item will have.

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

## Step three: determine value of item
Next, an item will have its value determined.

An item has a positive value, and a negative value. By default, the positive
value will be a random number between 2 and 5, and the negative value is 0. The
positive value is increased by the 'good' hint, and the negative value is
increased by the 'bad' hint. There is then three chances for both the positive
and negative values to be incremented by 1.

Will finish this document later
