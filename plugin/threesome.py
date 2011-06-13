import vim, os, sys

# Add the library to the Python path.
for p in vim.eval("&runtimepath").split(','):
   plugin_dir = os.path.join(p, "plugin")
   if os.path.exists(os.path.join(plugin_dir, "threesomelib")):
      if plugin_dir not in sys.path:
         sys.path.append(plugin_dir)
      break


# Wrapper functions
threesome = None
def ThreesomeInit():
    global threesome
    import threesomelib.init as init
    init.init()
    threesome = init

def ThreesomeDiff():
    threesome.modes.current_mode.key_diff()

def ThreesomeOriginal():
    threesome.modes.current_mode.key_original()

def ThreesomeOne():
    threesome.modes.current_mode.key_one()

def ThreesomeTwo():
    threesome.modes.current_mode.key_two()

def ThreesomeResult():
    threesome.modes.current_mode.key_result()

def ThreesomeGrid():
    threesome.modes.key_grid()

def ThreesomeLoupe():
    threesome.modes.key_loupe()
