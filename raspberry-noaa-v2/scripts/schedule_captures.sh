#!/bin/bash
#
# Purpose: Create an "at" scheduled job for capture based on the following
#          input parameter positions:
#            1. Satellite Name
#            2. Name of script to call for reception
#            3. TLE file
#            4. Start time to predict passes (ms)
#            5. End time to predict passes (ms)
#
# Example:
#   ./schedule_captures.sh "NOAA 18" "receive_noaa.sh" "weather.tle" 1617422399 1617425300

# import common lib and settings
# Use explicit path instead of $HOME since at jobs may set HOME=/root
. "/home/pi/.noaa-v2.conf"
. "$NOAA_HOME/scripts/common.sh"

# map inputs to sane var names
OBJ_NAME=$1
RECEIVE_SCRIPT=$2
TLE_FILE=$3
START_TIME_MS=$4
END_TIME_MS=$5

if [ "$OBJ_NAME" == "METEOR-M 2" ]; then
  SAT_MIN_ELEV=${METEOR_M2_3_SAT_MIN_ELEV:-10}
fi
if [ "$OBJ_NAME" == "METEOR-M2 3" ]; then
  SAT_MIN_ELEV=${METEOR_M2_3_SAT_MIN_ELEV:-10}
fi
if [ "$OBJ_NAME" == "METEOR-M2 4" ]; then
  SAT_MIN_ELEV=${METEOR_M2_4_SAT_MIN_ELEV:-10}
fi
# Default to 10 degrees if not set
SAT_MIN_ELEV=${SAT_MIN_ELEV:-10}

# come up with prediction start/end timings for pass
START_TIME_SEC=${START_TIME_MS%000}
END_TIME_SEC=${END_TIME_MS%000}
QTH_FILE="/home/pi/.predict/predict.qth"

