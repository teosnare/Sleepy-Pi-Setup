#!/usr/bin/env bash

set -eu

# trap "set +x; sleep 5; set -x" DEBUG

# Check whether we are running sudo
if [[ $EUID -ne 0 ]]; then
  	echo "This script must be run as root" 1>&2
  	exit 1
fi

# check if it is Jessie or Stretch
osInfo=$(cat /etc/os-release)
if [[ $osInfo == *"jessie"* ]]; then
    Jessie=true
elif [[ $osInfo == *"stretch"* ]]; then
   Stretch=true
elif [[ $osInfo == *"buster"* ]]; then
   Buster=true
else
    echo "This script only works on Jessie, Stretch or Buster at this time"
    exit 1
fi

echo '================================================================================ '
echo '|                                                                               |'
echo '|      Sleepy Pi Installation Script - Jessie, Stretch or Buster                 |'
echo '|                                                                               |'
echo '================================================================================ '

## Update and upgrade
# sudo apt-get update && sudo apt-get upgrade -y

## Detecting Pi model
## list available https://elinux.org/Rpi_HardwareHistory
RPi3=false
RPi4=false
RpiCPU=$(/bin/cat /proc/cpuinfo | /bin/grep Revision | /usr/bin/cut -d ':' -f 2 | /bin/sed -e "s/ //g")
if [ "$RpiCPU" == "a02082" ]; then
    echo "Rapberry Pi 3 detected"
    RPi3=true
elif [ "$RpiCPU" == "a22082" ]; then
    echo "Rapberry Pi 3 B detected"
    RPi3=true
elif [ "$RpiCPU" == "a32082" ]; then
    echo "Rapberry Pi 3 B detected"
    RPi3=true
elif [ "$RpiCPU" == "a020d3" ]; then
    echo "Rapberry Pi 3 B+ detected"
    RPi3=true
elif [ "$RpiCPU" == "9020e0" ]; then
    echo "Rapberry Pi 3 A+ detected"
    RPi3=true
elif [ "$RpiCPU" == "9000c1" ]; then
    echo "Rapberry Pi Zero W detected"
    RPi3=true
elif [ "$RpiCPU" == "a03111" ]; then
    echo "Raspberry Pi 4 1GB detected"
    RPi4=true
elif [ "$RpiCPU" == "b03111" ]; then
    echo "Raspberry Pi 4 2GB detected"
    RPi4=true
elif [ "$RpiCPU" == "c03111" ]; then
    echo "Raspberry Pi 4 4GB detected"
    RPi4=true
else
    # RaspberryPi 2 or 1... let's say it's 2...
    echo "Non-RapberryPi 3 or 4 detected"
    RPi3=false
    RPi4=false
fi

echo 'Begin Installation ? (Y/n) '
read ReadyInput
if [[ "$ReadyInput" == "Y" || "$ReadyInput" == "y" ]]; then
    echo "Beginning installation..."
else
    echo "Aborting installation"
    exit 0
fi

##-------------------------------------------------------------------------------------------------
##-------------------------------------------------------------------------------------------------
## Test Area
# echo every line
set +x

# exit 0
## End Test Area

##-------------------------------------------------------------------------------------------------
##-------------------------------------------------------------------------------------------------


##-------------------------------------------------------------------------------------------------

## Enable Serial Port
# Findme look at using sed to toggle it
echo 'Enable Serial Port...'
#echo "enable_uart=1" | sudo tee -a /boot/config.txt
if grep -q 'enable_uart=1' /boot/config.txt; then
    echo 'enable_uart=1 is already set - skipping'
else
    echo 'enable_uart=1' | sudo tee -a /boot/config.txt
fi
if grep -q 'core_freq=250' /boot/config.txt; then
    echo 'The frequency of GPU processor core is set to 250MHz already - skipping'
else
    echo 'core_freq=250' | sudo tee -a /boot/config.txt
fi

## Disable Serial login
echo 'Disabling Serial Login...'
set +x
if [ $RPi3 != true ] || [ $RPi4 != true ]; then
    # Non-RPi3 or 4
    systemctl stop serial-getty@ttyAMA0.service
    systemctl disable serial-getty@ttyAMA0.service
else
    # Rpi 3 or 4
    systemctl stop serial-getty@ttyS0.service
    systemctl disable serial-getty@ttyS0.service
fi

## Disable Boot info
echo 'Disabling Boot info...'
#sudo sed -i'bk' -e's/console=ttyAMA0,115200.//' -e's/kgdboc=tty.*00.//'  /boot/cmdline.txt
sed -i'bk' -e's/console=serial0,115200.//'  /boot/cmdline.txt

## Link the Serial Port to the Arduino IDE
echo 'Link Serial Port to Arduino IDE...'
if [ $RPi3 != true ] || [ $RPi4 != true ]; then
    # Anything other than Rpi 3
    #wget https://raw.githubusercontent.com/SpellFoundry/Sleepy-Pi-Setup/master/80-sleepypi.rules
    #mv /home/pi/80-sleepypi.rules /etc/udev/rules.d/
    mv 80-sleepypi.rules /etc/udev/rules.d/
fi
# Note: On Rpi3 or 4 GPIO serial port defaults to ttyS0 which is what we want

##-------------------------------------------------------------------------------------------------

## Getting Sleepy Pi to shutdown the Raspberry Pi
echo 'Setting up the shutdown...'
cd ~
if grep -q 'shutdowncheck.py' /etc/rc.local; then
    echo 'shutdowncheck.py is already setup - skipping...'
else
    mkdir -p /home/pi/bin
    mkdir -p /home/pi/bin/SleepyPi
    #wget https://raw.githubusercontent.com/SpellFoundry/Sleepy-Pi-Setup/master/shutdowncheck.py
    mv -f shutdowncheck.py /home/pi/bin/SleepyPi
    sed -i '/exit 0/i python /home/pi/bin/SleepyPi/shutdowncheck.py &' /etc/rc.local
    # echo "python /home/pi/bin/SleepyPi/shutdowncheck.py &" | sudo tee -a /etc/rc.local
fi

##-------------------------------------------------------------------------------------------------

# install i2c-tools
echo 'Enable I2C...'
if grep -q '#dtparam=i2c_arm=on' /boot/config.txt; then
  # uncomment
  sed -i '/dtparam=i2c_arm/s/^#//g' /boot/config.txt
else
  echo 'i2c_arm parameter already set - skipping...'
fi

echo 'Install i2c-tools...'
if hash i2cget 2>/dev/null; then
    echo 'i2c-tools are installed already - skipping...'
else
    sudo apt-get install -y i2c-tools
fi

##-------------------------------------------------------------------------------------------------
echo "Sleepy Pi setup complete!"
echo  "Would you like to reboot now? Y/n"
read RebootInput
if [ "$RebootInput" == "Y" ]; then
    echo "Now rebooting..."
    sleep 3
    reboot
fi
exit 0
##-------------------------------------------------------------------------------------------------
