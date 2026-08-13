import http from "node:http";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const TESTS_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = path.dirname(TESTS_DIR);
const TEMPLATE_PATH = path.join(PROJECT_DIR, "index.html");
const QR_VENDOR_PATH = path.join(PROJECT_DIR, "vendor", "qrcode.js");
const PORT = Number(process.env.HOMA_TEST_PORT || 4173);

export const fixtures = {
  active: {
    username: "mahdi_test",
    status: "active",
    used: 18 * 1024 ** 3,
    limit: 50 * 1024 ** 3,
    expire: Math.floor(Date.now() / 1000) + 18 * 86400,
    reset: "month",
    subscriptionUrl: "/sub/test-token",
    onlineAt: new Date(Date.now() - 14 * 60_000).toISOString(),
    createdAt: new Date(Date.now() - 45 * 86400_000).toISOString(),
    onHoldDuration: 0,
    links: [
      "vless://7b3797cd-38b8-4db1-9e15-a84c3f8db8aa@fr.example.test:443?security=reality&type=tcp#France",
      "trojan://homa-test-password@de.example.test:443?security=tls&type=ws#Germany",
    ],
  },
  unlimited: {
    username: "unlimited_user",
    status: "active",
    used: 7.5 * 1024 ** 3,
    limit: 0,
    expire: 0,
    reset: "no_reset",
    subscriptionUrl: "https://sub.example.test/sub/unlimited-token",
    onlineAt: "",
    createdAt: new Date(Date.now() - 120 * 86400_000).toISOString(),
    onHoldDuration: 0,
    links: ["vless://unlimited@example.test:443?security=tls#Unlimited"],
  },
  limited: {
    username: "limited_user",
    status: "limited",
    used: 55 * 1024 ** 3,
    limit: 50 * 1024 ** 3,
    expire: Math.floor(Date.now() / 1000) + 2 * 86400,
    reset: "no_reset",
    subscriptionUrl: "/sub/limited-token",
    onlineAt: new Date(Date.now() - 3 * 86400_000).toISOString(),
    createdAt: new Date(Date.now() - 60 * 86400_000).toISOString(),
    onHoldDuration: 0,
    links: [],
  },
  expired: {
    username: "expired_user",
    status: "expired",
    used: 4 * 1024 ** 3,
    limit: 20 * 1024 ** 3,
    expire: Math.floor(Date.now() / 1000) - 2 * 86400,
    reset: "no_reset",
    subscriptionUrl: "/sub/expired-token",
    onlineAt: new Date(Date.now() - 9 * 86400_000).toISOString(),
    createdAt: new Date(Date.now() - 90 * 86400_000).toISOString(),
    onHoldDuration: 0,
    links: [],
  },
  disabled: {
    username: "disabled_user",
    status: "disabled",
    used: 2 * 1024 ** 3,
    limit: 25 * 1024 ** 3,
    expire: Math.floor(Date.now() / 1000) + 12 * 86400,
    reset: "no_reset",
    subscriptionUrl: "/sub/disabled-token",
    onlineAt: "",
    createdAt: new Date(Date.now() - 20 * 86400_000).toISOString(),
    onHoldDuration: 0,
    links: [],
  },
  on_hold: {
    username: "on_hold_user",
    status: "on_hold",
    used: 0,
    limit: 30 * 1024 ** 3,
    expire: 0,
    reset: "no_reset",
    subscriptionUrl: "/sub/on-hold-token",
    onlineAt: "",
    createdAt: new Date(Date.now() - 2 * 86400_000).toISOString(),
    onHoldDuration: 30 * 86400,
    links: [],
  },
};

export function bytesformat(value) {
  const units = ["B", "KB", "MB", "GB", "TB"];
  if (!Number.isFinite(value) || value <= 0) return "0 B";
  const index = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
  const digits = index > 2 ? 2 : 1;
  return `${(value / 1024 ** index).toFixed(digits)} ${units[index]}`;
}

function renderConditional(source, expression, truthy, falsy, condition) {
  const block = `{% if ${expression} %}${truthy}{% else %}${falsy}{% endif %}`;
  return source.split(block).join(condition ? truthy : falsy);
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "'": "&#39;",
    '"': "&quot;",
  })[character]);
}

