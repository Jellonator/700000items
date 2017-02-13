#!/usr/bin/python3
from PIL import Image
from PIL import ImageDraw
from . import filepicker
import glob
import random
import os

# Dictionary of parts and associated directories
data_paths = {
    "face": "generators/graphics/face",
    "body": "generators/graphics/body",
    "accessory": "generators/graphics/accessory",
    "symbol": "generators/graphics/symbol",
    "back": "generators/graphics/back"
}

# Load files from part directories into table
data_files = {}
for name, path in data_paths.items():
    generator = glob.glob(path+"/**/*.png", recursive=True)
    data_files[name] = [fname for fname in generator]

# Palette colors to replace blue-keyed areas in sprites
PALETTE = [
    (100,  80, 200, 255), #RED
    (255, 255, 255, 255), #WHITE
    (240, 240,  80, 255), #YELLOW
    (255, 255,  20, 255), #BRIGHT YELLOW
    (255, 160,  30, 255), #ORANGE
    ( 90,  90,  90, 255), #DARK GRAY/BLACK
    (175, 170, 185, 255), #LIGHT GRAY
    (195, 155, 155, 255), #BROWN
    (115, 165, 220, 255), #LIGHT BLUE
    (210, 190, 165, 255), #SKIN
    (255, 190, 190, 255), #SKIN PEACH
    (155, 150, 180, 255), #PURPLE
    (160, 205, 140, 255), #GREEN
]

PALETTE_BRIGHT = [
    ( 67, 119, 231, 255), #Blue (libra/cancer/etc)
    (231,   0,   0, 255), #Red (brimstone)
    (255,  99,   0, 255), #Orange (Hot bombs)
    ( 35, 215,  31, 255), #Green (Toxic Shock)
    (255, 255, 255, 255), #White (not based on any items, but its kind of a holy color?)
]

# Pixel colors that will be replaced
# White, Blue, and Black can not be used. Colors with only `255` and `0` recommended
SPECIAL_PIXEL_COLORS = {
    "face":      [  0, 255,   0, 255],
    "accessory": [255, 255,   0, 255],
    "symbol":    [255,   0,   0, 255],
    # "unused":  [255,   0, 255, 255],
    # "unused":  [  0, 255, 255, 255],
}

def test_colors(color, test):
    """
    Check if two colors are equal
    -- color: color to test
    -- test: other color to test
    """
    for i in range(0, 4):
        if test[i] != color[i]:
            return False
    return True

def test_get_pixel_key(color):
    """
    Get the keyname for a key color if applicable
    -- color: color to test
    """
    for name, value in SPECIAL_PIXEL_COLORS.items():
        if test_colors(color, value):
            return name
    return None

def test_gradient_color(color):
    """
    Check if a color is a palette gradient (blue)
    -- color: color to test
    """
    if color[3] == 255 and color[0] == 0 and color[1] == 0:
        return True
    return False

