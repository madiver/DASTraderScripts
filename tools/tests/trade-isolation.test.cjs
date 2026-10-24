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
    .replace(/Price=Round([234]);/g, 'Price=Round(Price,$1);')
    // DAS evaluates both logical operands; do not hide missing-object errors.
    .replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\/\/[^\r\n]*|\/\*[\s\S]*?\*\/|&&|\|\|/g,
      token=>token==='&&'?'&':token==='||'?'|':token);
}
function runtime() {
  const r = {positions:new Map(), quotes:new Map(), alerts:new Map(), orders:[], cancels:[], logs:[],
    missing:new Set(), waitHook:null, sendHook:null, cancelHook:null, account:'LIVE', symbol:'AAA', secondary:null,
    ignoreStrictRefFilter:true,
    seconds:36000, waits:[], montageQuotes:new Map(), calls:{window:0,position:0,quote:0}};
  r.cancel=o=>{o.canceled=true;if(r.cancelHook)r.cancelHook(o);else o.Open=0;};
  const key = (a,s) => a+'|'+s;
  r.position = (a,s,share,avg=10) => r.positions.set(key(a,s),object({Share:share,AvgCost:avg}));
  r.quote = (s,bid=10,ask=10.02,last=10) => r.quotes.set(s,object({Bid:bid,Ask:ask,Last:last}));
  r.select = (a,s) => {r.account=a;r.symbol=s;};
  r.state = (a,s) => r.ctx.$tradeStates.Get(key(a,s));
  r.bind = (a,s) => {r.ctx.SetVar('TRADE_CONTEXT_ACCOUNT',a);r.ctx.SetVar('TRADE_CONTEXT_SYMBOL',s);};
  const montage = secondary => new Proxy({}, {
    get(_t,k) {
      const a=secondary?r.secondary?.account:r.account, s=secondary?r.secondary?.symbol:r.symbol;
      const p=r.positions.get(key(a,s)), q=r.montageQuotes.get(s)||r.quotes.get(s);
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
    GetWindowObj:n=>{r.calls.window++;return n==='Primary_OE'?primary:n==='Secondary_OE' && r.secondary?secondary:0;},
    GetAccountObj:a=>r.missing.has(a)?0:object({
      GetPosition:s=>{r.calls.position++;return r.missing.has(key(a,s))?0:r.positions.get(key(a,s))||0;},
      CancelOrder:(f,s,p)=>{r.cancels.push({account:a,symbol:s,flag:f});
        for(const o of r.orders) if(o.Account===a && o.Symbol===s &&
          (f==='BUY|SELL'||f==='BUY'&&o.Side==='B'||f==='SELL'&&o.Side==='S')) r.cancel(o);
      }
    }),
    GetQuoteObj:s=>{r.calls.quote++;return r.quotes.get(s)||0;}, GetSecond:()=>Math.floor(r.seconds)%86400,
    GetOrderObj:filter=>{
      const fields=Object.fromEntries(filter.split(',').map(s=>s.split('=')));
      const ref=filter.match(/RefNum(>=|=|>)(\d+)/);
      const matches=o=>!ref||ref[1]==='>'&&r.ignoreStrictRefFilter||
        (ref[1]==='>='?o.RefNum>=Number(ref[2]):ref[1]==='>'?o.RefNum>Number(ref[2]):o.RefNum===Number(ref[2]));
      return r.orders.filter(o=>o.Account===fields.Acc&&o.Symbol===fields.Symb&&matches(o))
        .sort((a,b)=>a.RefNum-b.RefNum)[0]||0;
    },
    Round:(n,prec,inc)=>prec===102?Math.round(n/inc)*inc:Math.round(n*10**prec)/10**prec,
    Wait:ms=>{r.waits.push(ms);r.seconds+=ms/1000;if(r.waitHook) r.waitHook(ms);}, FocusWindow:()=>{},
    NativeCancel:()=>{throw new Error('Unscoped native cancellation');},
    NativeReverse:()=>{
      const pos=r.positions.get(key(r.account,r.symbol))?.Share||0;
      const o=object({Account:r.account,Symbol:r.symbol,Side:pos<0?'B':'S',Share:ctx.Share,Price:ctx.Price,Route:ctx.ROUTE,
        Type:'L',Open:ctx.Share,RefNum:r.orders.length+1,GetInfo(){},Cancel(){r.cancel(o);}});
      r.orders.push(o);if(r.sendHook)r.sendHook(o);
    },
    NewOrderObj:()=>{
      let o=object({Open:1, Send(){o.Open=o.Share;o.RefNum=r.orders.length+1;r.orders.push(o);if(r.sendHook)r.sendHook(o);},
        Cancel(){r.cancel(o);},GetInfo(){}});return o;
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
  vm.runInContext(`for (const field of ['kind','priority','direction','fraction','exitPending','active','entryPending','closeManaged','closePriority']) {
    Object.defineProperty(Number.prototype, field, {get(){throw new Error('Missing Object: '+field);}});
  }`,ctx);
  r.runFile=f=>vm.runInContext('(function(){\n'+translate(fs.readFileSync(path.join(root,f),'utf8'))+'\n})()',ctx,{filename:f,timeout:1000});
  ctx.ExecHotkey=ctx.ExecHotKey=label=>{assert(scripts.has(label),'Unknown hotkey: '+label);r.runFile(scripts.get(label));};
  r.run=ctx.ExecHotkey;
  r.execute=s=>vm.runInContext(translate(s),ctx,{timeout:1000});
  r.tick=()=>{r.seconds+=1;r.runFile('other scripts/timer.das');};
  r.run('Set Global Variables');r.quote('AAA');r.position('LIVE','AAA',0);
  return r;
}
let count=0;
function test(name,f) {try{f();count++;}catch(e){console.error('FAIL:',name);throw e;}}
const buyLabels=[...scripts.keys()].filter(s=>/^Buy .* SL$/.test(s));
const longLabels=[...scripts.keys()].filter(s=>!['Set Auto Stop','Set Auto Stop BE 1/1','Set Take Profit'].includes(s)&&/^Sell |^Set Auto Stop/.test(s));
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
test('flat montage cannot clear another long stop/TP',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Auto Stop');r.run('Set Take Profit');
  const t=r.state('LIVE','AAA');const last=t.lastStop, names=[...r.alerts.keys()];
  r.select('LIVE','FLAT');r.position('LIVE','FLAT',0);for(let i=0;i<6;i++)r.tick();
  assert.equal(t.lastStop,last);assert.deepEqual([...r.alerts.keys()],names);
});
test('same symbol in LIVE and SIM has separate stops and alerts',()=>{
  const r=runtime();r.position('LIVE','AAA',100,10);r.run('Set Auto Stop');r.run('Set Take Profit');
  r.select('TRSIM','AAA');r.position('TRSIM','AAA',200,11);r.run('Set Auto Stop');r.run('Set Take Profit');
  assert.equal(r.alerts.size,2);assert.notEqual(r.state('LIVE','AAA').lastStop,r.state('TRSIM','AAA').lastStop);
  r.position('TRSIM','AAA',0);r.tick();assert.equal(r.alerts.size,1);assert.equal(r.state('LIVE','AAA').lastStop,9.5);
});
test('TP alert uses its account while montage shows another short',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Take Profit');const al=[...r.alerts.values()][0];
  r.position('TRSIM','SHORT',-200);r.quote('SHORT');r.select('TRSIM','SHORT');
  r.sendHook=o=>{if(o.Side==='S'&&o.Type==='L'){r.position(o.Account,o.Symbol,50);o.Open=0;}};
  r.execute(al.Script);
  assert(r.orders.length>=1);assert(r.orders.every(o=>o.Account==='LIVE'&&o.Symbol==='AAA'));
  assert.equal(r.account,'TRSIM');assert.equal(r.symbol,'SHORT');assert.equal(r.ctx.TP_SYMBOL,'');
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
for(const [avg,distance,trigger,limit] of [[10,0.5,10.5,10.6],[0.428,0.1,0.528,0.628],
  [0.18,0.1,0.28,0.38],[0.957,0.1,1.06,1.16],[0.2,0.01,0.21,0.31]]) {
  test('RESET protects signed short size at average '+avg+' with distance '+distance,()=>{
    const r=runtime();r.position('LIVE','AAA',-125,avg);r.availableOverride=0;
    r.ctx.$stopLossTrigger=distance;r.run('Set Auto Stop');
    assert.equal(r.orders.length,1);const o=r.orders[0];
    assert.equal(o.Account,'LIVE');assert.equal(o.Symbol,'AAA');assert.equal(o.Side,'B');
    assert.equal(o.Share,125);assert.equal(o.Route,'STOP');assert.equal(o.Type,'SLP');assert.equal(o.Tif,'DAY+');
    assert(Math.abs(o.StopPrice-trigger)<1e-8);assert(Math.abs(o.Price-limit)<1e-8);
    assert(o.Price>o.StopPrice);assert.equal(r.ctx.$stopSubmitted,1);
    assert.equal(r.state('LIVE','AAA').Get('shortStopOrder'),o);
    assert.deepEqual(r.cancels,[{account:'LIVE',symbol:'AAA',flag:'BUY'}]);
    assert.equal(r.ctx.$tradeActionDepth,0);
  });
}
for(const distance of [0.1,0.2,0.3,0.5]) test('RESET short uses the existing '+distance+' stop preset',()=>{
  const r=runtime();r.position('LIVE','AAA',-20,10);
  r.run('Set '+distance.toFixed(2)+' Stop');r.run('Set Auto Stop');
  assert(Math.abs(r.orders[0].StopPrice-(10+distance))<1e-8);
});
for(const offset of [0,-0.1,0.00001]) test('RESET short limit stays above its trigger with offset '+offset,()=>{
  const r=runtime();r.position('LIVE','AAA',-25,10);r.ctx.$exitOffset=offset;r.run('Set Auto Stop');
  assert.equal(r.orders.length,1);assert.equal(r.orders[0].StopPrice,10.5);assert.equal(r.orders[0].Price,10.51);
});
for(const initial of [-100,100]) for(const remaining of [0,-initial/2]) {
  test('RESET aborts if signed position '+initial+' changes direction or becomes flat at '+remaining,()=>{
    const r=runtime();r.position('LIVE','AAA',initial,10);
    r.waitHook=()=>r.position('LIVE','AAA',remaining,10);r.run('Set Auto Stop');
    assert.equal(r.orders.length,0);assert.equal(r.ctx.$stopSubmitted,0);assert.equal(r.ctx.$tradeActionDepth,0);
  });
}
test('RESET short uses refreshed size and average without following a montage switch',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('BBB');r.position('TRSIM','BBB',100,20);
  r.waitHook=()=>{r.position('LIVE','AAA',-30,10.2);r.select('TRSIM','BBB');};r.run('Set Auto Stop');
  assert.equal(r.orders.length,1);const o=r.orders[0];
  assert.equal(o.Account,'LIVE');assert.equal(o.Symbol,'AAA');assert.equal(o.Side,'B');assert.equal(o.Share,30);
  assert(Math.abs(o.StopPrice-10.7)<1e-8);assert.equal(r.account,'TRSIM');assert.equal(r.symbol,'BBB');
});
test('RESET short refuses missing average, invalid distance, or unknown signed position before cancellation',()=>{
  for(const invalid of ['average','distance','position']) {
    const r=runtime();r.position('LIVE','AAA',-100,invalid==='average'?0:10);
    if(invalid==='distance')r.ctx.$stopLossTrigger=0;
    if(invalid==='position'){r.missing.add('LIVE|AAA');r.availableOverride=0;}
    r.run('Set Auto Stop');assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);
  }
  const flat=runtime();flat.run('Set Auto Stop');assert.equal(flat.orders.length,0);assert.equal(flat.cancels.length,0);
});
test('RESET short replaces its old stop and waits for cancellation acknowledgment',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');const first=r.orders[0];
  r.cancelHook=()=>{};r.position('LIVE','AAA',-50,10);r.run('Set Auto Stop');
  assert.equal(r.orders.length,1);assert.equal(r.ctx.$stopSubmitted,0);
  assert.equal(r.state('LIVE','AAA').Get('shortStopOrder'),first);
  assert(r.logs.some(s=>s.includes('cancellation pending')));
  first.Open=0;r.cancelHook=null;r.run('Set Auto Stop');
  assert.equal(r.orders.length,2);assert.equal(r.orders[1].Share,50);assert.equal(first.canceled,true);
});
test('timer retains a RESET short stop across configuration reload without arming long protection',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');const o=r.orders[0];
  const t=r.state('LIVE','AAA');r.run('Set Global Variables');
  r.select('TRSIM','OTHER');r.quote('OTHER');r.position('TRSIM','OTHER',100,20);
  for(let i=0;i<5;i++)r.tick();
  assert.equal(r.orders.length,1);assert.equal(o.Open,100);assert.equal(o.canceled,undefined);
  assert.equal(t.lastStop,10.5);assert.equal(t.stopArmed,1);assert.equal(t.Get('shortStopOrder'),o);
  assert.equal(r.alerts.size,1);assert.equal([...r.alerts.values()][0].condition.op,'<');
});
for(const remaining of [0,100]) test('timer cancels only its stale short stop when position becomes '+remaining,()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');const stop=r.orders[0];
  r.position('LIVE','OTHER',-100,20);r.quote('OTHER');r.select('LIVE','OTHER');r.run('Set Auto Stop');const other=r.orders[1];
  r.position('LIVE','AAA',remaining,10);r.cancelHook=o=>{if(o===stop)stop.Open=100;};r.tick();
  assert.equal(stop.canceled,true);assert.equal(other.canceled,undefined);assert.equal(r.orders.length,2);
  assert.equal(r.state('LIVE','AAA').Get('shortStopOrder'),stop);
  stop.Open=0;r.cancelHook=null;r.tick();
  assert.equal(r.state('LIVE','AAA').Get('shortStopOrder'),0);
  assert.equal(r.state('LIVE','AAA').active,0);assert.equal(r.orders.length,2);
});
test('RESET short clears old long alerts and pending staging',()=>{
  const r=runtime();r.position('LIVE','AAA',100,10);r.run('Set Take Profit');const alert=[...r.alerts.values()][0];
  const t=r.state('LIVE','AAA');t.entryPending=1;t.entryStage=2;
  r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');r.execute(alert.Script);r.tick();
  assert.equal(r.orders.length,1);assert.equal(r.orders[0].Side,'B');assert.equal(r.orders[0].canceled,undefined);
  assert.equal(t.entryPending,0);assert.equal(t.entryWatch,0);assert.equal(r.alerts.size,1);
  assert.equal([...r.alerts.values()][0].condition.op,'<');
});
test('manual short protection does not occupy the single-long guard',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');
  r.select('LIVE','BBB');r.quote('BBB');r.position('LIVE','BBB',0);r.run('Buy MIB Ask SL');
  assert.equal(r.orders.length,2);assert.equal(r.orders[1].Symbol,'BBB');assert.equal(r.orders[1].Side,'B');
});
for(const label of ['Cancel All No Stops','Cover 1/1 Ask+','Cover 1/2 Ask+','Cover 1/4 Bid']) {
  test(label+' cancels RESET short protection without automatically rearming it',()=>{
    const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');const stop=r.orders[0];
    r.run(label);const count=r.orders.length;
    for(let i=0;i<3;i++)r.tick();
    assert.equal(stop.canceled,true);assert.equal(r.state('LIVE','AAA').Get('shortStopOrder'),0);
    assert.equal(r.orders.length,count);assert.equal(r.orders.filter(o=>o.Type==='SLP').length,1);
  });
}
for(const route of ['AUTOL','FREE1L','BESTL','SMRTL','ARCA1L']) test('RESET short keeps STOP independent of '+route,()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.ctx.$orderRoute=route;r.run('Set Auto Stop');
  assert.equal(r.orders[0].Route,'STOP');assert.equal(r.ctx.$orderRoute,route);
});
test('long timer mode cannot automatically arm a short stop',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.ctx.$timerMode=1;r.run('Set Auto Stop');
  assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);assert.equal(r.ctx.$stopSubmitted,0);
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
  assert.equal(r.state('LIVE','AAA').lastStop,9.5);assert.equal(r.state('LIVE','BBB').lastStop,19.5);
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
    assert(r.cancels.length>0);assert(r.cancels.every(c=>c.account==='LIVE'&&c.symbol==='AAA'));
    assert.equal(r.cancels[0].flag,'BUY|SELL');
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
  assert.equal(r.orders.at(-1).Symbol,'BBB');assert.equal(r.orders.at(-1).StopPrice,19.5);assert.equal(r.ctx.$tradeActionDepth,0);
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
  assert.equal(r.state('LIVE','AAA').entryPending,0);
  assert(!r.orders.some(o=>o.Type==='SLP'&&o.Side==='S'));
  assert.equal(r.orders.at(-1).Type,'SLP');assert.equal(r.orders.at(-1).Side,'B');
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
  assert.equal(r.symbol,'AAA');assert.equal(r.state('LIVE','AAA').lastStop,9.5);
});
test('Show Config reports account shares and does not read removed runtime variables',()=>{
  const r=runtime();r.position('LIVE','AAA',-100);r.availableOverride=0;r.run('Show Config');
  assert(r.logs.some(s=>s.includes('Account signed shares: -100')));assert.equal(r.ctx.$tradeActionDepth,0);
});
for(const label of ['Sell 1/2 Ask','Sell 1/4 Ask','Sell 1/2 Bid-','Sell 1/4 Bid-']) {
  test(label+' yields immediately and protects actual remaining shares on timer',()=>{
    const r=runtime();r.position('LIVE','AAA',101);r.run(label);
    const exit=r.orders[0];assert.equal(exit.Share,label.includes('1/2')?50:25);
    assert.deepEqual(r.waits,[100]);assert.equal(r.ctx.$tradeActionDepth,0);
    r.position('LIVE','AAA',101-exit.Share);exit.Open=0;
    r.select('TRSIM','SHORT');r.position('TRSIM','SHORT',-75);r.quote('SHORT');
    r.tick();const stop=r.orders.at(-1);
    assert.equal(stop.Type,'SLP');assert.equal(stop.Share,101-exit.Share);
    assert.equal(stop.Account,'LIVE');assert.equal(stop.Symbol,'AAA');
    assert.equal(r.state('LIVE','AAA').exitPending,0);assert.deepEqual(r.waits,[100]);
  });
}
test('no-fill partial exit times out without blocking GTFO or timer with Wait',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');const exit=r.orders[0];
  r.tick();assert.equal(r.orders.length,1);r.tick();
  assert(exit.canceled);assert.equal(r.orders.at(-1).Share,100);
  assert.equal(r.state('LIVE','AAA').exitPending,0);assert.deepEqual(r.waits,[100]);
});
test('delayed residual cancellation holds protection until acknowledgment',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Bid-');const exit=r.orders[0];
  r.position('LIVE','AAA',80);exit.Open=30;r.cancelHook=()=>{};
  r.tick();r.tick();r.tick();assert.equal(r.orders.length,1);
  assert.equal(r.state('LIVE','AAA').exitPending,1);
  // Late fill while cancel is pending: protection must use the resulting size.
  r.position('LIVE','AAA',70);exit.Open=0;r.tick();
  assert.equal(r.orders.at(-1).Share,70);assert.equal(r.state('LIVE','AAA').exitPending,0);
});
test('GTFO immediately interrupts a timer-owned partial; it never rearms later',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');const exit=r.orders[0];
  r.run('GTFO');assert(exit.canceled);assert.equal(r.orders.at(-1).Share,100);
  const n=r.orders.length;for(let i=0;i<5;i++)r.tick();assert.equal(r.orders.length,n);
  assert.equal(r.state('LIVE','AAA').exitPending,0);assert.deepEqual(r.waits,[100,100]);
});
test('Cancel All No Stops prevents timer-owned exit from resurrecting protection',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Bid-');r.run('Cancel All No Stops');
  const n=r.orders.length;for(let i=0;i<5;i++)r.tick();assert.equal(r.orders.length,n);
  assert.equal(r.state('LIVE','AAA').exitPending,0);assert.equal(r.alerts.size,0);
});
test('unacknowledged exit cancellation logs once and keeps GTFO available',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');r.cancelHook=()=>{};
  for(let i=0;i<32;i++)r.tick();
  assert.equal(r.logs.filter(s=>s.includes('Exit cancellation still pending')).length,1);
  assert.equal(r.orders.length,1);assert.equal(r.ctx.$tradeActionDepth,0);
  r.run('GTFO');assert.equal(r.orders.at(-1).Share,100);
});
test('pending exit blocks duplicate partial, same-symbol entry and manual stop',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');
  const n=r.orders.length,c=r.cancels.length;
  r.run('Sell 1/4 Bid-');r.run('Buy MIB Bid SL');r.run('Set Auto Stop');r.run('Set Take Profit');
  assert.equal(r.orders.length,n);assert.equal(r.cancels.length,c);assert.equal(r.ctx.$tradeActionDepth,0);
});
test('flat or reversed position during pending exit never receives a new SELL stop',()=>{
  for(const size of [0,-25]) {
    const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');r.position('LIVE','AAA',size);
    r.tick();assert.equal(r.orders.length,1);assert.equal(r.state('LIVE','AAA').active,0);
    assert(r.orders[0].canceled);
  }
});
test('missing position data still cancels a timed-out exit but does not invent protection',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');
  r.missing.add('LIVE|AAA');r.select('TRSIM','SHORT');r.position('TRSIM','SHORT',-100);r.quote('SHORT');
  r.tick();r.tick();assert(r.orders[0].canceled);assert.equal(r.orders.length,1);
  assert.equal(r.state('LIVE','AAA').exitPending,1);
  r.missing.clear();r.position('LIVE','AAA',85);r.tick();assert.equal(r.orders.at(-1).Share,85);
});
test('timer-owned exits are independent for the same symbol in two accounts',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');const a=r.orders[0];
  r.select('TRSIM','AAA');r.position('TRSIM','AAA',200);r.run('Sell 1/4 Bid-');const b=r.orders[1];
  r.position('LIVE','AAA',50);a.Open=0;r.position('TRSIM','AAA',150);b.Open=0;r.tick();
  const stops=r.orders.filter(o=>o.Type==='SLP');assert.equal(stops.length,2);
  assert.equal(stops.find(o=>o.Account==='LIVE').Share,50);assert.equal(stops.find(o=>o.Account==='TRSIM').Share,150);
});
test('LOAD CFG retains pending exit order and timer resumes it',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');const t=r.state('LIVE','AAA');
  r.run('Set Global Variables');assert.equal(t.exitPending,1);assert.equal(t.exitOrder,r.orders[0]);
  r.position('LIVE','AAA',50);r.orders[0].Open=0;r.tick();assert.equal(t.exitPending,0);
});
test('retained legacy context initializes performance fields on its first timer visit',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Auto Stop');const t=r.state('LIVE','AAA');
  t.Del('performanceStateVersion');delete t.exitPending;r.tick();
  assert.equal(t.exitPending,0);assert.equal(t.Get('performanceStateVersion'),1);
  assert.equal(t.lastStop,9.5);
});
test('cancel acknowledgment with a final fill uses a fresh TP position delta',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.quote('AAA',10.5,10.52,10.5);r.run('Set Take Profit');
  const al=[...r.alerts.values()][0];r.execute(al.Script);r.position('LIVE','AAA',80);
  r.cancelHook=o=>{o.Open=0;r.position('LIVE','AAA',50);};
  r.tick();r.tick();r.tick();assert.equal(r.orders.at(-1).Share,50);
  assert.equal(r.orders.at(-1).StopPrice,10.03);
});
test('TP full fill uses BE, while partial fill or rejection restores fixed stop and TP',()=>{
  for(const remaining of [50,80,100]) {
    const r=runtime();r.position('LIVE','AAA',100);r.quote('AAA',10.5,10.52,10.5);
    r.run('Set Take Profit');const al=[...r.alerts.values()][0];r.alerts.delete(al.Name);
    r.execute(al.Script);const exit=r.orders[0];r.execute(al.Script);assert.equal(r.orders.length,1);
    assert.deepEqual(r.waits,[300]);assert.equal(r.ctx.$tradeActionDepth,0);
    r.position('LIVE','AAA',remaining);exit.Open=0;r.tick();
    assert.equal(r.orders.at(-1).Share,remaining);
    assert.equal(r.orders.at(-1).StopPrice,remaining===50?10.03:9.5);
    assert.equal(r.alerts.size,remaining===50?0:1);assert.deepEqual(r.waits,[300]);
  }
});
test('exit timeout handles midnight rollover',()=>{
  const r=runtime();r.seconds=86399;r.position('LIVE','AAA',100);r.run('Sell 1/2 Ask');
  r.tick();assert.equal(r.orders.length,1);r.tick();assert(r.orders[0].canceled);
  assert.equal(r.orders.at(-1).Type,'SLP');
});
test('fresh entry arms stop and TP on first fill tick without cancelling SELLs',()=>{
  const r=runtime();r.run('Buy MIB Bid SL');r.orders[0].Open=0;r.position('LIVE','AAA',100);
  r.tick();assert.equal(r.orders.at(-1).Type,'SLP');assert.equal(r.alerts.size,1);
  assert(!r.cancels.some(c=>c.flag==='SELL'));assert.deepEqual(r.waits,[]);
});
test('fresh entry with a working manual SELL preserves cancellation staging',()=>{
  const r=runtime();const old=r.ctx.NewOrderObj();old.Account='LIVE';old.Symbol='AAA';old.Side='S';old.Share=100;old.Send();
  r.run('Buy MIB Bid SL');r.position('LIVE','AAA',100);r.tick();
  assert(old.canceled);assert(!r.orders.some(o=>o.Type==='SLP'));r.tick();
  assert.equal(r.orders.at(-1).Type,'SLP');
});
test('scale-in keeps separate cancel and protection ticks',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.quote('AAA',10.6,10.62,10.6);r.run('Set Auto Stop');
  r.run('Buy MIB Bid SL');r.position('LIVE','AAA',200,10.15);const n=r.orders.length;r.tick();
  assert.equal(r.orders.length,n);r.tick();assert.equal(r.orders.at(-1).Share,200);
});
test('bounded order history fails conservatively to normal entry staging',()=>{
  const r=runtime();for(let i=0;i<201;i++){
    const o=r.ctx.NewOrderObj();o.Account='LIVE';o.Symbol='AAA';o.Side='B';o.Share=1;o.Send();o.Open=0;
  }
  r.run('Buy MIB Bid SL');r.position('LIVE','AAA',100);const n=r.orders.length;r.tick();
  assert.equal(r.orders.length,n);r.tick();assert.equal(r.orders.at(-1).Type,'SLP');
});
test('late entry fill after first fast stop is still detected and resized',()=>{
  const r=runtime();r.run('Buy MIB Bid SL');r.position('LIVE','AAA',40);r.tick();
  assert.equal(r.orders.at(-1).Share,40);r.position('LIVE','AAA',100);r.tick();r.tick();
  assert.equal(r.orders.at(-1).Share,100);
});
test('inline entry skips padding but rejects an immediate second entry until cooldown',()=>{
  const r=runtime();r.ctx.$useTimerArming=0;r.sendHook=o=>{if(o.Side==='B'){r.position('LIVE','AAA',100);o.Open=0;}};
  r.run('Buy MIB Bid SL');assert.deepEqual(r.waits,[100,350]);
  r.quote('AAA',10.6,10.62,10.6);r.run('Check Global Guards');assert.equal(r.ctx.$trade_ok,0);
  r.seconds=36001;r.run('Check Global Guards');assert.equal(r.ctx.$trade_ok,1);
  assert(!r.waits.includes(1000));
});
test('entry cooldown is independent by account and rolls across midnight',()=>{
  const r=runtime();r.ctx.$useTimerArming=0;r.run('Check Global Guards');r.state('LIVE','AAA').lastEntrySecond=86400;
  r.seconds=86399;r.run('Check Global Guards');assert.equal(r.ctx.$trade_ok,0);
  r.select('TRSIM','AAA');r.position('TRSIM','AAA',0);r.run('Check Global Guards');assert.equal(r.ctx.$trade_ok,1);
  r.select('LIVE','AAA');r.seconds=86400;r.run('Check Global Guards');assert.equal(r.ctx.$trade_ok,1);
});
test('ten idle timer ticks fetch only fresh positions; no quote or montage lookups',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Auto Stop');
  r.calls={window:0,position:0,quote:0};r.waits=[];
  for(let i=0;i<10;i++)r.tick();
  assert.deepEqual(r.calls,{window:0,position:10,quote:0});assert.deepEqual(r.waits,[]);
});
test('full reader skips montage fallback for complete account and quote data',()=>{
  const r=runtime();r.run('Check Global Guards');r.calls={window:0,position:0,quote:0};
  r.run('Read Trade Position');assert.deepEqual(r.calls,{window:0,position:1,quote:1});
});
test('position-only reader clears stale quotes and its mode cannot leak',()=>{
  const r=runtime();r.run('Check Global Guards');r.run('Read Position Only');assert.equal(r.ctx.$tradeBid,0);
  r.run('Read Trade Position');assert.equal(r.ctx.$tradeBid,10);
  r.bind('LIVE','');r.run('Load Position Context');assert.equal(r.ctx.$tradeContextValid,0);
  r.run('Load Trade Context');assert.equal(r.ctx.$tradeBid,10);
});
test('missing quote still uses matching montage fallback without crossing contexts',()=>{
  const r=runtime();r.run('Check Global Guards');r.quotes.delete('AAA');
  r.montageQuotes.set('AAA',object({Bid:10.1,Ask:10.12,Last:10.1}));r.run('Read Trade Position');
  assert.equal(r.ctx.$tradeBid,10.1);assert.equal(r.ctx.$posNow,0);assert.equal(r.ctx.$tradePositionValid,1);
  r.select('TRSIM','SHORT');r.position('TRSIM','SHORT',-100);r.quote('SHORT',50,50.02,50);
  r.run('Read Trade Position');assert.equal(r.ctx.$tradeBid,0);assert.equal(r.ctx.$posNow,0);
});
for(const label of buyLabels) test(label+' inline protection has no throttle padding',()=>{
  const r=runtime();r.ctx.$useTimerArming=0;r.sendHook=o=>{
    if(o.Side==='B'){r.position(o.Account,o.Symbol,o.Share,o.Price);o.Open=0;}
  };
  r.run(label);assert.deepEqual(r.waits,[100,350]);
  assert.equal(r.orders.at(-1).Type,'SLP');assert.equal(r.orders.at(-1).Share,r.orders[0].Share);
});

