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
      r.orders.push(object({Account:r.account,Symbol:r.symbol,Side:pos<0?'B':'S',Share:ctx.Share,Price:ctx.Price,Route:ctx.ROUTE}));
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
  r.position('TRSIM','AAA',0);r.tick();assert.equal(r.alerts.size,2);assert.equal(r.state('LIVE','AAA').lastStop,9.5);
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
test('backstop supersedes pending TP exit without a later timer rearm',()=>{
  const r=runtime();r.position('LIVE','AAA',100);r.run('Set Auto Stop');r.run('Set Backstop Trigger');r.run('Set Take Profit');
  const backstop=r.alerts.get('Backstop LIVE AAA'), tp=[...r.alerts.values()].find(a=>a.Name.startsWith('TP '));
  r.execute(tp.Script);const partial=r.orders.at(-1);assert.equal(r.state('LIVE','AAA').exitPending,1);
  r.execute(backstop.Script);assert(partial.canceled);assert.equal(r.orders.at(-1).Share,100);
  assert.equal(r.state('LIVE','AAA').exitPending,0);
  const n=r.orders.length;r.tick();r.tick();assert.equal(r.orders.length,n);
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
for(const price of [0.1,0.4166,5/12,0.4167,0.75,0.9999,1,1.01,100]) {
  for(const side of ['B','S','SS']) test('AUTOL fee band '+price+' '+side,()=>{
    const r=runtime();r.run('Set Order Route AUTOL');
    const expected=price>=1?'FREE1L':price<=5/12?'BESTL':'SMARTL';
    assert.equal(resolveRoute(r,{side,limit:price,bid:price,ask:price}),expected);
    assert.equal(r.ctx.$orderRoute,'AUTOL');assert.equal(r.orders.length,0);
  });
}
test('AUTOL uses opposite quote for marketable orders and limit for resting orders',()=>{
  const r=runtime();r.run('Set Order Route AUTOL');
  assert.equal(resolveRoute(r,{limit:1.1,bid:0.97,ask:0.98}),'SMARTL');
  assert.equal(resolveRoute(r,{side:'S',limit:0.9,bid:1.02,ask:1.03}),'FREE1L');
  assert.equal(resolveRoute(r,{limit:0.4,bid:0.49,ask:0.5}),'BESTL');
  assert.equal(resolveRoute(r,{side:'SS',limit:1.01,bid:0.98,ask:0.99}),'FREE1L');
});
test('AUTOL invalid quotes clear the last result instead of choosing a fallback',()=>{
  const r=runtime();r.run('Set Order Route AUTOL');resolveRoute(r);
  assert.equal(resolveRoute(r,{ask:0}),'');assert.equal(resolveRoute(r,{bid:0}),'');
  assert.equal(resolveRoute(r,{limit:0}),'');assert.equal(resolveRoute(r,{side:'unknown'}),'');
  assert.equal(r.ctx.$orderRoute,'AUTOL');
});
test('manual route presets disable AUTOL and pass through without quotes',()=>{
  const r=runtime();
  for(const name of ['ARCA1L','FREE1L','BESTL','FLASH1L','SMARTL']) {
    r.run('Set Order Route AUTOL');r.run('Set Order Route '+name);
    assert.equal(resolveRoute(r,{bid:0,ask:0,limit:0}),name);
  }
});
for(const label of [...buyLabels,...manualExits,...scripts.keys()].filter((v,i,a)=>a.indexOf(v)===i&&/^(Buy .* SL|Sell |Cover |Short T)/.test(v))) {
  test(label+' submits a concrete AUTOL route and retains the mode',()=>{
    const r=runtime();r.quote('AAA',0.75,0.76,0.75);
    r.position('LIVE','AAA',label.startsWith('Sell ')?100:label.startsWith('Cover ')?-100:0,0.75);
    r.run('Set Order Route AUTOL');r.run(label);
    assert.equal(r.orders.length,1);assert.equal(r.orders[0].Route,'SMARTL');
    assert.equal(r.ctx.$orderRoute,'AUTOL');assert.equal(r.ctx.$tradeActionDepth,0);
  });
}
test('AUTOL sell uses bid above one dollar even with a sub-dollar exit limit',()=>{
  const r=runtime();r.position('LIVE','AAA',100,1.02);r.quote('AAA',1.02,1.03,1.02);
  r.run('Set Order Route AUTOL');r.run('Sell 1/1 Bid-');
  assert(r.orders[0].Price<1);assert.equal(r.orders[0].Route,'FREE1L');
});
test('AUTOL cover resolves using the final natively rounded limit',()=>{
  const r=runtime();r.position('LIVE','AAA',-100,0.99);r.quote('AAA',0.9996,1.01,1);
  r.run('Set Order Route AUTOL');r.run('Cover 1/1 Bid');
  assert.equal(r.orders[0].Price,1);assert.equal(r.orders[0].Route,'FREE1L');
});
test('AUTOL TP resolves the alert symbol instead of the active montage',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.75);r.quote('AAA',0.75,0.76,0.75);
  r.run('Set Take Profit');const al=[...r.alerts.values()][0];
  r.select('TRSIM','OTHER');r.position('TRSIM','OTHER',-100,10);r.quote('OTHER');
  r.run('Set Order Route AUTOL');r.execute(al.Script);
  assert.equal(r.orders[0].Symbol,'AAA');assert.equal(r.orders[0].Route,'SMARTL');
});
for(const share of [100,-100]) test('AUTOL GTFO uses BEST for signed position '+share,()=>{
  const r=runtime();r.position('LIVE','AAA',share,10);r.run('Set Order Route AUTOL');r.run('GTFO');
  assert.equal(r.orders.length,1);assert.equal(r.orders[0].Route,'BESTL');
  assert.equal(r.ctx.$gtfoRoute,'FLSH1L');assert.equal(r.ctx.$orderRoute,'AUTOL');
});
test('AUTOL backstop and hijack use BEST, manual emergency route stays independent',()=>{
  const r=runtime();r.position('LIVE','AAA',100,10);r.run('Set Auto Stop');r.run('Set Backstop Trigger');
  r.run('Set Order Route AUTOL');r.execute(r.alerts.get('Backstop LIVE AAA').Script);
  assert.equal(r.orders.at(-1).Route,'BESTL');
  const h=runtime();h.position('LIVE','AAA',1000,10);h.ctx.$hijackProtection=1;
  h.run('Set Order Route AUTOL');h.run('Hijack Exit');assert.equal(h.orders.at(-1).Route,'BESTL');
  const m=runtime();m.position('LIVE','AAA',100,10);m.run('GTFO');assert.equal(m.orders[0].Route,'FLSH1L');
});
test('AUTOL preserves STOP and resolves immediate breakeven limit exits',()=>{
  const r=runtime();r.position('LIVE','AAA',100,0.75);r.quote('AAA',0.75,0.76,0.75);
  r.run('Set Order Route AUTOL');r.run('Set Auto Stop BE 1/1');
  assert.equal(r.orders[0].Type,'L');assert.equal(r.orders[0].Route,'SMARTL');
  r.position('LIVE','AAA',100,10);r.quote('AAA',11,11.02,11);r.run('Set Auto Stop');
  assert.equal(r.orders.at(-1).Route,'STOP');
});
test('AUTOL never reroutes or retries a rejected submission',()=>{
  const r=runtime();r.run('Set Order Route AUTOL');
  r.sendHook=o=>{o.Open=0;o.Status='Rejected';};r.run('Buy MIB Ask SL');
  for(let i=0;i<12;i++)r.tick();
  assert.equal(r.orders.length,1);assert.equal(r.orders[0].Route,'FREE1L');
});

// Syntax-check all mapped scripts after translating native DAS statements.
for(const f of new Set(scripts.values())) new vm.Script('(function(){'+translate(fs.readFileSync(path.join(root,f),'utf8'))+'})()',{filename:f});
console.log(`${count} trade-isolation regression scenarios passed; ${scripts.size} hotkeys parsed.`);
