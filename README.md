# DisJ
The first (proof-of-concept) library for writing Discord bots in J. Written by a J newbie who couldn't figure out relative pathing works in J (especially cross-platform). J does not have an event-driven paradigm so I tried my best to implement one. 
 
## Prerequisites 
1. DisJ uses a node.js proxy to use HTTPS/WSS, so node should be installed. Additionally, the websocket library (identified in package.json) should also be installed via `npm i`. 
2. The `convert/pjson` J addon should be installed. 
3. In `./index.ijs`, fill `bottoken` with your Discord bot token
## Running the example
To start the example Discord bot, you will run a command like this: `jconsole ~\Desktop\Programming\J\disj\index.ijs`, replacing the path to `index.ijs` with the path of the folder where you are using DisJ *(I'm so sorry about this ... I couldn't get J to use relative pathing. If you do know, please reach out to me!)*

Your command line should see two lines. Once the second line appears, the bot is ready to be used.

    Starting proxy...
    Discord client connected and ready!

The Discord bot is a a simple color code converter that converts between hex and rgb format. Try sending `.hex2rgb 9179FF` and `.rgb2hex 145 121 255` over Discord. Use `.help`for more information.

# Reflection
DisJ is a very rough implementation of a Discord library. J, as stellar of a programming language it is, lacks many standard libraries. I tried my best to work around these limitations in these areas:
### Event-driven paradigm
J is pretty much a synchronous language. It doesn't support events particularly well. I ended up using an FPS loop that constantly checked for socket events, blocking and unblocking the thread with `sdioctl` as needed. It should work, but there are always edge cases lurking in the dark. In the future, I want to try the Observer design pattern instead.

### HTTPS
 This was the biggest issue I encountered. J simply does not support HTTPS. J only supports sockets, and implementing HTTP was easy enough. However, the TLS handshake required of an HTTPS was too advanced for me. So, I used a node.js proxy and used node's https library, having J and node communicate through a separate socket. 
   
J doesn't communicate well with other programming languages either, by the synchronous nature of foreigns `2!:0` and `2!:1`. I tried my best but the connection between J and the node proxy is always wonky.

### Control statements
I'm bummed about the sheer amount of control statements I had to use to construct the library. J is known for its terseness and elegance with hooks, forks, etc. However, I found few areas to use these principles outside of writing helper functions because implementing events just felt so *stateful*. I'm still new to J (coming from node.js) so my thinking is still boxed in procedural paradigms. If anybody has suggestions, please let me know!

*P.S. You can reach me on Discord at Kauhentus#9311*

# Library usage
This 'library' is actually just `./client.ijs`, with `socketserver.js` and `startserver.js`. A barebones `./index.ijs` would look like this:

```disj_parentdirectory =: '~\Desktop\Programming\J\disj\'
0!:0  < jpath disj_parentdirectory ,  'client.ijs'

bottoken =: '<your token>'
prefix =: disj_char2str '.'


disj_onready =: 3 : 0
	echo 'Discord client connected and ready!'
)

disj_onmessage =: 3 : 0
	eventdata =. y
	msgcontent =. 'content' disj_select eventdata
	msgchannelid =. 'channel_id' disj_select eventdata
	containsprefix =. prefix -: ($ prefix) {. msgcontent
	if.  0  = containsprefix do.  return.  end.
  
	userdata =. 'author' disj_select eventdata
	usertag =. ,/> (disj_select&userdata) &.> ('username'  ;  'discriminator')
	echo usertag ,  ' sent: '  , msgcontent
)

disj_begin_client bottoken
```
   
# Documentation
## Main Methods
### `disj_begin_client <token>`  
Logs in and connects the client to Discord's API.  
`<token>` -- string, bot token issued by Discord  

### `disj_onready <eventhandler>`  
Fires when the client is ready (finished logging in and connecting)  
`<eventhandler>` -- monad (preferably 3:0) where `y` is a   [`readyevent`](https://discord.com/developers/docs/topics/gateway#ready)  

### `disj_onmessage <eventhandler>`  
Fires when the client receives a message  
`<eventhandler>` -- monad (preferably 3:0) where `y` is a  [`messageevent`](https://discord.com/developers/docs/resources/channel#message-object)  

### `disj_update_presence <presence>`  
Sets the bot's presence  
`<presence>` -- string  

### `<channelid> disj_send_message <data>`  
Dyad that sends a message in a specified channel.  
`<channelid>` -- string, snowflake id of a channel, typically comes from  the `channel_id` property of a [`messageevent`](https://discord.com/developers/docs/resources/channel#message-object)  
`<data>` -- a custom messagedata object that will be covered below  
## Data structures in DisJ
Discord's api communicates with JSON data structures. The closest equivalent in J are 2xn box structures that look similar to this:
```
+------------------+-------------------------------------+
|id                |875068223274516530                   |
+------------------+-------------------------------------+
|type              |0                                    |
+------------------+-------------------------------------+
|content           |                                     |
+------------------+-------------------------------------+
|channel_id        |867805073684824125                   |
+------------------+-------------------------------------+
|author            |+-------------+------------------+   |
|                  ||id           |872288946439204876|   |
|                  |+-------------+------------------+   |
|                  ||username     |http              |   |
|                  |+-------------+------------------+   |
|                  ||avatar       |                  |   |
|                  |+-------------+------------------+   |
|                  ||discriminator|2505              |   |
|                  |+-------------+------------------+   |
|                  ||public_flags |0                 |   |
|                  |+-------------+------------------+   |
|                  ||bot          |1                 |   |
|                  |+-------------+------------------+   |
+------------------+-------------------------------------+
```

The `messageevent` and `readyevent` data are given in this format. DisJ has several helper functions to work with these map-like structures:
### `<key> disj_select <data>`  
Returns the value inside the object associated with a specific key  
`<key>` -- string, the key that is associated with a specific value    
`<data>` -- custom data structure, returned from `onmessage` and `onready` events  
### `<key> disj_contains <data>`  
Returns a `boolean` which tells if the data structure contains an entry for a given key  
`<key>` -- string, the key that is associated with a specific value  
`<data>` -- custom data structure, returned from `onmessage` and `onready` events  
### `disj_char2str <char>`  
For one letter keys, `disj_select` breaks because in J, a key like `'d'` is evaluated as a character, not a string. Convert characters to strings with this function.  
`<char>` -- character  
## Other methods
### `<token> disj_strsplit <string>`  
Splits a string into an array of strings on each token (ie a space), useful because J's `;:` is inadequate in specific cases  
`<token>` -- string, token to split the input string on  
`<string>` -- string, the string to be split up  

---
There are more methods inside `./client.ijs`, but they are only used internally. Some may be useful to you, some may not.
---
- Kauhentus aka Joshua Yang