for(let tier=1;tier<=4;tier++) for(const offset of [-0.03,-0.02,-0.01,0.01,0.03]) {
  test('Bid- short tier '+tier+' applies signed offset '+offset+' and multiplier',()=>{
    const r=runtime();r.ctx.$entryBidOffset=offset;r.ctx.$qtyMult=1.5;
    r.run('Short T'+tier+' Bid-');
    assert.equal(r.orders.length,1);const o=r.orders[0];
    assert.equal(o.Side,'SS');assert.equal(o.Type,'L');
    assert.equal(o.Account,'LIVE');assert.equal(o.Symbol,'AAA');
    assert.equal(o.Share,[100,200,300,500][tier-1]*1.5);
    assert(Math.abs(o.Price-(10-offset))<1e-8);
    assert.equal(r.alerts.size,0);assert.equal(r.ctx.$tradeActionDepth,0);
  });
}
for(let tier=1;tier<=4;tier++) {
  test('Bid- short tier '+tier+' rejects long before cancellation',()=>{
    const r=runtime();r.position('LIVE','AAA',100);r.run('Short T'+tier+' Bid-');
    assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);
  });
}
test('Bid- short adds to an existing short and uses the quote after cancellation',()=>{
  const r=runtime();r.position('LIVE','AAA',-50);r.ctx.$entryBidOffset=0.02;
  r.waitHook=()=>r.quote('AAA',9.9,9.92);r.run('Short T1 Bid-');
  assert.equal(r.orders.length,1);assert(Math.abs(r.orders[0].Price-9.88)<1e-8);
});
test('Bid- short rejects invalid adjusted price and changed montage',()=>{
  const r=runtime();r.quote('AAA',0.01,0.02);r.ctx.$entryBidOffset=0.03;
  r.run('Short T1 Bid-');assert.equal(r.orders.length,0);
  const other=runtime();other.waitHook=()=>other.select('LIVE','BBB');
  other.run('Short T1 Bid-');assert.equal(other.orders.length,0);
});
test('Bid- short rejects missing bid even when a negative offset gives a positive price',()=>{
  const r=runtime();r.ctx.$entryBidOffset=-0.01;r.waitHook=()=>r.quote('AAA',0,0.02);r.run('Short T1 Bid-');assert.equal(r.orders.length,0);
});

