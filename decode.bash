#!/bin/bash
inputfile=$1
outputfile=$2
bandnum=$3
pulseduration=$4
sensitivity=$5
debug=$6
function helpmenu {
echo "./decode.bash <input file> <output file> <bandnum> <pulse duration> <sensitivity> <debug (optional)>"
echo ""
echo "     Description: Extracts data from a previously encoded waveform (.wav) audio"
echo "     Options:"
echo "          <input file>      Enter the input file. It should have been captured from a speaker"
echo "                            and end in *.wav"
echo "          <output file>     Enter the output file. For compatibility's sake, it should end in"
echo "                            the same extension with which it began."
echo "          <bandnum>         Enter the number of bands present in the encoded message. Make"
echo "                            sure the number is correct or the message won't be decoded"
echo "                            properly!"
echo "          <pulse duration>  Enter the pulse duration of the encoded message. Make sure the"
echo "                            number is correct or the message won't be decoded at all!"
echo "          <sensitivity>     Enter the sensitivity. This will alter the threshold of pulse"
echo "                            loudness, so changing it might help solve a decoding issue."
echo "                            Values ranging from 1 to 10 are accepted."
echo "          <debug>           Enter any value to display debug information (optional)." 
exit 0
}
case $1 in
(-h | --help | h) helpmenu;;
esac
#Checking to make sure the input file (required) and the output file, pulse duration and sensitivity (optional) have been specified
case $inputfile in
("") echo "ERROR: No input file specified!"; exit 1;;
esac
case $outputfile in
("") echo "WARN: No output file specified, using 'output.txt'!"; outputfile="output.txt";;
esac
case $bandnum in
("") echo "WARN: No number of data channels specified, using 1 as default value!"; bandnum=1;;
(1 | 2 | 3 | 4 | 5) echo "INFO: Number of channels: $bandnum";;
(*) echo "ERROR: As of now, the maximum number of supported data channels is 5. Exiting..."; exit 1;;
esac
case $pulseduration in
("") pulseduration=0.1; echo "WARN: Pulse duration not specified, using 0.1 (s) as default value!";
esac
case $sensitivity in
("") sensitivity=2; echo "WARN: Sensitivity not specified, using 2 (on a scale >1 - >=10) as default value!"
esac
#Making sure output file is clean
if test -f $outputfile
then
read -n1 -p "WARN: Output file already exists. Overwrite? (y/n):" conf
case $conf in
(y | Y) rm $outputfile;;
(*) echo "ERROR: Output file exists and will not be overwritten!"; exit 0;;
esac
fi
function DETECT-PTIS {
#Checking for PTI (ie Prime Tonal Identifier, the beep that will indicate the beginning and end of the message)
	#There are three PTIS in a multi-band message, and two in a one-band message.
	#The Initial and Final PTIs mark the beginning and end of transmission whether multiple frequencies are
	#being used or not, while the Secondary PTI marks the end of transmission on the last band in case the
	#number of bits in the message is not a multiple of the number of bands being utilized.
minfreq=$1
maxfreq=$2
start=0
finish=$(echo "$pulseduration / 2" | bc -l | cut -c 1-3)
#Remove noise from other frequencies
sox $inputfile ptipreoutput.wav sinc -n 1000 "$minfreq"-"$maxfreq"
case $debug in
("") :;;
(*) echo "DEBUG: Minfreq: $minfreq Maxfreq: $maxfreq";;
esac
PTI=0
echo "INFO: Searching for PTIs..."
while [[ "$exitloop" != "true" ]]
do
case $debug in
("") :;;
(*) echo "DEBUG: Currently searching timestamp ranging from $start to $finish (s)";;
esac
#When the parser reaches the end of a file SoX should give a warning, which will serve as an EOF indication to
#exit the function.
parseerror=$(sox ptipreoutput.wav temp.wav trim =$start =$finish 2>&1)
parseerror=$(echo $parseerror | cut -c 1-1)
if [[ "$parseerror" != "" ]]
then
case $PTI in
(0 | 1) echo "ERROR: Less than 2 PTIs found! Make sure they are present and sensitivity is low enough!"; exit 1;;
(2) echo "WARN: 2 PTIs found! For single-band messages this is normal, but it may be cause for concern in multi-band messages!"; return 0;;
(3) echo "INFO: 3 PTIs Found"; return 0;;
(*) echo "WARN: More than 4 potential PTIs found (sensitivity may be too low)! Using the first 3..."; return 0;;
esac
fi
maxamp="$(sox temp.wav -n stat 2>&1 | grep "Maximum amplitude" | tr -d " " | cut -d ":" -f2 | cut -d "." -f2 | bc)"
case $debug in
("") :;;
(*) echo "DEBUG: Maxamp: $maxamp"
esac
if [[ "$maxamp" -ge $(echo "$sensitivity * 10000" | bc | cut -d "." -f1) ]]
then
PTI=$((PTI+1))
eval starttime"$PTI"=$(echo "$(echo "$start + $finish" | bc) / 2" | bc -l | cut -c 1-5)
case $debug in
("") :;;
(*) echo "DEBUG: Starttime1: $starttime1 Starttime2: $starttime2 Starttime3: $starttime3 Starttime4: $starttime4"
esac
echo "INFO: Found PTI at $start - $finish (s), continuing search..."
start=$(echo $finish + $(echo "$pulseduration / 2" | bc -l | cut -c 1-3) + $(echo "$pulseduration / 2" | bc -l | cut -c 1-3) + $(echo "$pulseduration / 2" | bc -l | cut -c 1-3) | bc)
finish=$(echo $start + $(echo "$pulseduration / 2" | bc -l | cut -c 1-3) | bc)
else
start=$finish
finish=$(echo $finish + $(echo "$pulseduration / 2" | bc -l | cut -c 1-3) | bc)
fi
case $debug in
("") :;;
(*) echo "DEBUG: Maxamp: $maxamp"
esac
done
#Cleaning up
rm ptipreoutput.wav secondaryptisilence.wav secondarytemppti.wav temp.wav
}
function EXTRACT-DATA {
minfreq=$1
maxfreq=$2
currentband=$3
output=""
start=$(echo "$starttime1 + $pulseduration" | bc)
finish=$(echo "$start + $(echo "$pulseduration / 2" | bc -l | cut -c 1-5)" | bc)
case $(echo "$bandnum - $currentband" | bc) in
(0) end=$starttime2;;
(*) end=$starttime3;;
esac
complete=false
sox $inputfile analysis.wav sinc "$minfreq"-"$maxfreq"
echo "INFO: Extracting data inside the interval $starttime1 - $end (s) on band $currentband"
while [[ "$complete" != true ]]
do
sox analysis.wav temp.wav trim =$start =$finish
case $debug in
("") :;;
(*) echo "DEBUG: Start: $start Finish: $finish"
esac
maxamp="$(sox temp.wav -n stat 2>&1 | grep "Maximum amplitude" | tr -d " " | cut -d ":" -f2 | cut -d "." -f2 | bc)"
case $debug in
("") :;;
(*) echo "DEBUG: Maxamp: $maxamp"
esac
if [[ "$maxamp" -ge $(echo "$sensitivity * 10000" | bc | cut -d "." -f1) ]]
then
output="$output"1
else
output="$output"0
fi
start=$(echo "$start + $pulseduration" | bc)
finish=$(echo "$finish + $pulseduration" | bc)
tempfinish=$(echo "$(echo "$finish * 1000000" | bc) / 1" | bc)
tempend=$(echo "$(echo "$end * 1000000" | bc) / 1" | bc)
if [[ "$tempfinish" -ge "$tempend" ]]
then
complete=true
fi
done
finaloutput=$finaloutput"$output"
}
DETECT-PTIS 300 500
case $bandnum in
(1) EXTRACT-DATA 600 1000 1;;
(2) EXTRACT-DATA 600 1000 1; EXTRACT-DATA 1600 2000 2;;
(3) EXTRACT-DATA 600 1000 1; EXTRACT-DATA 1600 2000 2; EXTRACT-DATA 2200 2600 3;;
(4) EXTRACT-DATA 600 1000 1; EXTRACT-DATA 1600 2000 2; EXTRACT-DATA 2200 2600 3; EXTRACT-DATA 3200 3600 4;;
(5) EXTRACT-DATA 600 1000 1; EXTRACT-DATA 1600 2000 2; EXTRACT-DATA 2200 2600 3; EXTRACT-DATA 3200 3600 4; EXTRACT-DATA 4000 4400 5;;
esac
echo "INFO: Converting output file to final form..."
finalhexoutput=$(echo "ibase=2; obase=10000; $finaloutput" | bc | tr -d '\\\n')
echo $finalhexoutput > pre$outputfile
xxd -r -p pre$outputfile $outputfile
case $debug in
("") :;;
(*) echo "DEBUG: pre$outputfile:"; cat pre$outputfile; echo "DEBUG: Final hex output: $finalhexoutput"; echo "DEBUG: Final output: $finaloutput";;
esac
rm pre$outputfile
