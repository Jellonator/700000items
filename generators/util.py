import random
import os
TARGET_FOLDER = "700000items"

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

def dict_to_lists(dict):
    """
    Convert a dictionary into two lists
    -- dict: dictionary to convert
    """
    reta = []
    retb = []
    for key, value in dict.items():
        reta.append(key)
        retb.append(value)
    return (reta, retb)

def choice_weights(choices, weights):
    """
    Pick a random item from choices given a list of weights for each item
    -- choices: A choice that can be chosen
    -- weights: The weights that correspond to each choice
    """
    total = sum(weights)
    rng = random.random() * total
    i = 0
    for i in range(0, len(choices)):
        weight = weights[i]
        name = choices[i]
        rng -= weight
        if rng <= 0:
            return name
        i += 1
