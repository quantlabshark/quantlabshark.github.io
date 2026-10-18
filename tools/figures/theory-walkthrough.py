"""Reproduce the numerical diagrams used in the theory walkthroughs."""
from pathlib import Path
import argparse, json, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, Circle

GREEN, BLUE, GOLD, RED = "#287460", "#427aab", "#bf8e3b", "#b65d60"
BG, INK, GRID = "#fbfcf9", "#263d43", "#dce5e1"
plt.rcParams.update({"font.family":["Microsoft YaHei","DejaVu Sans"],"font.size":12,
    "axes.labelsize":12,"xtick.labelsize":11,"ytick.labelsize":11,
    "text.color":INK,"axes.labelcolor":INK,"axes.edgecolor":"#a4b7b0",
    "xtick.color":INK,"ytick.color":INK,"figure.facecolor":BG,"axes.facecolor":BG,
    "savefig.facecolor":BG,"axes.spines.top":False,"axes.spines.right":False,
    "mathtext.fontset":"stix","svg.fonttype":"path","svg.hashsalt":"quantlab-walkthrough-v1"})
PLOTS={}
def plot(name):
    def register(fn): PLOTS[name]=fn; return fn
    return register
def canvas(n=1):
    fig,axes=plt.subplots(1,n,figsize=(8.4,4.6),layout="constrained",squeeze=False)
    for ax in axes[0]: ax.grid(alpha=.55,color=GRID);ax.set_axisbelow(True)
    return fig,axes[0]
def legend(ax,**kw): ax.legend(frameon=False,fontsize=10,**kw)
def normal(x,m,s): return np.exp(-.5*((x-m)/s)**2)/(s*np.sqrt(2*np.pi))

@plot("information-tree")
def information():
    f,(a,)=canvas();a.axis("off");a.set(xlim=(-.15,2.65),ylim=(-3.7,3.7))
    for x0,y0,x1,y1 in [(0,0,1,2),(0,0,1,-2),(1,2,2,3),(1,2,2,1),(1,-2,2,-1),(1,-2,2,-3)]:
        a.plot([x0,x1],[y0,y1],color=GREEN,lw=1.8);a.text((x0+x1)/2,(y0+y1)/2+.16,"1/2",fontsize=11,ha="center",backgroundcolor=BG)
    a.text(0,0,"开始",ha="center",va="center",backgroundcolor=BG)
    for y,lab in [(2,"H"),(-2,"T")]: a.text(1,y,lab,ha="center",va="center",backgroundcolor=BG,fontsize=15)
    for y,lab,value in [(3,"HH",2),(1,"HT",1),(-1,"TH",1),(-3,"TT",0)]:
        a.scatter(2,y,color=BLUE,s=38);a.text(2.08,y,f"{lab}    X = {value}",va="center")
    return f

@plot("variance-decomposition")
def variance():
    f,(a,)=canvas();a.axhline(1,color=GOLD,ls="--",label="总体均值 1")
    for xpos,ys,mean in [(0,[2,1],1.5),(1,[1,0],.5)]:
        a.plot([xpos-.18,xpos+.18],[mean,mean],color=GREEN,lw=3)
        a.scatter([xpos-.08,xpos+.08],ys,color=BLUE,s=65,zorder=3)
        for dx,y in zip([-.08,.08],ys):a.plot([xpos+dx,xpos+dx],[mean,y],color=BLUE,alpha=.5,lw=2)
        a.text(xpos+.22,mean,f"{mean:g}",color=GREEN,va="center")
    a.set(xticks=[0,1],xticklabels=["第一次 H","第一次 T"],ylabel="正面次数 X",xlim=(-.5,1.55),ylim=(-.25,2.3));legend(a);return f

@plot("rare-errors")
def rare():
    f,axs=canvas(2);n=np.geomspace(1,1e4,200)
    axs[0].loglog(n,1/n,color=GREEN,label="非零概率 1/n");axs[0].loglog(n,1/np.sqrt(n),color=BLUE,label="平均绝对误差")
    axs[1].loglog(n,np.sqrt(n),color=GOLD,label="非零幅度 √n");axs[1].loglog(n,np.ones_like(n),color=RED,label="均方误差 1")
    for a in axs:a.set_xlabel("序号 n");legend(a)
    return f

