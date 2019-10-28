import sys
import subprocess
import os
import glob

files = glob.glob(r"C:/Users/User/AppData/Local/Temp/subselect/fonts/*")
for f in files:
    os.remove(f)

subprocess.run(["nircmd", "exec2", "hide", r"C:\Users\User\AppData\Local\Temp\subselect\fonts", "ffmpeg", "-dump_attachment:t", "", "-i", sys.argv[1]])
