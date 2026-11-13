/**
 * Design-only review of the three provisional Navin Journal brand marks.
 * Tests rendering/selection/contrast layouts; does not approve branding.
 */
import assert from 'node:assert/strict';
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const url=pathToFileURL(path.join(root,'brand-study.html')).href;
const out=path.join(root,'artifacts');
await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true});
const sizes=[['phone-small',360,800],['phone-large',430,932],['tablet',1024,768],['desktop',1280,900]];
let checks=0;
const ok=(value,label)=>{assert.ok(value,label);console.log('PASS '+label);checks++;};
try{
 for(const [name,width,height] of sizes){
  const page=await browser.newPage({viewport:{width,height}});
  page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',err=>errors.push(err.message));
  await page.goto(url);
  ok(await page.locator('.candidate').count()===3,name+' 3 original candidates');
  ok(await page.locator('.mark-area svg').count()===3,name+' inline SVG renders');
  ok(await page.locator('.sample-size svg').count()===6,name+' small/large icon context present');
  ok(await page.locator('.preview .mark-container svg').count()===2,name+' selected mark appears in both journal contexts');
  ok((await page.locator('[aria-pressed="true"]').count())===1,name+' exactly one selected mark');
  const over=async()=>page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
  ok(await over()<=2,name+' light width has no overflow');
  await page.screenshot({path:path.join(out,name+'-brand-light.png'),fullPage:true});
  await page.locator('[data-pick="leaf"]').click();
  ok(await page.locator('[data-id="leaf"][data-selected="true"]').count()===1,name+' Quiet Leaf selection');
  ok(await page.locator('[data-pick="leaf"][aria-pressed="true"]').count()===1,name+' selected status accessible');
  await page.locator('[data-pick="window"]').click();
  ok(await page.locator('[data-id="window"][data-selected="true"]').count()===1,name+' Memory Window selection');
  await page.locator('#themeBtn').click();
  ok(await page.locator('body').getAttribute('data-theme')==='dark',name+' dark study');
  ok(await over()<=2,name+' dark width has no overflow');
  await page.screenshot({path:path.join(out,name+'-brand-dark.png'),fullPage:true});
  await page.locator('[data-pick="folded"]').click();
  ok(await page.locator('[data-id="folded"][data-selected="true"]').count()===1,name+' Folded Page can be reselected');
  ok(errors.length===0,name+' no uncaught JS errors: '+errors.join('; '));
  await page.close();
 }
 console.log('SUCCESS: '+checks+' brand study Chromium checks');
}finally{await browser.close();}
