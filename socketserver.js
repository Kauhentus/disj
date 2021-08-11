const net = require('net')
const https = require('https');
const W3CWebSocket = require('websocket').w3cwebsocket;

let websocket;
let websocketRunning = false;

const server = net.createServer((socket) => {
    socket.on('data', data => {
        const lines = data.toString().split('\n').map(line => line.trim());
        const requestLineArgs = lines[0].split(' ');

        console.log('Request received:');
        console.log(`${lines.map(line => `    ${line}`).join('\n').trim()} \n`);

        const headerEndIndex = lines.indexOf('');
        const headersArgs = lines.slice(1, headerEndIndex).map(line => {
            const splitIndex = line.indexOf(': ');
            return [line.slice(0, splitIndex), line.slice(splitIndex + 2)];
        });
        const messageBody = lines.slice(headerEndIndex + 1).join('\n');

        const options = {
            method: requestLineArgs[0],
            path: requestLineArgs[1],
            hostname: headersArgs.filter(headerArgs => headerArgs[0] == 'Host')[0][1].replace(/www./, ''),
            headers: headersArgs.filter(headerArgs => headerArgs[0] != 'Host').reduce((k,v)=>(k[v[0]]=v[1],k),{})
        };

        // console.log(options);
        console.log('Making HTTPS request...')

        if(options.method == 'SOCKETCONNECT'){
            if(websocketRunning) return;
            else websocketRunning = true;

            console.log('Connecting to websocket...')

            const messageHandler = msg => {
                console.log('Received websocket data, attempting to write data to socket...')
                console.log('msg length ' + msg.data.length)
                
                const socketresponse = `*Y$)2${msg.data}!&J$`;

                Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);
                socket.write(socketresponse, (err) => {
                    if(err) console.log('Failed to write data to socket')
                    else console.log('Successfully wrote data to socket')
                });
            } 

            const connect = () => {
                console.log(options.headers['Socket-url'])
                websocket = new W3CWebSocket(options.headers['Socket-url']);
            
                websocket.onmessage = messageHandler;
                websocket.onclose = () => {
                    console.log("Disconnected, trying to reconnect...")
                    connect(); // reopen websocket when closed by discord
                }
            }

            connect();

            return;
        }

        else if(options.method == 'SOCKET'){
            console.log('Writing to websocket...')
            websocket.send(messageBody);            
           
            return;
        }

        const req = https.request(options, res => {
            console.log(`Response received with statusCode: ${res.statusCode} \n`)

            let totaldata = '';
            res.on('data', d => {
                totaldata += d.toString();
            });

            res.on('end', () => {
                console.log('Attempting to write data to socket...'); 

                const socketresponse = `*Y$)${(totaldata != '' ? 0 : 1) + totaldata}!&J$`;
                
                Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);

                socket.write(socketresponse, (err) => {
                    if(err) console.log('Failed to write data to socket')
                    else console.log('Successfully wrote data to socket')
                });
            })
        })
        
        req.on('error', error => {
            console.log("#", error)
        });

        if(requestLineArgs[0] == 'POST'){
            console.log(`Preparing to send ${lines.slice(headerEndIndex + 1).join('\n').length} bytes of data`)
            req.write(messageBody);
        }

        req.end();
    });

    socket.on('error', (err) => {
        console.log("Server socket error:", err.message)
    })

    socket.on('close', () => {
        process.exit();
    });

    socket.on('timeout', () => {
        process.exit();
    });
});

server.listen({
    host: 'localhost',
    port: 8080,
    exclusive: true
});

server.on('listening', () => {
    console.log(`\n Socket server started on ${JSON.stringify(server.address())} \n`)
});

server.on('connection', socket => {
    console.log(`Connection made with socket ${JSON.stringify(socket.address())} \n`)
});

server.on('error', err => {
    console.log("$", err)
});