@plot("shared-increments")
def shared():
    f,(a,)=canvas()
    for j in range(3):
        for k in range(j+1):a.barh(j,1,left=k,height=.48,color=[GREEN,BLUE,GOLD][k],alpha=.8)
    a.set(yticks=[0,1,2],yticklabels=[r"$W_1$",r"$W_2$",r"$W_3$"],xticks=[.5,1.5,2.5],xticklabels=[r"$\Delta W_1$",r"$\Delta W_2$",r"$\Delta W_3$"],xlabel="共享的独立增量",xlim=(0,3.2));return f

@plot("exit-boundaries")
def exit_plot():
    f,(a,b)=canvas(2);x=np.linspace(0,3,200)
    a.plot(x,x/3,color=GREEN);a.scatter([1],[1/3],color=GOLD);a.annotate("1/3",(1,1/3),xytext=(1.25,.24))
    a.set(xlabel="起点 x",ylabel="从上端退出的概率",ylim=(0,1.05))
    for sig,c in [(1,BLUE),(2,GREEN)]:b.plot(x,x*(3-x)/sig**2,color=c,label=f"σ = {sig}")
    b.scatter([1,1],[2,.5],c=[BLUE,GREEN]);b.set(xlabel="起点 x",ylabel="平均退出时间");legend(b);return f

@plot("quadratic-variation")
def qv():
    f,(a,)=canvas();n=2.**np.arange(3,11);sd=np.sqrt(2/n)
    a.fill_between(n,1-sd,1+sd,color=BLUE,alpha=.18,label="均值 ± 标准差")
    a.plot(n,np.ones_like(n),color=GREEN,label=r"$E[Q_n]=1$")
    a.set(xscale="log",xlabel="分段数 n",ylabel="平方增量和",ylim=(.35,1.65));a.set_xticks([8,32,128,512],labels=["8","32","128","512"]);legend(a);return f

@plot("ito-left-right")
def ito_sum():
    f,(a,b)=canvas(2);t=np.arange(4);w=np.array([0,.4,-.1,.2])
    a.plot(t,w,"o-",color="#8c9c99",label="网格路径")
    a.step(t,w,where="post",color=GREEN,label="左端点权重");a.step(t,w,where="pre",color=BLUE,ls="--",label="右端点权重")
    a.set(xlabel="网格时点",ylabel="W");legend(a)
    left=w[:-1]*np.diff(w);right=w[1:]*np.diff(w);x=np.arange(3)
    b.bar(x-.18,left,width=.34,color=GREEN,label="左端点乘积");b.bar(x+.18,right,width=.34,color=BLUE,label="右端点乘积")
    b.axhline(0,color=INK,lw=.7);b.set(xticks=x,xticklabels=["0 → 1","1 → 2","2 → 3"],ylabel="权重 × 增量");legend(b);return f

@plot("adaptive-integrand")
def adaptive():
    f,(a,)=canvas()
    for value,c in [(-1,BLUE),(0,GOLD),(1,GREEN)]:
        a.plot([0,.5],[1,1],color=GREEN,lw=2)
        a.plot([.5,1],[value,value],color=c,label=f"W(1/2) = {value}")
        a.scatter([.5],[value],color=c,s=35)
    a.axvline(.5,color="#b8c5c0",ls=":");a.set(xlabel="时间 t",ylabel="权重 H",ylim=(-1.3,1.8));legend(a,loc="upper right");return f

@plot("wiener-kernels")
def kernels():
    f,(a,)=canvas();t=np.linspace(0,1,200)
    a.plot(t,t,color=GREEN,label="t");a.plot(t,1-t,color=BLUE,label="1 − t")
    a.fill_between(t,0,t*(1-t),color=GOLD,alpha=.3,label="乘积面积 = 1/6")
    a.set(xlabel="时间 t",ylabel="确定性权重");legend(a);return f

@plot("poisson-area")
def poisson_area():
    f,(a,)=canvas();t=np.array([0,.5,1.5,3,4]);n=np.array([0,1,2,3,3])
    a.step(t,n,where="post",color=GREEN,lw=2);a.fill_between(t,0,n,step="post",color=GREEN,alpha=.18)
    a.set(xlabel="时间 t",ylabel="累计事件数 N",xticks=t,yticks=range(4),ylim=(-.1,3.7))
    for x,y,s in [(1,.5,"1"),(2.25,1,"3"),(3.5,1.5,"3")]:a.text(x,y,s,ha="center",color=GREEN)
    return f

