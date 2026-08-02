const http=require('http');
const os=require('os');

http.createServer((req,res)=>{
res.writeHead(200,{"Content-Type":"text/html"});
res.end(`
<h1>Simple Docker App</h1>
<p>Hostname: ${os.hostname()}</p>
<p>Platform: ${os.platform()}</p>
<p>Architecture: ${os.arch()}</p>
<p>Node: ${process.version}</p>
`);
}).listen(3000);
