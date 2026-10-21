'use strict';
// KADR personal HTTPS relay: isolated prototype, not a multi-tenant public service.
// Routes encrypted opaque screenshot envelopes without storing files.
const https = require('node:https');
const fs = require('node:fs');
const crypto = require('node:crypto');
const {WebSocketServer, WebSocket} = require('ws');

const PORT = 8443;
const MAX_UPLOAD = 12 * 1024 * 1024;
const MAX_SESSIONS = 4;
const SESSION_TTL = 60 * 60 * 1000;
const tokenFormat = x => typeof x === 'string' && x.length >= 32 && x.length <= 160 && /^[A-Za-z0-9_-]+$/.test(x);
const idFormat = x => typeof x === 'string' && x.length >= 16 && x.length <= 160 && /^[A-Za-z0-9_-]+$/.test(x);
const sessions = new Map();
let inFlight = 0;
function fixedEqual(a,b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const aa = Buffer.from(a); const bb = Buffer.from(b);
  return aa.length === bb.length && crypto.timingSafeEqual(aa,bb);
}
function json(res,code,data) {
  if (res.writableEnded || res.destroyed) return;
  res.writeHead(code,{'Content-Type':'application/json','Cache-Control':'no-store'});
  res.end(JSON.stringify(data));
}
function validSession(sid, token, allowPcCreate=false) {
  if (!idFormat(sid) || !tokenFormat(token)) return null;
  let s = sessions.get(sid);
  if (s && s.expires < Date.now()) {
    for (const ws of s.peers.values()) ws.close(4000,'expired');
    sessions.delete(sid);
    s = null;
  }
  if (!s && allowPcCreate && sessions.size < MAX_SESSIONS) {
    s={id:sid,token,peers:new Map(),pendingAcks:new Map(),expires:Date.now()+SESSION_TTL,activeUploads:0};
    sessions.set(sid,s);
  }
  if (!s || !fixedEqual(s.token,token)) return null;
  s.expires=Date.now()+SESSION_TTL;
  return s;
}
setInterval(()=>{
  for (const [id,s] of sessions) {
    if (s.expires < Date.now()) {
      for (const ws of s.peers.values()) ws.close(4000,'expired');
      sessions.delete(id);
    }
  }
},60000).unref();

async function handleUpload(req,res,sid) {
  const bearer = req.headers.authorization || '';
  const token = bearer.startsWith('Bearer ') ? bearer.slice(7).trim() : '';
  const s = validSession(sid,token);
  if (!s) {req.resume();json(res,401,{ok:false,error:'not_authorized'});return;}
  const pc = s.peers.get('pc');
  if (!pc || pc.readyState !== WebSocket.OPEN) {
    req.resume();json(res,503,{ok:false,error:'desktop_offline'});return;
  }
  if (req.headers['x-kadr-enc'] !== 'aes-256-gcm') {
    req.resume();json(res,400,{ok:false,error:'encryption_required'});return;
  }
  if (inFlight >= 2 || s.activeUploads >= 1) {
    req.resume();json(res,503,{ok:false,error:'busy'});return;
  }
  if (Number(req.headers['content-length'] || 0) > MAX_UPLOAD) {
    req.resume();json(res,413,{ok:false,error:'too_large'});return;
  }
  inFlight++; s.activeUploads++;
  try {
    const chunks=[];let len=0;
    for await (const chunk of req) {
      len += chunk.length;
      if(len>MAX_UPLOAD) {json(res,413,{ok:false,error:'too_large'});return;}
      chunks.push(chunk);
    }
    if (!len || pc.readyState!==WebSocket.OPEN) {
      json(res,503,{ok:false,error:'desktop_offline'});return;
    }
    const safeName = String(req.headers['x-kadr-file-name'] || 'screenshot.png')
      .replace(/[^a-zA-Z0-9_.-]/g,'_').slice(0,120);
    const supportsAck = pc.kadrAckV1 === true;
    const uploadId = crypto.randomBytes(16).toString('base64url');
    const header=Buffer.from(JSON.stringify({
      type:'upload', fileName:safeName, contentType:'application/octet-stream',
      enc:'aes-256-gcm', size:len,
      ...(supportsAck ? {uploadId} : {})
    }));
    const frame=Buffer.concat([Buffer.from([1,header.length>>8,header.length&255]),header,...chunks]);
    let acknowledged;
    if (supportsAck) {
      acknowledged = new Promise(resolve=>{
        const timer=setTimeout(()=>{
          s.pendingAcks.delete(uploadId);
          resolve(false);
        },18000);
        s.pendingAcks.set(uploadId,{
          ws:pc,
          resolve:(ok)=>{
            clearTimeout(timer);
            s.pendingAcks.delete(uploadId);
            resolve(ok === true);
          }
        });
      });
    }
    const sent = await new Promise(resolve=>{
      if (pc.readyState!==WebSocket.OPEN || pc.bufferedAmount>MAX_UPLOAD) return resolve(false);
      pc.send(frame,{binary:true},err=>resolve(!err));
    });
    if (!sent) {
      if (supportsAck) s.pendingAcks.get(uploadId)?.resolve(false);
      json(res,503,{ok:false,error:'desktop_disconnected'});
      return;
    }
    if (!supportsAck) {
      // Legacy Windows remains compatible but is never reported as durably saved.
      json(res,200,{ok:true,path:'relay',confirmedSaved:false});
      return;
    }
    const saved = await acknowledged;
    // HTTP 200 now means the desktop capture pipeline accepted the file.
    // No receipt or a negative receipt leaves the original item on Android.
    json(res,saved?200:503,{
      ok:saved,path:'relay',confirmedSaved:saved,
      ...(!saved ? {error:'desktop_save_not_confirmed'} : {})
    });
  } catch (e) {
    json(res,503,{ok:false,error:'transfer_interrupted'});
  } finally {inFlight--;s.activeUploads--;}
}

