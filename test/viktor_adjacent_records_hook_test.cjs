'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let route;
vm.runInNewContext(
  fs.readFileSync('pb_hooks/viktor.records_adjust_adjacent.pb.js', 'utf8'),
  {routerAdd(method,path,cb) {
    assert.equal(method,'POST');
    assert.equal(path,'/api/viktor/records/adjust-adjacent');
    route=cb;
  },Date,Set,Math,Number,Object,String,Array,RegExp},
  {timeout:3000}
);
assert.equal(typeof route,'function');
const owner='aaaaabbbbbccccc', other='otherprofile123';
const one='aaabbbcccddd111', two='aaabbbcccddd222', blocker='aaabbbcccddd333';
const now=Date.now();
const at=ms=>new Date(now+ms).toISOString();
const from=at(-3*3600000), oldFirstEnd=at(-90*60000);
const oldSecondEnd=at(-20*60000), newFirstEnd=at(-150*60000);
const newSecondEnd=at(-2000), revision=at(-1000);
const copy=obj=>JSON.parse(JSON.stringify(obj));
let data, rejectSave;
function reset() {
  data={
    [one]:{user_id:owner,title:'Обед',status:'stopped',
      updated:revision,start_time:from,end_time:oldFirstEnd,parent_id:0},
    [two]:{user_id:owner,title:'Этника сайт',status:'stopped',
      updated:revision,start_time:oldFirstEnd,end_time:oldSecondEnd,parent_id:0},
  };
  rejectSave=null;
}
reset();
function mockRecord(id,row) {
  return {id,getString(k){return String(row[k]??'');},
    set(k,v){row[k]=v;}};
}
const app={runInTransaction(callback) {
  const staged=copy(data);
  const tx={
    findRecordById(coll,id) {
      assert.equal(coll,'records');
      if(!staged[id]) throw Error('missing');
      return mockRecord(id,staged[id]);
    },
    findRecordsByFilter(coll,filter,order,limit,offset,params) {
      assert.equal(coll,'records');
      assert.equal(params.owner,owner);
      return Object.entries(staged)
        .filter(([,row])=>row.user_id===owner&&
          Date.parse(row.start_time)<Date.parse(params.latest)&&
          (Date.parse(row.start_time)>=Date.parse(params.earliest)||
            Date.parse(row.end_time)>Date.parse(params.earliest)||
            row.status==='running'))
        .map(([id,row])=>mockRecord(id,row));
    },
    save(row){if(row.id===rejectSave)throw Error('simulated_second_save_failure');}
  };
  callback(tx);
  data=staged;
}};
const first={id:one,expected_title:'Обед',expected_updated:revision,
  expected_start:from,expected_end:oldFirstEnd,
  expected_status:'stopped',start_time:from,end_time:newFirstEnd};
const second={id:two,expected_title:'Этника сайт',expected_updated:revision,
  expected_start:oldFirstEnd,expected_end:oldSecondEnd,
  expected_status:'stopped',start_time:newFirstEnd,end_time:newSecondEnd};
function run(body={request_id:'viktor_record_atomic_20261113',first,second},
    id=owner) {
  return route({requestInfo(){return{auth:id?{id}:null,body};},app,
    json(status,body){return{status,body};}});
}
assert.equal(run(undefined,null).status,401);
assert.equal(run({...{request_id:'viktor_record_atomic_20261113',first,
  second:{...second,extra:'unexpected'}}}).status,400);
assert.equal(run({request_id:'viktor_record_atomic_20261113',
  first:{...first,id:two},second}).status,400);
assert.equal(run(undefined,other).status,409);
assert.equal(data[one].end_time,oldFirstEnd);
const staleSecond={...second,expected_updated:at(-800)};
assert.equal(run({request_id:'viktor_record_atomic_20261113',
  first,second:staleSecond}).status,409);
assert.equal(data[one].end_time,oldFirstEnd);
data[blocker]={...data[one],title:'Other task',
  start_time:at(-140*60000),end_time:at(-130*60000)};
assert.equal(run().status,409);
assert.equal(data[one].end_time,oldFirstEnd);
delete data[blocker];
rejectSave=two;
assert.equal(run().status,409);
assert.equal(data[one].end_time,oldFirstEnd,
  'failure writing second record must rollback first');
rejectSave=null;
const ok=run();
assert.equal(ok.status,200);
assert.equal(ok.body.updated,2);
assert.equal(data[one].end_time,newFirstEnd);
assert.equal(data[two].start_time,newFirstEnd);
assert.equal(data[two].end_time,newSecondEnd);
assert.equal(data[two].status,'stopped');
assert.equal(data[two].title,'Этника сайт');
assert.equal(run().status,409,'replayed stale request must fail');
process.stdout.write('Viktor two-record atomic adjustment verified\n');
