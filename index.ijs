NB. jconsole ~\Desktop\Programming\J\disj\index.ijs
NB. sdclose disj_sk

disj_parentdirectory =: '~\Desktop\Programming\J\disj\'
0!:0 < jpath disj_parentdirectory , 'client.ijs'

NB. update these as needed
bottoken =: '.'

prefix =: disj_char2str '.'

disj_onready =: 3 : 0
    echo 'Discord client connected and ready!'
    disj_update_presence 'Use .help to start'
)

disj_onmessage =: 3 : 0
    eventdata =. y
    msgcontent =. 'content' disj_select eventdata
    msgchannelid =. 'channel_id' disj_select eventdata

    NB. ignore messages that do not contain our prefix
    containsprefix =. prefix -: ($ prefix) {. msgcontent
    if. 0 = containsprefix do. return. end.                 

    NB. get the arguments our user submitted
    args =. ' ' disj_strsplit msgcontent                    
    command =. 0 {:: args

    NB. log the user and command to console
    userdata =. 'author' disj_select eventdata      
    usertag =. ,/> (disj_select&userdata) &.> ('username' ; 'discriminator')
    echo usertag , ' sent: ' , msgcontent  
    errormsgdata =. |: ('description' ; 'Con  lt `.help` and try again') ,. ('title' ; 'Bad input') ,. ('color' ; 16711680) ,. ('embed' ; 1)

    NB. handle different commands and their respective arguments
    select. command 
    case. prefix , 'ping' do.
        returndata =. |: ('embed' ; 0) ,. ('content' ; 'pong!')
        msgchannelid disj_send_message returndata

    case. prefix , 'hex2rgb' do.
        try. 
            hexstring =. 1 {:: args
            returnmsg =. ": hex2rgb hexstring
            colorint =. hex2int hexstring
            returndata =. |: ('description' ; returnmsg) ,. ('title' ; 'Converting HEX to RGB') ,. ('color' ; colorint) ,. ('embed' ; 1)
            msgchannelid disj_send_message returndata
        catch.
            msgchannelid disj_send_message errormsgdata
        end.

    case. prefix , 'rgb2hex' do.
        try.
            rgb =. > (1,:3) ];.0 args
            returnmsg =. rgb2hex rgb
            colorint =. rgb2int rgb
            returndata =. |: ('description' ; returnmsg) ,. ('title' ; 'Converting HEX to RGB') ,. ('color' ; colorint) ,. ('embed' ; 1)
            msgchannelid disj_send_message returndata
        catch.
            msgchannelid disj_send_message errormsgdata
        end.

    case. prefix , 'help' do.
        line1 =. '`.hex2rgb <hexstring>` where <hexstring> is a 6 letter hexcode\n\n'
        line2 =. '`.rgb2hex <r> <g> <b>` where <r> <g> <b> are ints 0 - 255\n\n'
        returndata =. |: ('description' ; line1 , line2) ,. ('title' ; 'Command help') ,. ('embed' ; 1)
        msgchannelid disj_send_message returndata
        
    end.
)

NB. rudimentary color conversion functions
hex2rgb =: 3 : 0
    hexmap =. (<"0 '0123456789abcdef') ,.  <"0 i.16
    hex =. (disj_select&hexmap)"0 tolower y 
    rgb =. (16&*@{.+{:)"1 |. 3 2  $ hex
    |. rgb
)

hex2int =: 3 : 0
    rgb =. hex2rgb y 
    +/ (65536 256 1) * rgb
)

rgb2hex =: 3 : 0
    hexmap =. (<"0 i.16) ,. <"0 '0123456789abcdef'
    rgbhex =. (disj_select&hexmap)"0 (<.@%&16 , |~&16)"0 ,/ ". y
    toupper ,/ rgbhex 
)

rgb2int =: 3 : 0
    rgb =. ". y 
    +/ (65536 256 1) * rgb
)

NB. don't output detailed echo logs and begin client
disj_displayconsole =: 0
disj_begin_client bottoken
