"""Regenerates images/architecture-digitalocean.svg. Run from packages/docs."""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from arch import *

D="#0080ff"; AMB="#b45309"; b=[]
R_ENGINE, R_MID, R_CANVAS = 353, 407, 460
RH = 46
CLI_Y, OPR_Y, EXT_Y = 353, 460, 562   # clients level with 443 rule, operator level with 3001 rule

d1,w1,_ = fitbox(0,0,"Managed Postgres 16",["one node · transaction pool","17 backend connections"],"postgres")
d2,w2,_ = fitbox(0,0,"Managed Redis 7",["one node · TLS","no snapshots by design"],"redis")
SGW = max(452, w1+w2+22+40)
_,ext_w,ext_h = fitbox(0,0,"External services",["allowlisted per package"],None,minw=214)
_,opr_w,opr_h = fitbox(0,0,"Operator",["your IP only"],None,minw=214)
_,cli_w,cli_h = fitbox(0,0,"Clients",["MCP · browser · embed"],None,minw=214)
LW = max(ext_w,opr_w,cli_w)
b.append(boundary(24,CLI_Y-cli_h/2-38,LW+36,(EXT_Y+ext_h/2)-(CLI_Y-cli_h/2-38)+18,"Outside your account","#8b93a5",dash="4 4"))
b.append(fitbox(42,CLI_Y-cli_h/2,"Clients",["MCP · browser · embed"],None,minw=LW)[0])
b.append(fitbox(42,OPR_Y-opr_h/2,"Operator",["your IP only"],None,minw=LW)[0])
b.append(fitbox(42,EXT_Y-ext_h/2,"External services",["allowlisted per package"],None,minw=LW)[0])
LR = 42+LW; X = LR + 52

# ── One load balancer. Each forwarding-rule row sits level with the service it
#    forwards to, so both lines leave the card dead straight. ──
LBW = 312; LBX = X + 26
LB_Y, LB_H = 280, 208
VX = LBX + LBW + 92
CORX = LBX + LBW + 46                  # the one return corridor, mid-gap
FW_Y, FW_H = 250, 268
HOST_Y, HOST_H = 286, 212
DATA_GY = 560; DATA_Y = 596
RW = (VX + SGW + 30) - X
REG_Y = 206; REG_H = (DATA_GY + 146 + 22) - REG_Y

b.append(boundary(X,REG_Y,RW,REG_H,"Your DigitalOcean project · one region",D))
b.append(f'<rect x="{LBX}" y="{LB_Y}" width="{LBW}" height="{LB_H}" rx="10" fill="#fff" stroke="{LINE}" stroke-width="1.5"/>')
b.append(text(LBX+16, LB_Y+26, "Load balancer", 15, 600, INK))
b.append(text(LBX+16, LB_Y+45, "Let's Encrypt for api + canvas · idle 600s", 12.5, 400, MUTE))
b.append(f'<line x1="{LBX+16}" y1="{LB_Y+58}" x2="{LBX+LBW-16}" y2="{LB_Y+58}" stroke="{LINE}"/>')
b.append(text(LBX+16, R_ENGINE+4, "api.example.com · 443  →  :4105", 13, 400, INK))
b.append(text(LBX+16, R_ENGINE+22, "the platform · health check /health", 11.5, 400, MUTE))
b.append(text(LBX+16, R_CANVAS-24, "canvas.example.com · 3001  →  :3001", 13, 400, AMB))
b.append(text(LBX+16, R_CANVAS-8, "Canvas · only when canvas_public is on", 11.5, 400, AMB))
b.append(text(LBX, LB_Y+LB_H+22, "manage_dns = true lets Terraform create the A record", 11, 400, MUTE))

b.append(boundary(VX,FW_Y,SGW,FW_H,"Cloud firewall · deny by default","#8b93a5",dash="4 4",bg="#fafafc"))
b.append(host(VX+18,HOST_Y,SGW-36,HOST_H,"Droplet · 4 vCPU, 16 GB","Ubuntu · running Docker","digitalocean"))
IW = SGW-64; SXX = VX+32
b.append(svc(SXX,R_ENGINE-RH/2,IW,"unoverse","MCP surface · workflow engine · nodes · :4105","public",h=RH))
b.append(svc(SXX,R_MID-RH/2,(IW-16)/2,"Memory","profiles and tasks · :4104","internal",h=RH))
b.append(svc(SXX+(IW+16)/2,R_MID-RH/2,(IW-16)/2,"Spatial ML","the semantic map · :5001","internal",h=RH))
b.append(svc(SXX,R_CANVAS-RH/2,IW,"Canvas","operator interface · :3001","operator",h=RH))

b.append(boundary(VX,DATA_GY,SGW,146,"Managed data","#8b93a5",dash="4 4",bg="#fafafc"))
LEFTM = (SGW-(w1+w2+22))/2
PGX = VX+LEFTM; RDX = PGX+w1+22
b.append(fitbox(PGX,DATA_Y,"Managed Postgres 16",["one node · transaction pool","17 backend connections"],"postgres")[0])
b.append(fitbox(RDX,DATA_Y,"Managed Redis 7",["one node · TLS","no snapshots by design"],"redis")[0])
b.append(text(VX+16,DATA_GY+134,"each database firewall admits the droplet and nothing else",11.5,400,MUTE))

SX = X + RW + 40
side,side_w,sbx = column(SX,R_ENGINE-30,[("Your OIDC issuer",["Auth0 today · you bring it"],None)],gap=24)
b.append(side)

# Every line is straight or one right angle.
b.append(edge([(LR,CLI_Y),(LBX,CLI_Y)])); b.append(step(LR+22,CLI_Y,1))
b.append(edge([(LBX+LBW,R_ENGINE),(SXX,R_ENGINE)]))
b.append(edge([(LR,OPR_Y),(LBX,OPR_Y)],dashed=True)); b.append(step(LR+22,OPR_Y,2))
b.append(edge([(LBX+LBW,R_CANVAS),(SXX,R_CANVAS)],dashed=True,colour=AMB))
b.append(edge([(SXX,R_ENGINE+RH/2-4),(CORX,R_ENGINE+RH/2-4),(CORX,EXT_Y),(LR,EXT_Y)])); b.append(step(LR+22,EXT_Y,5))
b.append(edge([(VX+SGW/2,HOST_Y+HOST_H),(VX+SGW/2,548),(PGX+w1/2,548),(PGX+w1/2,DATA_Y)]))
b.append(edge([(VX+SGW/2,548),(RDX+w2/2,548),(RDX+w2/2,DATA_Y)]))
b.append(step(VX+SGW/2,533,3))
cy0 = sbx[0][1]+sbx[0][3]/2
b.append(edge([(VX+SGW,cy0),(SX,cy0)])); b.append(step(SX-56,cy0,4))

pathlib.Path("images/architecture-digitalocean.svg").write_text(
  page(SX+side_w+26, REG_Y+REG_H+26, "unoverse on DigitalOcean","digitalocean",D,"".join(b),
       symbols(["digitalocean","postgres","redis","docker"])))
print("wrote images/architecture-digitalocean.svg")
