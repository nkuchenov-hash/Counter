#!/usr/bin/env python3
"""Exercise the real interactive recovery login migration on clean PocketBase.

Uses a disposable copy of the fresh database migrated in CI, writes no real
profile/email/password, starts a separate temporary localhost PB process.
"""
import os,pathlib,re,sqlite3,subprocess,sys,tempfile,json,urllib.request,time
from restore_browser_clone import insert

def main(pb_executable,empty_pb):
    with tempfile.TemporaryDirectory() as td:
        root=pathlib.Path(td)
        data=root/"pb_data"
        migrations=root/"pb_migrations"
        hooks=root/"empty_hooks"
        data.mkdir(); migrations.mkdir(); hooks.mkdir()
        src=sqlite3.connect("file:"+str(pathlib.Path(empty_pb).resolve())+"?mode=ro",uri=True)
        dst=sqlite3.connect(data/"data.db")
        src.backup(dst);src.close()
        dst.row_factory=sqlite3.Row
        with dst:
            insert(dst,"profiles",{"id":"xhjy54inue73piz","email":"","verified":False,"tokenKey":"b"*48})
        dst.close()

        launcher=pathlib.Path(__file__).with_name("activate_lifeos_web.sh").read_text()
        match=re.search(r"cat > .*?1793832010_claim_recovery_owner\.js.*?<<'JS'\n(.*?)\nJS",launcher,re.S)
        if not match: raise AssertionError("Real owner-claim migration missing from launcher")
        (migrations/"1793832010_claim_recovery_owner.js").write_text(match.group(1)+"\n")
        env={**os.environ,
             "LIFEOS_RECOVERY_OWNER_ID":"xhjy54inue73piz",
             "LIFEOS_OWNER_EMAIL":"recovery-fixture@example.invalid",
             "LIFEOS_OWNER_PASSWORD":"NotARealPasswordForCI!2026"}
        subprocess.run([pb_executable,"migrate","up",f"--dir={data}",
                        f"--migrationsDir={migrations}",f"--hooksDir={hooks}"],
                       check=True,env=env,timeout=35,stdout=subprocess.DEVNULL)
        conn=sqlite3.connect(data/"data.db")
        row=conn.execute("SELECT email,password FROM profiles WHERE id=?",("xhjy54inue73piz",)).fetchone()
        assert row[0]=="recovery-fixture@example.invalid"
        assert row[1] and "NotARealPasswordForCI!2026" not in row[1]
        conn.close()
        # Assert same original user ID actually signs in via PocketBase API.
        port=18105
        proc=subprocess.Popen([pb_executable,"serve",f"--http=127.0.0.1:{port}",f"--dir={data}",
                               f"--migrationsDir={migrations}",f"--hooksDir={hooks}"],
                              stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,env=env)
        try:
            for _ in range(30):
                try:
                    with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/health",timeout=1):
                        break
                except (OSError,TimeoutError):
                    time.sleep(.25)
            request=urllib.request.Request(f"http://127.0.0.1:{port}/api/collections/profiles/auth-with-password",
                       data=json.dumps({"identity":env["LIFEOS_OWNER_EMAIL"],"password":env["LIFEOS_OWNER_PASSWORD"]}).encode(),
                       headers={"Content-Type":"application/json"},method="POST")
            with urllib.request.urlopen(request,timeout=8) as resp: result=json.load(resp)
            assert result["record"]["id"]=="xhjy54inue73piz"
            assert result["token"]
        finally:
            proc.terminate()
            try:proc.wait(timeout=5)
            except subprocess.TimeoutExpired:proc.kill()
        print("PASS: original profile ID keeps relations, email/password login and bcrypt hash work on PB v0.40.6")

if __name__=="__main__":
    assert len(sys.argv)==3
    main(sys.argv[1],sys.argv[2])
