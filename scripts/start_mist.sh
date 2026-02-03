#!/data/data/com.termux/files/usr/bin/sh

# Check if MistController is already running
if pgrep -f "MistController" > /dev/null; then
    echo "MistServer is already running."
    exit 0
fi

# Start MistServer (/usr/bin/MistController inside Ubuntu)
nohup proot-distro login ubuntu -- MistController > /dev/null 2>&1 &

echo "MistServer started inside Ubuntu (proot)!"