@plot("compensated-payments")
def compensated():
    f,(a,b)=canvas(2);t=np.linspace(0,4,401);s=np.array([.5,1.5,3]);pay=((t[:,None]>=s)*(1+s)).sum(1);mean=t+t*t/2
    a.step(t,pay,where="post",color=BLUE,label="实际累计");a.plot(t,mean,color=GREEN,label="平均累计")
    b.step(t,pay-mean,where="post",color=BLUE);b.axhline(0,color=INK,lw=.8)
    a.set(xlabel="时间 t",ylabel="累计权重");b.set(xlabel="时间 t",ylabel="实际 − 平均");legend(a);return f

@plot("ito-correction")
def correction():
    f,(a,)=canvas();h=np.linspace(0,.2,200)
    a.plot(h,13*h+4*h*h,color=GREEN,label="精确平均增量")
    a.plot(h,13*h,color=BLUE,ls="--",label="伊藤一阶近似 13h")
    a.plot(h,4*h,color=RED,ls=":",label="遗漏二阶项 4h")
    a.set(xlabel="步长 h",ylabel="平方状态的平均增量");legend(a);return f

@plot("covariance-matrix")
def covariance():
    f,(a,)=canvas();A=np.array([[5,1],[1,10]]);im=a.imshow(A,cmap="YlGnBu",vmin=0,vmax=12)
    for i in range(2):
        for j in range(2):a.text(j,i,str(A[i,j]),ha="center",va="center",fontsize=24,color="white" if A[i,j]>6 else INK)
    a.grid(False);a.set(xticks=[0,1],yticks=[0,1],xticklabels=["X","Y"],yticklabels=["X","Y"]);f.colorbar(im,ax=a,label="单位时间协方差",shrink=.8);return f

@plot("backward-heat")
def heat():
    f,(a,)=canvas();x=np.linspace(-1.5,1.5,200)
    for tau,c in [(0,GOLD),(.25,BLUE),(.75,GREEN)]:a.plot(x,x*x+tau,color=c,label=f"剩余时间 {tau:g}")
    a.scatter([.4],[.91],color=INK,s=35);a.set(xlabel="当前状态 x",ylabel="终端平方的条件均值");legend(a);return f

@plot("euler-steps")
def euler():
    f,(a,)=canvas();t=np.array([0,.25,.5,.75]);x=np.array([0,.75,.625,.9375]);a.plot(t,x,"o-",color=GREEN,lw=2)
    for tx,xx in zip(t,x):a.annotate(f"{xx:g}",(tx,xx),xytext=(0,10),textcoords="offset points",ha="center")
    a.axhline(1,color=GOLD,ls="--",label="回复水平 1");a.set(xlabel="时间 t",ylabel="离散状态",ylim=(-.08,1.15),xticks=t);legend(a,loc="lower right");return f

@plot("ou-moments")
def ou():
    f,(a,)=canvas();t=np.linspace(0,8,300);m=10+4*np.exp(-.5*t);sd=np.sqrt(4*(1-np.exp(-t)))
    a.fill_between(t,m-sd,m+sd,color=BLUE,alpha=.18,label="均值 ± 标准差");a.plot(t,m,color=GREEN,label="均值");a.axhline(10,color=GOLD,ls="--",label="回复水平")
    a.set(xlabel="时间 t",ylabel="状态");legend(a);return f

@plot("picard-means")
def picard():
    f,(a,)=canvas();t=np.linspace(0,.8,200)
    for y,c,label in [(2*t,BLUE,r"$m_1$"),(2*t-2*t*t,GOLD,r"$m_2$"),(2*t-2*t*t+4*t**3/3,RED,r"$m_3$"),(1-np.exp(-2*t),GREEN,"精确均值")]:a.plot(t,y,color=c,label=label)
    a.set(xlabel="时间 t",ylabel="均值");legend(a);return f