for(let tier=1;tier<=4;tier++) for(const offset of [-0.03,-0.02,-0.01,0.01,0.03]) {
  test('Ask- short tier '+tier+' subtracts signed ASK offset '+offset+' across all size states',()=>{
    for(const multiplier of [1,1.5,2,3,0.5]) {
      const r=runtime();r.ctx.$entryAskOffset=offset;r.ctx.$entryBidOffset=0.13;r.ctx.$qtyMult=multiplier;
      r.run('Short T'+tier+' Ask-');
      assert.equal(r.orders.length,1);const o=r.orders[0];
      assert.equal(o.Side,'SS');assert.equal(o.Type,'L');
      assert.equal(o.Account,'LIVE');assert.equal(o.Symbol,'AAA');
      assert.equal(o.Share,[100,200,300,500][tier-1]*multiplier);
      assert(Math.abs(o.Price-(10.02-offset))<1e-8);
      assert.equal(r.alerts.size,0);assert.equal(r.ctx.$tradeActionDepth,0);
    }
  });
}
for(let tier=1;tier<=4;tier++) {
  test('Ask- short tier '+tier+' rejects long before cancellation',()=>{
    const r=runtime();r.position('LIVE','AAA',100);r.run('Short T'+tier+' Ask-');
    assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);
  });
  test('page 3 plain Ask and Bid tier '+tier+' ignore both entry offsets',()=>{
    for(const quote of ['Ask','Bid']) {
      const r=runtime();r.ctx.$entryAskOffset=-0.03;r.ctx.$entryBidOffset=0.03;
      r.run('Short T'+tier+' '+quote);
      assert.equal(r.orders.length,1);assert.equal(r.orders[0].Price,quote==='Ask'?10.02:10);
    }
  });
}
test('Ask- short uses fresh quote after cancellation and adds to an existing short',()=>{
  const r=runtime();r.position('LIVE','AAA',-50);r.ctx.$entryAskOffset=-0.01;
  r.waitHook=()=>r.quote('AAA',9.9,9.92);r.run('Short T1 Ask-');
  assert.equal(r.orders.length,1);assert(Math.abs(r.orders[0].Price-9.93)<1e-8);
});
test('Ask- short rejects missing Ask despite a negative offset, invalid limits, and changed context',()=>{
  const r=runtime();r.ctx.$entryAskOffset=-0.01;r.waitHook=()=>r.quote('AAA',0.01,0);r.run('Short T1 Ask-');
  assert.equal(r.orders.length,0);
  const invalid=runtime();invalid.quote('AAA',0.01,0.02);invalid.ctx.$entryAskOffset=0.03;
  invalid.run('Short T1 Ask-');assert.equal(invalid.orders.length,0);
  const switched=runtime();switched.waitHook=()=>switched.select('LIVE','BBB');
  switched.run('Short T1 Ask-');assert.equal(switched.orders.length,0);
  const turnedLong=runtime();turnedLong.waitHook=()=>turnedLong.position('LIVE','AAA',100);
  turnedLong.run('Short T1 Ask-');assert.equal(turnedLong.orders.length,0);
});
test('Ask- AUTOL uses taking bands when crossing Bid and ARCA when resting',()=>{
  const r=runtime();r.quote('AAA',1,1.02,1);r.ctx.$entryAskOffset=0.04;
  r.run('Set Order Route AUTOL');r.run('Short T1 Ask-');
  assert.equal(r.orders[0].Price,0.98);assert.equal(r.orders[0].Route,'BESTL');
  const passive=runtime();passive.quote('AAA',0.98,0.99,0.99);passive.ctx.$entryAskOffset=-0.03;
  passive.run('Set Order Route AUTOL');passive.run('Short T1 Ask-');
  assert.equal(passive.orders[0].Price,1.02);assert.equal(passive.orders[0].Route,'ARCA1L');
});

