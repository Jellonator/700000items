import shutil
import os
if os.path.exists('content'):
    shutil.rmtree('content')
if os.path.exists('main.lua'):
    os.remove('main.lua')
