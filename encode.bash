#!/bin/bash
#Setting environment variables, changing names to make them clearer
inputfile=$1
bandnum=$2
pulseduration=$3
debug=$4
function helpmenu {
echo "./encode.bash <input file> <bandnum> <pulse duration> <debug (optional)>"
echo ""
echo "     Description: Extracts data from a previously encoded waveform (.wav) audio"
echo "     All output files will be saved to 'output.wav'."
echo "     Options:"
echo "          <input file>      Enter the input file. It should have been captured from a speaker"
echo "                            and end in *.wav"
echo "          <bandnum>         Enter the number of bands present in the encoded message."
echo "                            Range: 1-5. Default: 1"
echo "          <pulse duration>  Enter the pulse duration of the encoded message. Make sure that"
echo "                            it isn't too short!"
echo "                            Default: 0.1"
echo "          <debug>           Enter any value to display debug information (optional)." 
exit 0
}
case $1 in
(-h | --help | h) helpmenu;;
esac
case $inputfile in
("") echo "ERROR: No input file specified! Exiting..."; exit 1;;
esac
case $pulseduration in
("") pulseduration=0.1; echo "WARN: Pulse duration not specified, using 0.1 (s) as default value!";;
esac
case $bandnum in
("") bandnum=1; lastband=1; echo "WARN: Number of tx bands not specified, using 1 as default value!";;
(2) lastband=2;;
(3) lastband=3;;
(4) lastband=4;;
(5) lastband=5;;
esac
function fileconvert {
bits=$(cat $inputfile | xxd -b -c1 | cut -d" " -f2 | tr -d " \n" | tr -d "\n")
}
function encode {
band=$1
bandminfreq=$2
bandfreq=$3
bandmaxfreq=$4
for i in $(eval echo {1..${#bandbitstring[$band]}})
do
case $debug in
("") :;;
(*) echo "DEBUG: GOT $(echo ${bandbitstring[$band]} | cut -c $i-$i), $i of ${#bits}"
esac
case $(echo ${bandbitstring[$band]} | cut -c $i-$i) in
(0) sox -n -r 100000 -b 16 -c 1 newfile.wav synth $pulseduration sin 5000 vol -1000dB;;
(1) sox -n -r 100000 -b 16 -c 1 newfile.wav synth $pulseduration sin $bandfreq vol -2dB fade $(echo "$pulseduration / 10" | bc -l | cut -c 1-5) $pulseduration $(echo "$pulseduration / 10" | bc -l | cut -c 1-5) sinc "$bandminfreq"-"$bandmaxfreq";;
esac
#Create Secondary PTI for the last band 
if [[ "${#bandbitstring[$band]}" == "$i" ]] && [[ "$band" == "$lastband" ]] && [[ "$band" -ne 1 ]]
then
secondaryptisilence=$(echo "$i * $pulseduration" | bc)
sox -r 100000 -n -b 16 -c 1 secondaryptisilence.wav synth $secondaryptisilence sin 5000 vol -1000dB 
sox -r 100000 -n -b 16 -c 1 secondarytemppti.wav synth $pulseduration sin 400 vol 0dB fade $(echo "$pulseduration / 10" | bc -l | cut -c 1-4) 0 sinc 300-500
sox secondaryptisilence.wav secondarytemppti.wav secondarypti.wav splice
secondarypti=secondarypti.wav
fi
if test -f construct.wav; then sox construct.wav newfile.wav temp.wav splice; mv temp.wav construct.wav; else mv newfile.wav construct.wav; fi
done
#Removing spikes
sox construct.wav tempconstruct.wav sinc "$bandminfreq"-"$bandmaxfreq"
mv tempconstruct.wav "$band"construct.wav
echo "INFO: Finished encoding band $band"
#Cleaning up for next round
rm construct.wav
}
fileconvert
if [[ $bandnum -gt 5 ]]
then
echo "ERROR: Number of tx bands exceeds currently supported number of 5"
exit 1
fi
numbits=${#bits}
echo "INFO: Number of bits to encode: $numbits"
bitmultiplier=$(echo "$numbits / $bandnum" | bc)
#In order to simplify recalling strings from the following array the 0th iteration of the bit string variable will simply be the total number of bits in the entire string.
bandbitstring=$numbits
case $bandnum in
(1) bandbitstring+=("$(echo $bits | cut -c 1-$bitmultiplier)");;
(*) bandbitstring+=("$(echo $bits | cut -c 1-$((bitmultiplier+1)))");;
esac
file1=1construct.wav
case $debug in
("") :;;
(*) echo "DEBUG: bit part 1: ${bandbitstring[1]}"
esac
if [[ $bandnum -ge 2 ]]
then
bandbitstring+=("$(echo $bits | cut -c 3- | cut -c $bitmultiplier-$(echo "$bitmultiplier * 2" | bc))")
file2=2construct.wav
case $debug in
("") :;;
(*) echo "DEBUG: bit part 2: ${bandbitstring[2]}"
esac
if [[ $bandnum -ge 3 ]]
then
bandbitstring+=("$(echo $bits | cut -c 4- | cut -c $(echo "$bitmultiplier * 2" | bc)-$(echo "$bitmultiplier * 3" | bc))")
file3=3construct.wav
case $debug in
("") :;;
(*) echo "DEBUG: bit part 3: ${bandbitstring[3]}"
esac
if [[ $bandnum -ge 4 ]]
then
bandbitstring+=("$(echo $bits | cut -c 5- | cut -c $(echo "$bitmultiplier * 3" | bc)-$(echo "$bitmultiplier * 4" | bc))")
file4=4construct.wav
case $debug in
("") :;;
(*) echo "DEBUG: bit part 4: ${bandbitstring[4]}"
esac
if [[ $bandnum -ge 5 ]]
then
bandbitstring+=("$(echo $bits | cut -c 6- | cut -c $(echo "$bitmultiplier * 4" | bc)-)")
case $debug in
("") :;;
(*) echo "DEBUG: bit part 5: ${bandbitstring[5]}"
esac
file5=5construct.wav
encode 1 600 800 1000
encode 2 1600 1800 2000
encode 3 2200 2400 2600
encode 4 3200 3400 3600
encode 5 4000 4200 4400
else
encode 1 600 800 1000
encode 2 1600 1800 2000
encode 3 2200 2400 2600
encode 4 3200 3400 3600
fi
else
encode 1 600 800 1000
encode 2 1600 1800 2000
encode 3 2200 2400 2600
fi
else
encode 1 600 800 1000
encode 2 1600 1800 2000
fi
else
encode 1 600 800 1000
fi
#Merging audio files
#For the sake of simplicity every file name has been turned into a variable, if it has null value it will simply be omitted, and if there is only one file no merging will occur.
if test -f 2construct.wav
then
sox -m $file1 $file2 $file3 $file4 $file5 $secondarypti construct.wav
else
cp $file1 construct.wav
fi
#Adding PTIS
echo "INFO: Adding PTIs..."
sox -r 100000 -n -b 16 -c 1 newfile.wav synth $pulseduration sin 400 vol -2dB fade $(echo "$pulseduration / 10" | bc -l | cut -c 1-4) $pulseduration sinc 300-500 
sox newfile.wav construct.wav intermediate.wav splice
sox -r 100000 -n -b 16 -c 1 newfile.wav synth $pulseduration sin 400 vol -2dB fade $(echo "$pulseduration / 10" | bc -l | cut -c 1-4) 0 sinc 300-500
sox intermediate.wav newfile.wav construct.wav splice
#Cleaning up
mv construct.wav output.wav
rm intermediate.wav newfile.wav
rm $file1 $file2 $file3 $file4 $file5 $secondarypti
