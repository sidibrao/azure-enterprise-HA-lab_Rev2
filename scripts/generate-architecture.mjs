import fs from "node:fs";
import path from "node:path";

const mode = process.argv[2] ?? "rev1";
const outDir = process.argv[3] ?? "docs/diagrams";
const palette = {
  bg: "#f8fafc", ink: "#172554", muted: "#475569", azure: "#0078d4",
  hub: "#dbeafe", spoke: "#dcfce7", security: "#fee2e2", ingress: "#f3e8ff",
  governance: "#fef3c7", white: "#ffffff", line: "#64748b",
};

const rev1 = {
  title: "Azure Enterprise Landing Zone — Rev1",
  subtitle: "Private workloads • Centralized egress • Firewall DNAT • Hub-and-spoke",
  boxes: [
    [40, 100, 1320, 680, "Azure Sandbox Subscription", palette.white, "subscription"],
    [80, 155, 480, 555, "Hub VNet  10.1.0.0/16", palette.hub, "hub"],
    [600, 155, 720, 555, "ERP Spoke VNet  10.2.0.0/16", palette.spoke, "spoke"],
    [110, 225, 420, 175, "Azure Firewall Basic\nPrivate IP  10.1.0.4\nUbuntu egress: HTTP 80 + HTTPS 443", palette.security, "firewall"],
    [110, 435, 195, 120, "Firewall Subnet\n10.1.0.0/26", palette.white, "fwsubnet"],
    [335, 435, 195, 120, "Management Subnet\n10.1.1.0/26", palette.white, "mgmtsubnet"],
    [110, 585, 420, 90, "Log Analytics\nFirewall diagnostics • 30-day retention", palette.governance, "logs"],
    [635, 225, 300, 170, "ERP Subnet  10.2.1.0/24\n\nERP Test VM\n10.2.1.10 • Private only", palette.white, "erp"],
    [980, 225, 300, 170, "Web Subnet  10.2.2.0/24\n\nNginx Web VM\n10.2.2.10 • Private only", palette.white, "web"],
    [635, 445, 645, 95, "UDR on workload subnets\n0.0.0.0/0  →  Virtual Appliance 10.1.0.4", palette.governance, "udr"],
    [635, 585, 300, 90, "NSGs\nERP isolation • Web TCP 80", palette.white, "nsg"],
    [980, 585, 300, 90, "Firewall DNAT\nPublic IP:80 → 10.2.2.10:80", palette.ingress, "dnat"],
    [1050, 30, 270, 70, "Internet Client\nHTTP to Firewall Public IP", palette.ingress, "internet"],
  ],
  arrows: [
    [1180, 100, 1180, 225, "1  HTTP :80", palette.azure],
    [980, 630, 530, 315, "2  DNAT + peering", palette.azure],
    [980, 480, 530, 330, "3  Forced egress", "#dc2626"],
    [320, 400, 320, 585, "4  Diagnostics", "#d97706"],
    [560, 330, 635, 330, "Bidirectional peering", palette.azure],
  ],
  notes: ["Public ingress", "Security boundary", "Private workloads", "Governance / routing"],
};

