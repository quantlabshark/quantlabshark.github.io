"""Original, title-free teaching plots. Explanations belong in the article."""
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch
from matplotlib.font_manager import fontManager
fontManager.addfont('C:/Windows/Fonts/msyh.ttc')
plt.rcParams.update({'font.family':'Microsoft YaHei','font.size':13,'axes.labelsize':14,'axes.spines.top':False,'axes.spines.right':False,'axes.edgecolor':'#a3b1b7','axes.labelcolor':'#334c58','text.color':'#334c58','xtick.color':'#667780','ytick.color':'#667780','axes.unicode_minus':False,'svg.fonttype':'path','savefig.facecolor':'#ffffff','axes.facecolor':'#ffffff','figure.facecolor':'#ffffff'})
OUT=Path(__file__).resolve().parents[2]/'source-quant/assets/figures/factor'
OUT.mkdir(parents=True,exist_ok=True)
C=['#388c82','#4d7ca5','#d7a064','#b66d80','#8297a1']
def save(fig,name):
    fig.savefig(OUT/(name+'.svg'),bbox_inches='tight',pad_inches=.2,metadata={'Creator':'QuantLab','Description':'Teaching example; explanations are in the article.'});plt.close(fig)
def clean(ax):
    ax.grid(axis='y',color='#e7edef',linewidth=.8);ax.set_axisbelow(True)
def arrow(ax,a,b,color='#8297a1',lw=1.8):
    ax.annotate('',xy=b,xytext=a,arrowprops={'arrowstyle':'->','color':color,'lw':lw})

fig,axs=plt.subplots(2,2,figsize=(9.4,6.4),layout='constrained')
a=axs[0,0];a.bar(['A','B','C','D'],[.3,.5,.8,1.1],color=C[0],width=.5);a.set_ylabel('账面市值比');clean(a)
a=axs[0,1];a.bar(['A','B','C','D'],[-.5,-.5,.5,.5],color=[C[3],C[3],C[0],C[0]],width=.5);a.axhline(0,color='#9baab1',lw=1);a.set_ylabel('多空组合权重');clean(a)
x=np.linspace(-2,2,9);e=np.array([.4,-.2,.2,-.2,.1,-.2,-.2,.3,.4]);a0=np.vstack([np.ones(8),x[:-1]]);e[:-1]+=a0.T@np.linalg.solve(a0@a0.T,np.array([-.4,-.8])-a0@e[:-1]);y=.2+1.2*x+e;a=axs[1,0];a.scatter(x,y,color=C[0],s=30);a.plot(x,.2+1.2*x,color=C[1]);a.text(-1.7,2,'β = 1.2',color=C[1]);a.set(xlabel='因子收益（%）',ylabel='资产超额收益（%）');clean(a)
a=axs[1,1];exposure=np.array([.4,.8,1.2,1.6]);a.plot(exposure,5*exposure,'o-',color=C[0]);a.set(xlabel='因子暴露 β',ylabel='预期超额收益（%）');a.text(.43,6.4,'λ = 5%',color=C[0]);clean(a)
save(fig,'factor-map')

fig,ax=plt.subplots(figsize=(8.8,4.5),layout='constrained');x=np.linspace(-2,2,9);y=.2+1.2*x+e;assert np.allclose(np.linalg.lstsq(np.column_stack([np.ones(9),x]),y,rcond=None)[0],[.2,1.2]);ax.scatter(x,y,s=55,color=C[0],zorder=4);ax.plot(x,.2+1.2*x,color=C[1],lw=2,label='0.2 + 1.2 f');ax.vlines(2,2.6,3,color=C[2],lw=3);ax.annotate('ε = 0.4',xy=(2,2.8),xytext=(.9,3.35),arrowprops={'arrowstyle':'-','color':C[2]},color=C[2]);ax.set(xlabel='因子收益（%）',ylabel='资产超额收益（%）',xlim=(-2.3,2.3),ylim=(-2.4,3.7));ax.axhline(0,color='#bac6cb',lw=.7);ax.axvline(0,color='#bac6cb',lw=.7);ax.legend(frameon=False,loc='upper left');clean(ax);save(fig,'regression')

