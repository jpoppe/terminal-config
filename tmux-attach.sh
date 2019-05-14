#!/bin/bash
# If we're not in a TMUX session lets attach to one or create a new one
function assessSession() {
  read -p "Choose a Session: " session_number
  enter=$(echo -e "\n")
  if [[ $session_number = $enter ]]; then
    SESSION="n"
  else
    for i in "${UNATTCHED_SESSIONS[@]}"
    do
        if [[ $i = $session_number ]]; then
            SESSION=$session_number
            case "$SESSION" in
            "X")
                SESSION="x"
                ;;
            "N")
                SESSION="n"
                ;;
            *)
                ;;
            esac
        fi
    done
  fi
}


if [[ $TERM_PROGRAM == "iTerm.app" ]]; then
    TMUX_CMD="tmux -CC"
    export ITERM2=TRUE
else
    TMUX_CMD="tmux"
    export ITERM2=FALSE
fi

#Don't run this script if we're in VS Code or IntelliJ
if [[ "$TERMINAL_EMULATOR" == "JetBrains-JediTerm" ]] ; then
    echo "Welcome to IntelliJ..."
    exit 666
fi

if [[ "$TERM_PROGRAM" == "vscode" ]]; then
    echo "Welcome to Visual Studio Code..."
    exit 666
fi

# There seems to be issues with WSL at the moment.  Don't run TMUX
if grep -q -i 'Microsoft' /proc/version 2>/dev/null || \
    grep -q -i 'Microsoft' /proc/sys/kernel/osrelease 2>/dev/null
    then
    ~/.screenfetch/screenfetch-dev -a ~/.screenfetch/ft.txt
    echo "WSL is running... Skipping TMUX..."
fi

#Only run this script if we're not already in a TMUX Session
if [[ -z "$TMUX" ]]; then
  # First check no sessions are runing sliently
  tmux ls &> /dev/null
  # If this exits with 1, no sessions are running, start a new one
  if [[ "$?" == "1" ]]; then
    exec $TMUX_CMD new-session "~/.screenfetch/screenfetch-dev -a ~/.screenfetch/ft.txt && zsh"
    exit 0
  fi

  TMUX_SESSIONS=($(tmux ls -F '#{session_name}, #{session_attached}' |grep -v ', 1' |cut -d, -f1))
  #If no sessions are available to attach to just create a new one
  if [[ ${#TMUX_SESSIONS[@]} == "0" ]]; then
    exec $TMUX_CMD new-session "~/.screenfetch/screenfetch-dev -a ~/.screenfetch/ft.txt && zsh"
    exit 0
  fi
  echo "TMUX sessions are availble to attach to:"
  tmux ls |grep -v attached
  echo " : n or ↵  to start a new session"

  UNATTCHED_SESSIONS=($(tmux ls -F '#{session_name}, #{session_attached}' |grep -v ', 1' |cut -d, -f1  && echo "n" && echo "N" && echo "X" && echo "x"))
  while [[ -z "$SESSION" ]]
  do
    if [[ -n "$LOOPRUN" ]]; then
        echo "Not a valid session number."
    fi
    assessSession "${UNATTCHED_SESSIONS[@]}"
    LOOPRUN=1
  done
  
  if [[ "$SESSION" = "n" ]]; then
    exec $TMUX_CMD new-session "~/.screenfetch/screenfetch-dev -a ~/.screenfetch/ft.txt && zsh"
    exit 0
  elif [[ "$SESSION" = "x" ]]; then
    exit 666
  else
    exec $TMUX_CMD a -t $SESSION
    exit 0
  fi

fi
