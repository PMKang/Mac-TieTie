import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const repository = process.env.GITHUB_REPOSITORY;
const token = process.env.GITHUB_TOKEN;
const output = resolve(process.cwd(), "assets/star-history.svg");

if (!repository || !token) {
  throw new Error("GITHUB_REPOSITORY and GITHUB_TOKEN are required.");
}

const requestHeaders = {
  Accept: "application/vnd.github.star+json",
  Authorization: `Bearer ${token}`,
  "X-GitHub-Api-Version": "2026-03-10",
  "User-Agent": "akang-star-history",
};

async function fetchStars() {
  const stars = [];
  let page = 1;

  while (true) {
    const response = await fetch(`https://api.github.com/repos/${repository}/stargazers?per_page=100&page=${page}`, {
      headers: requestHeaders,
    });
    if (!response.ok) throw new Error(`GitHub API returned ${response.status}: ${await response.text()}`);

    const batch = await response.json();
    stars.push(...batch.map((entry) => entry.starred_at).filter(Boolean));
    if (batch.length < 100) return stars;
    page += 1;
  }
}

function escapeXml(value) {
  return value.replace(/[&<>"']/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;" })[character]);
}

function buildSvg(starTimestamps) {
  const dates = starTimestamps.map((value) => new Date(value)).sort((a, b) => a - b);
  const today = new Date();
  const firstDate = dates[0] ?? today;
  const start = new Date(firstDate.getFullYear(), firstDate.getMonth(), 1);
  const end = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const days = Math.max(1, Math.round((end - start) / 86_400_000));
  const width = 880;
  const height = 300;
  const padding = { top: 58, right: 46, bottom: 54, left: 62 };
  const chartWidth = width - padding.left - padding.right;
  const chartHeight = height - padding.top - padding.bottom;
  const totalStars = dates.length;
  const maxStars = Math.max(1, totalStars);
  let cursor = 0;
  const points = [];

  for (let index = 0; index <= Math.min(days, 180); index += 1) {
    const ratio = index / Math.min(days, 180);
    const day = new Date(start.getTime() + ratio * days * 86_400_000);
    while (cursor < dates.length && dates[cursor] <= day) cursor += 1;
    const x = padding.left + ratio * chartWidth;
    const y = padding.top + chartHeight - (cursor / maxStars) * chartHeight;
    points.push([x, y]);
  }

  const line = points.map(([x, y], index) => `${index === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`).join(" ");
  const area = `${line} L${(padding.left + chartWidth).toFixed(1)},${padding.top + chartHeight} L${padding.left},${padding.top + chartHeight} Z`;
  const labels = [0, 0.5, 1].map((ratio) => {
    const value = Math.round(maxStars * ratio);
    const y = padding.top + chartHeight - ratio * chartHeight;
    return `<g><line x1="${padding.left}" x2="${padding.left + chartWidth}" y1="${y}" y2="${y}" class="grid"/><text x="${padding.left - 12}" y="${y + 4}" class="axis" text-anchor="end">${value}</text></g>`;
  }).join("");
  const updated = new Intl.DateTimeFormat("zh-CN", { year: "numeric", month: "short", day: "numeric", timeZone: "Asia/Shanghai" }).format(today);

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="title description">
  <title id="title">${escapeXml(repository)} Star 增长趋势</title>
  <desc id="description">截至 ${escapeXml(updated)}，仓库共有 ${totalStars} 个 Star。</desc>
  <style>
    .title { font: 700 22px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; fill: #1f2937; }
    .subtitle, .axis { font: 13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; fill: #6b7280; }
    .grid { stroke: #d1d5db; stroke-width: 1; stroke-dasharray: 3 5; }
  </style>
  <rect width="${width}" height="${height}" rx="18" fill="#fffdf5" stroke="#d6d3d1"/>
  <text x="${padding.left}" y="34" class="title">Star 增长趋势</text>
  <text x="${width - padding.right}" y="34" class="subtitle" text-anchor="end">${totalStars} Stars · 更新于 ${escapeXml(updated)}</text>
  ${labels}
  <path d="${area}" fill="#fbbf24" fill-opacity="0.18"/>
  <path d="${line}" fill="none" stroke="#b45309" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="${line}" transform="translate(0,1.8)" fill="none" stroke="#f59e0b" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" opacity="0.9"/>
  <text x="${padding.left}" y="${height - 22}" class="axis">${escapeXml(new Intl.DateTimeFormat("zh-CN", { year: "numeric", month: "short", timeZone: "Asia/Shanghai" }).format(start))}</text>
  <text x="${width - padding.right}" y="${height - 22}" class="axis" text-anchor="end">${escapeXml(new Intl.DateTimeFormat("zh-CN", { year: "numeric", month: "short", timeZone: "Asia/Shanghai" }).format(end))}</text>
</svg>`;
}

const stars = await fetchStars();
await mkdir(dirname(output), { recursive: true });
await writeFile(output, buildSvg(stars));
console.log(`Generated ${output} from ${stars.length} stars.`);
