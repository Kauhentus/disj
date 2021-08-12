NB. jconsole ~\Desktop\Programming\J\disj\client.ijs

(9 !: 11) 16
load 'socket'
coinsert 'jsocket'
load 'task'
coinsert 'jtask'
load 'convert/pjson'    NB. install in package manager

NB. function to get system time in millis, not standard but works
disj_getminorsecsfromtime =: 5&{+(60"_*4&{)+(3600"_*3&{)+(86400"_*2&{) 
disj_getmajdaysecs =: 86400"_ (* +/) 1&{ {. 0 31 28 31 30 31 30 31 31 30 31 30 31"_
disj_getmajyearsecs =: 31536000 * 0&{ - 1970"_
disj_getminorleapyearsecs =: 86400"_ * <.@(4"_ %~ 0&{ - 1972"_)
disj_gettimecombined =: disj_getminorsecsfromtime + disj_getmajdaysecs + disj_getmajyearsecs + disj_getminorleapyearsecs
disj_getsecs =: 1000&* @ disj_gettimecombined @ (6!:0) NB. disj_getsecs ''

NB. utility functions
disj_select =: 4 : '1 {:: ((>((x&-:) &.> {. |: y)) # i.($ {. |: y)) {:: y'
disj_contains =: 4 : '+/ > (x&-:) &.> {. |: y'
disj_takehead4 =: 4&{.
disj_taketail4 =: |.@(4&{.@|.)
disj_substr =: (];.0~ ,.)~"1
disj_char2str =: ,&''
disj_EOL =: CR , LF
disj_strsplit =: #@[ }.each [ (E. <;.1 ]) ,      NB. https://code.jsoftware.com/wiki/Phrases/Strings


NB. socket globals, initiated in begin client
disj_sk =: _ 
disj_address =: _

NB. custom "http requests" specially designed to "proxy" websockets (so unprofessional, I know ;-;)
NB. create websocket initiation request & send it
disj_websocketconnect =: 3 : 0
    request_line =. 'SOCKETCONNECT / HTTP/1.0'
    host_header =. 'Host: www.discord.com'
    surl_header =. 'Socket-url: wss://gateway.discord.gg/?v=6&encoding=json'
    request =. request_line , disj_EOL , host_header , disj_EOL , surl_header , disj_EOL ,  disj_EOL 
    sdcheck request sdsend disj_sk,0
)
NB. normal websocket request 
disj_websocketwrite =: 3 : 0
    srequest_line =. 'SOCKET / HTTP/1.0'
    shost_header =. 'Host: www.discord.com'
    ssurl_header =. 'Socket-url: wss://gateway.discord.gg/?v=6&encoding=json'
    request =. srequest_line , disj_EOL , shost_header , disj_EOL , ssurl_header , disj_EOL , disj_EOL , y , disj_EOL 
    sdcheck request sdsend disj_sk,0
)

disj_httpsrequest =: 4 : 0 
    request_line =. x , ' HTTP/1.0' NB. 'POST /api/v8/channels/867805073684824125/messages HTTP/1.0'
    auth_header =. 'Authorization: Bot ' , disj_bottoken
    host_header =. 'Host: www.discord.com'
    conn_header =. 'Connection: close'
    ctyp_header =. 'Content-Type: application/json'
    
    msg =. y NB. '{"content":"Hello, World!","tts":false,"embeds":[{"title":"Hello, Embed!","description":"This is an embedded message."}]}'
    clen_header =. 'Content-Length: ' , ": $ msg

    request =. request_line , disj_EOL , host_header , disj_EOL , auth_header , disj_EOL , conn_header , disj_EOL  , ctyp_header , disj_EOL , clen_header , disj_EOL , disj_EOL , msg , disj_EOL
    sdcheck request sdsend disj_sk,0
)

disj_displayconsole =: 0
disj_echo =: 3 : 'if. disj_displayconsole do. echo y end.'
disj_bottoken =: ''
disj_isloggedin =: 0

NB. heartbeat variables
disj_heartbeatinterval =: _
disj_beginheartbeat =: 0
disj_lastheartbeat =: _
disj_lastsequence =: 'null'

NB. socket variables for >2048 length messages
disj_intransit =: 0
disj_finishedtransit =: 0
disj_intransitmsg =: ''

disj_readyevent =: _

NB. functions called on the message and ready events, to be supplied by user
disj_onmessage =: _
disj_onready =: _

NB. handle discord events
disj_handleeventdispatch =: 3 : 0
    response =. y
    eventtype =: (disj_char2str 't') disj_select response
    eventdata =: (disj_char2str 'd') disj_select response

    disj_echo '    ' , eventtype

    select. eventtype
    case. 'MESSAGE_CREATE' do.      NB. https://discord.com/developers/docs/resources/channel#message-object
        disj_onmessage eventdata

    case. 'READY' do.
        disj_readyevent =: eventdata
        disj_onready eventdata

    case. do.
        disj_echo '    Unsupported event: ' , eventtype
    end.
)

NB. handle raw response from https/websocket
disj_handleresponse =: 3 : 0
    NB. collect data and check for errors (in node.js proxy)
    out =. y
    returncode =. ". {. out         
    2!:55 ^:(1 = returncode)  _ 
    response =. dec_pjson_ }. out

    NB. 0 = http response, 1 = node error, 2 = websocket response
    select. returncode
    case. 2 do.
        opcode =. 'op' disj_select response
        disj_echo '    Response op code: ' , ": opcode

        NB. implement discord gateway s field requirements
        receivedseqnull =. 1 = $ 1 , (disj_char2str 's') disj_select response
        if. receivedseqnull do. disj_lastsequence =: 'null'
        else. disj_lastsequence =: ": (disj_char2str 's') disj_select response end.

        select. opcode
        case. 10 do.    NB. hello (login or heartbeat request)
            disj_heartbeatinterval =: 'heartbeat_interval' disj_select (disj_char2str 'd') disj_select response
            disj_echo '    Heartbeat interval: ' , ": disj_heartbeatinterval

            if. disj_isloggedin do. 
                disj_echo '    NEW_HEARTBEAT_REQUEST'
                disj_lastheartbeat =: disj_getsecs '' 
                disj_websocketwrite '{"op":1,"d":' , disj_lastsequence , '}'
            else.
                disj_beginheartbeat =: 1
                disj_isloggedin =: 1
                disj_lastheartbeat =: disj_getsecs '' 
    
                NB. construct login json 
                returnopfield =. 'op' ; 2
                tokenfield =. 'token' ; disj_bottoken
                propertiesfield =. 'properties' ;  <(('os' ; 'browser') , ('browser' ; 'chrome') ,: ('device' ; 'cloud9'))
                compressfield =. 'compress' ; 0
                dfield =. 'd' ; <(tokenfield , propertiesfield ,: compressfield)
                requestjson =. enc_pjson_ returnopfield ,: dfield

                disj_websocketwrite requestjson
                disj_echo '    LOGGED_IN'
            end.  

        case. 0 do.     NB. event dispatched
            disj_handleeventdispatch response

        case. 11 do.    NB. heartbeat ack received
            disj_echo '    HEARTBEAT_RECEIVED'

        case. do.
            disj_echo opcode
        end.

    case. 0 do.
        disj_echo 'received dispatch event via https'
        NB. echo response

    case. do.
        echo 'ERROR: 1'
    end.
)

