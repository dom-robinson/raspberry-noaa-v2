<?php

namespace Config;

class Config {
  # how many captures to show per page (pagination)
  const CAPTURES_PER_PAGE = 18;

  # base directory for sqlite database
  const DB_FILE = '/opt/raspberry-noaa-v2/db/panel.db';

  # see files in App/Lang directory for available translations
  const LANG = 'en';

  # configure the date output format for the pass list - note that this must follow
  # a format that conforms to https://www.php.net/manual/en/datetime.format.php
  const PASSES_DATE_FORMAT = 'm/d/Y';

  # configure time output format on captures web page - note this must follow
  # a format that conforms to https://www.php.net/manual/en/datetime.format.php
  const DATETIME_FORMAT = 'm/d/Y H:i:s';
  const DATE_FORMAT = 'm/d/Y';

  # use https://www.php.net/manual/en/timezones.php
  const TIMEZONE = 'Europe/London';

  # location of images
  const IMAGE_PATH = '/srv/images';

  # location of thumbnails
  const THUMB_PATH = '/srv/images/thumb';

  # whether to enable satvis visualization
  const ENABLE_SATVIS = 'false';

  # whether to enable image video
  const ENABLE_ANIMATION = 'false';
  const ANIMATION_VIDEO_FILE = '/srv/videos/RollingAnimation.webm';

  # lat and lon coordinates of base station
  const BASE_STATION_LAT = '50.816368';
  const BASE_STATION_LON = '-0.06511';

  # how many captures to list on admin page for management
  const ADMIN_CAPTURES_PER_PAGE = 100;

  # which enhancements to display for day/night
  const NOAA_DAY_ENHANCEMENTS = 'MSA MSA-precip MCIR MCIR-precip HVC-precip HVCT-precip HVC HVCT ZA therm sea CC HE HF MD BD MB JF JJ LC TA WV NO histeq';
  const NOAA_NIGHT_ENHANCEMENTS = 'MCIR MCIR-precip HVCT ZA therm NO TA sea histeq';

  # admin endpoint auth
  const LOCK_ADMIN = 'true';
  const ADMIN_USER = 'd2';
  const ADMIN_PASS = 'wrxadmin';
}

?>
