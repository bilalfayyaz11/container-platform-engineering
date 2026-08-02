import * as http from "http";
import * as os from "os";

http.createServer((req,res)=>{
res.writeHead(200,{"Content-Type":"application/json"});
res.end(JSON.stringify({
hostname:os.hostname(),
platform:os.platform(),
architecture:os.arch(),
nodeVersion:process.version
},null,2));
}).listen(3000);
