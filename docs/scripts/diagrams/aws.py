"""Regenerates images/architecture-aws.svg. Run from packages/docs: python3 scripts/diagrams/aws.py"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from arch import *

O="#ff9900"; AMB="#b45309"; b=[]
R_ENGINE, R_MID, R_CANVAS = 353, 407, 460
RH = 46
CLI_Y, OPR_Y, EXT_Y = 353, 424, 560
GY, GH = 250, 180
ALBY, ALB_H = 282, 128
d1,w1,_ = fitbox(0,0,"RDS Postgres 16",["db.t4g.small · single AZ","20 to 50 GB gp3 · 7-day backups"],"rds")
d2,w2,_ = fitbox(0,0,"ElastiCache 7.1",["cache.t4g.micro · 1 node","TLS in transit · auth token"],"elasticache")
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
ALBW = 300; GX = X + 26; ALBX = GX + 18; GW = ALBW + 36
DNSY = GY + GH + 18
VX = GX + GW + 96
FW_Y, FW_H = 250, 268
HOST_Y, HOST_H = 286, 212
DATA_GY = 560; DATA_Y = 596
RW = (VX + SGW + 30) - X
REG_Y = GY - 44; REG_H = (DATA_GY + 146 + 22) - REG_Y
b.append(boundary(X,REG_Y,RW,REG_H,"AWS region · default VPC · one availability zone",O))
b.append(fitbox(GX+18,DNSY,"Route 53 or your DNS",["A record to the load balancer","ACM validated by DNS"],None,minw=ALBW)[0])
b.append(boundary(GX,GY,GW,GH,"ALB security group · 443 from the world","#8b93a5",dash="4 4",bg="#fafafc"))
b.append(f'<rect x="{ALBX}" y="{ALBY}" width="{ALBW}" height="{ALB_H}" rx="10" fill="#fff" stroke="{LINE}" stroke-width="1.5"/>')
b.append(text(ALBX+16, ALBY+28, "Application Load Balancer", 15, 600, INK))
b.append(text(ALBX+16, ALBY+47, "ACM certificate · TLS 1.3 · idle 3600s", 13, 400, MUTE))
b.append(f'<line x1="{ALBX+16}" y1="{ALBY+64}" x2="{ALBX+ALBW-16}" y2="{ALBY+64}" stroke="{LINE}"/>')
b.append(text(ALBX+16, ALBY+86, "api.example.com  →  :4105", 13, 400, MUTE))
b.append(text(ALBX+16, ALBY+106, "unoverse.example.com  →  :3001", 13, 400, AMB))
b.append(text(ALBX+16, ALBY+122, "added only when canvas_public is on", 11.5, 400, AMB))
b.append(boundary(VX,FW_Y,SGW,FW_H,"Application security group · from the ALB only","#8b93a5",dash="4 4",bg="#fafafc"))
b.append(host(VX+18,HOST_Y,SGW-36,HOST_H,"EC2 · t3.xlarge","Ubuntu 22.04 · 100 GB gp3 · Elastic IP","ec2"))
IW = SGW-64; SXX = VX+32
b.append(svc(SXX,R_ENGINE-RH/2,IW,"unoverse","MCP surface · workflow engine · nodes · :4105","public",h=RH))
b.append(svc(SXX,R_MID-RH/2,(IW-16)/2,"Memory","profiles and tasks · :4104","internal",h=RH))
b.append(svc(SXX+(IW+16)/2,R_MID-RH/2,(IW-16)/2,"Spatial ML","the semantic map · :5001","internal",h=RH))
b.append(svc(SXX,R_CANVAS-RH/2,IW,"Canvas","operator interface · :3001","operator",h=RH))
b.append(boundary(VX,DATA_GY,SGW,146,"Data security group","#8b93a5",dash="4 4",bg="#fafafc"))
LEFTM = (SGW-(w1+w2+22))/2
PGX = VX+LEFTM; RDX = PGX+w1+22
b.append(fitbox(PGX,DATA_Y,"RDS Postgres 16",["db.t4g.small · single AZ","20 to 50 GB gp3 · 7-day backups"],"rds")[0])
b.append(fitbox(RDX,DATA_Y,"ElastiCache 7.1",["cache.t4g.micro · 1 node","TLS in transit · auth token"],"elasticache")[0])
b.append(text(VX+16,DATA_GY+134,"accepts connections from the application security group only",11.5,400,MUTE))
SX = X + RW + 40
side,side_w,sbx = column(SX,R_ENGINE-30,[("Cognito",["Essentials pool · one group per role"],"cognito"),
                                         ("Pre-token Lambda",["email and roles on the token"],"lambda"),
                                         ("Bedrock",["scoped IAM user"],"aws")],gap=20)
b.append(side)
b.append(edge([(LR,R_ENGINE),(ALBX,R_ENGINE)])); b.append(step(LR+22,R_ENGINE,1))
b.append(edge([(ALBX+ALBW,R_ENGINE),(SXX,R_ENGINE)]))
b.append(edge([(ALBX+ALBW,ALBY+ALB_H-18),(VX-44,ALBY+ALB_H-18),(VX-44,R_CANVAS),(SXX,R_CANVAS)],dashed=True,colour=AMB))
b.append(edge([(LR,OPR_Y),(GX-10,OPR_Y),(GX-10,ALBY+ALB_H-24),(ALBX,ALBY+ALB_H-24)],dashed=True)); b.append(step(LR+22,OPR_Y,2))
b.append(edge([(SXX,R_ENGINE+RH/2-4),(VX-20,R_ENGINE+RH/2-4),(VX-20,EXT_Y),(LR,EXT_Y)])); b.append(step(LR+22,EXT_Y,5))
b.append(edge([(GX+GW/2,DNSY),(GX+GW/2,GY+GH)],dashed=True))
b.append(edge([(VX+SGW/2,HOST_Y+HOST_H),(VX+SGW/2,548),(PGX+w1/2,548),(PGX+w1/2,DATA_Y)]))
b.append(edge([(VX+SGW/2,548),(RDX+w2/2,548),(RDX+w2/2,DATA_Y)]))
b.append(step(VX+SGW/2,533,3))
cy=[y+h/2 for _,y,_,h in sbx]
b.append(edge([(VX+SGW,cy[0]),(SX,cy[0])])); b.append(step(SX-56,cy[0],4))
b.append(edge([(VX+SGW,R_MID),(SX-30,R_MID),(SX-30,cy[2]),(SX,cy[2])]))
b.append(edge([(SX+22,sbx[0][1]+sbx[0][3]),(SX+22,sbx[1][1])]))
pathlib.Path("images/architecture-aws.svg").write_text(
  page(SX+side_w+26, REG_Y+REG_H+26, "unoverse on AWS","aws",O,"".join(b),
       symbols(["aws","ec2","rds","elasticache","cognito","lambda","docker"])))
print("wrote images/architecture-aws.svg")