test('rollback preserves the requested stop default and removes coordinator helpers',()=>{
  const r=runtime();assert.equal(r.ctx.$stopLossTrigger,0.5);
  assert.equal(r.ctx.$tier1ShareSize,100);assert.equal(r.ctx.$entryBidOffset,0.01);
  for(const label of ['Request Exit','Process Exit','Check Exit Orders','Check Order Closed','Drain Exit Requests'])assert(!scripts.has(label));
  assert(!fs.readFileSync(path.join(root,'other scripts/timer.das'),'utf8').includes('Drain Exit Requests'));
});

const manualExits=[...scripts.keys()].filter(s=>/^Sell |^Cover /.test(s));
for(const label of manualExits) test(label+' exits a manual position without consulting an old rejected entry template',()=>{
  const r=runtime();r.select('TRSIM','TSLA');r.quote('TSLA',368.2,368.23,368.2);
  const direction=label.startsWith('Sell ')?1:-1;r.position('TRSIM','TSLA',direction*10,368.2);r.run('Load Trade Context');
  const t=r.state('TRSIM','TSLA');
  t.entryOrder=object({Account:'TRSIM',Symbol:'TSLA',Side:'SS',RefNum:292,oid:0,Share:100,Open:100,Status:'N/A',
    GetInfo(){throw new Error('Consulted rejected entry template');},Cancel(){throw new Error('Canceled rejected entry template');}});
  t.closeManaged=1;t.closeStage=1;t.closeRequest=object({kind:'CANCEL'});
  r.run(label);assert.equal(r.orders.length,1);const sent=r.orders[0];
  assert.equal(sent.Account,'TRSIM');assert.equal(sent.Symbol,'TSLA');assert.equal(sent.Side,direction>0?'S':'B');
  const divisor=Number(label.match(/1\/(\d)/)[1]);assert.equal(sent.Share,Math.floor(10/divisor));
  assert(!r.logs.some(s=>s.includes('entry order: Ref=292')));
});

test('manual full sell interrupts retained cancellation intent and sells the actual ten shares',()=>{
  const r=runtime();r.select('TRSIM','TSLA');r.quote('TSLA',368.2,368.23,368.2);r.position('TRSIM','TSLA',10,368.2);
  r.run('Load Trade Context');const t=r.state('TRSIM','TSLA');
  t.entryOrder=object({Account:'TRSIM',Symbol:'TSLA',Side:'SS',RefNum:292,oid:0,Share:100,Open:100,Status:'N/A'});
  t.closeManaged=1;t.closeStage=1;t.exitPending=1;t.closeRequest=object({kind:'CANCEL'});
  r.run('Sell 1/1 Bid-');assert.equal(r.orders.length,1);assert.equal(r.orders[0].Share,10);
  assert.equal(r.orders[0].Side,'S');assert.equal(t.exitPending,0);
});

test('a newly rejected scripted short cannot lock a later manual long sell',()=>{
  const r=runtime();r.select('TRSIM','TSLA');r.quote('TSLA',367.63,367.65,367.63);r.position('TRSIM','TSLA',0);
  r.sendHook=o=>{assert.equal(o.Side,'SS');assert.equal(o.Share,100);r.orders.pop();};
  r.run('Short T1 Bid');assert.equal(r.orders.length,0);
  r.sendHook=null;r.position('TRSIM','TSLA',10,368.2);r.run('Sell 1/1 Bid-');
  assert.equal(r.orders.length,1);assert.equal(r.orders[0].Side,'S');assert.equal(r.orders[0].Share,10);
});