const rev2 = {
  title: "Azure Enterprise HA Landing Zone — Rev2 Deployed",
  subtitle: "Shared hub • Corp HA web • Online WAF application • Private SQL • Public/private DNS",
  boxes: [
    [25, 95, 1350, 690, "Sandbox Subscription — ALZ boundaries modeled with networks and tags", palette.white, "tenant"],
    [50, 135, 365, 600, "PLATFORM / CONNECTIVITY\nHub VNet  10.1.0.0/16", palette.hub, "hub"],
    [75, 225, 315, 115, "Azure Firewall Basic\nPrivate 10.1.0.4\nLab 1 public DNS + DNAT", palette.security, "firewall"],
    [75, 380, 315, 95, "Central Log Analytics\nFirewall + WAF diagnostics", palette.governance, "monitor"],
    [75, 515, 315, 125, "Private DNS\nhub.contoso.internal\ncorp.contoso.internal\nonline.contoso.internal", palette.white, "dns"],
    [445, 135, 440, 600, "CORP LANDING ZONE — LAB 1\nERP Spoke  10.2.0.0/16", palette.spoke, "corp"],
    [475, 225, 380, 100, "Internal Standard LB  10.2.2.20\nFirewall DNAT target • /health", palette.hub, "corp-ilb"],
    [475, 365, 180, 125, "ZONE 1\nWeb VM\n10.2.2.11\nPrivate only", palette.white, "corp-z1"],
    [675, 365, 180, 125, "ZONE 2\nWeb VM\n10.2.2.12\nPrivate only", palette.white, "corp-z2"],
    [475, 535, 380, 105, "ERP VM 10.2.1.10\nUDR 0.0.0.0/0 → Firewall\nPublic/private DNS", palette.governance, "erp"],
    [915, 135, 430, 600, "ONLINE LANDING ZONE — LAB 4\nOnline Spoke  10.3.0.0/16", palette.spoke, "online"],
    [945, 205, 370, 95, "Application Gateway WAF_v2\nZones 1 + 2 • OWASP 3.2\nPublic Azure DNS", palette.ingress, "waf"],
    [945, 335, 175, 110, "ZONE 1\nFrontend .11\nAPI .11\nPrivate only", palette.white, "online-z1"],
    [1140, 335, 175, 110, "ZONE 2\nFrontend .12\nAPI .12\nPrivate only", palette.white, "online-z2"],
    [945, 480, 370, 80, "Internal API LB  10.3.2.20:8000\napi.online.contoso.internal", palette.hub, "api-ilb"],
    [945, 595, 370, 95, "Azure SQL Basic + Private Endpoint\n10.3.3.4 • Public access disabled", palette.governance, "sql"],
    [1050, 20, 295, 65, "Internet + Public DNS\nLab 1 and WAF endpoints", palette.ingress, "internet"],
  ],
  arrows: [
    [1125, 85, 1125, 205, "WAF ingress", palette.azure],
    [1050, 85, 230, 225, "Lab 1 ingress", palette.azure],
    [390, 280, 475, 275, "DNAT + peering", palette.azure],
    [885, 280, 945, 250, "Hub peering", palette.azure],
    [1125, 300, 1035, 335, "Frontend Z1", "#16a34a"],
    [1160, 300, 1225, 335, "Frontend Z2", "#16a34a"],
    [1035, 445, 1050, 480, "API traffic", "#16a34a"],
    [1225, 445, 1210, 480, "API traffic", "#16a34a"],
    [1130, 560, 1130, 595, "Private SQL", "#d97706"],
    [885, 675, 390, 300, "Forced egress", "#dc2626"],
  ],
  notes: ["WAF Layer 7 ingress", "Firewall/NSG security", "Two zonal application tiers", "Private PaaS + DNS"],
};

const design = mode === "rev2" ? rev2 : rev1;
const esc = (s) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const lines = (s) => s.split("\n");
let elements = [];
let seed = 100;
const base = (type, x, y, w, h, id) => ({
  id, type, x, y, width: w, height: h, angle: 0, strokeColor: palette.ink,
  backgroundColor: "transparent", fillStyle: "solid", strokeWidth: 2,
  strokeStyle: "solid", roughness: 1, opacity: 100, groupIds: [], frameId: null,
  index: `a${seed++}`, roundness: type === "rectangle" ? { type: 3 } : null,
  seed: seed * 7919, version: 1, versionNonce: seed * 3571, isDeleted: false,
  boundElements: [], updated: 1, link: null, locked: false,
});
const addText = (x, y, w, h, text, size = 18, color = palette.ink, id = `text-${seed}`) => {
  elements.push({ ...base("text", x, y, w, h, id), strokeColor: color, text,
    fontSize: size, fontFamily: 2, textAlign: "center", verticalAlign: "middle",
    containerId: null, originalText: text, autoResize: true, lineHeight: 1.25 });
};
addText(40, 15, 900, 45, design.title, 30, palette.ink, "title");
addText(40, 58, 900, 28, design.subtitle, 16, palette.muted, "subtitle");
for (const [x, y, w, h, label, fill, id] of design.boxes) {
  elements.push({ ...base("rectangle", x, y, w, h, id), backgroundColor: fill });
  addText(x + 12, y + 8, w - 24, h - 16, label, h < 60 ? 15 : 17, palette.ink, `${id}-label`);
}
for (const [x1, y1, x2, y2, label, color] of design.arrows) {
  const id = `arrow-${seed}`;
  elements.push({ ...base("arrow", x1, y1, x2 - x1, y2 - y1, id), strokeColor: color,
    points: [[0, 0], [x2 - x1, y2 - y1]], lastCommittedPoint: null,
    startBinding: null, endBinding: null, startArrowhead: null, endArrowhead: "arrow",
    elbowed: false });
  addText((x1 + x2) / 2 - 85, (y1 + y2) / 2 - 14, 170, 28, label, 13, color, `${id}-label`);
}

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, `architecture-${mode}.excalidraw`), JSON.stringify({
  type: "excalidraw", version: 2, source: "https://excalidraw.com", elements,
  appState: { gridSize: null, viewBackgroundColor: palette.bg }, files: {},
}, null, 2));

