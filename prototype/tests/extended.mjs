/**
 * Stage 3 extended responsive / bilingual / focus UX checks.
 * Headless Chromium only. These are design-simulation tests, NOT real
 * Android IME, native accessibility, or durable journaling tests.
 */
import assert from 'node:assert/strict';
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const out=path.join(root,'artifacts'); await mkdir(out,{recursive:true});
const url=pathToFileURL(path.join(root,'stage3-ux-preview.html')).href;
const browser=await chromium.launch({headless:true});
const sizes=[['phone-small',360,800],['phone-large',430,932],['tablet-portrait',768,1024],['tablet-landscape',1024,768]];
const bilingual='ఈ రోజు నాకు ప్రశాంతంగా అనిపించింది. Today felt calm. అమ్మతో మాట్లాడాను. 🌿';
let checks=0;
function check(ok,label){assert.ok(ok,label);console.log('PASS '+label);checks++}
async function noOverflow(page,label){
 const px=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);
 check(px<=2,label+' horizontal overflow = '+px+'px');
}
try{
 for(const [name,width,height] of sizes){
  const page=await browser.newPage({viewport:{width,height}});
  page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',err=>errors.push(err.message));
  await page.goto(url);
  await page.locator('[data-action="start"]').click();
  await page.locator('[data-action="createVault"]').click();
  await page.locator('[data-action="write"]:visible').first().click();
  await page.locator('#draftTitle').fill('నా మొదటి ఆలోచన — First thought');
  await page.locator('#draftBody').fill(bilingual);
  check(await page.locator('#draftBody').inputValue()===bilingual,name+' mixed Telugu/English/emoji input exact');
  await page.locator('[data-action="theme"]:visible').click();
  check(await page.locator('#draftBody').inputValue()===bilingual,name+' Unicode content preserved across theme rerender');
  await page.locator('[data-action="theme"]:visible').click();
  await page.setViewportSize({width,height:500}); // approximate viewport loss from keyboard, not Android IME simulation
  await page.locator('#draftBody').focus();
  await noOverflow(page,name+' reduced viewport while writing');
  await page.setViewportSize({width,height});
  await page.screenshot({path:path.join(out,name+'-telugu-writer.png'),fullPage:true});
  await page.locator('[data-action="closeEditor"]').first().click();
  check(await page.locator('.hero h1').textContent()==='Your pages, your pace.',name+' Writer returns to Today origin');
  await page.locator('[data-view="journals"]:visible').last().click();
  await page.locator('[data-journal="Travel"]').click();
  await page.locator('[data-action="write"]:visible').first().click();
  check(await page.locator('#journalSelect').inputValue()==='Travel',name+' Journal Writer retains chosen origin');
  await page.locator('#journalSelect').selectOption('Ideas');
  check(await page.locator('#journalSelect').inputValue()==='Ideas',name+' Journal selector functions');
  await page.locator('[data-action="closeEditor"]').first().click();
  check(await page.locator('.hero h1').textContent()==='Travel',name+' Writer returns to Journal Detail origin');
  await page.locator('[data-entry="1"]').click();
  await page.locator('[data-action="edit"]').click();
  await page.locator('[data-action="closeEditor"]').first().click();
  check(await page.locator('.reader h1').textContent()==='The trip I’ll always remember',name+' Edit exits back to Reader');
  await page.locator('[data-action="goBack"]').click();
  check(await page.locator('.hero h1').textContent()==='Travel',name+' Reader returns to Journal Detail');
  await page.locator('[data-view="settings"]:visible').last().click();
  for(let i=0;i<3;i++)await page.locator('[data-action="typeUp"]').click();
  check(await page.locator('[data-type-scale="2"]').count()===1,name+' 200 percent type scale selected');
  await page.screenshot({path:path.join(out,name+'-settings-200pct.png'),fullPage:true});
  await noOverflow(page,name+' Settings at 200 percent');
  await page.locator('[data-view="today"]:visible').last().click();
  await noOverflow(page,name+' Today at 200 percent');
  await page.screenshot({path:path.join(out,name+'-today-200pct.png'),fullPage:true});
  await page.locator('[data-action="write"]:visible').first().click();
  await noOverflow(page,name+' Writer at 200 percent');
  const titleHeight=await page.locator('#draftTitle').evaluate(el=>({scroll:el.scrollHeight,client:el.clientHeight,wrap:el.scrollHeight>80}));
  check(titleHeight.scroll<=titleHeight.client+3,name+' enlarged multiline title remains fully visible');
  check(await page.locator('#draftBody').inputValue()===sampleText(),name+' temporary sample content retained at 200 percent');
  await page.screenshot({path:path.join(out,name+'-writing-200pct.png'),fullPage:true});
  await page.locator('[data-action="closeEditor"]').first().click();
  await page.locator('[data-view="settings"]:visible').last().click();
  for(let i=0;i<3;i++)await page.locator('[data-action="typeDown"]').click();
  check(await page.locator('[data-type-scale="1"]').count()===1,name+' type scale returns to standard');
  await page.locator('[data-action="backup"]').click();
  await page.locator('[data-action="restoreFail"]').click();
  check(await page.locator('#dialogDismiss').evaluate(x=>document.activeElement===x),name+' modal gets keyboard focus');
  await page.keyboard.press('Escape');
  check(await page.locator('[role="dialog"]').count()===0,name+' Escape closes modal');
  check(errors.length===0,name+' no uncaught page errors '+errors.join(';'));
  await page.close();
 }
 console.log('SUCCESS: '+checks+' extended browser checks');
}finally{await browser.close()}
function sampleText(){return 'The trip I’ll always remember'===null?'': 'The hills, the clouds, and the kind of silence you don’t get in the city. I felt like a small reset — the kind that stays with you.\n\nSome journeys become memories before they have even ended.';}