function resolveRoute(r,{side='B',limit=1,bid=1,ask=1,urgent=0,request=r.ctx.$orderRoute}={}) {
  Object.assign(r.ctx,{$routeRequest:request,$routeSide:side,$routeLimit:limit,$routeBid:bid,$routeAsk:ask,$routeUrgent:urgent});
  r.run('Resolve Order Route');return r.ctx.$resolvedOrderRoute;
}
for(const preset of ['Set Order Route SMRTL','Set Order Route AUTOL']) {
  test(preset+' routes the reported passive 250-share LUCD short',()=>{
    const r=runtime();r.select('LIVE','LUCD');r.position('LIVE','LUCD',0);
    r.quote('LUCD',0.427,0.428,0.428);r.ctx.$tier1ShareSize=250;
    r.run(preset);r.run('Short T1 Ask');
    assert.equal(r.orders.length,1);
    const o=r.orders[0];assert.equal(o.Symbol,'LUCD');assert.equal(o.Side,'SS');
    assert.equal(o.Share,250);assert.equal(o.Price,0.428);
    assert.equal(o.Route,preset==='Set Order Route AUTOL'?'ARCA1L':'SMRTL');
  });
}
for(const price of [0.1,0.4166,5/12,0.4167,0.75,0.9999,1,1.01,100]) {
  for(const side of ['B','S','SS']) test('AUTOL fee band '+price+' '+side,()=>{
    const r=runtime();r.run('Set Order Route AUTOL');
    const expected=price>=1?'BESTL':price<=5/12?'BESTL':'SMRTL';
    assert.equal(resolveRoute(r,{side,limit:price,bid:price,ask:price}),expected);
    assert.equal(r.ctx.$orderRoute,'AUTOL');assert.equal(r.orders.length,0);
  });
}
test('AUTOL uses opposite quote for marketable orders and ARCA for resting orders',()=>{
  const r=runtime();r.run('Set Order Route AUTOL');
  assert.equal(resolveRoute(r,{limit:1.1,bid:0.97,ask:0.98}),'SMRTL');
  assert.equal(resolveRoute(r,{side:'S',limit:0.9,bid:1.02,ask:1.03}),'BESTL');
  assert.equal(resolveRoute(r,{limit:0.4,bid:0.49,ask:0.5}),'ARCA1L');
  assert.equal(resolveRoute(r,{side:'SS',limit:1.01,bid:0.98,ask:0.99}),'ARCA1L');
});
for(const [bid,ask] of [[0.1,0.12],[0.4,0.42],[0.75,0.77],[0.99,1.01],[10,10.02]]) {
  for(const [side,limits] of [['B',[bid-0.01,bid,(bid+ask)/2]],
    ['S',[(bid+ask)/2,ask,ask+0.01]],['SS',[(bid+ask)/2,ask,ask+0.01]]]) {
    test('AUTOL selects ARCA for expected adding '+side+' at quotes '+bid+'/'+ask,()=>{
      const r=runtime();
      for(const limit of limits) {
        assert.equal(resolveRoute(r,{side,limit,bid,ask}),'ARCA1L');
        assert.equal(r.ctx.$orderRoute,'AUTOL');assert.equal(r.orders.length,0);
      }
      assert(r.logs.some(s=>s.includes('expected adding liquidity')));
    });
  }
}
test('AUTOL recomputes liquidity classification for successive submissions',()=>{
  const r=runtime();
  assert.equal(resolveRoute(r,{limit:0.75,bid:0.75,ask:0.76}),'ARCA1L');
  assert.equal(resolveRoute(r,{limit:0.76,bid:0.75,ask:0.76}),'SMRTL');
  assert.equal(resolveRoute(r,{side:'S',limit:0.76,bid:0.75,ask:0.76}),'ARCA1L');
  assert.equal(resolveRoute(r,{side:'SS',limit:0.75,bid:0.75,ask:0.76}),'SMRTL');
});
for(const side of ['B','S','SS']) test('AUTOL urgent '+side+' overrides expected adding and missing quotes',()=>{
  const r=runtime();
  assert.equal(resolveRoute(r,{side,limit:side==='B'?0.74:0.77,bid:0.75,ask:0.76,urgent:1}),'BESTL');
  assert.equal(resolveRoute(r,{side,limit:0,bid:0,ask:0,urgent:1}),'BESTL');
});
test('AUTOL invalid quotes clear the last result instead of choosing a fallback',()=>{
  const r=runtime();r.run('Set Order Route AUTOL');resolveRoute(r);
  assert.equal(resolveRoute(r,{ask:0}),'');assert.equal(resolveRoute(r,{bid:0}),'');
  assert.equal(resolveRoute(r,{limit:0}),'');assert.equal(resolveRoute(r,{side:'unknown'}),'');
  assert.equal(r.ctx.$orderRoute,'AUTOL');
});
test('manual route presets disable AUTOL and pass through without quotes',()=>{
  const r=runtime();
  for(const name of ['ARCA1L','FREE1L','BESTL','FLASH1L','SMRTL']) {
    r.run('Set Order Route AUTOL');r.run('Set Order Route '+name);
    assert.equal(resolveRoute(r,{bid:0,ask:0,limit:0}),name);
  }
});
test('AUTOL uses BEST for the CLRO $3.72 case while manual FREE remains selectable',()=>{
  const auto=runtime();auto.quote('AAA',3.71,3.72,3.72);auto.run('Buy MIB Ask SL');
  assert.equal(auto.orders.length,1);assert.equal(auto.orders[0].Price,3.72);
  assert.equal(auto.orders[0].Route,'BESTL');assert.equal(auto.ctx.$orderRoute,'AUTOL');
  const manual=runtime();manual.quote('AAA',3.71,3.72,3.72);manual.run('Set Order Route FREE1L');
  manual.run('Buy MIB Ask SL');assert.equal(manual.orders.length,1);
  assert.equal(manual.orders[0].Route,'FREE1L');assert.equal(manual.ctx.$orderRoute,'FREE1L');
});
for(const label of [...buyLabels,...manualExits,...scripts.keys()].filter((v,i,a)=>a.indexOf(v)===i&&/^(Buy .* SL|Sell |Cover |Short T)/.test(v))) {
  test(label+' submits a concrete AUTOL route and retains the mode',()=>{
    const r=runtime();r.quote('AAA',0.75,0.76,0.75);
    r.position('LIVE','AAA',label.startsWith('Sell ')?100:label.startsWith('Cover ')?-100:0,0.75);
    r.run('Set Order Route AUTOL');r.run(label);
    assert.equal(r.orders.length,1);const o=r.orders[0];
    const expectedAdding=o.Side==='B'?o.Price<0.76:o.Price>0.75;
    assert.equal(o.Route,expectedAdding?'ARCA1L':'SMRTL');
    assert.equal(r.ctx.$orderRoute,'AUTOL');assert.equal(r.ctx.$tradeActionDepth,0);
  });
}
test('AUTOL sell uses bid above one dollar even with a sub-dollar exit limit',()=>{
  const r=runtime();r.position('LIVE','AAA',100,1.02);r.quote('AAA',1.02,1.03,1.02);
  r.run('Set Order Route AUTOL');r.run('Sell 1/1 Bid-');
  assert(r.orders[0].Price<1);assert.equal(r.orders[0].Route,'BESTL');
});
test('AUTOL cover resolves using the final natively rounded limit',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,0.99);r.quote('AAA',0.9996,1.01,1);
  r.run('Set Order Route AUTOL');r.run('Cover 1/1 Bid');
  assert.equal(r.orders[0].Price,1);assert.equal(r.orders[0].Route,'ARCA1L');
  const taking=runtime();taking.position('LIVE','AAA',-100,0.99);taking.quote('AAA',0.9996,1,1);
  taking.run('Cover 1/1 Bid');
  assert.equal(taking.orders[0].Price,1);assert.equal(taking.orders[0].Route,'BESTL');
});
test('AUTOL TP resolves the alert symbol instead of the active montage',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.75);r.quote('AAA',0.75,0.76,0.75);
  r.run('Set Take Profit');const al=[...r.alerts.values()][0];
  r.select('TRSIM','OTHER');r.position('TRSIM','OTHER',-100,10);r.quote('OTHER');
  r.run('Set Order Route AUTOL');r.execute(al.Script);
  assert.equal(r.orders[0].Symbol,'AAA');assert.equal(r.orders[0].Route,'SMRTL');
});
for(const share of [100,-100]) test('AUTOL GTFO uses BEST for signed position '+share,()=>{
  const r=runtime();r.position('LIVE','AAA',share,10);r.run('Set Order Route AUTOL');r.run('GTFO');
  assert.equal(r.orders.length,1);assert.equal(r.orders[0].Route,'BESTL');
  assert.equal(r.ctx.$gtfoRoute,'FLSH1L');assert.equal(r.ctx.$orderRoute,'AUTOL');
});
test('AUTOL hijack uses BEST, manual emergency route stays independent',()=>{
  const h=runtime();h.position('LIVE','AAA',1000,10);h.ctx.$hijackProtection=1;
  h.run('Set Order Route AUTOL');h.run('Hijack Exit');assert.equal(h.orders.at(-1).Route,'BESTL');
  const m=runtime();m.run('Set Order Route ARCA1L');m.position('LIVE','AAA',100,10);m.run('GTFO');assert.equal(m.orders[0].Route,'FLSH1L');
});
test('AUTOL preserves STOP and resolves immediate breakeven limit exits',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.75);r.quote('AAA',0.75,0.76,0.75);
  r.run('Set Order Route AUTOL');r.run('Set Auto Stop BE 1/1');
  assert.equal(r.orders[0].Type,'L');assert.equal(r.orders[0].Route,'SMRTL');
  r.position('LIVE','AAA',100,10);r.quote('AAA',11,11.02,11);r.run('Set Auto Stop');
  assert.equal(r.orders.at(-1).Route,'STOP');
});
test('startup and configuration reload enable AUTOL without a route preset hotkey',()=>{
  const r=runtime();assert.equal(r.ctx.$orderRoute,'AUTOL');
  assert.equal(r.ctx.$exitOffsetMaxPct,0.05);
  r.quote('AAA',0.75,0.76,0.75);r.run('Buy MIB Ask SL');
  assert.equal(r.orders[0].Route,'SMRTL');
  r.run('Set Order Route ARCA1L');assert.equal(r.ctx.$orderRoute,'ARCA1L');
  r.ctx.$exitOffsetMaxPct=0.02;
  r.run('Set Global Variables');assert.equal(r.ctx.$orderRoute,'AUTOL');
  assert.equal(r.ctx.$exitOffsetMaxPct,0.05);
  assert.equal(r.ctx.$gtfoRoute,'FLSH1L');
  r.position('LIVE','AAA',100,0.76);r.run('GTFO');
  assert.equal(r.orders.at(-1).Route,'BESTL');
});
for(const [label,expected] of [['Buy MIB Ask SL','BESTL'],['Buy MIB Bid SL','ARCA1L']]) {
  test('AUTOL never reroutes or retries a rejected '+expected+' submission',()=>{
    const r=runtime();r.run('Set Order Route AUTOL');
    r.sendHook=o=>{o.Open=0;o.Status='Rejected';};r.run(label);
    for(let i=0;i<12;i++)r.tick();
    assert.equal(r.orders.length,1);assert.equal(r.orders[0].Route,expected);
  });
}

const cushionedExits = ['Cover 1/1 Ask+','Cover 1/2 Ask+','Cover 1/4 Ask+',
  'Sell 1/1 Bid-','Sell 1/2 Bid-','Sell 1/4 Bid-'];