const svgBox = ([x, y, w, h, label, fill]) => {
  const text = lines(label).map((line, i, all) => `<tspan x="${x + w / 2}" dy="${i ? 23 : -(all.length - 1) * 11}">${esc(line)}</tspan>`).join("");
  return `<g><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="14" fill="${fill}" stroke="${palette.ink}" stroke-width="2"/><text x="${x + w / 2}" y="${y + h / 2}" text-anchor="middle" dominant-baseline="middle" fill="${palette.ink}" font-size="16" font-family="Inter,Segoe UI,sans-serif" font-weight="600">${text}</text></g>`;
};
const svgArrow = ([x1, y1, x2, y2, label, color]) => `<g><path d="M ${x1} ${y1} L ${x2} ${y2}" stroke="${color}" stroke-width="3" fill="none" marker-end="url(#arrow-${color.slice(1)})"/><rect x="${(x1 + x2) / 2 - 72}" y="${(y1 + y2) / 2 - 13}" width="144" height="26" rx="8" fill="${palette.bg}" opacity=".94"/><text x="${(x1 + x2) / 2}" y="${(y1 + y2) / 2 + 5}" text-anchor="middle" fill="${color}" font-size="12" font-family="Inter,Segoe UI,sans-serif" font-weight="700">${esc(label)}</text></g>`;
const markerColors = [...new Set(design.arrows.map((a) => a[5]))];
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="850" viewBox="0 0 1400 850"><defs>${markerColors.map((c) => `<marker id="arrow-${c.slice(1)}" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto"><path d="M0,0 L0,6 L9,3 z" fill="${c}"/></marker>`).join("")}<filter id="shadow"><feDropShadow dx="0" dy="4" stdDeviation="6" flood-opacity=".12"/></filter></defs><rect width="1400" height="850" fill="${palette.bg}"/><text x="40" y="48" fill="${palette.ink}" font-size="30" font-family="Inter,Segoe UI,sans-serif" font-weight="800">${esc(design.title)}</text><text x="40" y="77" fill="${palette.muted}" font-size="16" font-family="Inter,Segoe UI,sans-serif">${esc(design.subtitle)}</text><g filter="url(#shadow)">${design.boxes.map(svgBox).join("")}</g>${design.arrows.map(svgArrow).join("")}<g transform="translate(40 815)">${design.notes.map((n, i) => `<circle cx="${i * 315 + 8}" cy="0" r="7" fill="${[palette.ingress, palette.security, palette.spoke, palette.governance][i]}" stroke="${palette.ink}"/><text x="${i * 315 + 22}" y="5" fill="${palette.muted}" font-size="13" font-family="Inter,Segoe UI,sans-serif">${esc(n)}</text>`).join("")}</g></svg>`;
fs.writeFileSync(path.join(outDir, `architecture-${mode}.svg`), svg);
console.log(`Generated ${mode} Excalidraw and SVG in ${outDir}`);
