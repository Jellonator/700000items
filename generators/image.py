#!/usr/bin/python3
from PIL import Image
from PIL import ImageDraw
import glob
import random
import os

data_paths = {
    "face": "generators/graphics/face",
    "body": "generators/graphics/body",
    "accessory": "generators/graphics/accessory"
}

data_files = {}
for name, path in data_paths.items():
    generator = glob.glob(path+"/**/*.png", recursive=True)
    data_files[name] = [fname for fname in generator]

OUTPUT_PATH = "700000items/resources/gfx/items/collectibles"

PALETTE = [
    [100,  80, 200, 255], #RED
    [255, 255, 255, 255], #WHITE
    [240, 240,  80, 255], #YELLOW
    [255, 255,  20, 255], #BRIGHT YELLOW
    [255, 160,  30, 255], #ORANGE
    [ 90,  90,  90, 255], #DARK GRAY/BLACK
    [175, 170, 185, 255], #LIGHT GRAY
    [195, 155, 155, 255], #BROWN
    [115, 165, 220, 255], #LIGHT BLUE
    [210, 190, 165, 255], #SKIN
    [255, 190, 190, 255], #SKIN PEACH
    [155, 150, 180, 255], #PURPLE
    [160, 205, 140, 255], #GREEN
]

SPECIAL_PIXEL_COLORS = {
    "face": [0, 255, 0, 255],
    "accessory": [255, 255, 0, 255],
}

def test_colors(color, test):
    for i in range(0, 4):
        if test[i] != color[i]:
            return False
    return True

def test_get_pixel_key(color):
    for name, value in SPECIAL_PIXEL_COLORS.items():
        if test_colors(color, value):
            return name
    return None

def test_gradient_color(color):
    if color[3] == 255 and color[0] == 0 and color[1] == 0:
        return True
    return False

def mult_color(color, mult, alpha):
    return ((color[0]*mult)//255, (color[1]*mult)//255, (color[2]*mult)//255, color[3]*alpha//255)

def load_part(path, can_face):
    palette = random.choice(PALETTE)
    image = Image.open(path).convert("RGBA")
    draw = ImageDraw.Draw(image)
    portions = []
    for y in range(0, image.height):
        for x in range(0, image.width):
            pos = (x, y)
            color = image.getpixel(pos)
            replace_key = test_get_pixel_key(color)
            if replace_key != None:
                portions.append((pos, replace_key))
            # print(color)
            if test_gradient_color(color):
                color = mult_color(palette, color[2], color[3])
                draw.point(pos, color)
    for data in portions:
        # print("WOW")
        part_pos = data[0]
        part_key = data[1]
        part_x = part_pos[0]
        part_y = part_pos[1]
        part = request_part(part_key)
        pos = (part_x - part.width//2 + 1, part_y - part.height//2)
        # image.paste(part, pos, part)
        temp = create_image(image.width, image.height)
        temp.paste(part, pos, part)
        image = Image.alpha_composite(image, temp)
    return image

def request_part(key):
    path = random.choice(data_files[key])
    return load_part(path, True)

def create_image(width, height, func=None):
    ret = Image.new('RGBA', (width, height), (0,0,0,0))
    return ret

def generate_image(name):
    output = os.path.join(OUTPUT_PATH, name)
    image = request_part("body")
    image.save(output)

# image = request_part("body")
# image.save(OUTPUT_FILE)

# print(face_files)
# print(body_files)
