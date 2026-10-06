/* Run with node tools/tests/trade-isolation.test.cjs.
 * Executes the actual DAS sources against a small in-memory DAS model. This
 * checks script decisions and context routing; it is not a DAS/broker emulator.
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');
const entries = [...fs.readFileSync(path.join(root, 'keymap.yaml'), 'utf8')
  .matchAll(/label: (.+)\r?\n\s+scriptPath: (.+)/g)];
const scripts = new Map(entries.map(m => [m[1].trim(), m[2].trim()]));
function object(fields = {}) {
  const store = Object.fromEntries(Object.entries(fields).map(([k,v]) => [k.toLowerCase(),v]));
  return new Proxy(store, {
    get(t,k) { return typeof k === 'string' ? t[k.toLowerCase()] : t[k]; },
    set(t,k,v) { t[String(k).toLowerCase()] = v; return true; }
  });
}
function userObject() {
  const values = new Map();
  return object({Set(k,v) {values.set(String(k),v);}, Get(k) {return values.get(String(k)) || 0;},
    Del(k) {if (k === '*') values.clear(); else values.delete(String(k));}});
}
function translate(s) {
  return s.replace(/FocusWindow (\w+);/g, 'FocusWindow("$1");')
    .replace(/SetFocus (\w+);/g, 'FocusWindow("$1");')
    .replace(/(?:SetFilter Account|Account) %%\w+%%;/g, 'NativeAccountCommand();')
    .replace(/CXL (ALLSYMB|ALL);/g, 'NativeCancel("$1");')
    .replace(/LockAllMontage Lock;/g, 'LockAllMontage();')
    .replace(/TIF=DAY\+;/gi, 'TIF="DAY+";')
    .replace(/SEND=Reverse;/gi, 'NativeReverse();')
    .replace(/Price=Round([234]);/g, 'Price=Round(Price,$1);');
}
function runtime() {
  const r = {positions:new Map(), quotes:new Map(), alerts:new Map(), orders:[], cancels:[], logs:[],
    missing:new Set(), waitHook:null, sendHook:null, account:'LIVE', symbol:'AAA', secondary:null};
  const key = (a,s) => a+'|'+s;
  r.position = (a,s,share,avg=10) => r.positions.set(key(a,s),object({Share:share,AvgCost:avg}));
  r.quote = (s,bid=10,ask=10.02,last=10) => r.quotes.set(s,object({Bid:bid,Ask:ask,Last:last}));
  r.select = (a,s) => {r.account=a;r.symbol=s;};
  r.state = (a,s) => r.ctx.$tradeStates.Get(key(a,s));
  r.bind = (a,s) => {r.ctx.TRADE_CONTEXT_ACCOUNT=a;r.ctx.TRADE_CONTEXT_SYMBOL=s;};
  const montage = secondary => new Proxy({}, {
    get(_t,k) {
      const a=secondary?r.secondary?.account:r.account, s=secondary?r.secondary?.symbol:r.symbol;
      const p=r.positions.get(key(a,s)), q=r.quotes.get(s);
      switch(String(k).toLowerCase()) {
        case 'account':return a; case 'symb':return s;
        case 'pos':return Math.abs(p?.Share||0); case 'avgcost':return p?.AvgCost||0;
        case 'bid':return q?.Bid||0; case 'ask':return q?.Ask||0; case 'last':return q?.Last||0;
        case 'getcurrpos':return () => r.availableOverride ?? p?.Share ?? 0;
      }
    }, set(){throw new Error('Scripts must not switch montage account/symbol');}
  });
  const primary=montage(false), secondary=montage(true);
  const ctx = {
    GetVar:n=>ctx[n.startsWith('$')?n:'$'+n] ?? ctx[n] ?? '',
    SetVar:(n,v)=>{ctx['$'+n]=v;ctx[n]=v;},
    NewUserObj:userObject, IsObj:v=>v!==null && (typeof v==='object' || typeof v==='function'),
    StrTrim:s=>String(s).trim(), StrLen:s=>String(s).length, StrFind:(s,p)=>String(s).indexOf(p),
    MsgBox:s=>r.logs.push(s), MsgLog:s=>r.logs.push(s), Speak:()=>{}, LockAllMontage:()=>{},
    GetWindowObj:n=>n==='Primary_OE'?primary:n==='Secondary_OE' && r.secondary?secondary:0,
    GetAccountObj:a=>r.missing.has(a)?0:object({
      GetPosition:s=>r.missing.has(key(a,s))?0:r.positions.get(key(a,s))||0,
      CancelOrder:(f,s,p)=>{r.cancels.push({account:a,symbol:s,flag:f});
        for(const o of r.orders) if(o.Account===a && o.Symbol===s &&
          (f==='BUY|SELL'||f==='BUY'&&o.Side==='B'||f==='SELL'&&o.Side==='S')) o.canceled=true;
      }
    }),
    GetQuoteObj:s=>r.quotes.get(s)||0, GetSecond:()=>r.seconds ?? 36000,
    Round:(n,prec,inc)=>prec===102?Math.round(n/inc)*inc:Math.round(n*10**prec)/10**prec,
    Wait:ms=>{if(r.waitHook) r.waitHook(ms);}, FocusWindow:()=>{},
    NativeCancel:()=>{throw new Error('Unscoped native cancellation');},
    NativeReverse:()=>{
      const pos=r.positions.get(key(r.account,r.symbol))?.Share||0;
      r.orders.push(object({Account:r.account,Symbol:r.symbol,Side:pos<0?'B':'S',Share:ctx.Share,Price:ctx.Price,Route:ctx.ROUTE}));
    },
    NewOrderObj:()=>{
      let o=object({Open:1, Send(){o.Open=o.Share;r.orders.push(o);if(r.sendHook)r.sendHook(o);},
        Cancel(){o.canceled=true;},GetInfo(){}});return o;
    },
    NewAlertObj:()=>{
      let al=object({AddItem(field,op,px){al.condition={field,op,px};},Save(){r.alerts.set(al.Name,al);},Delete(){r.alerts.delete(al.Name);}});
      return al;
    },
    GetAlertObj:n=>r.alerts.get(n)||0,
  };
  for(const [native,prop] of Object.entries({Account:'Account',Symbol:'Symb',Pos:'Pos',AvgCost:'AvgCost',BID:'Bid',ASK:'Ask',Bid:'Bid',Ask:'Ask'})) {
    Object.defineProperty(ctx,native,{get:()=>primary[prop],configurable:true});
  }
  vm.createContext(ctx);r.ctx=ctx;
  r.runFile=f=>vm.runInContext('(function(){\n'+translate(fs.readFileSync(path.join(root,f),'utf8'))+'\n})()',ctx,{filename:f,timeout:1000});
  ctx.ExecHotkey=ctx.ExecHotKey=label=>{assert(scripts.has(label),'Unknown hotkey: '+label);r.runFile(scripts.get(label));};
  r.run=ctx.ExecHotkey;
  r.execute=s=>vm.runInContext(translate(s),ctx,{timeout:1000});
  r.tick=()=>r.runFile('other scripts/timer.das');
  r.run('Set Global Variables');r.quote('AAA');r.position('LIVE','AAA',0);
  return r;
}
let count=0;
function test(name,f) {try{f();count++;}catch(e){console.error('FAIL:',name);throw e;}}
const buyLabels=[...scripts.keys()].filter(s=>/^Buy .* SL$/.test(s));
const longLabels=[...scripts.keys()].filter(s=>/^Sell |^Set Auto Stop|^Set Take Profit$|^Set Backstop Trigger$/.test(s));
for(const label of [...buyLabels,...longLabels]) test(label+' rejects short before cancel/send',()=>{
  const r=runtime();r.position('LIVE','AAA',-100);r.availableOverride=0;r.run(label);
  assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);assert.equal(r.alerts.size,0);
});
test('short and long coexist; timer protects long off montage',()=>{
  const r=runtime();r.position('LIVE','SHORT',-200);r.quote('SHORT');
  r.run('Buy MIB Bid+ SL');const entry=r.orders[0];assert.equal(entry.Price,10.01);
  r.position('LIVE','AAA',100,10.01);r.select('LIVE','SHORT');r.availableOverride=-200;
  for(let i=0;i<4;i++)r.tick();
  const stop=r.orders.find(o=>o.Type==='SLP');assert(stop);assert.equal(stop.Symbol,'AAA');assert.equal(stop.Share,100);
  assert.equal(r.symbol,'SHORT');assert.equal(r.state('LIVE','AAA').entryPending,0);
  assert([...r.alerts.values()].every(a=>a.Symb==='AAA'));
});
test('flat montage cannot clear another long stop/backstop/TP',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Auto Stop');r.run('Set Take Profit');r.run('Set Backstop Trigger');
  const t=r.state('LIVE','AAA');const last=t.lastStop, names=[...r.alerts.keys()];
  r.select('LIVE','FLAT');r.position('LIVE','FLAT',0);for(let i=0;i<6;i++)r.tick();
  assert.equal(t.lastStop,last);assert.deepEqual([...r.alerts.keys()],names);
});
test('same symbol in LIVE and SIM has separate stops and alerts',()=>{
  const r=runtime();r.position('LIVE','AAA',100,10);r.run('Set Auto Stop');r.run('Set Take Profit');r.run('Set Backstop Trigger');
  r.select('TRSIM','AAA');r.position('TRSIM','AAA',200,11);r.run('Set Auto Stop');r.run('Set Take Profit');r.run('Set Backstop Trigger');
  assert.equal(r.alerts.size,4);assert.notEqual(r.state('LIVE','AAA').lastStop,r.state('TRSIM','AAA').lastStop);
  r.position('TRSIM','AAA',0);r.tick();assert.equal(r.alerts.size,2);assert.equal(r.state('LIVE','AAA').lastStop,9.8);
});
test('TP alert uses its account while montage shows another short',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Take Profit');const al=[...r.alerts.values()][0];
  r.position('TRSIM','SHORT',-200);r.quote('SHORT');r.select('TRSIM','SHORT');
  r.sendHook=o=>{if(o.Side==='S'&&o.Type==='L'){r.position(o.Account,o.Symbol,50);o.Open=0;}};
  r.execute(al.Script);
  assert(r.orders.length>=1);assert(r.orders.every(o=>o.Account==='LIVE'&&o.Symbol==='AAA'));
  assert.equal(r.account,'TRSIM');assert.equal(r.symbol,'SHORT');assert.equal(r.ctx.TP_SYMBOL,'');
});
test('backstop alert uses recorded account and keeps independent retry budgets',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Auto Stop');r.run('Set Backstop Trigger');
  const al=r.alerts.get('Backstop LIVE AAA');r.select('TRSIM','SHORT');r.position('TRSIM','SHORT',-200);r.quote('SHORT');
  r.execute(al.Script);assert.equal(r.state('LIVE','AAA').backstopRetries,2);
  const o=r.orders.at(-1);assert.equal(o.Account,'LIVE');assert.equal(o.Symbol,'AAA');assert.equal(o.Share,100);
  r.execute(r.alerts.get('Backstop LIVE AAA').Script);r.execute(r.alerts.get('Backstop LIVE AAA').Script);
  assert.equal(r.state('LIVE','AAA').backstopRetries,0);
  const n=r.orders.length;r.execute(al.Script);assert.equal(r.orders.length,n);
});
test('stale TP payload on a now-short position cannot add short shares',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Take Profit');const al=[...r.alerts.values()][0];
  r.position('LIVE','AAA',-100);r.execute(al.Script);assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);
  r.tick();assert.equal(r.alerts.size,0);
  r.position('LIVE','AAA',100);r.run('Set Take Profit');r.execute(al.Script);assert.equal(r.orders.length,0);
});
test('legacy symbol-only payload fails closed',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.ctx.SetVar('TP_SYMBOL','AAA');r.run('Take Profit Executor');
  assert.equal(r.orders.length,0);assert.equal(r.ctx.TP_SYMBOL,'');
});
for(const label of longLabels.filter(s=>/^Sell |^Set Auto Stop/.test(s))) test(label+' rechecks direction after cancellation',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.waitHook=()=>r.position('LIVE','AAA',-20);r.run(label);
  assert.equal(r.orders.length,0);
});
test('stop quantity reflects reduced size during cancel wait',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.waitHook=()=>r.position('LIVE','AAA',25);r.run('Set Auto Stop');assert.equal(r.orders[0].Share,25);
});
test('reserved shares do not hide signed account position',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.availableOverride=0;r.run('Set Auto Stop');assert.equal(r.orders[0].Share,100);
});
test('missing account data and unresolved reserved position do not trade',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.missing.add('LIVE|AAA');r.availableOverride=0;r.run('Set Auto Stop');
  assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);
});
test('single-long guard is account scoped and blocks another long',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Auto Stop');
  r.quote('BBB');r.position('LIVE','BBB',0);r.select('LIVE','BBB');r.run('Buy MIB Bid SL');assert.equal(r.orders.length,1);
  r.select('TRSIM','BBB');r.position('TRSIM','BBB',0);r.run('Buy MIB Bid SL');assert.equal(r.orders.length,2);
});
test('guard off supports independently staged long entries',()=>{
  const r=runtime();r.ctx.$singlePositionGuard=0;r.run('Buy MIB Bid SL');r.position('LIVE','AAA',100);
  for(let i=0;i<4;i++)r.tick();
  r.select('LIVE','BBB');r.quote('BBB',20,20.02,20);r.position('LIVE','BBB',0);r.run('Buy MIB Bid SL');r.position('LIVE','BBB',100,20);
  r.select('LIVE','SHORT');r.quote('SHORT');r.position('LIVE','SHORT',-50);
  for(let i=0;i<4;i++)r.tick();
  assert.equal(r.state('LIVE','AAA').lastStop,9.8);assert.equal(r.state('LIVE','BBB').lastStop,19.8);
});
test('pending timeout cancels original account/symbol after montage swap',()=>{
  const r=runtime();r.run('Buy MIB Bid SL');r.ctx.$entryMaxTicks=2;r.select('TRSIM','SHORT');r.position('TRSIM','SHORT',-100);r.quote('SHORT');
  r.tick();r.tick();assert(r.cancels.every(c=>c.account==='LIVE'&&c.symbol==='AAA'));
  assert.equal(r.state('LIVE','AAA').entryPending,0);
});
test('LOAD CFG retains protection and open pending state',()=>{
  const r=runtime();r.run('Buy MIB Bid SL');const t=r.state('LIVE','AAA');r.run('Set Global Variables');assert.equal(r.state('LIVE','AAA'),t);assert.equal(t.entryPending,1);
});
test('cancel all and GTFO only cancel selected account and symbol',()=>{
  for(const label of ['Cancel All','Cancel All No Stops','GTFO']) {
    const r=runtime();r.position('LIVE','AAA',-100);r.run(label);
    assert(r.cancels.length>0);assert(r.cancels.every(c=>c.account==='LIVE'&&c.symbol==='AAA'&&c.flag==='BUY|SELL'));
    if(label==='GTFO'){assert.equal(r.orders[0].Side,'B');assert.equal(r.orders[0].Share,100);}
  }
});
test('timer retries protection while average is unavailable',()=>{
  const r=runtime();r.run('Buy MIB Bid SL');r.position('LIVE','AAA',100,0);r.tick();r.tick();
  assert.equal(r.state('LIVE','AAA').entryStage,2);assert.equal(r.orders.length,1);
  r.position('LIVE','AAA',100,10);r.tick();assert.equal(r.orders.length,2);
});
test('inactive registry slots are reusable across a long trading session',()=>{
  const r=runtime();for(let i=0;i<225;i++){const s='T'+i;r.select('LIVE',s);r.position('LIVE',s,0);r.quote(s);r.run('Check Global Guards');}
  assert.equal(r.ctx.$tradeSlotCount,1);assert.equal(r.ctx.$trade_ok,1);
});
test('timer cannot clobber an action during a cancel wait',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Auto Stop');r.run('Set Take Profit');
  r.select('LIVE','BBB');r.position('LIVE','BBB',100,20);r.quote('BBB',20,20.02,20);
  r.waitHook=()=>r.tick();r.run('Set Auto Stop');
  assert.equal(r.orders.at(-1).Symbol,'BBB');assert.equal(r.orders.at(-1).StopPrice,19.8);assert.equal(r.ctx.$tradeActionDepth,0);
});
test('alert arriving during another trade wait is deferred without changing context',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Take Profit');const alert=[...r.alerts.values()][0];
  r.select('LIVE','BBB');r.position('LIVE','BBB',100,20);r.quote('BBB',20,20.02,20);
  r.waitHook=()=>{r.waitHook=null;r.execute(alert.Script);};r.run('Set Auto Stop');
  assert.equal(r.orders[0].Symbol,'BBB');assert.equal(r.state('LIVE','AAA').deferredTp,1);
  r.sendHook=o=>{if(o.Symbol==='AAA'&&o.Type==='L'){r.position('LIVE','AAA',50);o.Open=0;}};
  r.tick();assert(r.orders.some(o=>o.Symbol==='AAA'&&o.Type==='L'));assert.equal(r.ctx.$tradeActionDepth,0);
});
test('interrupted-action lease expires so the timer can resume',()=>{
  const r=runtime();r.ctx.$tradeActionDepth=1;r.ctx.$tradeActionUntil=36030;r.seconds=36031;r.tick();assert.equal(r.ctx.$tradeActionDepth,0);
});
test('Cancel All invalidates an already captured TP payload',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Take Profit');const al=[...r.alerts.values()][0];
  r.run('Cancel All');const n=r.orders.length;r.execute(al.Script);assert.equal(r.orders.length,n);
});
test('a full manual long exit removes only its own alerts',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Take Profit');
  r.select('TRSIM','AAA');r.position('TRSIM','AAA',200);r.run('Set Take Profit');
  r.select('LIVE','AAA');r.run('Sell 1/1 Ask');assert.equal(r.alerts.size,1);
  assert.equal([...r.alerts.values()][0].Name,'TP 1R Partial TRSIM AAA');
});
for(const label of buyLabels) test(label+' protects its entry while a short is open elsewhere',()=>{
  const r=runtime();r.position('LIVE','SHORT',-200);r.quote('SHORT');r.run(label);
  const entry=r.orders[0];assert(entry);assert.equal(entry.Side,'B');assert.equal(entry.Symbol,'AAA');
  r.position('LIVE','AAA',entry.Share,entry.Price);r.select('LIVE','SHORT');for(let i=0;i<4;i++)r.tick();
  const stop=r.orders.find(o=>o.Type==='SLP');assert(stop);assert.equal(stop.Symbol,'AAA');assert.equal(stop.Share,entry.Share);
});
test('inline entry mode sizes protection from actual fills, not a rejected order open=0',()=>{
  const r=runtime();r.ctx.$useTimerArming=0;r.sendHook=o=>{o.Open=0;};r.run('Buy MIB Bid SL');
  assert.equal(r.orders.length,1);assert.equal(r.state('LIVE','AAA').active,0);assert.equal(r.ctx.$tradeActionDepth,0);
  r.sendHook=o=>{if(o.Side==='B'){r.position('LIVE','AAA',40,10);o.Open=0;}};r.run('Buy MIB Bid SL');
  assert.equal(r.orders.at(-1).Type,'SLP');assert.equal(r.orders.at(-1).Share,40);
});
for(const label of [...scripts.keys()].filter(s=>/^Short T|^Cover /.test(s))) test(label+' cancellation is account scoped',()=>{
  const r=runtime();r.position('LIVE','AAA',-100);r.run(label);
  assert(r.cancels.length>0);assert(r.cancels.every(c=>c.account==='LIVE'&&c.symbol==='AAA'&&c.flag==='BUY|SELL'));
});
test('manual full sell and GTFO suspend pending entry staging',()=>{
  for(const label of ['Sell 1/1 Ask','GTFO']) {
    const r=runtime();r.run('Buy MIB Bid SL');r.position('LIVE','AAA',100);r.run(label);
    const n=r.orders.length;r.tick();r.tick();assert.equal(r.orders.length,n);
    assert.equal(r.state('LIVE','AAA').entryPending,0);
  }
});
test('short entry after a canceled long buy clears the pending long context',()=>{
  const r=runtime();r.run('Buy MIB Bid SL');r.run('Short T1 Bid');r.position('LIVE','AAA',-100);r.tick();
  assert.equal(r.state('LIVE','AAA').entryPending,0);assert(!r.orders.some(o=>o.Type==='SLP'));
});
test('GTFO pressed during a wait executes as soon as that action finishes',()=>{
  const r=runtime();r.position('LIVE','AAA',100);
  r.waitHook=()=>{r.waitHook=null;r.run('GTFO');};r.run('Set Auto Stop');
  const exit=r.orders.at(-1);assert.equal(exit.Type,'L');assert.equal(exit.Side,'S');assert.equal(exit.Share,100);assert.equal(exit.Price,9.5);
  assert.equal(r.ctx.$tradeActionDepth,0);assert.equal(r.ctx.GTFO_PENDING_ACCOUNT,'');
});
test('queued GTFO keeps its account/symbol even if the montage changes again',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.position('TRSIM','SHORT',-75);r.quote('SHORT');
  r.waitHook=()=>{r.waitHook=null;r.select('TRSIM','SHORT');r.run('GTFO');r.select('LIVE','AAA');};r.run('Set Auto Stop');
  const exit=r.orders.at(-1);assert.equal(exit.Account,'TRSIM');assert.equal(exit.Symbol,'SHORT');assert.equal(exit.Side,'B');assert.equal(exit.Share,75);
  assert.equal(r.symbol,'AAA');assert.equal(r.state('LIVE','AAA').lastStop,9.8);
});
test('Show Config reports account shares and does not read removed runtime variables',()=>{
  const r=runtime();r.position('LIVE','AAA',-100);r.availableOverride=0;r.run('Show Config');
  assert(r.logs.some(s=>s.includes('Account signed shares: -100')));assert.equal(r.ctx.$tradeActionDepth,0);
});
// Syntax-check all mapped scripts after translating native DAS statements.
for(const f of new Set(scripts.values())) new vm.Script('(function(){'+translate(fs.readFileSync(path.join(root,f),'utf8'))+'})()',{filename:f});
console.log(`${count} trade-isolation regression scenarios passed; ${scripts.size} hotkeys parsed.`);