fig,ax=plt.subplots(figsize=(9,4.2));ax.set(xlim=(-.8,3.8),ylim=(-.7,2.8));ax.axis('off')
for i,row in enumerate(['小市值','大市值']):
    yy=1.6-i*1.15;ax.text(-.18,yy,row,ha='right',va='center')
    for j,col in enumerate(['低 B/M','中 B/M','高 B/M']):
        xx=.55+j*1.15
        for dx,dy in [(-.15,-.13),(.05,-.14),(.16,.07),(-.08,.13)]:ax.scatter(xx+dx,yy+dy,s=160,color=[C[1],C[4],C[0]][j],alpha=.85)
        ax.text(xx,yy-.43,[['S/L','S/M','S/H'],['B/L','B/M','B/H']][i][j],ha='center',fontsize=12)
for j,col in enumerate(['低 B/M','中 B/M','高 B/M']):ax.text(.55+j*1.15,2.35,col,ha='center')
for xx in [1.12,2.27]:ax.plot([xx,xx],[.0,2.15],color='#dce5e8',lw=1)
ax.plot([.05,3.3],[1.02,1.02],color='#dce5e8',lw=1)
save(fig,'portfolio-sort')

fig,ax=plt.subplots(figsize=(8,4.8),layout='constrained');data=np.zeros((5,8));data[2,:]=1;data[:,5]=2;data[2,5]=3
from matplotlib.colors import ListedColormap
ax.imshow(data,cmap=ListedColormap(['#edf1f2','#b8d9d4','#b7cde0','#598c94']),aspect='auto',vmin=0,vmax=3)
ax.set_xticks(range(8),[f'$t_{i}$' for i in range(1,9)]);ax.set_yticks(range(5),['A','B','C','D','E']);ax.set(xlabel='时间',ylabel='股票');ax.set_xticks(np.arange(-.5,8,1),minor=True);ax.set_yticks(np.arange(-.5,5,1),minor=True);ax.grid(which='minor',color='white',lw=3);ax.tick_params(which='minor',length=0);ax.text(1,2,'时序',ha='center',va='center',color='#23685f');ax.text(5,.5,'截面',ha='center',va='center',color='#315e84');ax.spines[['left','bottom']].set_visible(False);save(fig,'testing')

fig,axs=plt.subplots(1,2,figsize=(9.2,4),sharey=True,layout='constrained')
for ax,state,vals in zip(axs,['景气状态','困难状态'],[[120,80],[80,120]]):
    bars=ax.bar(['顺周期资产','保险型资产'],vals,color=C[:2],width=.48);ax.bar_label(bars,padding=5);ax.set_ylim(0,140);ax.set_xlabel(state);clean(ax)
axs[0].set_ylabel('期末支付（元）');save(fig,'sdf')

fig,axs=plt.subplots(1,3,figsize=(9.7,3.5),layout='constrained');x=np.linspace(-2,2,7);y0=np.array([25,0,-15,-20,-15,0,25],float);y0=y0/y0.std()*x.std()
for ax,rho,y,vol in zip(axs,[1,0,-1],[x,y0,-x],[20,14.1,0]):
    ax.scatter(x,y,color=C[0],s=45);ax.axhline(0,color='#dce4e6');ax.axvline(0,color='#dce4e6');ax.set(xlabel=f'资产 A（ρ = {rho}）',xlim=(-2.5,2.5),ylim=(-2.5,2.5));ax.text(.04,.93,rf'$\sigma_p$ = {vol}%',transform=ax.transAxes,va='top',color=C[1]);ax.set_xticks([-2,0,2]);ax.set_yticks([-2,0,2])
axs[0].set_ylabel('资产 B（标准化收益）');save(fig,'covariance')

rng=np.random.default_rng(25);ret=rng.normal(0,.012,(20,120));nav=np.cumprod(1+ret,axis=1);best=(nav[:,79]/nav[:,59]).argmax()
fig,ax=plt.subplots(figsize=(9,4.3),layout='constrained')
for i in range(20):ax.plot(np.arange(120),nav[i],color='#bdcbd1',lw=.8,alpha=.55)
ax.plot(np.arange(120),nav[best],color=C[0],lw=2.4,label='验证期选出的组合');ax.axvspan(60,79.5,color=C[1],alpha=.07);ax.axvspan(80,119,color=C[2],alpha=.10);ax.axvline(59.5,color=C[1],ls='--',lw=1);ax.axvline(79.5,color=C[2],ls='--',lw=1);ax.text(27,.82,'训练',ha='center',color=C[4]);ax.text(70,.82,'验证',ha='center',color=C[1]);ax.text(100,.82,'测试',ha='center',color=C[2]);ax.set(xlabel='期数',ylabel='累计资金',xlim=(0,119));clean(ax);ax.legend(frameon=False,loc='upper left');save(fig,'factor-zoo')

