const fs = require('fs');
const path = require('path');
const assert = require('node:assert/strict');
const root = path.join(__dirname, '..');
let count = 0;
const check = (name, fn) => { fn(); count++; console.log('PASS ' + name); };
const all = Object.fromEntries(['01','02','03','04','05','05B'].map(k => [k, JSON.parse(fs.readFileSync(path.join(root,'workflows',k+'.json')))]));
const node = (id,name) => all[id].nodes.find(n=>n.name===name);
const run = (id,name,input,lookup=()=>{throw Error('Unexpected lookup');}) =>
 new Function('$input','$',node(id,name).parameters.jsCode)({first:()=>({json:input})},lookup);

for(const [id,w] of Object.entries(all)) {
 check(id+' valid graph and JavaScript',()=>{
  const names=new Set(w.nodes.map(n=>n.name));assert.equal(names.size,w.nodes.length);
  for(const n of w.nodes)if(n.type==='n8n-nodes-base.code')new Function('$input','$',n.parameters.jsCode);
  for(const [name,outputs] of Object.entries(w.connections)){
   assert(names.has(name));for(const branches of Object.values(outputs))for(const branch of branches)for(const e of branch)assert(names.has(e.node),e.node);
  }
 });
 check(id+' exported timezone compatibility and bounded external retries',()=>{
  assert(!w.settings.timezone || w.settings.timezone==='Europe/Paris');
  for(const n of w.nodes)if(['n8n-nodes-base.httpRequest','n8n-nodes-base.postgres','@n8n/n8n-nodes-langchain.chainLlm'].includes(n.type)){
   assert.equal(n.retryOnFail,true,n.name);assert(n.maxTries>=2&&n.maxTries<=3,n.name);assert(n.waitBetweenTries>=1000,n.name);
  }
 });
}
const msg=text=>({update:{update_id:100,message:{chat:{id:123456789,type:'private'},text}}});
for(const [command,route,value] of [['/start','home'],['/events','events'],['/myteams','my_follows'],['/daily off','daily'],['/previews off','alert_settings','off'],['/reminders on','alert_settings','on'],['/alerts','alert_settings','status']]){
 check(command+' routes correctly',()=>{const r=run('01','Understand command',msg(command))[0].json;assert.equal(r.route,route);if(value)assert.equal(r.alert_value,value);if(command==='/daily off')assert.equal(r.daily,false);});
}
check('Unknown command returns useful help',()=>assert.match(run('01','Understand command',msg('/nonsense'))[0].json.reply,/Unknown command.*\/events/));
check('Missing daily argument returns usage',()=>assert.match(run('01','Understand command',msg('/daily'))[0].json.reply,/\/daily on.*\/daily off/));
check('Group messages are ignored',()=>assert.equal(run('01','Understand command',{update:{message:{chat:{id:-1,type:'group'},text:'/events'}}}).length,0));
check('Home callback returns welcome',()=>assert.match(run('01','Understand command',{update:{callback_query:{data:'menu:sports',message:{chat:{id:123456789,type:'private'}}}}})[0].json.reply,/Welcome to Sports Radar/));
check('AI accepts the exact overview schema',()=>{const r=run('02','Validate AI overview',{text:JSON.stringify({overview:'Chelsea and the Knicks have games this week.'})})[0].json;assert(r.overview_valid);});
for(const value of ['', 'not JSON', JSON.stringify({overview:''}),JSON.stringify({overview:'x'.repeat(181)}),JSON.stringify({overview:'Example',extra:true}),JSON.stringify({overview:'Read https://example.com'}),JSON.stringify({overview:'Starts at 21:00'})]){
 check('AI rejects invalid output '+count,()=>assert.equal(run('02','Validate AI overview',{text:value})[0].json.overview_valid,false));
}
check('AI API failure takes the fallback',()=>assert.equal(run('02','Validate AI overview',{error:'Provider unavailable'})[0].json.overview_valid,false));
check('Fallback preserves the verified calendar list',()=>{
 const c={body:'Chelsea FC vs Tottenham Hotspur FC',warning:'',chat_id:'123456789',mode:'manual',local_date:'2026-10-22'};
 const r=run('02','Format Telegram message',{text:'',overview_valid:false},()=>({first:()=>({json:c})}))[0].json;
 assert(r.text.includes(c.body));assert(!r.text.includes('undefined'));assert(r.text.length<4096);
});
check('Sub-workflow inputs are declared and mapped',()=>{
 assert.equal(node('02','Briefing requested').parameters.workflowInputs.values[0].name,'context');
 assert.equal(node('05B','Alert requested').parameters.workflowInputs.values[0].name,'job_id');
 assert(node('01','Build and send briefing').parameters.workflowInputs.value.context);
 assert(node('03','Send each daily briefing').parameters.workflowInputs.value.context);
 assert(node('05','Start alert worker').parameters.workflowInputs.value.job_id);
});
check('Telegram spacing is one second',()=>{const n=node('05B','Space Telegram sends');assert.equal(n.parameters.amount,1);assert.equal(n.parameters.unit || (n.typeVersion>1?'seconds':'hours'),'seconds');});
check('All operational workflows link to the error workflow',()=>{for(const id of ['01','02','03','05','05B'])assert.equal(all[id].settings.errorWorkflow,all['04'].id);});
check('All user messages have navigation and attribution is disabled',()=>{
 for(const w of Object.values(all))for(const n of w.nodes)if(n.type==='n8n-nodes-base.telegram'&&n.name!=='Acknowledge button'){
  assert.equal(n.parameters.additionalFields.appendAttribution,false,n.name);assert.equal(n.parameters.replyMarkup,'inlineKeyboard',n.name);
 }
});
check('No obvious embedded secrets in exported workflows',()=>{
 const text=JSON.stringify(all);
 for(const re of [/\b\d{7,12}:[A-Za-z0-9_-]{30,}\b/,/\bgsk_[A-Za-z0-9]{20,}\b/,/\bsk-[A-Za-z0-9_-]{20,}\b/,/postgres(?:ql)?:\/\/[^\s:@]+:[^\s@]+@/])assert(!re.test(text));
});
console.log('\n'+count+' checks passed. These are local checks, not a claim of live provider availability.');
