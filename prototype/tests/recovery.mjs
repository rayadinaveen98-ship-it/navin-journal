/**
 * Connected journal-management and recovery UX — test-only browser workflow.
 * No real persistent storage or actual encryption/backup is implemented.
 */
import assert from 'node:assert/strict';
import path from 'node:path';
import {mkdir} from 'node:fs/promises';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {chromium} from 'playwright';

const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const url=pathToFileURL(path.join(root,'journal-recovery-review.html')).href;
const out=path.join(root,'artifacts'); await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true});
const sizes=[['phone-small',360,800],['tablet',1024,768]];
let count=0;
function ok(condition,label){assert.ok(condition,label);console.log('PASS '+label);count++}
async function verifyWidth(page,label){const extra=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth);ok(extra<=2,label+' horizontal overflow '+extra+'px')}
try{
 for(const [name,width,height] of sizes){
  const page=await browser.newPage({viewport:{width,height}});
  page.setDefaultTimeout(7000);const errs=[];page.on('pageerror',e=>errs.push(e.message));
  await page.goto(url);
  ok(await page.locator('h1').first().textContent()==='Your journals',name+' opening library');
  ok(await page.locator('[data-action^="open:"]').count()===3,name+' three fictional journals');
  await verifyWidth(page,name+' library');
  await page.screenshot({path:path.join(out,name+'-management-library.png'),fullPage:true});
  await page.locator('[data-action="create"]').click();
  ok(await page.locator('#journalName').isVisible(),name+' journal form');
  await page.locator('#journalForm button[type="submit"]').click();
  ok((await page.locator('#nameError').textContent()).includes('Enter a journal name'),name+' empty name rejected');
  await page.locator('#journalName').fill('Personal');
  await page.locator('#journalForm button[type="submit"]').click();
  ok((await page.locator('#nameError').textContent()).includes('already in use'),name+' duplicate name rejected');
  await page.locator('#journalName').fill('Film Notes');
  await page.locator('#journalForm button[type="submit"]').click();
  ok(await page.locator('h1').textContent()==='Film Notes',name+' creates journal in volatile state');
  ok((await page.locator('main').textContent()).includes('No sample entries'),name+' new journal is empty');
  await page.screenshot({path:path.join(out,name+'-management-created.png'),fullPage:true});
  await page.locator('[data-action="rename"]').click();
  await page.locator('#journalName').fill('Cinema Journal');
  await page.locator('#journalForm button[type="submit"]').click();
  ok(await page.locator('h1').textContent()==='Cinema Journal',name+' rename succeeds');
  await page.locator('[data-action="archive"]').click();
  ok((await page.locator('main').textContent()).includes('Archived'),name+' archive status');
  await page.locator('[data-route="journals"]:visible').last().click();
  ok(await page.locator('[data-action="open:j4"]').count()===0,name+' archived journal absent from active');
  await page.locator('[data-action="archives"]').click();
  ok((await page.locator('main').textContent()).includes('Cinema Journal'),name+' archived journal discoverable');
  await page.locator('[data-action="open:j4"]').click();
  await page.locator('[data-action="archive"]').click();
  ok((await page.locator('main').textContent()).includes('Active'),name+' unarchive returns to active');
  await page.locator('[data-route="journals"]:visible').last().click();
  ok(await page.locator('[data-action="open:j4"]').count()===1,name+' restored journal visible');
  await page.locator('[data-action="open:j2"]').click();
  await page.locator('[data-action="read:e2"]').click();
  ok(await page.locator('h1').textContent()==='The trip I’ll always remember',name+' reads example entry');
  await page.locator('[data-action="deleteEntry"]').click();
  ok(await page.locator('[role="dialog"]').isVisible(),name+' delete entry requires confirmation');
  ok((await page.locator('[role="dialog"]').textContent()).includes('can be restored'),name+' recovery is explained');
  await page.locator('[data-action="cancelModal"]').click();
  ok(await page.locator('h1').textContent()==='The trip I’ll always remember',name+' cancel preserves reader');
  await page.locator('[data-action="deleteEntry"]').click();
  await page.locator('[data-action="confirmModal"]').click();
  ok((await page.locator('main').textContent()).includes('The trip I’ll always remember'),name+' entry present in Trash');
  await page.screenshot({path:path.join(out,name+'-management-trash.png'),fullPage:true});
  await page.locator('[data-action="restore:te2"]').click();
  ok((await page.locator('main').textContent()).includes('Nothing in Trash'),name+' restore empties Trash');
  await page.locator('[data-route="journals"]:visible').last().click();
  await page.locator('[data-action="open:j2"]').click();
  ok(await page.locator('[data-action="read:e2"]').count()===1,name+' restored entry returns to journal');
  await page.locator('[data-route="journals"]:visible').last().click();
  await page.locator('[data-action="open:j1"]').click();
  await page.locator('[data-action="deleteJournal"]').click();
  ok((await page.locator('[role="dialog"]').textContent()).includes('1 entry'),name+' journal deletion gives exact entry count');
  await page.locator('[data-action="confirmModal"]').click();
  ok((await page.locator('main').textContent()).includes('Personal'),name+' journal recoverable in Trash');
  await page.locator('[data-action="restore:tj1"]').click();
  await page.locator('[data-route="journals"]:visible').last().click();
  ok(await page.locator('[data-action="open:j1"]').count()===1,name+' journal restored to library');
  await page.locator('[data-action="open:j1"]').click();
  ok(await page.locator('[data-action="read:e1"]').count()===1,name+' journal restore retains its entry');
  await page.locator('[data-route="backup"]:visible').last().click();
  await page.locator('[data-action="invalid"]').click();
  ok((await page.locator('main').textContent()).includes('This archive could not be verified'),name+' failed backup warning');
  await page.screenshot({path:path.join(out,name+'-management-backup-failure.png'),fullPage:true});
  await page.locator('[data-action="verified"]').click();
  ok((await page.locator('main').textContent()).includes('example only'),name+' simulated verification clearly labeled');
  await page.locator('[data-action="confirmBackup"]').click();
  ok(await page.locator('[role="dialog"]').isVisible(),name+' restore requires final confirmation');
  await page.keyboard.press('Escape');
  ok(await page.locator('[role="dialog"]').count()===0,name+' Escape closes restore dialog');
  await page.locator('[data-action="theme"]').click();
  ok(await page.locator('body').getAttribute('data-theme')==='dark',name+' dark appearance');
  await verifyWidth(page,name+' backup/dark');
  await page.screenshot({path:path.join(out,name+'-management-dark.png'),fullPage:true});
  await page.reload();
  ok(await page.locator('[data-action^="open:"]').count()===3,name+' reload resets temporary sample data');
  ok(await page.locator('[data-action="open:j4"]').count()===0,name+' temporary new journal does not persist');
  ok(errs.length===0,name+' no uncaught JavaScript exceptions '+errs.join('; '));
  await page.close();
 }
 console.log('SUCCESS: '+count+' journal/recovery workflow browser checks');
}finally{await browser.close()}
