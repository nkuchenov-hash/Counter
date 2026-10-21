'use strict';
const https=require('node:https'),crypto=require('node:crypto');
const {WebSocket}=require('ws');
const host='217-114-0-201.sslip.io:8443';
const sid=crypto.randomBytes(18).toString('base64url');
const token=crypto.randomBytes(32).toString('base64url');
function request(method,path,headers={},body=null) {
  return new Promise((resolve,reject)=>{
    const req=https.request({host:'217-114-0-201.sslip.io',port:8443,path,method,headers,timeout:10000},res=>{
      let text='';res.on('data',x=>text+=x);res.on('end',()=>resolve({status:res.statusCode,body:text}));
    });
    req.on('error',reject);req.on('timeout',()=>req.destroy(new Error('request timeout')));
    if(body)req.write(body);req.end();
  });
}
async function main(){
  const health=await request('GET','/health');
  if(health.status!==200 || JSON.parse(health.body).persistentSessions!==true)throw Error('bad health');
  const ws=new WebSocket('wss://'+host+'/v1/session/'+sid+'/ws?role=pc&token='+token,{handshakeTimeout:10000});
  await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject)});
  const forbidden=await request('POST','/v1/session/'+sid+'/upload',{
     'Authorization':'Bearer wrong','X-KADR-Enc':'aes-256-gcm',
     'Content-Length':'1'
   },Buffer.from('a'));
  if(forbidden.status!==401)throw Error('unauthorized upload accepted');
  const body=Buffer.from('opaque-test-ciphertext-not-a-real-screenshot');
  let received=false;
  const receivedPromise=new Promise((resolve,reject)=>{
    const timeout=setTimeout(()=>reject(Error('WS transfer timeout')),9000);
    ws.on('message',(frame,binary)=>{
      if(!binary)return;
      const len=(frame[1]<<8)|frame[2];
      const header=JSON.parse(frame.subarray(3,3+len).toString());
      const data=frame.subarray(3+len);
      if(header.type==='upload' && header.enc==='aes-256-gcm' && data.equals(body)){
        clearTimeout(timeout);received=true;resolve();
      }
    });
  });
  const transfer=await request('POST','/v1/session/'+sid+'/upload',{
     'Authorization':'Bearer '+token,'X-KADR-Enc':'aes-256-gcm',
     'X-KADR-File-Name':'test.png','Content-Length':String(body.length)
   },body);
  await receivedPromise;
  if(transfer.status!==200 || !received)throw Error('transfer not relayed');
  ws.close();
  const offline=await request('POST','/v1/session/'+sid+'/upload',{
     'Authorization':'Bearer '+token,'X-KADR-Enc':'aes-256-gcm',
     'Content-Length':'1'
  },Buffer.from('a'));
  if(offline.status!==503 && offline.status!==200)throw Error('unexpected offline status');
  console.log('relay_health=200');
  console.log('relay_wrong_token=401');
  console.log('relay_ws_encrypted_frame=verified');
  console.log('relay_http_upload=200');
  console.log('relay_test_result=PASS');
}
main().catch(error=>{console.error('relay_test_result=FAIL '+error.message);process.exitCode=1});