@plot("measure-change")
def measure():
    f,(a,)=canvas();x=np.linspace(-4,3,500)
    for m,c,label in [(0,BLUE,"P：均值 0"),(-.5,GREEN,"Q：均值 −0.5")]:
        y=normal(x,m,1);a.plot(x,y,color=c,label=label);a.fill_between(x,0,y,where=x>=0,color=c,alpha=.14)
    a.axvline(0,color=INK,lw=.7);a.set(xlabel=r"$W_1$",ylabel="概率密度");legend(a);return f

@plot("kalman-update")
def kalman():
    f,(a,)=canvas();x=np.linspace(3,18,500)
    for m,s,c,label in [(10,2,BLUE,"先验"),(11,2,GOLD,"测量似然"),(10.5,np.sqrt(2),GREEN,"后验")]:
        y=normal(x,m,s);a.plot(x,y,color=c,label=label)
        if c==GREEN:a.fill_between(x,0,y,color=c,alpha=.1)
    a.set(xlabel="状态值",ylabel="密度 / 归一化似然");legend(a);return f

@plot("portfolio-variance")
def portfolio():
    f,(a,)=canvas();x=np.linspace(0,1,200);v=.01*x*x+.04*(1-x)**2
    a.plot(x,v,color=GREEN);a.scatter([.8,.5],[.008,.0125],color=[GREEN,GOLD],s=50);a.annotate("最小值",( .8,.008),xytext=(.56,.018),arrowprops={"arrowstyle":"->","color":GREEN})
    a.set(xlabel="第一项资产权重",ylabel="组合方差",ylim=(.004,.043));return f

@plot("garch-forecast")
def garch():
    f,(a,)=canvas();k=np.arange(26);v=.00002+.9**k*(.000122-.00002)
    a.plot(k,v*1e4,"o-",color=GREEN,ms=3);a.axhline(.2,color=GOLD,ls="--",label="长期方差")
    a.set(xlabel="向前期数 k",ylabel="条件方差（×10⁻⁴）");legend(a);return f

@plot("hjb-feedback")
def hjb():
    f,(a,)=canvas();x=np.linspace(-3,3,200)
    for tau,c in [(0,RED),(.5,BLUE),(1,GREEN)]:a.plot(x,-x/(1+tau),color=c,label=f"剩余时间 {tau:g}")
    a.axhline(0,color=GRID);a.axvline(0,color=GRID);a.set(xlabel="当前状态 x",ylabel="最优控制 u");legend(a);return f

@plot("kernel-contributions")
def kernel_contrib():
    f,(a,)=canvas();y=[4,-3,0,1];a.bar(range(4),y,color=[BLUE,RED,GOLD,GREEN],width=.55);a.axhline(0,color=INK,lw=.8)
    for i,v in enumerate(y):a.text(i,v+(.12 if v>=0 else -.2),f"{v:g}",ha="center",va="bottom" if v>=0 else "top")
    a.set(xticks=range(4),xticklabels=[r"$\gamma_0$",r"$2k(1/2)\gamma_1$",r"$2k(1)\gamma_2$","合计 RK"],ylabel="贡献（×10⁻⁶）",ylim=(-3.8,4.8));return f

@plot("asynchronous-intervals")
def asynchronous():
    f,(a,)=canvas()
    for y,intervals,c in [(1,[(0,1,2),(1,3,-1)],GREEN),(0,[(0,2,1),(2,3,3)],BLUE)]:
        for left,right,r in intervals:
            a.plot([left,right],[y,y],color=c,lw=5,alpha=.65);a.scatter([left,right],[y,y],color=c,s=40)
            a.text((left+right)/2,y+.15,f"收益 {r}",ha="center",color=c)
    a.set(xlabel="观测时间",yticks=[0,1],yticklabels=["资产 Y","资产 X"],xticks=range(4),ylim=(-.6,1.65));return f

@plot("hawkes-events")
def hawkes():
    f,(a,)=canvas();t=np.linspace(0,3,1501);lam=.2+sum(.6*np.exp(-2*(t-s))*(t>=s) for s in [1,2])
    a.plot(t,lam,color=GREEN);a.fill_between(t,0,lam,color=GREEN,alpha=.12)
    for s,pre in [(1,.2),(2,.2+.6*np.exp(-2))]:
        a.scatter(s,pre,edgecolors=GREEN,facecolors=BG,s=55,zorder=4);a.scatter(s,pre+.6,color=GREEN,s=35,zorder=4)
        a.axvline(s,color=GOLD,ls=":",lw=1);a.annotate(f"{pre:.4f}",(s,pre),xytext=(7,-18),textcoords="offset points",fontsize=10)
    a.set(xlabel="时间 t",ylabel="条件强度 λ(t)",ylim=(0,1));return f

