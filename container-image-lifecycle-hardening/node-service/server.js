const express = require("express");
const os = require("os");

const app = express();
const port = Number(process.env.PORT || 3000);

app.get("/", (_request, response) => {
  response.json({
    message: "Container image optimization is working",
    version: "1.0.0",
    hostname: os.hostname(),
    nodeVersion: process.version,
    timestamp: new Date().toISOString()
  });
});

app.get("/health", (_request, response) => {
  response.status(200).json({
    status: "healthy",
    uptimeSeconds: Math.floor(process.uptime())
  });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Service listening on port ${port}`);
});
