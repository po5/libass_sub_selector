import os
import sys
import subprocess

if not os.path.exists(sys.argv[1]):
    os.makedirs(sys.argv[1])

if sys.argv[3] != "nil":
    subprocess.run(["ffmpeg", "-loglevel", "8", "-i", sys.argv[2], "-map", "0:" + sys.argv[3], "-y", sys.argv[4]])

os.chdir(sys.argv[1])
subprocess.run(["ffmpeg", "-loglevel", "0", "-dump_attachment:t", "", "-i", sys.argv[2]])
