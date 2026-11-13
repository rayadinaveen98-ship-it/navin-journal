/**
 * Stage 3 design-only connected journey:
 * create journal -> write a fictional entry -> edit -> Trash -> restore.
 * Only tests in-memory prototype interactions, NOT durable/secure journaling.
 */
import assert from 'node:assert/strict';
import path from 'node:path';
import {mkdir} from 'node:fs/promises';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {chromium} from 'playwright';

const dir=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const url=pathToFileURL(path.join(dir,'journal-recovery-review.html')).href;
const out=path.join(dir,'artifacts');await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true});
const viewports=[['phone',360,800],['tablet',1024,768]];
const entry='ఈ రోజు నాకు మంచి జ్ఞాపకం వచ్చింది. Today was a beautiful day. 🌿';
let count=0;
const check=(condition,label)=>{assert.ok(condition,label);console.log('PASS '+label);count++;};
try {
 for(const [name,width,height] of viewports){
  const page=await browser.newPage({viewport:{width,height}});
  page.setDefaultTimeout(7000);
  const errors=[];page.on('pageerror',x=>errors.push(x.message));
  await page.goto(url);
  await page.locator('[data-action="open:j1"]').click();
  await page.locator('[data-action="newEntry"]').click();
  check(await page.locator('#entryForm').count()===1,name+' writing form opens from specific journal');
  check(await page.locator('#entryJournal').inputValue()==='j1',name+' writer journal inherited');
  await page.locator('#entryForm button[type="submit"]').click();
  check((await page.locator('#entryError').textContent()).includes('Write a title or a thought'),name+' blank entry refused');
  await page.locator('#entryTitle').fill('నా రోజు — My journal');
  await page.locator('#entryBody').fill(entry);
  await page.locator('[data-action="theme"]').click();
  check(await page.locator('#entryBody').inputValue()===entry,name+' theme preserves Telugu/English draft');
  await page.locator('[data-action="leaveWriter"]').first().click();
  check(await page.locator('[role="dialog"]').isVisible(),name+' unsaved draft requires confirmation');
  await page.locator('[data-action="cancelModal"]').click();
  check(await page.locator('#entryBody').inputValue()===entry,name+' cancel discard keeps draft');
  await page.screenshot({path:path.join(out,name+'-connected-writer.png'),fullPage:true});
  await page.locator('#entryForm button[type="submit"]').click();
  check((await page.locator('.reader h1').textContent()).includes('నా రోజు'),name+' saved in temporary Reader');
  check((await page.locator('.reader .body').textContent())===entry,name+' Unicode content intact');
  await page.locator('[data-action="editEntry"]').click();
  check(await page.locator('#entryForm').count()===1,name+' edit action opens studio');
  await page.locator('#entryTitle').fill('My revised memory');
  await page.locator('#entryBody').fill(entry+' A tiny second thought.');
  await page.locator('#entryForm button[type="submit"]').click();
  check(await page.locator('.reader h1').textContent()==='My revised memory',name+' revised title appears');
  check((await page.locator('.reader .body').textContent()).includes('second thought'),name+' revised body appears');
  await page.locator('[data-route="journal"]').click();
  check(await page.locator('[data-action="read:e4"]').count()===1,name+' new entry appears in Personal journal');
  await page.locator('[data-action="read:e4"]').click();
  await page.locator('[data-action="deleteEntry"]').click();
  check(await page.locator('[role="dialog"]').isVisible(),name+' deletion confirmation');
  await page.locator('[data-action="confirmModal"]').click();
  check(await page.locator('[data-action="restore:te4"]').count()===1,name+' entry recoverable in Trash');
  await page.locator('[data-action="restore:te4"]').click();
  check(await page.locator('[data-action="restore:te4"]').count()===0,name+' restore removed entry from Trash');
  await page.locator('[data-route="journals"]:visible').last().click();
  await page.locator('[data-action="open:j1"]').click();
  check(await page.locator('[data-action="read:e4"]').count()===1,name+' original journal contains restored entry');
  await page.screenshot({path:path.join(out,name+'-connected-library.png'),fullPage:true});
  check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2),name+' no horizontal overflow');
  await page.reload();
  await page.locator('[data-action="open:j1"]').click();
  check(await page.locator('[data-action="read:e4"]').count()===0,name+' reload clears fictional new entry');
  check(errors.length===0,name+' no browser exceptions: '+errors.join('; '));
  await page.close();
 }
 console.log('SUCCESS: '+count+' connected writing-to-recovery browser checks');
}finally{await browser.close()}
