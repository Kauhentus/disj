const { execSync } = require('child_process');
execSync(`node ${process.argv[2]}socketserver.js`);
console.log('Proxy ended.');