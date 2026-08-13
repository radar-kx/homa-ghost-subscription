import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import axe from "axe-core";
import { HtmlValidate } from "html-validate";
import { JSDOM, VirtualConsole } from "jsdom";

import { createTestServer, fixtures, renderTemplate } from "./test-server.mjs";

const TESTS_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = path.dirname(TESTS_DIR);
const templateSource = await readFile(path.join(PROJECT_DIR, "index.html"), "utf8");
const qrVendor = await readFile(path.join(PROJECT_DIR, "vendor", "qrcode.js"), "utf8");
const localInstaller = await readFile(path.join(PROJECT_DIR, "install.sh"), "utf8");
const onlineInstaller = await readFile(path.join(PROJECT_DIR, "install-online.sh"), "utf8");

const userAgents = {
  Android: "Mozilla/5.0 (Linux; Android 16; Pixel 9) AppleWebKit/537.36 Chrome/140 Mobile Safari/537.36",
  iOS: "Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148",
  Windows: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140 Safari/537.36",
  macOS: "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_5) AppleWebKit/605.1.15 Safari/605.1.15",
  Linux: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/140 Safari/537.36",
};

function successFetch(url, options = {}) {
  const target = new URL(String(url), "https://panel.test");
  if (target.pathname.endsWith("/usage")) {
    const start = new Date(target.searchParams.get("start"));
    const day = Math.floor(start.getTime() / 86400000);
    const total = (1 + (Math.abs(day) % 5)) * 256 * 1024 ** 2;
    return Promise.resolve(new Response(JSON.stringify({
      username: fixtures.active.username,
      usages: [
        { node_id: null, node_name: "Master", used_traffic: total * 0.6 },
        { node_id: 1, node_name: "France", used_traffic: total * 0.4 },
      ],
    }), { status: 200, headers: { "content-type": "application/json" } }));
  }
  if (target.pathname.endsWith("/info")) {
    return Promise.resolve(new Response(JSON.stringify({
      username: fixtures.active.username,
      status: "active",
      used_traffic: 20 * 1024 ** 3,
      data_limit: 50 * 1024 ** 3,
      expire: fixtures.active.expire,
      data_limit_reset_strategy: "month",
      online_at: new Date().toISOString(),
      on_hold_expire_duration: null,
    }), { status: 200, headers: { "content-type": "application/json" } }));
  }
  if (target.pathname === "/__up" && options.method === "POST") {
    return Promise.resolve(new Response(JSON.stringify({ received: options.body?.byteLength || 0 }), {
      status: 200,
      headers: { "content-type": "application/json" },
    }));
  }
  if (target.pathname === "/__down") {
    const size = Math.min(Number(target.searchParams.get("bytes")) || 1, 5_000_000);
    return Promise.resolve(new Response(new Uint8Array(size), { status: 200 }));
  }
  return Promise.resolve(new Response("Not found", { status: 404 }));
}

async function waitFor(check, timeout = 4000) {
  const started = Date.now();
  while (Date.now() - started < timeout) {
    if (await check()) return;
    await new Promise((resolve) => setTimeout(resolve, 15));
  }
  throw new Error("Timed out waiting for page state");
}

