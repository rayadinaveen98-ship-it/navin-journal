/**
 * Automated WCAG 2.0/2.1 A/AA audit of the Stage 3 HTML mock.
 * It is a design/a11y smoke test, not certification of a native app.
 */
import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const url=pathToFileURL(path.join(root,'stage3-ux-preview.html')).href;
const axeScript=readFileSync(path.join(root,'node_modules','axe-core','axe.min.js'),'utf8');
const out=path.join(root,'artifacts');await mkdir(out,{recursive:true});
const browser=await chromium.launch({headless:true});
let page=await browser.newPage({viewport:{width:430,height:932}});
const reports=[];
async function audit(name){
 await page.addScriptTag({content:axeScript});
 const result=await page.evaluate(async()=>window.axe.run(document,{
  runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa']}
 }));
 const issues=result.violations.map(x=>({id:x.id,impact:x.impact,description:x.description,nodes:x.nodes.map(n=>({target:n.target,summary:n.failureSummary})).slice(0,8)}));
 reports.push({screen:name,totalChecks:result.passes.length,issues});
 const bad=issues.filter(i=>i.impact==='critical'||i.impact==='serious');
 console.log(name+': '+result.passes.length+' passed rules, '+issues.length+' violation types, '+bad.length+' serious/critical types');
 for(const i of issues)console.log('  '+i.impact+' '+i.id+' ('+i.nodes.length+' samples)');
}
try{
 await page.goto(url);
 await audit('welcome');
 await page.locator('[data-action="start"]').click();
 await audit('setup');
 await page.locator('[data-action="createVault"]').click();
 await audit('today');
 await page.locator('[data-action="write"]:visible').first().click();
 await audit('writer');
 await page.locator('[data-action="closeEditor"]').first().click();
 await page.locator('[data-entry="1"]').first().click();
 await audit('reader');
 await page.locator('[data-view="memories"]:visible').last().click();
 await page.locator('[data-memory="gallery"]').click();
 await audit('memories-gallery');
 await page.locator('[data-view="discover"]:visible').last().click();
 await page.locator('[data-action="theme"]').click();
 await audit('discover-dark');
 await page.close();
 page=await browser.newPage({viewport:{width:430,height:932}});
 await page.goto(pathToFileURL(path.join(root,'journal-recovery-review.html')).href);
 await audit('recovery-library');
 await page.locator('[data-action="open:j1"]').click();
 await audit('recovery-journal');
 await page.locator('[data-action="newEntry"]').click();
 await audit('recovery-writer');
 await page.locator('[data-action="leaveWriter"]').first().click();
 await page.locator('[data-action="read:e1"]').click();
 await audit('recovery-reader');
 await page.locator('[data-action="deleteEntry"]').click();
 await audit('recovery-delete-confirmation');
 await page.locator('[data-action="confirmModal"]').click();
 await audit('recovery-trash');
 await page.locator('[data-route="backup"]:visible').last().click();
 await page.locator('[data-action="invalid"]').click();
 await audit('recovery-backup-failure');
 const bad=reports.flatMap(r=>r.issues.filter(i=>['serious','critical'].includes(i.impact)).map(i=>({screen:r.screen,...i})));
 await writeFile(path.join(out,'accessibility-audit.json'),JSON.stringify({date:'2026-11-13',reports,seriousCriticalCount:bad.length},null,2));
 if(bad.length){console.error('Accessibility audit failed: '+bad.length+' serious/critical issue types across screens');process.exitCode=1}
 else console.log('PASS: no serious or critical Axe violations in sampled HTML screens');
}finally{await browser.close()}