function ordinaryExit(label,{bid,ask,offset=0.1,cap=0.05,route='AUTOL'}={}) {
  const r=runtime();r.quote('AAA',bid,ask,bid);
  r.position('LIVE','AAA',label.startsWith('Cover ')?-750:750,bid);
  r.ctx.$exitOffset=offset;r.ctx.$exitOffsetMaxPct=cap;r.ctx.$orderRoute=route;
  r.run(label);assert.equal(r.orders.length,1);return r;
}
for(const label of cushionedExits) {
  for(const ref of [0.0001,0.01,0.1796,0.2381,0.4298,0.952,0.9999,1,1.999,2,10]) {
    test(label+' keeps final limit inside the 5% ceiling at quote '+ref,()=>{
      const isBuy=label.startsWith('Cover ');
      const r=ordinaryExit(label,{bid:ref,ask:ref});const o=r.orders[0];
      const boundary=ref*(isBuy?1.05:0.95);
      assert.equal(o.Side,isBuy?'B':'S');assert(o.Price>0);
      if(isBuy)assert(o.Price<=boundary+1e-12,`${o.Price} > ${boundary}`);
      else assert(o.Price>=boundary-1e-12,`${o.Price} < ${boundary}`);
      const divisor=Number(label.match(/1\/(\d)/)[1]);assert.equal(o.Share,Math.floor(750/divisor));
      assert.equal(r.ctx.$orderRoute,'AUTOL');assert.equal(r.ctx.$tradeActionDepth,0);
      assert.equal(r.ctx.$exitOffset,0.1);assert.equal(r.ctx.$exitOffsetMaxPct,0.05);
      if(ref===10)assert(Math.abs(o.Price-(isBuy?10.1:9.9))<1e-10);
    });
  }
  test(label+' supports a different percentage ceiling and a smaller dollar cushion',()=>{
    const isBuy=label.startsWith('Cover ');
    const tight=ordinaryExit(label,{bid:0.43,ask:0.43,cap:0.01}).orders[0];
    assert(isBuy?tight.Price<=0.4343+1e-12:tight.Price>=0.4257-1e-12);
    const fixed=ordinaryExit(label,{bid:10,ask:10,offset:0.02}).orders[0];
    assert(Math.abs(fixed.Price-(isBuy?10.02:9.98))<1e-10);
  });
  test(label+' permits disabling the cap for legacy dollar-offset pricing',()=>{
    const isBuy=label.startsWith('Cover ');
    const r=ordinaryExit(label,{bid:0.18,ask:0.18,cap:0});
    assert(Math.abs(r.orders[0].Price-(isBuy?0.28:0.08))<1e-10);
  });
  test(label+' applies the same ceiling with a manual route',()=>{
    const r=ordinaryExit(label,{bid:0.43,ask:0.43,route:'ARCA1L'});
    assert.equal(r.orders[0].Route,'ARCA1L');
    assert(label.startsWith('Cover ')?r.orders[0].Price<=0.4515:r.orders[0].Price>=0.4085);
  });
}
for(const label of cushionedExits.filter(s=>s.startsWith('Cover '))) {
  test(label+' reproduces the LUCD and GPUS cover failures with capped prices',()=>{
    const lucd=ordinaryExit(label,{bid:0.4286,ask:0.4298}).orders[0];
    assert.equal(lucd.Route,'SMRTL');assert.equal(lucd.Price,0.451);
    assert(lucd.Price<0.4286*1.10);
    const gpus=ordinaryExit(label,{bid:0.1795,ask:0.1796}).orders[0];
    assert.equal(gpus.Route,'BESTL');assert.equal(gpus.Price,0.1885);
    assert(gpus.Price<0.1796*1.50);
  });
  test(label+' uses native rounding and logs the final submitted price',()=>{
    const r=runtime();r.position('LIVE','AAA',-100,0.18);r.quote('AAA',0.1795,0.1796,0.1795);
    r.ctx.Round=(n,precision)=>{assert.notEqual(precision,102,'covers must retain montage-native rounding');return Math.round(n*10**precision)/10**precision;};
    r.run(label);assert.equal(r.orders[0].Price,0.1885);
    assert(r.logs.some(s=>s.includes('at Ask+ 0.1885 via BESTL')));
  });
  test(label+' rejects an Ask that disappears after cancellation even with the cap disabled',()=>{
    const r=runtime();r.position('LIVE','AAA',-100);r.ctx.$exitOffsetMaxPct=0;r.ctx.$orderRoute='ARCA1L';
    r.waitHook=()=>r.quote('AAA',10,0,10);r.run(label);
    assert.equal(r.orders.length,0);assert.equal(r.ctx.$tradeActionDepth,0);
  });
}
test('the ordinary-exit cap leaves STOP, GTFO, and hijack prices unchanged',()=>{
  const stop=runtime();stop.position('LIVE','AAA',100,10);stop.ctx.$exitOffsetMaxPct=0.001;
  stop.run('Set Auto Stop');assert.equal(stop.orders[0].Route,'STOP');
  assert.equal(stop.orders[0].StopPrice,9.5);assert.equal(stop.orders[0].Price,9.4);
  for(const share of [100,-100]) {
    const gtfo=runtime();gtfo.position('LIVE','AAA',share,10);gtfo.ctx.$exitOffsetMaxPct=0.001;gtfo.run('GTFO');
    assert.equal(gtfo.orders[0].Route,'BESTL');assert.equal(gtfo.orders[0].Price,share>0?9.5:10.52);
  }
  const hijack=runtime();hijack.position('LIVE','AAA',1000,10);hijack.ctx.$exitOffsetMaxPct=0.001;
  hijack.ctx.$hijackProtection=1;hijack.run('Hijack Exit');assert.equal(hijack.orders[0].Price,9.9);
});

for(const label of [...scripts.keys()].filter(s=>/^Short T/.test(s))) {
  test(label+' protects actual partial and late fills when stops are on',()=>{
    const r=runtime();r.run(label);const entry=r.orders[0];const partial=Math.floor(entry.Share/2);
    r.tick();assert.equal(r.orders.length,1,'submission alone must not arm protection');
    r.position('LIVE','AAA',-partial,10);entry.Open=entry.Share-partial;r.tick();
    const first=r.orders.at(-1);assert.equal(first.Type,'SLP');assert.equal(first.Side,'B');
    assert.equal(first.Share,partial);assert.equal(first.StopPrice,10.5);assert.equal(first.Route,'STOP');
    r.position('LIVE','AAA',-entry.Share,10.02);entry.Open=0;r.tick();
    assert.equal(first.canceled,true);assert.equal(r.orders.length,2);
    r.tick();const full=r.orders.at(-1);assert.equal(full.Share,entry.Share);
    assert(Math.abs(full.StopPrice-10.52)<1e-8);assert.equal(full.Route,'STOP');assert.equal(full.Side,'B');
    assert.equal(r.alerts.size,1);assert.equal([...r.alerts.values()][0].condition.op,'<');
    assert.equal(r.ctx.$orderRoute,'AUTOL');
  });
  test(label+' leaves automatic protection off when stops are off',()=>{
    const r=runtime();r.ctx.$useAutoStop='No';r.run(label);
    r.position('LIVE','AAA',-r.orders[0].Share,10);for(let i=0;i<3;i++)r.tick();
    assert.equal(r.orders.length,1);assert.equal(r.orders[0].Side,'SS');
  });
}
for(const label of [...scripts.keys()].filter(s=>/^Cover /.test(s))) {
  test(label+' restores short protection only after the working cover closes',()=>{
    const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');const initial=r.orders[0];
    r.run(label);const cover=r.orders[1];assert.equal(initial.canceled,true);
    r.tick();assert.equal(r.orders.length,2,'working cover and new BUY stop must not overlap');
    const partial=Math.max(1,Math.floor(cover.Share/2));
    r.position('LIVE','AAA',-100+partial,10);cover.Open=cover.Share-partial;r.tick();assert.equal(r.orders.length,2);
    r.position('LIVE','AAA',-100+cover.Share,10);cover.Open=0;r.tick();
    if(cover.Share===100) {
      assert.equal(r.orders.length,2);assert.equal(r.state('LIVE','AAA').active,0);
    } else {
      assert.equal(r.orders.length,3);const stop=r.orders[2];
      assert.equal(stop.Type,'SLP');assert.equal(stop.Side,'B');assert.equal(stop.Share,100-cover.Share);
    }
  });
}
test('a canceled cover restores short protection without resubmitting the cover',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Cover 1/2 Ask+');const cover=r.orders[0];
  cover.Open=0;cover.Status='Canceled';r.tick();
  assert.equal(r.orders.length,2);assert.equal(r.orders[1].Type,'SLP');assert.equal(r.orders[1].Share,100);
  assert.equal(r.orders.filter(o=>o.Type==='L').length,1);
});
test('flat during a working cover cancels its BUY and waits for acknowledgment',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Cover 1/2 Ask+');const cover=r.orders[0];
  r.position('LIVE','AAA',0,0);r.cancelHook=()=>{};r.tick();
  assert.equal(cover.canceled,true);assert.equal(r.state('LIVE','AAA').shortCoverPending,1);
  assert.equal(r.orders.length,1);r.run('Buy MIB Ask SL');assert.equal(r.orders.length,1);
  cover.Open=0;r.cancelHook=null;r.tick();assert.equal(r.state('LIVE','AAA').active,0);
});
test('RESET waits for a cover cancellation instead of overlapping BUY orders',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Cover 1/2 Ask+');const cover=r.orders[0];
  r.cancelHook=()=>{};r.run('Set Auto Stop');assert.equal(r.orders.length,1);assert.equal(r.ctx.$stopSubmitted,0);
  cover.Open=0;r.cancelHook=null;r.tick();assert.equal(r.orders.length,2);assert.equal(r.orders[1].Share,100);
});
test('RESET retains an unfilled short remainder for cleanup after a full stop fill',()=>{
  const r=runtime();r.run('Short T1 Bid');const entry=r.orders[0];entry.Open=50;
  r.position('LIVE','AAA',-50,10);r.tick();r.run('Set Auto Stop');const stop=r.orders.at(-1);
  assert.equal(r.state('LIVE','AAA').shortEntryOrder,entry);
  stop.Open=0;r.position('LIVE','AAA',0,0);r.tick();assert.equal(entry.canceled,true);
  r.tick();assert.equal(r.state('LIVE','AAA').active,0);
});
test('short stop replacement waits for acknowledgment and uses the latest signed size',()=>{
  const r=runtime();r.run('Short T1 Bid');const entry=r.orders[0];entry.Open=0;
  r.position('LIVE','AAA',-100,10);r.tick();const stop=r.orders[1];
  r.position('LIVE','AAA',-150,10);r.cancelHook=()=>{};r.tick();r.tick();
  assert.equal(r.orders.length,2);assert.equal(stop.canceled,true);
  r.position('LIVE','AAA',-175,10.1);stop.Open=0;r.cancelHook=null;r.tick();
  assert.equal(r.orders.length,3);assert.equal(r.orders[2].Share,175);assert.equal(r.orders[2].Side,'B');
});
test('a partial short-stop fill keeps its already-working remaining BUY shares',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');const stop=r.orders[0];
  stop.Open=40;r.position('LIVE','AAA',-40,10);r.tick();
  assert.equal(r.orders.length,1);assert.equal(stop.canceled,undefined);
  assert.equal(r.state('LIVE','AAA').shortStopQty,40);
});
test('short no-fill timeout waits for cancellation and does not arm a stop while flat',()=>{
  const r=runtime();r.ctx.$entryMaxTicks=2;r.run('Short T1 Bid');const entry=r.orders[0];
  r.tick();r.tick();assert.equal(entry.canceled,true);r.tick();
  assert.equal(r.orders.length,1);assert.equal(r.state('LIVE','AAA').active,0);
});
test('short fill racing timeout cancellation still receives protection',()=>{
  const r=runtime();r.ctx.$entryMaxTicks=1;r.run('Short T1 Bid');const entry=r.orders[0];
  r.cancelHook=o=>{o.Open=0;r.position('LIVE','AAA',-25,10);};r.tick();r.cancelHook=null;r.tick();
  assert.equal(r.orders.length,2);assert.equal(r.orders[1].Share,25);assert.equal(r.orders[1].Type,'SLP');
});
test('short pending entry blocks a long buy in the same symbol',()=>{
  const r=runtime();r.run('Short T1 Ask');r.run('Buy MIB Bid SL');
  assert.equal(r.orders.length,1);assert(r.logs.some(s=>s.includes('short entry still pending')));
});
test('automatic short and long protection remain isolated off montage across accounts',()=>{
  const r=runtime();r.run('Short T1 Bid');const shortEntry=r.orders[0];shortEntry.Open=0;r.position('LIVE','AAA',-100,10);
  r.select('TRSIM','AAA');r.position('TRSIM','AAA',0);r.run('Buy MIB Ask SL');r.position('TRSIM','AAA',100,10);
  r.select('LIVE','OTHER');r.quote('OTHER');r.position('LIVE','OTHER',-10,20);
  r.tick();r.tick();const stops=r.orders.filter(o=>o.Type==='SLP');
  assert.equal(stops.length,2);assert.equal(stops.find(o=>o.Account==='LIVE').Side,'B');
  assert.equal(stops.find(o=>o.Account==='TRSIM').Side,'S');assert.equal(r.symbol,'OTHER');
});
test('automatic short staging survives LOAD CFG and retries missing average',()=>{
  const r=runtime();r.run('Short T1 Bid');const entry=r.orders[0];entry.Open=0;r.position('LIVE','AAA',-50,0);
  r.run('Set Global Variables');r.tick();assert.equal(r.orders.length,1);
  r.position('LIVE','AAA',-50,10);r.tick();assert.equal(r.orders[1].Share,50);
});
test('short protection follows the stop toggle without duplicating a working stop',()=>{
  const r=runtime();r.run('Short T1 Bid');r.ctx.$useAutoStop='No';r.orders[0].Open=0;
  r.position('LIVE','AAA',-100,10);r.tick();assert.equal(r.orders.length,1);
  r.ctx.$useAutoStop='Yes';r.tick();r.tick();assert.equal(r.orders.length,2);
});
test('Cancel All honors stop-reset settings for a short and No Stops suppresses rearming',()=>{
  for(const enabled of [true,false]) {
    const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');const stop=r.orders[0];
    r.ctx.$resetStopOnCancel=enabled?'Yes':'No';r.run('Cancel All');r.tick();
    assert.equal(stop.canceled,true);assert.equal(r.orders.length,enabled?2:1);
    r.run('Cancel All No Stops');const count=r.orders.length;r.tick();assert.equal(r.orders.length,count);
  }
});
test('short protection scans long order history over multiple ticks without exceeding the loop limit',()=>{
  const r=runtime();for(let i=0;i<205;i++)r.orders.push(object({Account:'LIVE',Symbol:'AAA',Side:'B',Open:0,RefNum:i+1}));
  r.run('Short T1 Bid');r.orders.at(-1).Open=0;r.position('LIVE','AAA',-100,10);
  r.tick();assert.equal(r.orders.length,206);r.tick();assert.equal(r.orders.length,207);
  assert.equal(r.orders.at(-1).Type,'SLP');
});
test('a rejected short entry never creates protection or automatic route fallback',()=>{
  const r=runtime();r.sendHook=o=>{o.Open=0;o.Status='Rejected';};r.run('Short T1 Bid');
  for(let i=0;i<12;i++)r.tick();assert.equal(r.orders.length,1);assert.equal(r.orders[0].Type,'L');
});

