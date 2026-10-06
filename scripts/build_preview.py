"""Generate an offline clickable preview from the native plugin's display lists."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
scenes = (root / "preview-scenes.json").read_text()
template = r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>The Reading Room — interactive preview</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#e9e7e1;color:#202322;font:15px system-ui,sans-serif}
main{max-width:1040px;margin:32px auto;display:grid;grid-template-columns:280px 1fr;gap:48px;padding:24px}
aside{padding-top:20px}h1{font:36px Georgia,serif;margin:0 0 18px}p{line-height:1.6;color:#505651}
.note{font-size:13px}nav{display:grid;gap:8px;margin:28px 0}nav button{font:inherit;text-align:left;padding:12px 16px;background:transparent;border:1px solid #aaa;cursor:pointer}
nav button[aria-current=true]{background:#2d4d5e;color:white;border-color:#2d4d5e}
#screen{display:block;width:100%;max-width:600px;height:auto;background:#fff;border:1px solid #8a8a83}
#toast{min-height:55px;max-width:600px;padding:16px 0;line-height:1.5;color:#374d58}
.hit{cursor:pointer;fill:transparent}.hit:hover{fill:#2d4d5e;fill-opacity:.07}.hit:focus{outline:none;stroke:#2d4d5e;stroke-width:2}
@media(max-width:760px){main{display:block;margin:0;padding:16px}aside{padding-top:0}h1{font-size:28px;margin-bottom:8px}nav{display:flex;gap:6px;margin:16px 0;flex-wrap:wrap}nav button{padding:8px 10px}.intro{display:none}#screen{margin:auto}#toast{margin:auto}}
</style>
<main><aside><h1>The Reading Room</h1><p class="intro">Your personal library, laid out like a literary newspaper.</p><nav aria-label="Preview screens"></nav><p class="note">Interactive design preview built from the KOReader plugin’s layout. Sample books and status; plugin actions are simulated.</p><p class="note">The installable version uses your actual books, covers, collections and enabled plugins.</p></aside><section><svg id="screen" viewBox="0 0 600 800" role="group" aria-label="Kindle screen preview"></svg><div id="toast" role="status" aria-live="polite"></div></section></main>
<script>
const scenes=SCENE_DATA;
const sections=['library','collections','discover','tools'];
const titles=['Library','Collections','Discover','Tools'];
const colors={ink:'#171b1b',accent:'#2d4d5e',light:'#d8d9d6',muted:'#747672'};
let active='library';const svg=document.querySelector('#screen');const ns='http://www.w3.org/2000/svg';
function element(tag,attrs){const n=document.createElementNS(ns,tag);for(const [k,v]of Object.entries(attrs))n.setAttribute(k,v);return n}
function textBox(item){const f=element('foreignObject',{x:item.x,y:item.y,width:item.w,height:item.h});const d=document.createElementNS('http://www.w3.org/1999/xhtml','div');d.style.cssText=`height:100%;overflow:hidden;font:${item.style==='bold'?'700':'400'} ${item.size}px ${item.style==='sans'?'Arial,sans-serif':'Georgia,serif'};line-height:1.15;text-align:${item.align||'left'};color:${colors[item.color||'ink']};white-space:pre-wrap;overflow-wrap:anywhere`;d.textContent=item.text;f.append(d);svg.append(f)}
function action(t){if(t.y===130){show(sections[Math.round((t.x-20)/140)]);return}if(t.y===753&&t.x===400){show('discover');return}if(t.y===753&&t.x===220){show(active);toast('Preview refreshed.');return}if(active==='library'&&t.x===526){toast('Book actions: Read · Book information · Add to collection · Send to X3 · Send notes · Progress sync.');return}if(active==='library'&&t.x===526){toast('Book actions: Read · Book information · Add to collection · Send to X3 · Send notes · Progress sync.');return}if(active==='library'&&t.x===207){toast('On your Kindle, Continue reading opens the book at its saved position.');return}if(active==='discover'&&t.y===693){toast('Opens AO3 Downloader for search, downloads, downloaded works and work updates. This preview does not connect to AO3.');return}if(active==='discover'){toast('This opens the corresponding search or browsing screen in the installed plugin. No network request is made in this preview.');return}if(active==='tools'){toast('This opens the installed plugin’s controls. Sync is never run by this preview.');return}if(active==='collections'){toast('This opens your collection in KOReader.');return}toast('This opens KOReader’s book or file browser on your device.')}
function toast(s){document.querySelector('#toast').textContent=s}
function show(section){active=section;svg.replaceChildren();for(const item of scenes[section].items){if(item.kind==='text'){textBox(item)}else if(item.kind==='cover'){svg.append(element('rect',{x:item.x,y:item.y,width:item.w,height:item.h,fill:'#f0eee8',stroke:'#646961','stroke-width':1}));textBox({x:item.x+4,y:item.y+6,w:item.w-8,h:item.h-12,text:item.w<60?'BOOK':item.title,size:item.w<60?9:14,style:'serif',align:'center'})}else{svg.append(element('rect',{x:item.x,y:item.y,width:item.w,height:item.h,fill:item.kind==='outline'?'none':colors[item.color],stroke:item.kind==='outline'?colors[item.color]:'none','stroke-width':1}))}}for(const t of scenes[section].targets){const label=scenes[section].items.find(i=>i.kind==='text'&&i.x>=t.x&&i.x<t.x+t.w&&i.y>=t.y&&i.y<t.y+t.h)?.text||'Open';const hit=element('rect',{...t,width:t.w,height:t.h,class:'hit',tabindex:0,role:'button','aria-label':label});hit.addEventListener('click',()=>action(t));hit.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();action(t)}});svg.append(hit)}document.querySelectorAll('nav button').forEach(b=>b.setAttribute('aria-current',b.dataset.section===section));toast('')}
sections.forEach((s,i)=>{const b=document.createElement('button');b.textContent=titles[i];b.dataset.section=s;b.onclick=()=>show(s);document.querySelector('nav').append(b)});show('library');
</script></html>'''
(root / "preview.html").write_text(template.replace("SCENE_DATA", scenes))
print("Built", root / "preview.html")
