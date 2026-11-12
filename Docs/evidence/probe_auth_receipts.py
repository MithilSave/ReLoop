import httpx, json
B="http://localhost:8000/api/v1"; c=httpx.Client(timeout=30,headers={"Connection":"close"})
def login(e):
    r=c.post(B+"/auth/login",json={"login":e,"password":"reloop123"}); r.raise_for_status(); return r.json()
T={k:login(k+"@reloop.in") for k in ["generator","collector","recycler","ngo","epr","admin"]}
H=lambda k:{"Authorization":"Bearer "+T[k]["access_token"]}
for k,v in T.items(): print(k, v["org"]["org_type"], v["org"]["legal_name"], v["role"], "admin" if v["user"]["is_platform_admin"] else "")
def show(t,r): print(f"\n## {t}: {r.status_code} {r.text[:300]}")
# 1 refresh
pass
# 2 refresh token as access token
show("refresh-token-as-bearer /auth/me", c.get(B+"/auth/me",headers={"Authorization":"Bearer "+T["collector"]["refresh_token"]}))
# 3 batches overview
bs=c.get(B+"/batches",headers=H("admin")).json()
print("\nbatches:",[(b["batch_code"],b["status"],b["material"]) for b in bs])
# 4 cross-org read: collector reads any batch?
show("NGO list batches count", httpx.Response(200,text=str(len(c.get(B+"/batches",headers=H("ngo")).json()))))
# 5 receipt on LISTED batch (should be refused?)
listed=[b for b in bs if b["status"]=="LISTED"][0]
show("receipt on LISTED batch "+listed["batch_code"], c.post(B+"/recycler/receipts",headers=H("recycler"),json={"batch_id":listed["id"],"received_kg":10,"accepted_kg":10,"rejected_kg":0}))
# 6 second receipt on same batch, then batch detail
show("second receipt same batch", c.post(B+"/recycler/receipts",headers=H("recycler"),json={"batch_id":listed["id"],"received_kg":12,"accepted_kg":12,"rejected_kg":0}))
show("batch detail after 2 receipts", c.get(B+"/batches/"+listed["id"],headers=H("recycler")))
# 7 processing input exceeding accepted
recs=c.post(B+"/recycler/receipts",headers=H("recycler"),json={"batch_id":[b for b in bs if b["status"]=="LISTED"][1]["id"],"received_kg":20,"accepted_kg":20,"rejected_kg":0}).json()
show("receipt for over-process test", httpx.Response(200,text=json.dumps(recs)))
show("process 500kg from a 20kg receipt", c.post(B+"/recycler/processing-records",headers=H("recycler"),json={"material_code":"PET","run_started_at":"2026-11-12T08:00:00Z","run_ended_at":"2026-11-12T10:00:00Z","inputs":[{"recycler_receipt_id":recs["receipt_id"],"input_kg":500}],"output_kg":450,"residue_kg":10,"eligible_kg":450}))
show("same receipt processed again", c.post(B+"/recycler/processing-records",headers=H("recycler"),json={"material_code":"PET","run_started_at":"2026-11-12T08:00:00Z","run_ended_at":"2026-11-12T10:00:00Z","inputs":[{"recycler_receipt_id":recs["receipt_id"],"input_kg":20}],"output_kg":18,"residue_kg":1,"eligible_kg":18}))
# 8 NGO assignment of new verifications
v=c.get(B+"/ngo/verifications",headers=H("ngo")).json(); print("\nngo queue:",[(x["batch_code"],x["decision"]) for x in v])
import sqlite3
db=sqlite3.connect("/home/claude/mithilsave/reloop/backend/reloop.db")
print("verification ngo orgs:",db.execute("select o.legal_name, v.decision, count(*) from ngo_verifications v join organisations o on o.id=v.ngo_org_id where v.is_current=1 group by 1,2").fetchall())
# 9 org listing endpoints
for p in ["/orgs","/admin/orgs","/organisations","/orgs/recyclers"]: show("GET "+p, c.get(B+p,headers=H("admin")))
# 10 anomalies resolve by collector (OWNER role)
an=c.get(B+"/anomalies",headers=H("collector")).json(); print("\nanomalies visible to collector:",len(an))
if an: show("collector resolves anomaly", c.post(B+f"/anomalies/{an[0]['id']}/resolve",headers=H("collector"),json={"status":"RESOLVED","note":"probe"}))
# 11 public passport route claimed in README
show("GET /b/{code} (README)", c.get("http://localhost:8000/b/"+bs[0]["batch_code"]))
show("passport without auth", c.get(B+"/passports/"+bs[0]["batch_code"]))
# 12 404 / 422 formats
show("422 format", c.post(B+"/batches",headers=H("generator"),json={"material_code":"PET"}))
show("403 format", c.post(B+"/batches",headers=H("collector"),json={}))
show("401 format", c.get(B+"/batches"))