fig,axs=plt.subplots(1,3,figsize=(10.2,3.6),layout='constrained');labels=['A','B','C','D'];prediction=np.array([5,8,3,6]);cov=np.array([[.04,.015,.01,.012],[.015,.05,.009,.02],[.01,.009,.02,.008],[.012,.02,.008,.03]])
inv=np.linalg.inv(cov);one=np.ones(4);mu=prediction/100;eta=(one@inv@mu-4)/(one@inv@one);weights=inv@(mu-eta*one)/4;assert np.isclose(weights.sum(),1) and np.all(weights>0)
axs[0].barh(labels,prediction,color=C[0]);axs[0].set_xlabel('预测收益（%）');im=axs[1].imshow(cov,cmap='Blues',vmin=0,vmax=.05);axs[1].set_xticks(range(4),labels);axs[1].set_yticks(range(4),labels);axs[1].set_xlabel('协方差');fig.colorbar(im,ax=axs[1],shrink=.75,ticks=[0,.025,.05]);axs[2].barh(labels,weights*100,color=C[1]);axs[2].set_xlabel('组合权重（%）');clean(axs[0]);clean(axs[2]);save(fig,'portfolio')

fig,ax=plt.subplots(figsize=(8.8,3.3),layout='constrained');ax.barh([0],[.020],color=C[0],height=.46,label='共同因子');ax.barh([0],[.005],left=[.020],color=C[1],height=.46,label='特质项');ax.text(.01,0,'0.020',ha='center',va='center',color='white',fontsize=16);ax.text(.0225,0,'0.005',ha='center',va='center',color='white',fontsize=13);ax.set(yticks=[],xlabel='收益方差',xlim=(0,.027),ylim=(-.6,.6));ax.legend(frameon=False,ncol=2,loc='upper center');ax.spines['left'].set_visible(False);save(fig,'risk-decomposition')

fig,ax=plt.subplots(figsize=(9.2,4.2),layout='constrained');times=np.arange(-5,6);ar=np.array([.05,-.07,.03,-.02,.01,1.2,.08,-.03,.02,-.01,.0]);ax.bar(times,ar,width=.65,color=[C[1] if t<0 else C[0] for t in times]);ax.axvline(-.5,color='#b4c0c5',ls='--');ax.axhline(0,color='#b4c0c5',lw=.8);ax.set(xlabel='事件时间（公告日 = 0）',ylabel='异常收益（%）',xticks=times);ax.annotate('1.2%',xy=(0,1.2),xytext=(1.3,.95),arrowprops={'arrowstyle':'-','color':C[0]},color=C[0]);clean(ax);save(fig,'event-study')
beta=np.array([1.,.5,.25]);mu=.02+.08*beta;cov=.04*np.outer(beta,beta)+np.diag([0,.0225,.01])
fig,ax=plt.subplots(figsize=(9,4.7),layout='constrained')
for n,col,label in [(2,C[1],'两项风险资产'),(3,C[0],'加入第三项资产')]:
    inv=np.linalg.inv(cov[:n,:n]);one=np.ones(n);m=mu[:n];A=one@inv@one;B=one@inv@m;D=A*(m@inv@m)-B*B;mean0=B/A;sd0=1/np.sqrt(A);means=np.linspace(mean0,.16,180);sds=np.sqrt((A*means**2-2*B*means+m@inv@m)/D)
    ax.plot(sds*100,means*100,color=col,lw=2.3,label=label);ax.scatter([sd0*100],[mean0*100],color=col,s=45,zorder=5);ax.annotate(f'({sd0:.1%}, {mean0:.1%})',xy=(sd0*100,mean0*100),xytext=(sd0*100+.6,mean0*100-1.4),color=col,fontsize=11)
ax.plot([0,35],[2,16],color=C[2],ls='--',lw=1.6);ax.scatter([20],[10],color=C[2],zorder=6);ax.annotate('(20%, 10%)',xy=(20,10),xytext=(24,8.4),arrowprops={'arrowstyle':'-','color':C[2]},color=C[2]);ax.text(.8,2.5,'Rf = 2%',color=C[2]);ax.set(xlabel='波动率（%）',ylabel='预期收益（%）',xlim=(0,43),ylim=(0,17));ax.legend(frameon=False,loc='upper left');clean(ax);save(fig,'frontier')

