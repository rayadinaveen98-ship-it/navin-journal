/**
 * Selected Folded Page review. Headless-browser checks for a DESIGN-ONLY prototype.
 * No Android launcher, app persistence, encryption or native icon rendering is tested here.
 */
import assert from 'node:assert/strict';
import path from 'node:path';
import {mkdir} from 'node:fs/promises';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {chromium} from 'playwright';

const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const appURL=pathToFileURL(path.join(root,'stage3-ux-preview.html')).href;
const iconURL=pathToFileURL(path.join(root,'brand','adaptive-preview.html')).href;
const out=path.join(root,'artifacts');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true});
const viewports=[['phone',430,932],['tablet',1024,768]];
let passed=0;
const check=(condition,label)=>{assert.ok(condition,label);console.log('PASS '+label);passed++;};
const imageReady=async image=>image.evaluate(async img=>{try{if(typeof img.decode==='function')await img.decode()}catch{}return img.complete&&img.naturalWidth>0});
try{
 for(const [name,width,height] of viewports){
  const page=await browser.newPage({viewport:{width,height}});
  page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(appURL);
  check(await page.locator('.welcome-brand .brand-symbol').count()===1,name+' welcome has selected identity');
  check(await imageReady(page.locator('.welcome-brand .brand-symbol')),name+' welcome icon SVG loads');
  check((await page.locator('.welcome-brand').textContent()).includes('Navin Journal'),name+' welcome wordmark remains provisional');
  await page.screenshot({path:path.join(out,name+'-approved-welcome-light.png'),fullPage:true});
  await page.locator('[data-action="theme"]').click();
  check((await page.locator('.welcome-brand .brand-symbol').getAttribute('src')).includes('folded-page-dark.svg'),name+' dark mark active on Welcome');
  check(await imageReady(page.locator('.welcome-brand .brand-symbol')),name+' dark vector loads');
  await page.screenshot({path:path.join(out,name+'-approved-welcome-dark.png'),fullPage:true});
  await page.locator('[data-action="start"]').click();
  check(await imageReady(page.locator('.welcome-brand .brand-symbol')),name+' setup carries selected mark');
  await page.locator('[data-action="createVault"]').click();
  const expected=width<761?'.brand-symbol-mini:visible':'.brand-symbol-sidebar:visible';
  check(await page.locator(expected).count()===1,name+' chosen mark visible on Today');
  check(await imageReady(page.locator(expected)),name+' main header SVG loaded');
  await page.screenshot({path:path.join(out,name+'-approved-today-dark.png'),fullPage:true});
  await page.locator('[data-action="write"]:visible').first().click();
  check(await page.locator('#draftBody').isVisible(),name+' Writer still works after branding');
  if(width<761)check(!(await page.locator('.brand-symbol-mini').isVisible()),name+' editor remains logo-free on compact phone');
  await page.screenshot({path:path.join(out,name+'-approved-writer-dark.png'),fullPage:true});
  check(errors.length===0,name+' no uncaught errors');
  await page.close();
 }
 const page=await browser.newPage({viewport:{width:1100,height:800}});
 await page.goto(iconURL);
 check(await page.locator('.mask').count()===4,'all four launcher mask studies present');
 check(await page.locator('.mask .background').count()===3,'three adaptive backgrounds');
 check(await page.locator('.mask .foreground').count()===3,'three adaptive foregrounds');
 check(await page.locator('.mask img').evaluateAll(imgs=>imgs.every(i=>i.complete&&i.naturalWidth>0)),'adaptive vector layers load');
 check(await page.locator('.guide img').evaluate(el=>el.complete&&el.naturalWidth>0),'safe-area foreground guide loads');
 check(await page.locator('.guide .safe').count()===1,'66dp safe-area guide exists');
 await page.screenshot({path:path.join(out,'approved-launcher-masks-light.png'),fullPage:true});
 await page.locator('#theme').click();
 check(await page.locator('body').getAttribute('data-theme')==='dark','adaptive mask page dark theme works');
 await page.screenshot({path:path.join(out,'approved-launcher-masks-dark.png'),fullPage:true});
 check(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+2),'adaptive preview no page-wide overflow');
 await page.close();
 console.log('SUCCESS: '+passed+' approved Folded Page browser checks');
}finally{await browser.close()}