@plot("hawkes-network")
def network():
    f,(a,)=canvas();a.axis("off");a.set(xlim=(-.5,3.5),ylim=(-1.5,1.5))
    for x,c,n in [(0,GREEN,1),(3,BLUE,2)]:
        a.add_patch(Circle((x,0),.3,facecolor=c,alpha=.15,edgecolor=c,lw=2));a.text(x,0,str(n),ha="center",va="center",fontsize=20)
        a.add_patch(FancyArrowPatch((x-.2,.25),(x+.2,.25),connectionstyle="arc3,rad=-1.4",arrowstyle="-|>",mutation_scale=16,color=c))
        a.text(x,1.05,"0.2",ha="center",color=c)
    for s,e,rad,label,y in [((.32,0),(2.68,0),-.35,"0.3",.6),((2.68,0),(.32,0),-.35,"0.1",-.65)]:
        a.add_patch(FancyArrowPatch(s,e,connectionstyle=f"arc3,rad={rad}",arrowstyle="-|>",mutation_scale=16,color=INK,lw=1.6));a.text(1.5,y,label,ha="center")
    return f

@plot("queue-position")
def queue():
    f,(a,)=canvas();end=np.log(1.2)/.05;t=np.linspace(0,end,200)
    a.plot(t,100+0*t,color=BLUE,label="总深度 Q");a.plot(t,240*np.exp(-.05*t)-200,color=GREEN,label="前方数量 Z")
    a.scatter(end,0,color=GREEN);a.set(xlabel="时间（秒）",ylabel="数量",ylim=(-5,110));legend(a);return f

@plot("execution-inventory")
def execution():
    f,(a,)=canvas();t=np.linspace(0,1,200)
    for k,c in [(0,GOLD),(1,BLUE),(2,GREEN)]:
        x=100*(1-t) if k==0 else 100*np.sinh(k*(1-t))/np.sinh(k);a.plot(t,x,color=c,label=f"κ = {k}")
    a.set(xlabel="时间 t",ylabel="剩余库存");legend(a);return f

@plot("book-depth")
def depth():
    f,(a,)=canvas();x=np.linspace(0,1,200);y=x*(100+100*x)
    a.plot(x,y,color=GREEN);a.fill_between(x,0,y,color=GREEN,alpha=.2)
    a.text(.5,65,r"$\int_0^1 x f(x)\,dx=83.33$",ha="center",fontsize=16)
    a.set(xlabel="价格距离（元）",ylabel=r"$x f(x)$",ylim=(0,220));return f

@plot("execution-modes")
def modes():
    f,(a,)=canvas();t=np.linspace(0,1,200)
    for eig,c,label in [(1.5,GREEN,"共同方向"),(.5,BLUE,"对冲方向")]:
        k=np.sqrt(eig);a.plot(t,np.sinh(k*(1-t))/np.sinh(k),color=c,label=label)
    a.set(xlabel="时间 t",ylabel="归一化剩余库存");legend(a);return f

@plot("inventory-quotes")
def quotes():
    f,(a,)=canvas();qs=np.array([-5,0,5]);center=100-.1*qs*4*.5;width=.2+20*np.log(1.05)
    a.axvline(100,color=GOLD,ls="--",label="中间价")
    for i,(q,r) in enumerate(zip(qs,center)):
        a.plot([r-width/2,r+width/2],[i,i],color=GREEN,lw=3);a.scatter([r],[i],color=BLUE,s=50);a.scatter([r-width/2,r+width/2],[i,i],color=GREEN,s=30)
    a.set(yticks=range(3),yticklabels=[f"q = {q}" for q in qs],xlabel="报价",ylim=(-.5,2.5));legend(a);return f

