const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const src = fs.readFileSync(__dirname + '/browser_cache_export.js', 'utf8');

(async () => {
  const data = {
    'flutter.cache_records_flat_v1_abcd': '[{"title":"Work"}]',
    'flutter.cache_categories_raw_v1_abcd': '[{"name":"Personal"}]',
    'flutter.pb_auth': JSON.stringify({token:'SECRET_JWT', record:{id:'abcdefghijklmno', email:'test@example.com'}}),
    'flutter.some_api_key': 'NOT_EXPORTED',
    'unrelatedKey': 'NOT_EXPORTED_EITHER',
  };
  let result;
  let filename;
  const anchor = {style:{},click(){filename=this.download;},remove(){}};
  const ctx = {
    location: {origin:'https://nkuchenov-hash.github.io',pathname:'/Counter/'},
    localStorage: {length:Object.keys(data).length,key:i=>Object.keys(data)[i],getItem:k=>data[k]},
    indexedDB: {databases:async()=>[]},
    document: {createElement:()=>anchor,body:{appendChild(){}}},
    Blob,URL:{createObjectURL(blob){result=blob;return 'blob:private';},revokeObjectURL(){}},
    setTimeout(){},Date,JSON,Object,Error,Promise,String,console:{info(){}},
  };
  vm.runInNewContext(src,ctx);
  await new Promise(resolve=>setTimeout(resolve,100));
  const parsed=JSON.parse(await result.text());
  assert.strictEqual(parsed.identity.pocketBaseId,'abcdefghijklmno');
  assert.strictEqual(parsed.identity.email,'test@example.com');
  const serialized=JSON.stringify(parsed);
  for(const secret of ['SECRET_JWT','NOT_EXPORTED','NOT_EXPORTED_EITHER']){
    assert(!serialized.includes(secret),'Secret leaked from browser export: '+secret);
  }
  assert.strictEqual(parsed.localStorage['flutter.cache_records_flat_v1_abcd'],'[{"title":"Work"}]');
  assert(filename.startsWith('LIFEOS-BROWSER-RECOVERY'));
  console.log('PASS: browser recovery exporter saves expected caches and excludes auth tokens');
})().catch(e=>{console.error(e);process.exit(1)});