disj_fps =: 30
disj_clock =: disj_getsecs ''
disj_loop =: 3 : 0
while. 1 do. 
    NB. fps loop logic
    newdisj_clock =. disj_getsecs ''
    deltaticks =: (1000 % disj_fps) - (newdisj_clock - disj_clock)
    if. deltaticks > 0 do. 6!:3 (deltaticks % 1000) end. 
    if. deltaticks < -30 do. disj_clock =: newdisj_clock - 30
    else. disj_clock =: newdisj_clock + deltaticks end.

    NB. socket logic
    sdcheck sdioctl disj_sk , FIONBIO , 1

    NB. check if socket has data to read, block the thread if needed
    socketstatus =. sdcheck sdselect disj_sk ; (<i.0) , (<i.0) , <0
    unblock =. $ 0 {:: socketstatus

    if. unblock do.
        sdcheck sdioctl disj_sk , FIONBIO , 0

        out =. sdcheck sdrecv disj_sk,2048,0    NB. transmit data in 2048 byte chunks, limit probably should be raised

        NB. system to collect unit of data over multiple socket writes
        if. disj_intransit do.
            disj_intransitmsg =: disj_intransitmsg , {. > out
            disj_finishedtransit =: '!&J$' -: disj_taketail4 disj_intransitmsg
        else.
            rawtext =. {. > out

            if. '*Y$)' -: disj_takehead4 rawtext do.
                disj_intransitmsg =: disj_intransitmsg , rawtext
                disj_intransit =: 1

                if. '!&J$' -: disj_taketail4 disj_intransitmsg do.
                    disj_finishedtransit =: 1
                end.
            end.
        end.

        NB. full data has been received, send it to handler
        if. disj_finishedtransit do.
            disj_echo '---------------------------'
            disj_echo 'Received complete response:'
            totalmsglen =. $ disj_intransitmsg
            completeresponse =. (4 , totalmsglen - 8) disj_substr disj_intransitmsg
            
            disj_intransit =: 0
            disj_finishedtransit =: 0
            disj_intransitmsg =: ''
            
            disj_handleresponse completeresponse
        end.

        NB. unblock thread, heartbeat can continue while waiting for next msg
        sdcheck sdioctl disj_sk , FIONBIO , 1
    else. 
        
    end.

    NB. heartbeat logic as required by discord api
    if. disj_beginheartbeat do.
        timesincelastbeat =: (disj_getsecs '') - disj_lastheartbeat
        
        if. timesincelastbeat > disj_heartbeatinterval do.
            sdcheck sdioctl disj_sk , FIONBIO , 0
            disj_websocketwrite '{"op":1,"d":' , disj_lastsequence , '}'
            sdcheck sdioctl disj_sk , FIONBIO , 1

            disj_echo '---------------------------'
            disj_echo '<3 Sent heartbeat'
            disj_lastheartbeat =: disj_getsecs ''
        end.
    end.
end.
)

NB. assemble fields (some optional) into json and send it
disj_send_message =: 4 : 0
    data =. y 
    
    containsembed =. 'embed' disj_select data

    containscontent =. 'content' disj_contains data
    if. containscontent do. content =. 'content' disj_select data
    else. content =. '' end.

    containsembedcolor =. 'color' disj_contains data
    if. containsembedcolor do. colorid =. ": 'color' disj_select data
    else. colorid =. '2303786' end.

    if. containsembed do.
        embedtitle =. 'title' disj_select data
        embeddescrip =. 'description' disj_select data
        json =. '{"content":"' , content , '","tts":false,"embeds":[{"title":"' , embedtitle , '","description":"' , embeddescrip , '","color":' , colorid  , '}]}'
    else.
        json =. '{"content":"' , content , '","tts":false}'
    end.

    ('POST /api/v8/channels/' , x , '/messages') disj_httpsrequest json
)

NB. update text in discord presence feature
disj_update_presence =: 3 : 0
    sdcheck sdioctl disj_sk , FIONBIO , 1
    json =. '{"op":3,"d":{"since":null,"activities":[{"name":"' , y , '","type":0}],"status":"online","afk":false}}'
    disj_websocketwrite json
    sdcheck sdioctl disj_sk , FIONBIO , 0
)

NB. starting point of DisJ
disj_begin_client =: 3 : 0 
    NB. start node.js server proxy (allows us to use https & wss)
    echo 'Starting proxy...'
    3000 fork 'node ' , disj_parentdirectory , 'startserver.js' , ' ' , disj_parentdirectory

    NB. connect to node.js proxy
    disj_sk =: 0 pick sdcheck sdsocket ''
    disj_address =: sdcheck sdgethostbyname 'localhost'  NB. find host
    sdcheck sdconnect disj_sk ; disj_address , <8080  NB. connect to port 80

    NB. begin websocket connection
    disj_bottoken =: y
    disj_websocketconnect _
    disj_loop ''
)