for(const [shares,op,target] of [[100,'>',10.5],[-100,'<',9.5]]) {
  test('RESET TAKE PROFIT arms the correct direction for signed size '+shares,()=>{
    const r=runtime();r.position('LIVE','AAA',shares,10);r.run('Set Take Profit');
    const alert=[...r.alerts.values()][0];assert.equal(alert.condition.field,'Last Sale');
    assert.equal(alert.condition.op,op);assert.equal(alert.condition.px,target);
    assert.equal(r.orders.length,0);assert.equal(r.ctx.$tpCreated,1);
    assert(alert.Script.includes('TP_DIRECTION'));assert(alert.Script.includes('TP_REVISION'));
  });
}
test('short TP refuses nonpositive targets without replacing an existing valid alert',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,0.4);r.ctx.$stopLossTrigger=0.1;r.run('Set Take Profit');
  const alert=[...r.alerts.values()][0];r.ctx.$stopLossTrigger=0.5;r.run('Set Take Profit');
  assert.equal(r.ctx.$tpCreated,0);assert.equal(r.alerts.size,1);assert.equal([...r.alerts.values()][0],alert);
  r.position('LIVE','AAA',0);r.run('Set Take Profit');assert.equal(r.orders.length,0);
});
test('invalid automatic short TP target logs once while short stop protection remains active',()=>{
  const r=runtime();r.quote('AAA',0.39,0.4,0.4);r.run('Short T1 Bid');r.orders[0].Open=0;
  r.position('LIVE','AAA',-100,0.4);for(let i=0;i<4;i++)r.tick();
  assert.equal(r.orders.length,2);assert.equal(r.orders[1].Type,'SLP');assert.equal(r.alerts.size,0);
  assert.equal(r.logs.filter(s=>s.includes('Take profit not created')).length,1);
});
for(const label of [...scripts.keys()].filter(s=>/^Short T/.test(s))) {
  test(label+' automatically arms short TP independently of stops',()=>{
    const r=runtime();r.ctx.$useAutoStop='No';r.run(label);const entry=r.orders[0];
    r.tick();assert.equal(r.alerts.size,0);entry.Open=0;r.position('LIVE','AAA',-entry.Share,10);r.tick();
    assert.equal(r.orders.length,1);assert.equal(r.alerts.size,1);
    assert.equal([...r.alerts.values()][0].condition.px,9.5);
    assert.equal([...r.alerts.values()][0].condition.op,'<');
  });
}
test('short TP toggle disables automatic arming while manual RESET still works',()=>{
  const r=runtime();r.ctx.$useTakeProfit='No';r.run('Short T1 Bid');r.orders[0].Open=0;
  r.position('LIVE','AAA',-100,10);r.tick();assert.equal(r.orders[1].Type,'SLP');assert.equal(r.alerts.size,0);
  r.run('Set Take Profit');assert.equal(r.alerts.size,1);assert.equal([...r.alerts.values()][0].condition.op,'<');
});
test('RESET STOP LOSS and full BE retain an existing short TP alert when TP is off',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.ctx.$useTakeProfit='No';r.run('Set Take Profit');
  const alert=[...r.alerts.values()][0];const revision=r.state('LIVE','AAA').tpRevision;
  r.run('Set Auto Stop');assert.equal([...r.alerts.values()][0],alert);
  r.run('Set Auto Stop BE 1/1');assert.equal([...r.alerts.values()][0],alert);
  assert.equal(r.state('LIVE','AAA').tpRevision,revision);
});
for(const [ask,avg,expected] of [[9.5,10,'BESTL'],[0.65,0.75,'SMRTL'],[0.4,0.5,'BESTL']]) {
  test('short TP buys at Ask '+ask+' through the existing AUTOL fee bands',()=>{
    const r=runtime();r.position('LIVE','AAA',-100,avg);r.quote('AAA',ask-0.01,ask,ask-0.01);
    r.ctx.$stopLossTrigger=0.1;r.run('Set Take Profit');r.execute([...r.alerts.values()][0].Script);
    assert.equal(r.orders.length,1);const cover=r.orders[0];
    assert.equal(cover.Side,'B');assert.equal(cover.Share,50);assert.equal(cover.Price,ask);assert.equal(cover.Route,expected);
    assert.equal(r.ctx.$orderRoute,'AUTOL');assert.equal(r.state('LIVE','AAA').exitStartPos,-100);
  });
}
test('short TP honors manual routing and rehab quantity rules',()=>{
  for(const [account,apply,expected] of [['LIVE',0,25],['TRSIM',0,50],['TRSIM',1,25]]) {
    const r=runtime();r.select(account,'AAA');r.position(account,'AAA',-100,10);r.quote('AAA',9.49,9.5,9.49);
    r.ctx.$rehab=1;r.ctx.$applyLiveGuardsToSim=apply;r.ctx.$takeProfitSizeRehab=0.25;
    r.run('Set Order Route FREE1L');r.run('Set Take Profit');r.execute([...r.alerts.values()][0].Script);
    assert.equal(r.orders[0].Share,expected);assert.equal(r.orders[0].Side,'B');assert.equal(r.orders[0].Route,'FREE1L');
  }
});
test('short TP cannot act on a long, and replaced TP payloads are invalidated by revision',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Take Profit');const old=[...r.alerts.values()][0];
  r.run('Set Take Profit');r.execute(old.Script);assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);
  const current=[...r.alerts.values()][0];r.position('LIVE','AAA',100,10);r.execute(current.Script);
  assert.equal(r.orders.length,0);assert.equal(r.cancels.length,0);
});
test('short TP payload uses its original account and symbol off montage',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('AAA',9.49,9.5,9.49);r.run('Set Take Profit');
  const shortAlert=[...r.alerts.values()][0];r.select('TRSIM','OTHER');r.position('TRSIM','OTHER',200,20);r.quote('OTHER',20.49,20.5,20.49);
  r.run('Set Take Profit');r.execute(shortAlert.Script);
  assert.equal(r.orders[0].Account,'LIVE');assert.equal(r.orders[0].Symbol,'AAA');assert.equal(r.orders[0].Side,'B');
  assert.equal(r.orders[0].Price,9.5);assert.equal(r.account,'TRSIM');assert.equal(r.symbol,'OTHER');
});
test('deferred short TP retains direction and revision while another action waits',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('AAA',9.49,9.5,9.49);r.run('Set Take Profit');
  const shortAlert=[...r.alerts.values()][0];r.select('TRSIM','OTHER');r.position('TRSIM','OTHER',100,20);r.quote('OTHER');
  r.waitHook=()=>{r.waitHook=null;r.execute(shortAlert.Script);};r.run('Set Auto Stop');
  assert.equal(r.state('LIVE','AAA').deferredTpDirection,-1);r.tick();
  const cover=r.orders.find(o=>o.Symbol==='AAA'&&o.Type==='L');assert(cover);assert.equal(cover.Side,'B');assert.equal(cover.Share,50);
});
test('short TP waits for BUY stop cancellation before sending its cover',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('AAA',9.49,9.5,9.49);r.run('Set Auto Stop');
  const stop=r.orders[0];r.run('Set Take Profit');r.cancelHook=()=>{};r.execute([...r.alerts.values()][0].Script);
  assert.equal(r.orders.length,1);assert.equal(r.state('LIVE','AAA').tpCancelPending,1);
  r.tick();assert.equal(r.orders.length,1);stop.Open=0;r.cancelHook=null;r.tick();
  assert.equal(r.orders.length,2);assert.equal(r.orders[1].Side,'B');assert.equal(r.orders[1].Type,'L');
});
for(const remaining of [50,80,100]) test('short TP restores protection for remaining size '+remaining,()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('AAA',9.49,9.5,9.49);r.run('Set Auto Stop');r.run('Set Take Profit');
  const payload=[...r.alerts.values()][0].Script;r.execute(payload);const cover=r.orders.at(-1);cover.Open=0;r.position('LIVE','AAA',-remaining,10);r.tick();
  const protection=r.orders.at(-1);assert.equal(protection.Side,'B');assert.equal(protection.Type,'SLP');assert.equal(protection.Share,remaining);
  assert(Math.abs(protection.StopPrice-(remaining===50?9.97:10.5))<1e-8);
  assert.equal(r.alerts.size,remaining===50?0:1);assert.equal(r.state('LIVE','AAA').exitPending,0);
  const count=r.orders.length;r.tick();assert.equal(r.orders.length,count);assert.equal(r.alerts.size,remaining===50?0:1);
  r.execute(payload);assert.equal(r.orders.length,count,'consumed TP payload must never execute again');
});
test('short TP leaves its stop untouched when Ask is unavailable before execution',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');r.run('Set Take Profit');
  const payload=[...r.alerts.values()][0].Script;const stop=r.orders[0];r.quote('AAA',9.49,0,9.49);r.execute(payload);
  assert.equal(r.orders.length,1);assert.equal(stop.canceled,undefined);assert.equal(r.state('LIVE','AAA').stopArmed,1);
});
test('RESET TAKE PROFIT invalidates a deferred short TP cancellation handoff',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.run('Set Auto Stop');const stop=r.orders[0];r.run('Set Take Profit');
  const payload=[...r.alerts.values()][0].Script;r.cancelHook=()=>{};r.execute(payload);
  assert.equal(r.state('LIVE','AAA').tpCancelPending,1);r.run('Set Take Profit');r.tick();
  assert.equal(r.orders.length,1);assert.equal(r.state('LIVE','AAA').deferredTp,0);
  stop.Open=0;r.cancelHook=null;r.tick();assert.equal(r.orders.length,2);assert.equal(r.orders[1].Type,'SLP');
  r.execute(payload);assert.equal(r.orders.length,2);
});
test('short TP residual cancellation uses the final filled amount before choosing BE',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('AAA',9.49,9.5,9.49);r.run('Set Take Profit');
  r.execute([...r.alerts.values()][0].Script);const cover=r.orders[0];cover.Open=30;r.position('LIVE','AAA',-80,10);
  r.cancelHook=()=>{};for(let i=0;i<4;i++)r.tick();assert.equal(r.orders.length,1);
  r.cancelHook=o=>{o.Open=0;r.position('LIVE','AAA',-50,10);};r.tick();r.tick();
  assert.equal(r.orders.length,2);assert.equal(r.orders[1].Share,50);assert.equal(r.orders[1].StopPrice,9.97);
});
test('full-position short TP cleans pending entry remainders before flat cleanup',()=>{
  const r=runtime();r.run('Short T1 Bid');const entry=r.orders[0];entry.Open=50;
  r.position('LIVE','AAA',-50,10);r.quote('AAA',9.49,9.5,9.49);r.tick();r.ctx.$takeProfitSize=1;
  r.execute([...r.alerts.values()][0].Script);r.orders.at(-1).Open=0;r.position('LIVE','AAA',0);r.tick();r.tick();r.tick();
  assert.equal(entry.canceled,true);assert.equal(r.state('LIVE','AAA').active,0);assert.equal(r.alerts.size,0);
});
test('short TP retains its BE order identity when the position flattens during BE submission',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('AAA',9.49,9.5,9.49);r.run('Set Take Profit');
  r.execute([...r.alerts.values()][0].Script);r.orders[0].Open=0;r.position('LIVE','AAA',-50,10);
  r.quote('AAA',9.98,9.99,9.98);r.sendHook=o=>{if(o.Type==='L'){r.position('LIVE','AAA',0);o.Open=50;}};
  r.cancelHook=()=>{};r.tick();const be=r.orders[1];assert.equal(be.Type,'L');
  assert.equal(r.state('LIVE','AAA').exitPending,1);r.tick();assert.equal(be.canceled,true);
  assert.equal(r.state('LIVE','AAA').Get('shortStopOrder'),be);
  be.Open=0;r.cancelHook=null;r.tick();assert.equal(r.state('LIVE','AAA').active,0);
});
test('GTFO interrupts short TP without later stop or TP resurrection',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('AAA',9.49,9.5,9.49);r.run('Set Take Profit');
  const alert=[...r.alerts.values()][0];r.execute(alert.Script);const cover=r.orders[0];r.run('GTFO');const count=r.orders.length;
  assert.equal(cover.canceled,true);r.execute(alert.Script);r.tick();r.tick();assert.equal(r.orders.length,count);assert.equal(r.alerts.size,0);
});
for(const [ask,type,route] of [[9.5,'SLP','STOP'],[10.02,'L','ARCA1L']]) {
  test('existing full BE hotkey supports short with Ask '+ask,()=>{
    const r=runtime();r.position('LIVE','AAA',-100,10);r.quote('AAA',ask-0.01,ask,ask);r.run('Set Auto Stop BE 1/1');
    assert.equal(r.orders.length,1);const o=r.orders[0];assert.equal(o.Side,'B');assert.equal(o.Share,100);
    assert.equal(o.Type,type);assert.equal(o.Route,route);assert.equal(o.Price,10);
    if(type==='SLP')assert.equal(o.StopPrice,9.97);assert.equal(r.ctx.$tradeActionDepth,0);
  });
}

