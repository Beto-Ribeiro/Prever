import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import postcss from 'postcss'
import { applySmdnSettings, readSmdnSettings, saveSmdnSettings } from '../src/hooks/useSmdnSettings.js'
const css=postcss.parse(fs.readFileSync(new URL('../src/accessibility.css',import.meta.url),'utf8'))
function palette(theme,contrast,colorblind){
 const vars={}
 css.nodes.filter(n=>n.type==='rule').forEach(rule=>{
  const matches=rule.selector.split(',').some(s=>{
   s=s.trim();if(s===':root')return true
   if(!/^html(?:\[data-[\w-]+='[\w-]+'\])+$/.test(s))return false
   return [...s.matchAll(/\[data-([\w-]+)='([\w-]+)'\]/g)].every(([,k,v])=>({theme,contrast,colorblind})[k]===v)
  })
  if(matches)rule.nodes.filter(n=>n.type==='decl'&&n.prop.startsWith('--')).forEach(n=>vars[n.prop]=n.value.split(' ').map(Number))
 });return vars
}
const luminance=rgb=>rgb.map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4}).reduce((sum,v,i)=>sum+v*[.2126,.7152,.0722][i],0)
const ratio=(a,b)=>{a=luminance(a);b=luminance(b);return (Math.max(a,b)+.05)/(Math.min(a,b)+.05)}
for(const theme of ['light','dark'])for(const contrast of ['normal','high'])for(const colorblind of ['false','true'])test(`contraste das cores compartilhadas: ${theme}/${contrast}/${colorblind}`,()=>{
 const p=palette(theme,contrast,colorblind)
 for(const [fg,bg] of [['body-text','manager-surface'],['muted-text','manager-surface'],['button-text','button-bg'],['body-text','control-bg']])assert.ok(ratio(p['--'+fg],p['--'+bg])>=4.5,`${fg}/${bg}`)
 for(const status of ['critical','severe','regular','success'])assert.ok(ratio(p['--status-'+status],p['--status-'+status+'-bg'])>=4.5,status)
})
test('preferências alteram todos os atributos globais e persistem',()=>{
 const stored=new Map();globalThis.document={documentElement:{dataset:{}}};globalThis.window={matchMedia:()=>({matches:false}),localStorage:{getItem:k=>stored.get(k),setItem:(k,v)=>stored.set(k,v)},dispatchEvent:()=>{}};globalThis.CustomEvent=class{}
 saveSmdnSettings({theme:'light',fontScale:'xlarge',density:'compact',highContrast:true,colorBlind:true,reducedMotion:true})
 assert.deepEqual(document.documentElement.dataset,{theme:'light',themeMode:'light',fontScale:'xlarge',contrast:'high',motion:'reduced',colorblind:'true',density:'compact',promptRecommendations:'on'})
 assert.equal(readSmdnSettings().theme,'light')
 applySmdnSettings({theme:'invalid',density:'invalid'});assert.equal(document.documentElement.dataset.density,'comfortable')
})
test('preferência de movimento do dispositivo também é respeitada',()=>{
 window.matchMedia=q=>({matches:q.includes('reduced-motion')});applySmdnSettings({theme:'light',reducedMotion:false});assert.equal(document.documentElement.dataset.motion,'reduced')
})