@plot("impulse-cost")
def impulse():
    f,axs=canvas(2)
    for q,a in zip([3,5],axs):
        j=np.arange(q);c=.01*j*j+.1+.02*(q-j);a.plot(j,c,"o-",color=GREEN,label="主动调仓成本")
        a.axhline(.01*q*q,color=GOLD,ls="--",label="不交易");a.set(xlabel=f"目标库存 j（当前 q={q}）",ylabel="成本",xticks=range(q),ylim=(.065,.27));legend(a)
    return f

@plot("censored-capacity")
def censored():
    f,(a,b)=canvas(2)
    for i,(n,r) in enumerate([(3,1),(3,3),(2,2),(4,2)]):
        a.plot([0,r],[i,i],color=GREEN,lw=1.5)
        if r<n:a.scatter(r,i,color=GREEN,s=45)
        else:a.annotate("",xy=(r+.65,i),xytext=(r,i),arrowprops={"arrowstyle":"->","color":BLUE,"lw":2})
    a.set(xlabel="容量 / 已知下界",yticks=range(4),yticklabels=["样本 1","样本 2","样本 3","样本 4"],xlim=(0,4))
    b.step([0,1,2,3],[1,1,.75,.375],where="post",color=GREEN);b.scatter([0,1,2,3],[1,1,.75,.375],color=GREEN)
    b.set(xlabel="容量门槛 l",ylabel="估计尾概率 S(l)",xticks=range(4),ylim=(0,1.1));return f

@plot("order-ledger")
def ledger():
    f,(a,b)=canvas(2);x=np.arange(4)
    a.bar(x,[0,40,70,70],color=GREEN,label="已成交持仓");a.bar(x,[100,60,30,0],bottom=[0,40,70,70],color=BLUE,alpha=.35,label="未成交挂单")
    b.plot(x,[2000,1599.6,1298.7,1298.7],"o-",color=GREEN);b.set_ylabel("现金（元）")
    for ax in (a,b):ax.set_xticks(x,["接受","成交 40","成交 30","撤单"],rotation=20)
    a.set_ylabel("股数");legend(a);return f

@plot("latency-timeline")
def latency():
    f,(a,)=canvas();left=0
    for width,c,label in zip([120,40,40,60,140],[GREEN,BLUE,GOLD,RED,"#8c78a7"],["行情传输","解码","策略计算","发送等待","订单传输"]):
        a.barh(0,width,left=left,height=.35,color=c,alpha=.8,label=label);a.text(left+width/2,0,str(width),ha="center",va="center",color="white",fontsize=11);left+=width
    a.set(xlabel="自事件生成起的时间（微秒）",yticks=[],ylim=(-.5,.7),xticks=[0,120,160,200,260,400]);legend(a,ncol=3,loc="upper center");return f

@plot("markov-rate")
def markov():
    f,(a,)=canvas();t=np.linspace(0,1.2,200)
    a.plot(t,2/3*(1-np.exp(-3*t)),color=GREEN,label="精确转移概率")
    a.plot(t,2*t,color=BLUE,ls="--",label="短时近似 2t");a.axhline(2/3,color=GOLD,ls=":",label="长期概率 2/3")
    a.set(xlabel="时间（秒）",ylabel="从 0 到 1 的概率",ylim=(0,1.05));legend(a);return f

@plot("reflected-queue")
def reflected():
    f,(a,)=canvas();t=np.arange(5);x=np.array([0,-1,2,-2,1]);L=np.maximum(0,-np.minimum.accumulate(x));q=x+L
    for y,c,label in [(x,RED,"净输入 X"),(L,GOLD,"累计调节 L"),(q,GREEN,"队列 Q")]:a.step(t,y,where="post",color=c,label=label);a.scatter(t,y,color=c,s=25)
    a.axhline(0,color=INK,lw=.6);a.set(xlabel="离散时点",ylabel="数量",xticks=t);legend(a,ncol=3);return f

def main():
    parser=argparse.ArgumentParser();parser.add_argument("--output",default="figures");parser.add_argument("--only");parser.add_argument("--png",action="store_true")
    args=parser.parse_args();out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
    names=args.only.split(",") if args.only else sorted(PLOTS)
    for name in names:
        fig=PLOTS[name]();fig.savefig(out/(name+".svg"),metadata={"Date":None})
        if args.png:fig.savefig(out/(name+".png"),dpi=150)
        plt.close(fig)
    print(json.dumps({"figures":len(names),"output":str(out)}))
if __name__=="__main__":main()
