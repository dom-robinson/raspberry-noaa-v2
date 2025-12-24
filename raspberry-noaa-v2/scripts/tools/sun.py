import ephem
import time
import sys
import os
import subprocess  # Import the subprocess module
import re

# Use parameter expansion to expand ~ to the home folder
config_file = os.path.expanduser('~/.noaa-v2.conf')

# Read config file directly (handles both latitude= and LAT= formats)
lat = None
lon = None
if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('#') or not line:
                continue
            # Match latitude= or LAT=
            if re.match(r'^(latitude|LAT)\s*=', line):
                lat = line.split('=', 1)[1].strip().strip('"\'')
            # Match longitude= or LON=
            elif re.match(r'^(longitude|LON)\s*=', line):
                lon = line.split('=', 1)[1].strip().strip('"\'')

if not lat or not lon:
    raise ValueError(f"Could not find latitude/longitude in {config_file}")

# Use subprocess to get the local time offset from UTC
timezone = int(subprocess.check_output('echo $(date "+%:::z") | sed "s/\\([+-]\\)0\\?/\\1/"', shell=True, text=True))

date = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(int(sys.argv[1]) - (timezone * 60 * 60)))

lat = str(lat)
lon = str(lon)

obs = ephem.Observer()
obs.lat = lat
obs.long = lon
obs.date = date

sun = ephem.Sun(obs)
sun.compute(obs)
sun_angle = float(sun.alt) * 57.2957795  # Rad to deg

print(int(sun_angle))
