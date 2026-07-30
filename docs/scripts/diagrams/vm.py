"""Regenerates images/architecture-vm.svg. Run from packages/docs."""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from arch import *

b=[]
R_ENGINE, R_MID, R_CANVAS = 183, 237, 290
RH = 46
CLI_Y, OPR_Y, EXT_Y = 183, 290, 375

_,ext_w,ext_h = fitbox(0,0,"External services",["what your nodes call","allowlisted per package"],None,minw=214)
_,opr_w,opr_h = fitbox(0,0,"Operator",["your IP only"],None,minw=214)
_,cli_w,cli_h = fitbox(0,0,"Clients",["MCP · browser · embed"],None,minw=214)
LW = max(ext_w,opr_w,cli_w)
b.append(fitbox(42,CLI_Y-cli_h/2,"Clients",["MCP · browser · embed"],None,minw=LW)[0])
b.append(fitbox(42,OPR_Y-opr_h/2,"Operator",["your IP only"],None,minw=LW)[0])
b.append(fitbox(42,EXT_Y-ext_h/2,"External services",["what your nodes call","allowlisted per package"],None,minw=LW)[0])
LR = 42+LW; X = LR + 56

lb_s, lb_w, lb_h = fitbox(0,0,"Load balancer",["TLS terminates here · 443"],None,minw=210)
LBX = X; LBY = CLI_Y - lb_h/2
b.append(lb_s.replace('x="0" y="0"', f'x="{LBX}" y="{LBY}"') if False else fitbox(LBX,LBY,"Load balancer",["TLS terminates here · 443"],None,minw=210)[0])

VX = LBX + 210 + 64
SGW = 470
HOST_Y, HOST_H = 110, 232
b.append(host(VX,HOST_Y,SGW,HOST_H,"The universe VM","Docker runs the four platform images","docker"))
IW = SGW-32; SXX = VX+16
b.append(svc(SXX,R_ENGINE-RH/2,IW,"unoverse","MCP surface · workflow engine · nodes · :4105","public",h=RH))
b.append(svc(SXX,R_MID-RH/2,(IW-16)/2,"Memory","profiles and tasks · :4104","internal",h=RH))
b.append(svc(SXX+(IW+16)/2,R_MID-RH/2,(IW-16)/2,"Spatial ML","the semantic map · :5001","internal",h=RH))
b.append(svc(SXX,R_CANVAS-RH/2,IW,"Canvas","operator interface · :3001","operator",h=RH))
b.append(text(VX,HOST_Y+HOST_H+18,"log viewer :8080 · operator address only",11.5,500,MUTE))

SX = VX + SGW + 72
side,side_w,sbx = column(SX,R_ENGINE-30,[("Postgres",["workflows, assets, credentials"],"postgres"),
                                         ("Redis",["shared state and streams"],"redis")],gap=24)
b.append(side)

b.append(edge([(LR,CLI_Y),(LBX,CLI_Y)],"443",lx=(LR+LBX)/2,ly=CLI_Y-22))
b.append(edge([(LBX+210,CLI_Y),(SXX,R_ENGINE)]))
b.append(edge([(LR,OPR_Y),(SXX,R_CANVAS)],dashed=True))
b.append(edge([(SXX,R_ENGINE+RH/2-4),(VX-28,R_ENGINE+RH/2-4),(VX-28,EXT_Y),(LR,EXT_Y)],
              "outbound 443 · allowlisted",lx=VX-160,ly=EXT_Y-16))
cy=[y+h/2 for _,y,_,h in sbx]
b.append(edge([(VX+SGW,cy[0]),(SX,cy[0])]))
b.append(edge([(VX+SGW,R_MID),(SX-30,R_MID),(SX-30,cy[1]),(SX,cy[1])]))
b.append(legend(42, 462, [("Reached from the internet","public"),
                          ("Operator address only","operator"),
                          ("Inside the machine, blocked by the firewall","internal")]))
pathlib.Path("images/architecture-vm.svg").write_text(
  page(SX+side_w+26, 560, "Inside the universe VM","docker","#0080ff","".join(b),
       symbols(["docker","postgres","redis"])))
print("wrote images/architecture-vm.svg")