for(const ref of [0.0001,0.001,0.01,0.05,0.1796,0.2,0.2381,0.2499,0.25,0.4298,
  0.49,0.5,0.500001,0.50004,0.5001,0.99,1,1.051,10,10.02,100]) {
  for(const shares of [125,-125]) test('GTFO caps price distance at quote '+ref+' for signed shares '+shares,()=>{
    const r=runtime();r.position('LIVE','AAA',shares,ref);r.quote('AAA',ref,ref,ref);r.run('GTFO');
    assert.equal(r.orders.length,1);const o=r.orders[0];
    assert.equal(o.Account,'LIVE');assert.equal(o.Symbol,'AAA');assert.equal(o.Type,'L');assert.equal(o.Tif,'DAY+');
    assert.equal(o.Share,125);assert.equal(o.Side,shares>0?'S':'B');assert.equal(o.Route,'BESTL');assert(o.Price>0);
    assert(shares>0?o.Price>=ref*0.95-1e-12&&o.Price<=ref+1e-12:o.Price<=ref*1.05+1e-12&&o.Price>=ref-1e-12);
    assert.equal(r.ctx.$orderRoute,'AUTOL');assert.equal(r.ctx.$tradeActionDepth,0);
  });
}
for(const [ref,shares,expected] of [[0.2,100,0.19],[0.5,100,0.475],[0.2,-100,0.21],
  [0.4298,-750,0.451],[0.1796,-2450,0.1885],[10,100,9.5],[10.02,-100,10.52]]) {
  test('GTFO concrete capped limit '+expected+' at quote '+ref+' and signed size '+shares,()=>{
    const r=runtime();r.position('LIVE','AAA',shares,ref);r.quote('AAA',ref,ref,ref);r.run('GTFO');
    assert.equal(r.orders.length,1);assert(Math.abs(r.orders[0].Price-expected)<1e-10);
  });
}
test('GTFO refreshes price and signed size after its cancellation wait',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.2);r.quote('AAA',0.2,0.21,0.2);
  r.waitHook=()=>{r.position('LIVE','AAA',30,0.2);r.quote('AAA',0.1,0.11,0.1);};r.run('GTFO');
  assert.equal(r.orders[0].Share,30);assert.equal(r.orders[0].Price,0.095);
});
test('queued GTFO exits a low-price long after the active stop action finishes',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.2);r.quote('AAA',0.2,0.21,0.2);
  r.ctx.$stopLossTrigger=0.05;r.ctx.$exitOffset=0.01;
  r.waitHook=()=>{r.waitHook=null;r.run('GTFO');};r.run('Set Auto Stop');
  const exit=r.orders.at(-1);assert.equal(exit.Type,'L');assert.equal(exit.Side,'S');
  assert.equal(exit.Share,100);assert.equal(exit.Route,'BESTL');assert(Math.abs(exit.Price-0.19)<1e-10);
  assert.equal(r.ctx.$tradeActionDepth,0);assert.equal(r.ctx.GTFO_PENDING_ACCOUNT,'');
});
for(const shares of [100,-100]) test('GTFO uses the existing Last fallback for a missing quote with signed size '+shares,()=>{
  const r=runtime();r.position('LIVE','AAA',shares,0.2);r.quote('AAA',0,0,0.2);r.run('GTFO');
  assert.equal(r.orders.length,1);assert(Math.abs(r.orders[0].Price-(shares>0?0.19:0.21))<1e-10);
});
test('GTFO submits no order without any positive quote or Last',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.2);r.quote('AAA',0,0,0);r.run('GTFO');
  assert.equal(r.orders.length,0);assert(r.logs.some(s=>s.includes('no positive quote/last')));
  assert.equal(r.ctx.$tradeActionDepth,0);
});
for(const [selected,emergency,expected] of [['AUTOL','ARCA1L','BESTL'],['FREE1L','FLSH1L','FLSH1L'],
  ['SMRTL','BESTL','BESTL'],['ARCA1L','','ARCA1L']]) {
  test('low-price GTFO preserves urgent routing '+selected+'/'+emergency,()=>{
    const r=runtime();r.position('LIVE','AAA',100,0.2);r.quote('AAA',0.2,0.21,0.2);
    r.ctx.$orderRoute=selected;r.ctx.$gtfoRoute=emergency;r.run('GTFO');
    assert.equal(r.orders.length,1);assert.equal(r.orders[0].Route,expected);
    assert.equal(r.ctx.$orderRoute,selected);assert.equal(r.ctx.$gtfoRoute,emergency);
  });
}
test('GTFO percentage ceiling is independent of the ordinary-exit cap',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.2);r.quote('AAA',0.2,0.21,0.2);
  r.ctx.$exitOffsetMaxPct=0.001;r.ctx.$exitOffset=0.01;r.run('GTFO');assert(Math.abs(r.orders[0].Price-0.19)<1e-10);
  r.ctx.$gtfoOffsetMaxPct=0.1;r.run('GTFO');assert(Math.abs(r.orders[1].Price-0.18)<1e-10);
  r.run('Show Config');assert(r.logs.some(s=>s.includes('gtfoOffsetMaxPct: 10%')));
});
test('disabled GTFO cap retains the dollar cushion with a positive minimum sell limit',()=>{
  for(const shares of [100,-100]) {
    const r=runtime();r.position('LIVE','AAA',shares,0.2);r.quote('AAA',0.2,0.2,0.2);r.ctx.$gtfoOffsetMaxPct=0;r.run('GTFO');
    assert.equal(r.orders.length,1);assert(Math.abs(r.orders[0].Price-(shares>0?0.0001:0.7))<1e-10);
  }
});
test('GTFO cannot round a tiny positive sell price to zero when its cap is disabled',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.500001);r.quote('AAA',0.500001,0.51,0.500001);
  r.ctx.$gtfoOffsetMaxPct=0;r.run('GTFO');assert.equal(r.orders[0].Price,0.0001);
});
for(const shares of [100,-100]) test('rejected low-price GTFO does not trigger a route fallback for '+shares,()=>{
  const r=runtime();r.position('LIVE','AAA',shares,0.2);r.quote('AAA',0.2,0.2,0.2);
  r.sendHook=o=>{o.Open=0;o.Status='Rejected';};r.run('GTFO');for(let i=0;i<12;i++)r.tick();
  assert.equal(r.orders.length,1);assert.equal(r.orders[0].Route,'BESTL');
});

// Syntax-check all mapped scripts after translating native DAS statements.
for(const f of new Set(scripts.values())) new vm.Script('(function(){'+translate(fs.readFileSync(path.join(root,f),'utf8'))+'})()',{filename:f});
console.log(`${count} trade-isolation regression scenarios passed; ${scripts.size} hotkeys parsed.`);
