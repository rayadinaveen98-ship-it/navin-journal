/**
 * Stage 3 keyboard/focus regression tests in Chromium.
 * Design-only. Not a native TalkBack or VoiceOver test.
 */
import assert from 'node:assert/strict';
import { chromium } from 'playwright';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const url=pathToFileURL(path.join(root,'stage3-ux-preview.html')).href;
const browser=await chromium.launch({headless:true});
const targets=[['phone-small',360,800],['tablet-portrait',768,1024],['tablet-landscape',1024,768]];
let count=0;
function check(condition,label){assert.ok(condition,label);console.log('PASS '+label);count++;}
try{
 for(const [label,width,height] of targets){
  const page=await browser.newPage({viewport:{width,height}});
  page.setDefaultTimeout(7000);
  await page.goto(url);
  await page.keyboard.press('Tab');
  check(await page.locator('.skip-link').evaluate(e=>document.activeElement===e),label+' skip-to-main link first in tab order');
  await page.keyboard.press('Enter');
  check(await page.evaluate(()=>location.hash==='#mainContent'),label+' skip link navigates to main');
  await page.locator('[data-action="start"]').click();
  await page.locator('[data-action="createVault"]').click();
  const journalsNav=page.locator('.nav button[data-view="journals"]:visible, .mobile-nav button[data-view="journals"]:visible').first();
  await journalsNav.focus();
  await page.keyboard.press('Enter');
  check(await page.locator('.section-head h2').first().textContent()==='Your journals',label+' keyboard navigation opens Journals');
  check(await page.evaluate(()=>document.activeElement?.dataset?.view==='journals'),label+' focus restored after route re-render');
  check(await page.locator('[aria-current="page"][data-view="journals"]:visible').count()===1,label+' current nav exposed semantically');
  await page.keyboard.press('Control+k');
  check(await page.locator('#journalSearch').evaluate(e=>document.activeElement===e),label+' Ctrl+K focuses Discover search');
  await page.locator('[data-view="settings"]:visible').last().click();
  await page.locator('[data-action="backup"]').click();
  await page.locator('[data-action="restoreFail"]').click();
  check(await page.locator('#dialogDismiss').evaluate(e=>document.activeElement===e),label+' modal receives initial keyboard focus');
  await page.keyboard.press('Shift+Tab');
  check(await page.locator('#dialogDismiss').evaluate(e=>document.activeElement===e),label+' modal traps backward tab');
  await page.keyboard.press('Control+k');
  check(await page.locator('[role="dialog"]').count()===1,label+' global shortcut cannot bypass modal');
  await page.keyboard.press('Escape');
  check(await page.locator('[role="dialog"]').count()===0,label+' Escape closes modal');
  check(await page.locator('[data-action="restoreFail"]').evaluate(e=>document.activeElement===e),label+' Escape returns focus to opening action');
  await page.close();
 }
 console.log('SUCCESS: '+count+' keyboard navigation checks');
}finally{await browser.close()}