const tls={
  key:fs.readFileSync('/tls/privkey.pem'),
  cert:fs.readFileSync('/tls/fullchain.pem'),
  minVersion:'TLSv1.2'
};
const server=https.createServer(tls,(req,res)=>{
  let url;
  try {url=new URL(req.url,'https://localhost');} catch {return json(res,400,{ok:false});}
  if(req.method==='GET' && url.pathname==='/health') {
    return json(res,200,{service:'kadr-relay',ok:true,protocolVersion:3,persistentSessions:true,durableAckSupported:true});
  }
  const match=url.pathname.match(/^\/v1\/session\/([A-Za-z0-9_-]+)\/upload$/);
  if(req.method==='POST' && match) {void handleUpload(req,res,match[1]);return;}
  if (req.method==='POST' && url.pathname==='/v1/session') {
    return json(res,403,{ok:false,error:'legacy_session_disabled'});
  }
  json(res,404,{ok:false,error:'not_found'});
});
const wss=new WebSocketServer({noServer:true,perMessageDeflate:false,maxPayload:MAX_UPLOAD+4096});
server.on('upgrade',(req,socket,head)=>{
  try {
    const url=new URL(req.url,'https://localhost');
    const m=url.pathname.match(/^\/v1\/session\/([A-Za-z0-9_-]+)\/ws$/);
    const role=url.searchParams.get('role');
    const token=url.searchParams.get('token') || '';
    if(!m || !['pc','phone'].includes(role)) {socket.destroy();return;}
    const s=validSession(m[1],token,role==='pc');
    if(!s) {socket.destroy();return;}
    wss.handleUpgrade(req,socket,head,ws=>{
      ws.kadrAckV1 = role === 'pc' && url.searchParams.get('ack') === '1';
      const previous=s.peers.get(role);
      if(previous) previous.close(4003,'replaced');
      s.peers.set(role,ws);
      ws.send(JSON.stringify({type:'welcome',role,sessionId:s.id,peers:[...s.peers.keys()],protocolVersion:3,expiresAt:s.expires}));
      const peer=s.peers.get(role==='pc'?'phone':'pc');
      if(peer && peer.readyState===WebSocket.OPEN) {
        peer.send(JSON.stringify({type:'peer_joined',role}));
        ws.send(JSON.stringify({type:'peer_joined',role:role==='pc'?'phone':'pc'}));
      }
      ws.on('message',(data,isBinary)=>{
        s.expires=Date.now()+SESSION_TTL;
        if (isBinary || role!=='pc' || !ws.kadrAckV1) return;
        try {
          const msg=JSON.parse(data.toString());
          if (msg.type!=='upload_ack' || typeof msg.uploadId!=='string') return;
          const pending=s.pendingAcks.get(msg.uploadId);
          if (pending && pending.ws===ws) pending.resolve(msg.ok===true);
        } catch (_) {}
      });
      ws.on('close',()=>{
        if(role==='pc') {
          for (const pending of s.pendingAcks.values()) {
            if(pending.ws===ws) pending.resolve(false);
          }
        }
        if(s.peers.get(role)===ws) {
          s.peers.delete(role);
          const other=s.peers.get(role==='pc'?'phone':'pc');
          if(other && other.readyState===WebSocket.OPEN) other.send(JSON.stringify({type:'peer_left',role}));
        }
      });
    });
  } catch {socket.destroy();}
});
server.headersTimeout=10000;
server.requestTimeout=40000;
server.keepAliveTimeout=5000;
if(process.getuid && process.getuid()===0) {
  process.setgid(1000);
  process.setuid(1000);
}
server.listen(PORT,'0.0.0.0',()=>console.log('KADR_PERSONAL_RELAY_READY port='+PORT));