def mult_color(color, mult, alpha):
    """
    Multiply two colors together
    -- color: Color to multiply
    -- mult: Palette color to multiply color with
    -- alpha: Alpha scalar
    """
    return ((color[0]*mult)//255, (color[1]*mult)//255, (color[2]*mult)//255, color[3]*alpha//255)

def sample_nearby(image, pos):
    """
    Get most common color near a pixel
    image: Image to sample from
    pos: Position of the pixel
    """
    x = pos[0]
    y = pos[1]
    colors = {}
    color_values = {}
    for ix in range(max(0, x-1), min(x+2, image.width)):
        for iy in range(max(0, y-1), min(y+2, image.height)):
            if ix != x or iy != y:
                color = image.getpixel((ix, iy))
                # if color[3] > 0:
                rgba = color[0]*0x01000000 + color[1]*0x00010000\
                     + color[2]*0x00000100 + color[3]*0x00000001
                if not rgba in colors:
                    colors[rgba] = 0
                    color_values[rgba] = color
                colors[rgba] += 1
    highest_count = 0
    highest_rgba = 0
    for rgba, count in colors.items():
        if count > highest_count:
            highest_count = count
            highest_rgba = rgba
    return color_values[highest_rgba]

def load_part(path, can_face, genstate):
    """
    Load a part from a path
    path: image path to load from
    can_face: Does nothing actually
    """
    palette = random.choice(PALETTE)
    image = Image.open(path).convert("RGBA")
    draw = ImageDraw.Draw(image)
    portions = []
    # Find key colors and palettize blues
    for y in range(0, image.height):
        for x in range(0, image.width):
            pos = (x, y)
            color = image.getpixel(pos)
            replace_key = test_get_pixel_key(color)
            if replace_key != None:
                portions.append((pos, replace_key))
            if test_gradient_color(color):
                color = mult_color(palette, color[2], color[3])
                draw.point(pos, color)
    # Replace key colors with sample of nearby colors (by most common)
    # Removes annoying dots
    for data in portions:
        pos = data[0]
        repl_color = sample_nearby(image, pos)
        draw.point(pos, repl_color)
    # paste images on top of graphic
    for data in portions:
        part_pos = data[0]
        part_key = data[1]
        part_x = part_pos[0]
        part_y = part_pos[1]
        part = request_part(part_key, genstate)
        pos = (part_x - part.width//2, part_y - part.height//2)
        temp = create_image(image.width, image.height)
        temp.paste(part, pos, part)
        image = Image.alpha_composite(image, temp)
    return image

def request_part(key, genstate):
    """
    Request for a part to be loaded, return image of part
    key: Name of part list to load from
    """
    picker = filepicker.get_path(data_paths[key])
    filedef = picker.choose_random_with_hint(genstate, 20)
    path = filedef.get_path()

    # path = random.choice(data_files[key])
    return load_part(path, True, genstate)

def create_image(width, height):
    """
    create a new image
    If you can't figure out what 'width' and 'height' are, I'm sorry for your loss
     |   | |
    | |  | _
    """
    ret = Image.new('RGBA', (width, height), (0,0,0,0))
    return ret

CONST_NEAR_TEST = [
    ( 2,  0), (-2,  0), ( 0,  2), ( 0, -2),
    ( 1,  0), (-1,  0), ( 0,  1), ( 0, -1),
    ( 1,  1), ( 1, -1), (-1, -1), (-1,  1),
]

def is_pixel_near_pos(image, pos):
    for val in CONST_NEAR_TEST:
        x,y = pos[0]+val[0], pos[1]+val[1]
        if x < 0 or y < 0 or x >= image.width or y >= image.height:
            continue
        tpos = (x,y)
        color = image.getpixel(tpos)
        if color[3] > 0:
            return True
    return False

def outline_image(image):
    palette = random.choice(PALETTE_BRIGHT)
    new_image = create_image(image.width, image.height)
    draw = ImageDraw.Draw(new_image)
    for y in range(0, image.height):
        for x in range(0, image.width):
            pos = (x, y)
            if is_pixel_near_pos(image, pos):
                draw.point(pos, palette)
    return Image.alpha_composite(new_image, image)

def add_backdrop(image, genstate):
    part = request_part("back", genstate)
    return Image.alpha_composite(part, image)

def generate_image(output, genstate, resize=None):
    """
    Generate a random image
    -- name: Name to save image as
    """
    # output = os.path.join(OUTPUT_PATH, name)
    image = request_part("body", genstate)
    outline_chance = 4
    outline_chance += genstate.get_hint("outline")
    if random.random() < 0.01*outline_chance:
        image = outline_image(image)
    if random.random() < 0.25:
        image = add_backdrop(image, genstate)
    if resize:
        if isinstance(resize, list):
            resize = (resize[0], resize[1])
        image = image.resize(resize)
    image.save(output)