async function createPage({
  fixture = fixtures.active,
  userAgent = userAgents.Android,
  fetchImpl = successFetch,
  seedStorage,
  prefersLight = false,
} = {}) {
  const errors = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on("jsdomError", (error) => errors.push(error));
  virtualConsole.on("error", (error) => errors.push(error));

  const html = renderTemplate(templateSource, fixture, qrVendor);
  const pageUrl = new URL(fixture.subscriptionUrl, "https://panel.test").href;
  const dom = new JSDOM(html, {
    url: pageUrl,
    runScripts: "dangerously",
    pretendToBeVisual: true,
    virtualConsole,
    beforeParse(window) {
      Object.defineProperty(window.navigator, "userAgent", { value: userAgent, configurable: true });
      Object.defineProperty(window, "isSecureContext", { value: true, configurable: true });
      Object.defineProperty(window.navigator, "clipboard", {
        value: { writeText: async (value) => { window.__copiedText = value; } },
        configurable: true,
      });
      window.matchMedia = () => ({
        matches: prefersLight,
        media: "(prefers-color-scheme: light)",
        addEventListener() {},
        removeEventListener() {},
      });
      window.fetch = fetchImpl;
      window.Response = Response;
      window.Headers = Headers;
      window.Request = Request;
      window.Element.prototype.scrollIntoView = () => {};
      window.document.execCommand = () => true;
      if (window.HTMLDialogElement) {
        window.HTMLDialogElement.prototype.showModal = function showModal() {
          this.setAttribute("open", "");
        };
        window.HTMLDialogElement.prototype.close = function close() {
          this.removeAttribute("open");
        };
      }
      if (seedStorage) seedStorage(window);
    },
  });

  await new Promise((resolve) => {
    if (dom.window.document.readyState === "complete") resolve();
    else dom.window.addEventListener("load", resolve, { once: true });
  });
  await waitFor(() => !dom.window.document.querySelector("#chartSource")?.textContent.startsWith("در حال دریافت"));
  return { dom, document: dom.window.document, window: dom.window, errors, html };
}

test("template uses official subscription fields and keeps QR code local", () => {
  for (const token of [
    "user.username",
    "user.status.value",
    "user.used_traffic",
    "user.data_limit",
    "user.expire",
    "user.data_limit_reset_strategy.value",
    "user.subscription_url",
    "user.online_at",
    "user.on_hold_expire_duration",
    "user.links",
  ]) {
    assert.match(templateSource, new RegExp(token.replaceAll(".", "\\.")));
  }
  assert.doesNotMatch(templateSource, /<script[^>]+src=/i);
  assert.match(templateSource, /subscription\/vendor\/qrcode\.js/);
});

test("responsive stylesheet covers desktop, tablet, mobile, and 320 px screens", () => {
  for (const breakpoint of [1080, 820, 640, 380]) {
    assert.match(templateSource, new RegExp(`@media\\(max-width:${breakpoint}px\\)`));
  }
  assert.match(templateSource, /overflow-x:hidden/);
  assert.match(templateSource, /--page:min\(100% - 18px,1240px\)/);
  assert.match(templateSource, /prefers-reduced-motion:reduce/);
  assert.match(templateSource, /mobile-dock/);
});

