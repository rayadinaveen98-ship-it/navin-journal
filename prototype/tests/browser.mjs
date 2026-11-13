/**
 * Stage 3 Chromium UX review (design-only; no persistent diary).
 * Run: cd prototype && npm install && npx playwright install chromium && node tests/browser.mjs
 */
import assert from 'node:assert/strict';
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const url=pathToFileURL(path.join(root,'stage3-ux-preview.html')).href;
const out=path.join(root,'artifacts');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true});
const sizes=[['phone-small',360,800],['phone-large',430,932],['tablet-portrait',768,1024],['tablet-landscape',1024,768]];
let checks=0;
function verify(condition,label){assert.ok(condition,label);checks++;console.log('PASS '+label)}
try{
 for(const [name,width,height] of sizes){
  const page=await browser.newPage({viewport:{width,height},deviceScaleFactor:1});
  page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(url);
  verify(await page.locator('[data-action="start"]').count()===1,name+' welcome');
  await page.screenshot({path:path.join(out,name+'-welcome.png'),fullPage:true});
  await page.locator('[data-action="start"]').click();
  verify(await page.getByText('Your first journal.').count()>0,name+' setup');
  await page.locator('[data-action="createVault"]').click();
  verify(await page.locator('.hero h1').textContent()==='Your pages, your pace.',name+' Today');
  await page.screenshot({path:path.join(out,name+'-today.png'),fullPage:true});
  let overflow=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  verify(overflow<=2,name+' Today horizontal overflow '+overflow);
  await page.locator('[data-action="write"]:visible').first().click();
  const area=page.locator('#draftBody');
  verify(await area.isVisible(),name+' Writing Studio visible');
  verify(await area.evaluate(el=>document.activeElement===el),name+' editor focus');
  await page.locator('#draftTitle').fill('A private thought');
  await area.fill(('This is a sample entry during a browser design review.\n').repeat(9));
  verify(await area.evaluate(el=>el.scrollHeight<=el.clientHeight+3),name+' writing canvas does not scroll internally');
  if(width<760)verify(!(await page.locator('.mobile-nav').isVisible()),name+' mobile navigation hidden while writing');
  await page.screenshot({path:path.join(out,name+'-writing.png'),fullPage:true});
  overflow=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  verify(overflow<=2,name+' editor horizontal overflow '+overflow);
  await page.locator('[data-action="closeEditor"]').first().click();
  await page.locator('[data-view="journals"]:visible').last().click();
  await page.locator('[data-journal="Travel"]').click();
  await page.locator('[data-action="write"]:visible').first().click();
  verify((await page.locator('.editor-head').textContent()).includes('Travel'),name+' journal context');
  await page.locator('[data-action="closeEditor"]').first().click();
  await page.locator('[data-view="memories"]:visible').last().click();
  await page.locator('[data-memory="gallery"]').click();
  await page.screenshot({path:path.join(out,name+'-memories.png'),fullPage:true});
  await page.locator('[data-entry="1"]').first().click();
  verify(await page.locator('.reader h1').textContent()==='The trip I’ll always remember',name+' reader');
  await page.screenshot({path:path.join(out,name+'-reader.png'),fullPage:true});
  verify((await page.locator('.reader-siblings').isVisible())===(width>=900),name+' reader layout');
  await page.locator('[data-action="goBack"]').first().click();
  verify(await page.locator('.memory-grid').count()===1,name+' Back from Reader');
  await page.locator('[data-view="discover"]:visible').last().click();
  await page.locator('#journalSearch').fill('trip');
  verify(await page.locator('#searchResults .entry').count()===1,name+' search matches');
  await page.locator('#journalSearch').fill('nothingmatcheswhatevers');
  verify((await page.locator('#searchResults').textContent()).includes('No entries matched'),name+' empty search');
  await page.locator('[data-action="theme"]').first().click();
  verify(await page.locator('body').getAttribute('data-theme')==='dark',name+' dark theme');
  await page.screenshot({path:path.join(out,name+'-dark.png'),fullPage:true});
  await page.locator('[data-view="settings"]:visible').last().click();
  await page.locator('[data-action="backup"]').click();
  await page.locator('[data-backup-state="failed"]').click();
  verify((await page.locator('main').textContent()).includes('Verification failed'),name+' backup failure review');
  await page.locator('[data-action="restoreFail"]').click();
  verify(await page.locator('[role="dialog"]').isVisible(),name+' restore rejection modal');
  verify(errors.length===0,name+' no page errors '+errors.join('; '));
  await page.close();
 }
 console.log('SUCCESS: '+checks+' Chromium checks. Screenshots in prototype/artifacts/');
}finally{await browser.close();}
