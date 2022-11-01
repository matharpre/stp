# stp
The Sonar Transmission Protocol
  
A functional data transmission protocol based on sound!

# HOW TO OPERATE:
Encoding:
    ./encode.bash <input file> <bandnum> <pulse duration> <debug (optional)>

     Description: Extracts data from a previously encoded waveform (.wav) audio
     All output files will be saved to 'output.wav'.
     Options:
          <input file>      Enter the input file. It should have been captured from a speaker
                            and end in *.wav
          <bandnum>         Enter the number of bands present in the encoded message.
                            Range: 1-5. Default: 1
          <pulse duration>  Enter the pulse duration of the encoded message. Make sure that
                            it isn't too short!
                            Default: 0.1
          <debug>           Enter any value to display debug information (optional).
Decoding:
     ./decode.bash <input file> <output file> <bandnum> <pulse duration> <sensitivity> <debug (optional)>

     Description: Extracts data from a previously encoded waveform (.wav) audio
     Options:
          <input file>      Enter the input file. It should have been captured from a speaker
                            and end in *.wav
          <output file>     Enter the output file. For compatibility's sake, it should end in
                            the same extension with which it began.
          <bandnum>         Enter the number of bands present in the encoded message. Make
                            sure the number is correct or the message won't be decoded
                            properly!
          <pulse duration>  Enter the pulse duration of the encoded message. Make sure the
                            number is correct or the message won't be decoded at all!
          <sensitivity>     Enter the sensitivity. This will alter the threshold of pulse
                            loudness, so changing it might help solve a decoding issue.
                            Values ranging from 1 to 10 are accepted.
          <debug>           Enter any value to display debug information (optional).
