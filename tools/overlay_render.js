// overlay_render.js: docs/overlays/*.svg -> .pdf (US Letter, actual size)
// and .png (300 dpi sheet), plus -preview.png: the left overlay alone.
// Needs Node and Playwright with Chromium:  node tools/overlay_render.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, '..', 'docs', 'overlays');
const W_MM = 215.9, H_MM = 279.4;
// left overlay's box on the sheet in mm (x, y, w, h), bleed included
const PREVIEW = { 'acadia-5200': [47.5, 49.5, 56, 88], 'acadia-touchpad': [34.5, 49.5, 69, 107] };

(async () => {
  const browser = await chromium.launch();
  for (const name of ['acadia-5200', 'acadia-touchpad']) {
    const svg = fs.readFileSync(path.join(DIR, name + '.svg'), 'utf8');
    const html = '<!doctype html><html><head><style>@page{size:' + W_MM + 'mm ' + H_MM +
      'mm;margin:0}html,body{margin:0;padding:0}svg{display:block}</style></head><body>' +
      svg.replace(/^<\?xml[^>]*>\s*/, '') + '</body></html>';
    // PDF: vector, actual size
    let page = await browser.newPage();
    await page.setContent(html);
    await page.pdf({ path: path.join(DIR, name + '.pdf'), width: W_MM + 'mm', height: H_MM + 'mm',
                     printBackground: true, preferCSSPageSize: true });
    await page.close();
    // PNG: 300 dpi (CSS px are 96 dpi)
    const px = mm => Math.round(mm / 25.4 * 96);
    page = await browser.newPage({ viewport: { width: px(W_MM), height: px(H_MM) },
                                   deviceScaleFactor: 300 / 96 });
    await page.setContent(html);
    await page.screenshot({ path: path.join(DIR, name + '.png'), fullPage: false });
    // preview: the left overlay alone, for the README
    const box = PREVIEW[name];
    await page.screenshot({ path: path.join(DIR, name + '-preview.png'),
                            clip: { x: px(box[0]), y: px(box[1]), width: px(box[2]), height: px(box[3]) } });
    await page.close();
  }
  await browser.close();
})();