test("every account state renders without unresolved Jinja syntax", () => {
  for (const [name, fixture] of Object.entries(fixtures)) {
    const html = renderTemplate(templateSource, fixture, qrVendor);
    assert.doesNotMatch(html, /{{|{%/, `${name} left unresolved Jinja syntax`);
    assert.match(html, new RegExp(fixture.username));
  }
});

test("active account initializes account data, QR, clients, configs, and chart", async () => {
  const page = await createPage();
  assert.equal(page.document.querySelector("#statusText").textContent, "اشتراک فعال");
  assert.match(page.document.querySelector("#usagePercent").textContent, /۳۶/);
  assert.equal(page.document.querySelectorAll("#mainQr svg").length, 1);
  assert.equal(page.document.querySelectorAll(".os-tab").length, 5);
  assert.equal(page.window.HomaGhost.CLIENTS.length, 9);
  assert.equal(page.document.querySelectorAll(".client-chip").length, 4);
  assert.equal(page.document.querySelector("#guideName").textContent, "Hiddify");
  assert.equal(page.document.querySelectorAll(".guide-step").length, 4);
  assert.equal(page.document.querySelectorAll(".config-row").length, 2);
  assert.equal(page.document.querySelectorAll("#chartWrap .point").length, 7);
  assert.match(page.document.querySelector("#chartSource").textContent, /داده واقعی مرزبان/);
  assert.equal(page.document.querySelector("#topNode").textContent, "Master");
  assert.equal(page.errors.length, 0);
  page.dom.window.close();
});

test("operating-system detection and recommendation catalog are correct", async () => {
  const page = await createPage({ userAgent: userAgents.macOS });
  for (const os of Object.keys(userAgents)) {
    assert.equal(page.window.HomaGhost.detectOS(userAgents[os]), os);
  }
  assert.equal(page.document.querySelector("#guideName").textContent, "Hiddify");
  assert.match(page.document.querySelector("#quickClient").textContent, /Hiddify/);

  const coverage = Object.fromEntries(Object.keys(userAgents).map((os) => [
    os,
    page.window.HomaGhost.CLIENTS.filter((client) => client.os.includes(os)).length,
  ]));
  assert.deepEqual(coverage, { Android: 4, iOS: 5, Windows: 4, macOS: 4, Linux: 5 });
  page.dom.window.close();
});

test("limited, expired, disabled, unlimited, and on-hold states are accurate", async () => {
  const expectations = [
    [fixtures.limited, "حجم تمام شده", "۱۰۰٪"],
    [fixtures.expired, "اشتراک منقضی", "۰ روز"],
    [fixtures.disabled, "اشتراک غیرفعال", null],
    [fixtures.unlimited, "اشتراک فعال", "∞"],
    [fixtures.on_hold, "در انتظار شروع", "۳۰ روز پس از شروع"],
  ];

  for (const [fixture, status, secondary] of expectations) {
    const page = await createPage({ fixture });
    assert.equal(page.document.querySelector("#statusText").textContent, status);
    if (fixture === fixtures.limited) assert.equal(page.document.querySelector("#usagePercent").textContent, secondary);
    if (fixture === fixtures.expired || fixture === fixtures.on_hold) assert.equal(page.document.querySelector("#daysLeft").textContent, secondary);
    if (fixture === fixtures.unlimited) {
      assert.equal(page.document.querySelector("#usagePercent").textContent, secondary);
      assert.match(page.document.querySelector("#remainingText").textContent, /نامحدود/);
    }
    page.dom.window.close();
  }
});

test("tutorial center supports mouse and RTL keyboard navigation", async () => {
  const page = await createPage();
  page.document.querySelector('[data-client="v2box"]').click();
  assert.equal(page.document.querySelector("#guideName").textContent, "V2Box");
  assert.match(page.document.querySelector("#guideDownload").href, /play\.google\.com\/store\/apps\/details\?id=dev\.hexasoftware\.v2box/);
  assert.match(page.document.querySelector("#guideTitle").textContent, /اندروید/);

  const android = page.document.querySelector('[data-os="Android"]');
  android.focus();
  android.dispatchEvent(new page.window.KeyboardEvent("keydown", { key: "ArrowLeft", bubbles: true }));
  const ios = page.document.querySelector('[data-os="iOS"]');
  assert.equal(ios.getAttribute("aria-selected"), "true");
  assert.equal(ios.tabIndex, 0);
  assert.equal(page.document.activeElement, ios);
  assert.equal(page.document.querySelector("#guidePanel").getAttribute("aria-labelledby"), ios.id);

  page.document.querySelector('[data-client="v2box"]').click();
  assert.equal(page.document.querySelector("#guideName").textContent, "V2Box");
  assert.match(page.document.querySelector("#guideDownload").href, /apps\.apple\.com/);
  assert.match(page.document.querySelector("#guideTitle").textContent, /آیفون و آیپد/);

  const streisand = page.document.querySelector('[data-client="streisand"]');
  streisand.click();
  assert.equal(page.document.querySelector("#guideName").textContent, "Streisand");
  assert.equal(page.document.querySelector('[data-client="streisand"]').getAttribute("aria-pressed"), "true");
  assert.equal(page.document.querySelectorAll(".guide-step").length, 4);
  assert.match(page.document.querySelector("#guideDownload").href, /apps\.apple\.com/);
  page.dom.window.close();
});

test("one-click import schemes and Clash Meta route are generated correctly", async () => {
  const page = await createPage();
  const clients = Object.fromEntries(page.window.HomaGhost.CLIENTS.map((client) => [client.id, client]));
  assert.match(page.window.HomaGhost.deepLink(clients.hiddify), /^hiddify:\/\/import\//);
  assert.match(page.window.HomaGhost.deepLink(clients.v2rayng), /^v2rayng:\/\/install-config\?url=/);
  assert.match(page.window.HomaGhost.deepLink(clients.happ), /^happ:\/\/add\//);
  assert.match(page.window.HomaGhost.deepLink(clients.streisand), /^streisand:\/\/import\//);
  assert.match(page.window.HomaGhost.deepLink(clients.v2box), /^v2box:\/\/install-sub\?/);
  assert.match(page.window.HomaGhost.deepLink(clients.shadowrocket), /^sub:\/\//);
  assert.match(page.window.HomaGhost.deepLink(clients.clashverge), /^clash:\/\/install-config\?/);
  assert.match(decodeURIComponent(page.window.HomaGhost.deepLink(clients.clashverge)), /\/sub\/test-token\/clash-meta/);
  assert.equal(page.window.HomaGhost.deepLink(clients.v2rayn), "");
  assert.equal(page.window.HomaGhost.deepLink(clients.v2raya), "");
  page.dom.window.close();
});

test("usage chart supports 7, 14, and 30 day ranges", async () => {
  const page = await createPage();
  for (const count of [7, 14, 30]) {
    await page.window.HomaGhost.loadChart(count);
    assert.equal(page.document.querySelectorAll("#chartWrap .point").length, count);
    assert.match(page.document.querySelector("#chartSource").textContent, /داده واقعی مرزبان/);
  }
  page.dom.window.close();
});

test("usage chart falls back safely to local history when /usage fails", async () => {
  const failingUsage = (url, options) => {
    const target = new URL(String(url), "https://panel.test");
    if (target.pathname.endsWith("/usage")) return Promise.resolve(new Response("Unavailable", { status: 404 }));
    return successFetch(url, options);
  };
  const page = await createPage({
    fetchImpl: failingUsage,
    seedStorage(window) {
      const date = new Date();
      date.setDate(date.getDate() - 1);
      const pad = (number) => String(number).padStart(2, "0");
      const yesterday = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
      window.localStorage.setItem(
        `homa-usage-v3-${window.location.host}-${fixtures.active.username}`,
        JSON.stringify([{ date: yesterday, total: fixtures.active.used - 512 * 1024 ** 2 }]),
      );
    },
  });
  assert.match(page.document.querySelector("#chartSource").textContent, /تاریخچه محلی/);
  assert.notEqual(page.document.querySelector("#chartTotal").textContent, "—");
  assert.equal(page.errors.length, 0);
  page.dom.window.close();
});

test("speed test reports download, upload, ping, and jitter and handles failure", async () => {
  const success = await createPage();
  await success.window.HomaGhost.runSpeed();
  assert.equal(success.document.querySelector("#speedState").textContent, "تکمیل شد");
  for (const id of ["downloadSpeed", "uploadSpeed", "pingSpeed", "jitterSpeed"]) {
    assert.notEqual(success.document.querySelector(`#${id}`).textContent, "—");
  }
  assert.equal(success.document.querySelector("#runSpeed").disabled, false);
  success.dom.window.close();

  const failed = await createPage({
    fetchImpl: (url, options) => {
      const target = new URL(String(url), "https://panel.test");
      if (target.pathname.endsWith("/usage")) return successFetch(url, options);
      return Promise.resolve(new Response("Bad gateway", { status: 502 }));
    },
  });
  await failed.window.HomaGhost.runSpeed();
  assert.equal(failed.document.querySelector("#speedState").textContent, "خطای شبکه");
  assert.equal(failed.document.querySelector("#runSpeed").disabled, false);
  failed.dom.window.close();
});

test("refresh, clipboard, config QR, and persistent theme controls work", async () => {
  const page = await createPage({ prefersLight: true });
  assert.equal(page.document.documentElement.dataset.theme, "light");
  page.document.querySelector("#themeButton").click();
  assert.equal(page.document.documentElement.dataset.theme, "dark");
  assert.equal(page.window.localStorage.getItem("homa-theme-v2"), "dark");

  await page.window.HomaGhost.refreshAccount();
  assert.match(page.document.querySelector("#usagePercent").textContent, /۴۰/);
  assert.match(page.document.querySelector("#lastSync").textContent, /همین حالا/);

  page.document.querySelector('[data-copy-index="0"]').click();
  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.equal(page.window.__copiedText, fixtures.active.links[0]);

  page.document.querySelector('[data-qr-index="0"]').click();
  assert.equal(page.document.querySelector("#qrDialog").hasAttribute("open"), true);
  assert.equal(page.document.querySelectorAll("#modalQr svg").length, 1);
  page.document.querySelector("#closeQr").click();
  assert.equal(page.document.querySelector("#qrDialog").hasAttribute("open"), false);
  page.dom.window.close();
});

test("rendered HTML passes structural validation", async () => {
  const html = renderTemplate(templateSource, fixtures.active, qrVendor);
  const validator = new HtmlValidate({
    extends: ["html-validate:recommended"],
    rules: {
      "attr-quotes": "off",
      "doctype-style": "off",
      "no-inline-style": "off",
      "no-raw-characters": "off",
      "prefer-native-element": "off",
      "svg-focusable": "off",
      "wcag/h30": "off",
    },
  });
  const report = await validator.validateString(html);
  const messages = report.results
    .flatMap((result) => result.messages)
    .map((message) => `${message.line}:${message.column} ${message.ruleId} ${message.message}`)
    .join("\n");
  assert.equal(report.valid, true, messages);
});

test("page has no critical automated accessibility violations", async () => {
  const page = await createPage();
  page.window.eval(axe.source);
  const result = await page.window.axe.run(page.document, {
    rules: { "color-contrast": { enabled: false } },
  });
  const critical = result.violations.filter((item) => item.impact === "critical");
  assert.equal(critical.length, 0, critical.map((item) => item.id).join(", "));
  page.dom.window.close();
});

test("installer shell syntax is valid", () => {
  execFileSync("bash", ["-n", path.join(PROJECT_DIR, "install.sh")]);
  assert.match(localInstaller, /HOMA_GHOST_TEMPLATE_DIR/);
  assert.match(localInstaller, /HOMA_GHOST_BACKUP_ROOT/);
});

test("one-line installer verifies and hands off the official v2.2.0 package", () => {
  execFileSync("bash", ["-n", path.join(PROJECT_DIR, "install-online.sh")]);
  assert.match(onlineInstaller, /VERSION="\$\{HOMA_GHOST_VERSION:-2\.2\.0\}"/);
  assert.match(onlineInstaller, /radar-kx\/homa-ghost-subscription/);
  assert.match(onlineInstaller, /sha256sum -c/);
  assert.match(onlineInstaller, /unzip -q/);
  assert.match(onlineInstaller, /bash "\$INSTALLER"/);
});

test("HTTP smoke server serves every state and auxiliary endpoint", async () => {
  const server = createTestServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const { port } = server.address();
  const origin = `http://127.0.0.1:${port}`;

  try {
    for (const fixture of Object.values(fixtures)) {
      const route = new URL(fixture.subscriptionUrl, origin).pathname;
      const response = await fetch(`${origin}${route}`, { headers: { Accept: "text/html" } });
      const html = await response.text();
      assert.equal(response.status, 200);
      assert.match(html, new RegExp(fixture.username));
      assert.doesNotMatch(html, /{{|{%/);
    }

    const usage = await fetch(`${origin}/sub/test-token/usage?start=2026-07-29T00%3A00%3A00%2B04%3A00&end=2026-07-30T00%3A00%3A00%2B04%3A00`);
    assert.equal(usage.status, 200);
    assert.equal(Array.isArray((await usage.json()).usages), true);

    const info = await fetch(`${origin}/sub/test-token/info`);
    assert.equal(info.status, 200);
    assert.equal((await info.json()).username, fixtures.active.username);

    const download = await fetch(`${origin}/__down?bytes=5000000`);
    assert.equal(download.status, 200);
    assert.equal((await download.arrayBuffer()).byteLength, 5_000_000);

    const upload = await fetch(`${origin}/__up`, { method: "POST", body: new Uint8Array(128_000) });
    assert.equal(upload.status, 200);
    assert.equal((await upload.json()).received, 128_000);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
