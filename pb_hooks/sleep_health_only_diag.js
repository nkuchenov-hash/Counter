function env(name) { try { return String($os.getenv(name) || '').trim(); } catch (_) { return ''; } }
function form(values) { var parts=[]; for (var key in values) if (Object.prototype.hasOwnProperty.call(values,key)) parts.push(encodeURIComponent(key)+'='+encodeURIComponent(String(values[key]))); return parts.join('&'); }
function tokenKey(app) { var key=env('SLEEP_SYNC_TOKEN_KEY'); if(key.length===32) return key; var envName=''; try{envName=String(app.encryptionEnv()||'').trim();}catch(_){} var inherited=envName?env(envName):''; if(inherited.length===32) return inherited; throw new Error('token_key_unavailable'); }
function connection(app) { return app.findFirstRecordByFilter('sleep_sync_connections', "provider = 'google_fit'", {}); }
function healthToken(app,c) {
  var refreshEnc=String(c.get('refresh_token_enc')||''); if(!refreshEnc) throw new Error('refresh_token_missing');
  var clientId=env('SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID'), clientSecret=env('SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET'); if(!clientId||!clientSecret) throw new Error('oauth_client_missing');
  var refresh=String($security.decrypt(refreshEnc,tokenKey(app)));
  var res=$http.send({url:'https://oauth2.googleapis.com/token',method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:form({refresh_token:refresh,client_id:clientId,client_secret:clientSecret,grant_type:'refresh_token',scope:'https://www.googleapis.com/auth/googlehealth.sleep.readonly'}),timeout:30});
  if(res.statusCode<200||res.statusCode>=300||!res.json||!res.json.access_token) throw new Error('token_refresh_'+res.statusCode);
  return String(res.json.access_token);
}
function latestDay(rows){var latest=0; for(var i=0;i<rows.length;i++){var p=rows[i]||{},s=p.sleep||{},iv=s.interval||{},raw=String(iv.endTime||iv.end_time||''); var ms=raw?Date.parse(raw):NaN; if(isFinite(ms)&&ms>latest)latest=ms;} return latest?new Date(latest).toISOString().slice(0,10):'none';}
function run(e){
  try{
    var c=connection(e.app), token=healthToken(e.app,c);
    var ti=$http.send({url:'https://oauth2.googleapis.com/tokeninfo?access_token='+encodeURIComponent(token),method:'GET',headers:{'accept':'application/json'},timeout:30});
    var start=new Date(Date.now()-4*86400000).toISOString(), end=new Date().toISOString();
    var res=$http.send({url:'https://health.googleapis.com/v4/users/me/dataTypes/sleep/dataPoints:reconcile?'+form({pageSize:100,dataSourceFamily:'users/me/dataSourceFamilies/all-sources',filter:'sleep.interval.end_time >= "'+start+'" AND sleep.interval.end_time < "'+end+'"'}),method:'GET',headers:{'authorization':'Bearer '+token,'accept':'application/json'},timeout:60});
    var rows=(res.json&&(res.json.dataPoints||res.json.data_points))||[];
    var recent=[]; try{recent=e.app.findRecordsByFilter('records',"(title = 'Sleep' || title = 'Сон') && end_time >= {:cutoff}",'',100,0,{cutoff:new Date(Date.now()-36*3600000).toISOString()});}catch(_){}
    return e.json(200,{token_status:ti?ti.statusCode:0,health_status:res?res.statusCode:0,health_points:rows.length,latest_health_sleep_day:latestDay(rows),pocketbase_sleep_last_36h:recent.length,enabled:!!c.get('enabled'),stored_error:String(c.get('last_error')||'')||'none'});
  }catch(err){return e.json(200,{diagnostic_error:String(err)});}
}
module.exports={run:run};