# Wrapper function to run predict non-interactively
# Convert relative paths to absolute paths and use qemu-arm-static for 32-bit binary
run_predict() {
  local tle_file=$1
  local sat_name=$2
  local epoch_time=$3
  # Convert relative paths to absolute paths (predict requires absolute paths)
  local abs_tle_file="$tle_file"
  if [[ "$tle_file" != /* ]]; then
    abs_tle_file="$(cd "$NOAA_HOME" && readlink -f "$tle_file" 2>/dev/null || echo "$NOAA_HOME/$tle_file")"
  fi
  # Use TERM=linux to allow predict to run with ncurses in non-interactive mode
  # The -p flag enables quickpredict mode which outputs data directly
  TERM=linux /usr/bin/predict -t "$abs_tle_file" -q "$QTH_FILE" -p "$sat_name" "$epoch_time" 2>&1 || true
}

# Try to get predict output, searching forward in time if no pass at exact start time
predict_output=""
current_time=$START_TIME_SEC
max_search_seconds=3600  # Search up to 1 hour ahead
search_count=0

while [ -z "$predict_output" ] && [ $search_count -lt 60 ]; do
  predict_output=$(run_predict "$TLE_FILE" "${OBJ_NAME}" "${current_time}")
  # Filter out empty lines and validate output
  predict_start=$(echo "$predict_output" | grep -v "^$" | awk 'NR==1')
  predict_end=$(echo "$predict_output" | grep -v "^$" | awk 'END{print}')
  
  # Check if we got valid data
  if [ -n "$predict_start" ] && [ -n "$predict_end" ] && echo "$predict_start" | grep -qE "^[0-9]+"; then
    break  # Found valid output
  fi
  
  # No valid output, try 60 seconds ahead
  current_time=$(expr "$current_time" + 60 2>/dev/null || echo "$current_time")
  search_count=$(expr "$search_count" + 1 2>/dev/null || echo "60")
  predict_output=""
done

# Validate we got actual data (predict outputs epoch time as first field)
if [ -z "$predict_start" ] || [ -z "$predict_end" ] || ! echo "$predict_start" | grep -qE "^[0-9]+"; then
  log "Failed to get valid predict output for ${OBJ_NAME} after searching from ${START_TIME_SEC}" "WARN"
  exit 0
fi

max_elev=$(echo "$predict_output" | grep -v "^$" | awk -v max=0 '{if(NF>=5 && $5+0==$5 && $5>max){max=$5}}END{print max}')
azimuth_at_max=$(echo "$predict_output" | grep -v "^$" | awk -v max=0 -v az=0 '{if(NF>=6 && $5+0==$5 && $6+0==$6 && $5>max){max=$5;az=$6}}END{print az}')
end_epoch_time=$(echo "${predict_end}" | awk '{print $1}')
starting_azimuth=$(echo "${predict_start}" | awk '{if(NF>=6) print $6; else print "0"}')

# get and schedule passes for user-defined days
# Continue while we have valid predictions and haven't exceeded our end time
while [ -n "${end_epoch_time}" ] && [ "${end_epoch_time}" -gt 0 ] 2>/dev/null; do
  start_datetime=$(echo "$predict_start" | cut -d " " -f 3-4)
  start_epoch_time=$(echo "$predict_start" | cut -d " " -f 1)
  
  # Check if this pass is within our scheduling window
  # Skip if pass starts after our window ends
  if [ -z "${start_epoch_time}" ] || ! echo "${start_epoch_time}" | grep -qE "^[0-9]+$"; then
    break
  fi
  if [ "${start_epoch_time}" -gt "${END_TIME_SEC}" ]; then
    break
  fi
  # Skip if pass ends before our window starts (but continue to next pass)
  if [ -n "${end_epoch_time}" ] && [ "${end_epoch_time}" -gt 0 ] 2>/dev/null && [ "${end_epoch_time}" -lt "${START_TIME_SEC}" ]; then
    next_predict=$(expr "${end_epoch_time}" + 60 2>/dev/null || echo "${START_TIME_SEC}")
    predict_output=$(run_predict "$TLE_FILE" "${OBJ_NAME}" "${next_predict}")
    predict_start=$(echo "$predict_output" | grep -v "^$" | awk 'NR==1')
    predict_end=$(echo "$predict_output" | grep -v "^$" | awk 'END{print}')
    if [ -z "$predict_start" ] || [ -z "$predict_end" ] || ! echo "$predict_start" | grep -qE "^[0-9]+"; then
      break
    fi
    max_elev=$(echo "$predict_output" | grep -v "^$" | awk -v max=0 '{if(NF>=5 && $5+0==$5 && $5>max){max=$5}}END{print max}')
    azimuth_at_max=$(echo "$predict_output" | grep -v "^$" | awk -v max=0 -v az=0 '{if(NF>=6 && $5+0==$5 && $6+0==$6 && $5>max){max=$5;az=$6}}END{print az}')
    end_epoch_time=$(echo "${predict_end}" | awk '{print $1}')
    starting_azimuth=$(echo "${predict_start}" | awk '{if(NF>=6) print $6; else print "0"}')
    continue
  fi
  start_time_seconds=$(echo "$start_datetime" | cut -d " " -f 2 | cut -d ":" -f 3 2>/dev/null || echo "0")
  timer=$(expr "${end_epoch_time}" - "${start_epoch_time}" + "${start_time_seconds}" 2>/dev/null || echo "600")
  #file_date_ext=$(date --date="TZ=\"UTC\" ${start_datetime}" +%Y%m%d-%H%M%S)
  file_date_ext=$(date --utc --date="${start_datetime}" +%Y%m%d-%H%M%S)

  schedule_enabled_by_sun_elev=1
  if [ "$OBJ_NAME" == "METEOR-M2 3" ]; then
      START_SUN_ELEV=$(python3 "$SCRIPTS_DIR"/tools/sun.py "$start_epoch_time" 2>/dev/null || echo "0")
      if [ -n "${START_SUN_ELEV}" ] && [ -n "${METEOR_M2_3_SCHEDULE_SUN_MIN_ELEV}" ] && [ "${START_SUN_ELEV}" -lt "${METEOR_M2_3_SCHEDULE_SUN_MIN_ELEV}" ] 2>/dev/null; then
        log "Not scheduling Meteor-M2 3 with START TIME $start_epoch_time because $START_SUN_ELEV is below configured minimum sun elevation $METEOR_M2_3_SCHEDULE_SUN_MIN_ELEV" "INFO"
        schedule_enabled_by_sun_elev=0
      fi
  fi
  if [ "$OBJ_NAME" == "METEOR-M2 4" ]; then
      START_SUN_ELEV=$(python3 "$SCRIPTS_DIR"/tools/sun.py "$start_epoch_time" 2>/dev/null || echo "0")
      if [ -n "${START_SUN_ELEV}" ] && [ -n "${METEOR_M2_4_SCHEDULE_SUN_MIN_ELEV}" ] && [ "${START_SUN_ELEV}" -lt "${METEOR_M2_4_SCHEDULE_SUN_MIN_ELEV}" ] 2>/dev/null; then
        log "Not scheduling Meteor-M2 4 with START TIME $start_epoch_time because $START_SUN_ELEV is below configured minimum sun elevation $METEOR_M2_4_SCHEDULE_SUN_MIN_ELEV" "INFO"
        schedule_enabled_by_sun_elev=0
      fi
  fi

  # schedule capture if elevation is above configured minimum
  if [ -n "${max_elev}" ] && [ -n "${SAT_MIN_ELEV}" ] && [ "${max_elev}" -gt "${SAT_MIN_ELEV}" ] 2>/dev/null && [ "${schedule_enabled_by_sun_elev}" -eq "1" ]; then
    direction="null"

    # calculate travel direction
    starting_azimuth_num=$(echo "$starting_azimuth" | awk '{print int($1+0)}')
    if [ -n "$starting_azimuth_num" ] && [ "$starting_azimuth_num" -le 90 ] 2>/dev/null || [ "$starting_azimuth_num" -ge 270 ] 2>/dev/null; then
      direction="Southbound"
    else
      direction="Northbound"
    fi

    # calculate side of travel
    pass_side="W"
    azimuth_at_max_num=$(echo "$azimuth_at_max" | awk '{print int($1+0)}')
    if [ -n "$azimuth_at_max_num" ] && [ "$azimuth_at_max_num" -ge 0 ] 2>/dev/null && [ "$azimuth_at_max_num" -le 180 ] 2>/dev/null; then
      pass_side="E"
    fi

    # should at send mail ?
    mail_arg=""
    if [ "${DISABLE_AT_MAIL}" == "true" ]; then
      mail_arg="-M"
    fi

    printf -v safe_obj_name "%q" $(echo "${OBJ_NAME}" | sed "s/ /-/g")
    log "Scheduling capture for: ${safe_obj_name} ${file_date_ext} ${max_elev}" "INFO"
    # Use epoch time directly to avoid date parsing issues with predict's date format
    at_time=$(date --date="@${start_epoch_time}" +"%H:%M %D" 2>&1)
    if [ $? -ne 0 ]; then
      log "Failed to format date from epoch ${start_epoch_time}: ${at_time}" "ERROR"
      # Fallback: try parsing the start_datetime
      at_time=$(date --utc --date="${start_datetime}" +"%H:%M %D" 2>&1)
    fi
    job_output=$(echo "${NOAA_HOME}/scripts/${RECEIVE_SCRIPT} \"${OBJ_NAME}\" ${safe_obj_name}-${file_date_ext} ${TLE_FILE} \
                                                              ${start_epoch_time} ${timer} ${max_elev} ${direction} ${pass_side}" \
                | at "${at_time}" ${mail_arg} 2>&1)

    # attempt to capture the job id if job scheduling succeeded
    at_job_id=$(echo $job_output | sed -n 's/.*job \([0-9]\+\) at.*/\1/p')
    if [ -z "${at_job_id}" ]; then
      log "Issue scheduling job: ${job_output}" "WARN"
    else
      log "Scheduled capture with job id: ${at_job_id}" "INFO"

      # update database with scheduled pass
      $SQLITE3 $DB_FILE "INSERT OR REPLACE INTO predict_passes (sat_name,pass_start,pass_end,max_elev,is_active,pass_start_azimuth,azimuth_at_max,direction,at_job_id) VALUES (\"${OBJ_NAME}\",$start_epoch_time,$end_epoch_time,$max_elev,1,$starting_azimuth,$azimuth_at_max,'$direction',$at_job_id);"
    fi
  fi

  next_predict=$(expr "${end_epoch_time}" + 60 2>/dev/null || echo "${END_TIME_SEC}")
  predict_output=$(run_predict "$TLE_FILE" "${OBJ_NAME}" "${next_predict}")
  predict_start=$(echo "$predict_output" | grep -v "^$" | awk 'NR==1')
  predict_end=$(echo "$predict_output" | grep -v "^$" | awk 'END{print}')
  if [ -z "$predict_start" ] || [ -z "$predict_end" ] || ! echo "$predict_start" | grep -qE "^[0-9]+"; then
    break
  fi
  max_elev=$(echo "$predict_output" | grep -v "^$" | awk -v max=0 '{if(NF>=5 && $5+0==$5 && $5>max){max=$5}}END{print max}')
  azimuth_at_max=$(echo "$predict_output" | grep -v "^$" | awk -v max=0 -v az=0 '{if(NF>=6 && $5+0==$5 && $6+0==$6 && $5>max){max=$5;az=$6}}END{print az}')
  end_epoch_time=$(echo "${predict_end}" | awk '{print $1}')
  starting_azimuth=$(echo "${predict_start}" | awk '{if(NF>=6) print $6; else print "0"}')
done
