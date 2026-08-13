import http from "node:http";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import path from "node:path";

const root = path.resolve(process.argv[2] || ".");
const server = http.createServer(async (request, response) => {
  try {
    const url = new URL(request.url || "/", "http://127.0.0.1");
    const prefix = "/dist/";
    if (!url.pathname.startsWith(prefix)) throw new Error("not_found");
    const requested = decodeURIComponent(url.pathname.slice(prefix.length));
    if (!requested || requested !== path.basename(requested)) throw new Error("not_found");
    const target = path.join(root, requested);
    const metadata = await stat(target);
    if (!metadata.isFile()) throw new Error("not_found");
    response.writeHead(200, {
      "content-length": metadata.size,
      "content-type": "application/octet-stream",
      "cache-control": "no-store",
    });
    createReadStream(target).pipe(response);
  } catch {
    response.writeHead(404, { "content-type": "text/plain" });
    response.end("Not found");
  }
});

server.listen(0, "127.0.0.1", () => {
  process.stdout.write(`${server.address().port}\n`);
});