fig,ax=plt.subplots(figsize=(10,3));ax.set(xlim=(0,10),ylim=(0,3));ax.axis('off');arrow(ax,(.3,1.4),(9.7,1.4))
for x,label,when,col in [(1,'报告期末','2023-12-31',C[4]),(5.3,'收盘后披露','2024-04-25',C[1]),(8.7,'可以使用','2024-04-26',C[0])]:
    ax.scatter([x],[1.4],s=80,color=col,zorder=4);ax.text(x,1.85,label,ha='center',color=col);ax.text(x,.85,when,ha='center',fontsize=12)
ax.plot([1,5.3],[.4,.4],color='#ccd7da',lw=1.2);ax.text(3.15,.08,'尚未公开',ha='center',color=C[4],fontsize=12);save(fig,'data-timing')

fig,ax=plt.subplots(figsize=(10,3.2),layout='constrained');ax.broken_barh([(0,11)],(.8,.4),facecolors=C[0]);ax.broken_barh([(11,1)],(.8,.4),facecolors=C[2]);ax.broken_barh([(12,1)],(.8,.4),facecolors=C[1]);ax.set(xlim=(0,13),ylim=(.25,1.7),yticks=[]);ax.set_xticks([0,5,11,12,13],['2018-01','2018-06','2018-12','2019-01','2019-02'],rotation=30,ha='right');ax.set_xlabel('月末');ax.tick_params(axis='x',labelsize=11);ax.text(5.5,1.37,'评分：11 段月收益',ha='center',color=C[0]);ax.annotate('跳过',xy=(11.5,1.2),xytext=(10.7,1.6),ha='center',fontsize=12,arrowprops={'arrowstyle':'-','color':C[2]},color=C[2]);ax.annotate('持有',xy=(12.5,1.2),xytext=(12.8,1.6),ha='center',fontsize=12,arrowprops={'arrowstyle':'-','color':C[1]},color=C[1]);ax.spines['left'].set_visible(False);save(fig,'momentum')

fig,ax=plt.subplots(figsize=(9,4.2),layout='constrained');days=np.arange(1,253);turn=np.r_[np.full(231,1.),np.full(21,4.)];ax.fill_between(days,0,turn,step='mid',color=C[0],alpha=.28);ax.plot(days,turn,color=C[0],lw=2);ax.axhline(1.25,color=C[2],ls='--',lw=1.6,label='252 日均值：1.25%');ax.axvspan(232,252,color=C[1],alpha=.13);ax.text(122,3.2,'231 日 × 1%',color=C[0]);ax.annotate('21 日 × 4%',xy=(241,4),xytext=(168,4.5),arrowprops={'arrowstyle':'-','color':C[1]},color=C[1]);ax.set(xlabel='交易日',ylabel='日换手率（%）',xlim=(1,252),ylim=(0,5));ax.legend(frameon=False,loc='upper left');clean(ax);save(fig,'turnover')

rng=np.random.default_rng(32);n=60;innov=rng.normal(size=n);ar=np.empty(n);ar[0]=innov[0]
for t in range(1,n):ar[t]=.75*ar[t-1]+innov[t]
fig,axs=plt.subplots(2,1,figsize=(9.3,4.8),sharex=True,sharey=True,layout='constrained')
for ax,vals,label,col in zip(axs,[innov/innov.std(),ar/ar.std()],['独立误差示意','正相关误差示意'],C[:2]):
    ax.plot(np.arange(n),vals,color=col,lw=1.4,marker='o',ms=2);ax.axhline(0,color='#bdc9ce',lw=1);ax.set_ylabel('标准化误差');ax.text(.01,.93,label,transform=ax.transAxes,color=col,va='top',fontsize=11)
axs[1].set_xlabel('期数');save(fig,'inference')

fig,axs=plt.subplots(1,2,figsize=(9.4,4),sharex=True,sharey=True,layout='constrained')
for ax,r,col in zip(axs,[.06,.12],C[:2]):
    pv=108/(1+r);ax.bar(['支付现值','投入'],[pv,100],color=[col,'#ccd7da'],width=.45);ax.axhline(100,color=C[2],ls='--',lw=1);ax.text(0,pv+1.1,f'{pv:.2f}',ha='center',color=col);ax.text(1,101.1,'100',ha='center');ax.set_xlabel(f'要求回报率 {r:.0%}');ax.set_ylim(90,108);clean(ax)
axs[0].set_ylabel('金额（元）');save(fig,'investment')
print('Generated 16 title-free illustrations.')
