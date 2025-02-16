#! /bin/bash

readonly HomeDir=$(readlink -m $(dirname $0))
echo "use HomeDir: $HomeDir"

function start {
  # note that this script must be run under root
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] watchdog was started by $USER"

  local runningBinary=""
  local initRun="true"

  while(true); do
    if [[ "$initRun" == "true" ]]; then
      initRun="false"
    else 
      sleep 60
    fi
    
    if [ ! -d $HomeDir/bin ]; then 
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] directory $HomeDir/bin doesn't exit"
      continue
    fi

    binaryLatest=$(cd $HomeDir/bin; ls -rt | tail -n 1)
    if [[ "$binaryLatest" == "" ]]; then 
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] found no avaiable super-agent binary under $HomeDir/bin"
      continue
    fi

    currentPid=$(lslocks | grep /run/super-agent.pid | awk '{ print $2 }')
    if [[ "$currentPid" != "" ]]; then 
      cmdline=$(ps -p $currentPid -o cmd --no-header)
      if [[ "$cmdline" =~ "$binaryLatest" ]]; then 
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] super-agent is already using $binaryLatest"
        continue
      fi
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] kill super-agent for upgrade now: current=$cmdline, latest=$binaryLatest"

      kill $currentPid
      sleep 5

      # If the super-agent still exists, let's use "kill -s SIGKILL $pid"
      while (true); do 
        currentPid2=$(lslocks | grep /run/super-agent.pid | awk '{ print $2 }')
        if [[ "$currentPid" == "currentPid2" ]]; then 
          echo "[$(date +'%Y-%m-%d %H:%M:%S')] force kill super agent now"
          kill -s SIGKILL $currentPid
          sleep 3
        else 
          echo "[$(date +'%Y-%m-%d %H:%M:%S')] super-agent has been killed"
          break
        fi
      done
      runningBinary=""
    elif [[ "$runningBinary" != "" ]]; then
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] super-agent has exited un-expectedly: binary=$runningBinary"
    else
      echo "[$(date +'%Y-%m-%d %H:%M:%S')] found no running super-agent"
    fi
    
    chmod u+rx $HomeDir/bin/$binaryLatest

    version=$($HomeDir/bin/$binaryLatest --version)
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] use latest super-agent binary: $binaryLatest, version: $version"

    if grep -qE 'level\W+DEBUG' $HomeDir/config.yaml; then 
      # if debug is enabled, we also dump the request/response details
      $HomeDir/bin/$binaryLatest --config $HomeDir/config.yaml >$HomeDir/super-agent.stdout 2>$HomeDir/super-agent.stderr &
    else
      rm -f $HomeDir/super-agent.std*
      $HomeDir/bin/$binaryLatest --config $HomeDir/config.yaml > /dev/null 2>&1 &
    fi
    runningBinary=$binaryLatest

  done
}

function stop {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] watchdog was stopped"
}

if [[ "$1" == "stop" ]]; then 
  stop
else 
  start
fi