export function renderTemplate(source, fixture, qrVendor) {
  let html = source;
  html = renderConditional(
    html,
    "not user.data_limit",
    "نامحدود",
    "{{ user.data_limit | bytesformat }}",
    !fixture.limit,
  );
  html = renderConditional(
    html,
    "not user.data_limit",
    "0",
    "{{ user.data_limit }}",
    !fixture.limit,
  );
  html = renderConditional(
    html,
    "not user.expire",
    "0",
    "{{ user.expire }}",
    !fixture.expire,
  );
  html = renderConditional(
    html,
    "not user.on_hold_expire_duration",
    "0",
    "{{ user.on_hold_expire_duration }}",
    !fixture.onHoldDuration,
  );

  const linksLoop = '{% for link in user.links %}<span data-link="{{ link | e }}"></span>{% endfor %}';
  const renderedLinks = (fixture.links || [])
    .map((link) => `<span data-link="${escapeHtml(link)}"></span>`)
    .join("");
  html = html.split(linksLoop).join(renderedLinks);

  const replacements = new Map([
    ["{{ user.username }}", fixture.username],
    ["{{ user.status.value }}", fixture.status],
    ["{{ user.used_traffic | bytesformat }}", bytesformat(fixture.used)],
    ["{{ user.used_traffic }}", String(fixture.used)],
    ["{{ user.data_limit | bytesformat }}", bytesformat(fixture.limit)],
    ["{{ user.data_limit }}", String(fixture.limit)],
    ["{{ user.expire }}", String(fixture.expire)],
    ["{{ user.data_limit_reset_strategy.value }}", fixture.reset],
    ["{{ user.subscription_url }}", fixture.subscriptionUrl],
    ["{{ user.online_at or '' }}", fixture.onlineAt || ""],
    ["{{ user.created_at or '' }}", fixture.createdAt || ""],
    ["{{ user.on_hold_expire_duration }}", String(fixture.onHoldDuration || 0)],
  ]);
  for (const [token, value] of replacements) html = html.split(token).join(value);

  return html
    .replace('{% include "subscription/vendor/qrcode.js" %}', () => qrVendor)
    .replaceAll("https://speed.cloudflare.com/__down?bytes=5000000", "/__down?bytes=5000000")
    .replaceAll("https://speed.cloudflare.com/__down?bytes=1", "/__down?bytes=1")
    .replaceAll("https://speed.cloudflare.com/__up", "/__up");
}

function send(res, status, body, contentType = "text/html; charset=utf-8") {
  res.writeHead(status, {
    "Content-Type": contentType,
    "Cache-Control": "no-store",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(body);
}

export function createTestServer() {
  return http.createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
  const fixtureByToken = Object.values(fixtures).find((fixture) => {
    try {
      const fixturePath = new URL(fixture.subscriptionUrl, "http://local.test").pathname.replace(/\/+$/, "");
      const requestPath = url.pathname.replace(/\/(?:usage|info|clash-meta|clash|outline|sing-box|v2ray|v2ray-json)\/?$/, "");
      return fixturePath === requestPath;
    } catch {
      return false;
    }
  });

  if (url.pathname === "/__down") {
    const requested = Number(url.searchParams.get("bytes") || 1);
    const size = Math.max(1, Math.min(requested, 5_000_000));
    return send(res, 200, Buffer.alloc(size, 97), "application/octet-stream");
  }

  if (url.pathname === "/__up") {
    let received = 0;
    req.on("data", (chunk) => {
      received += chunk.length;
    });
    req.on("end", () => send(res, 200, JSON.stringify({ received }), "application/json"));
    return;
  }

  if (url.pathname === "/usage" || /\/sub\/[^/]+\/usage\/?$/.test(url.pathname)) {
    const start = new Date(url.searchParams.get("start") || Date.now());
    const dayNumber = Math.floor(start.getTime() / 86400000);
    const total = Math.max(0, (0.55 + (Math.abs(dayNumber) % 6) * 0.37) * 1024 ** 3);
    return send(res, 200, JSON.stringify({
      username: (fixtureByToken || fixtures.active).username,
      usages: [
        { node_id: null, node_name: "Master", used_traffic: Math.round(total * 0.62) },
        { node_id: 1, node_name: "France", used_traffic: Math.round(total * 0.38) },
      ],
    }), "application/json; charset=utf-8");
  }

  if (/\/sub\/[^/]+\/info\/?$/.test(url.pathname)) {
    const fixture = fixtureByToken || fixtures.active;
    return send(res, 200, JSON.stringify({
      username: fixture.username,
      status: fixture.status,
      used_traffic: fixture.used,
      data_limit: fixture.limit || null,
      expire: fixture.expire || null,
      data_limit_reset_strategy: fixture.reset,
      online_at: fixture.onlineAt || null,
      on_hold_expire_duration: fixture.onHoldDuration || null,
    }), "application/json; charset=utf-8");
  }

  if (url.pathname === "/harness") {
    const width = Math.max(320, Math.min(Number(url.searchParams.get("width") || 390), 1440));
    const fixture = url.searchParams.get("fixture") || "active";
    const selected = fixtures[fixture] || fixtures.active;
    const frameUrl = new URL(selected.subscriptionUrl, "http://local.test").pathname;
    const harness = `<!doctype html>
<html lang="fa" dir="rtl">
<head><meta charset="utf-8"><title>Homa Ghost QA</title>
<style>html,body{margin:0;background:#222}iframe{display:block;width:${width}px;height:900px;border:0;margin:0 auto;background:#fff}</style></head>
<body><iframe title="Homa Ghost fixture" src="${frameUrl}"></iframe></body></html>`;
    return send(res, 200, harness);
  }

  if (url.pathname === "/" || url.pathname === "/index.html" || /\/sub\/[^/]+\/?$/.test(url.pathname)) {
    const [source, qrVendor] = await Promise.all([
      readFile(TEMPLATE_PATH, "utf8"),
      readFile(QR_VENDOR_PATH, "utf8"),
    ]);
    const fixture = fixtureByToken || fixtures[url.searchParams.get("fixture")] || fixtures.active;
    return send(res, 200, renderTemplate(source, fixture, qrVendor));
  }

  send(res, 404, "Not found", "text/plain; charset=utf-8");
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const server = createTestServer();
  server.listen(PORT, "0.0.0.0", () => {
    console.log(`Homa Ghost test server listening on ${PORT}`);
  });
}
