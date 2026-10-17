"""Title-free original teaching plots for the market microstructure lessons."""
from pathlib import Path
import random
from statistics import mean, NormalDist
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import fontManager
fontManager.addfont('C:/Windows/Fonts/msyh.ttc')
plt.rcParams.update({'font.family':'Microsoft YaHei','font.size':13,'axes.labelsize':14,'axes.spines.top':False,'axes.spines.right':False,'axes.edgecolor':'#a3b1b7','axes.labelcolor':'#334c58','text.color':'#334c58','xtick.color':'#667780','ytick.color':'#667780','axes.unicode_minus':False,'svg.fonttype':'path','savefig.facecolor':'white','axes.facecolor':'white','figure.facecolor':'white'})
OUT=Path(__file__).resolve().parents[2]/'source-quant/assets/figures/harris'
OUT.mkdir(parents=True,exist_ok=True)
C=['#388c82','#4d7ca5','#d7a064','#b66d80','#8297a1']
def single():
    fig,ax=plt.subplots(figsize=(8.8,4.6),layout='constrained');ax.grid(axis='y',color='#e7edef');ax.set_axisbelow(True);return fig,ax
def save(fig,name):
    fig.savefig(OUT/(name+'.svg'),bbox_inches='tight',pad_inches=.2,metadata={'Creator':'QuantLab','Description':'Original teaching example; explanations are in the article.'});plt.close(fig)

fig,ax=single();p=np.array([10.04,10.05,10.08]);available=np.array([100,200,500]);filled=np.array([100,200,100]);y=np.arange(3)
ax.barh(y,available,color='#e6eeee',height=.5,label='可用数量');ax.barh(y,filled,color=C[0],height=.5,label='本次成交');ax.set(yticks=y,yticklabels=[f'{x:.2f}' for x in p],xlabel='数量（股）',ylabel='卖价（元）',xlim=(0,570));ax.invert_yaxis()
for i,(a,b) in enumerate(zip(available,filled)):ax.text(a+8,i,f'{b} / {a}',va='center',fontsize=12)
ax.legend(frameon=False);save(fig,'order-book')

fig,ax=single();prices=np.array([98,99,100,101,102]);demand=[7,7,7,3,0];supply=[0,2,7,7,7];ax.step(prices,demand,where='post',lw=2.5,color=C[1],label='累计买量');ax.step(prices,supply,where='post',lw=2.5,color=C[0],label='累计卖量');ax.scatter([100],[7],s=90,facecolors='white',edgecolors=C[3],linewidths=2,zorder=4);ax.axvline(100,color=C[3],ls=':',lw=1);ax.set(xlabel='候选成交价',ylabel='数量',xticks=prices,ylim=(-.5,8.5));ax.legend(frameon=False);save(fig,'call-auction')

fig,ax=single();n=np.arange(1,101);v=9
for rho,c in zip([0,.5,1],C):ax.plot(n,v*(rho+(1-rho)/n),color=c,lw=2,label=f'ρ = {rho:g}')
ax.set(xlabel='信息来源数量',ylabel='平均估值误差的方差');ax.legend(frameon=False);save(fig,'information-aggregation')

fig,ax=single();q=np.linspace(0,220,300);profit=.2*q-.001*q*q-5;ax.plot(q,profit,color=C[0],lw=2.5);ax.axhline(0,color='#a3b1b7',lw=1);ax.scatter([100],[5],color=C[3],s=65);ax.annotate('(100, 5)',xy=(100,5),xytext=(125,5),fontsize=12);ax.set(xlabel='交易数量',ylabel='扣除研究费用后的利润');save(fig,'information-profit')

fig,ax=single();q=np.linspace(0,100,200);price=100+.002*q;ax.plot(q,price,color=C[1],lw=2.5);ax.annotate('',xy=(65,100.13),xytext=(35,100.07),arrowprops={'arrowstyle':'->','color':C[0],'lw':3});ax.annotate('',xy=(75,100.15),xytext=(95,100.19),arrowprops={'arrowstyle':'->','color':C[3],'lw':3});ax.text(43,100.11,'买入',color=C[0]);ax.text(79,100.135,'卖回',color=C[3]);ax.set(xlabel='累计净买入量',ylabel='边际成交价',ylim=(99.985,100.23));save(fig,'round-trip')

fig,ax=single();inv=np.linspace(-120,120,121);mid=50-.001*inv;ax.plot(inv,mid+.05,color=C[3],lw=2,label='卖价');ax.plot(inv,mid-.05,color=C[0],lw=2,label='买价');ax.fill_between(inv,mid-.05,mid+.05,color='#e5eeee');ax.axvline(0,color='#a3b1b7',ls=':');ax.axhline(50,color='#a3b1b7',ls=':');ax.set(xlabel='库存相对目标的偏离（股）',ylabel='报价（元）');ax.legend(frameon=False);save(fig,'inventory-quotes')

fig,ax=single();a=np.linspace(0,1,101);ax.plot(a,100+4*a,color=C[3],lw=2,label='卖价');ax.plot(a,100-4*a,color=C[0],lw=2,label='买价');ax.fill_between(a,100-4*a,100+4*a,color='#edf2f4');ax.set(xlabel='知情交易者比例',ylabel='零利润报价');ax.legend(frameon=False);save(fig,'adverse-selection')

fig,ax=single();rng=random.Random(16);allmean=[];winner=[]
for n in [2,5,20]:
    errors=[];wins=[]
    for _ in range(10000):
        estimates=[rng.gauss(0,5) for _ in range(n)];errors.extend(estimates);wins.append(max(estimates))
    allmean.append(mean(errors));winner.append(mean(wins))
x=np.arange(3);ax.bar(x-.17,allmean,.34,color=C[1],label='全部估值');ax.bar(x+.17,winner,.34,color=C[2],label='获胜者估值');ax.axhline(0,color='#a3b1b7',lw=1);ax.set(xticks=x,xticklabels=['2','5','20'],xlabel='竞价人数',ylabel='平均估值误差');ax.legend(frameon=False);save(fig,'winner-curse')

fig,ax=single();fallback=np.linspace(100.1,100.5,100);expected=.6*100+.4*fallback;ax.plot(fallback,expected,lw=2.5,color=C[0],label='先挂限价单');ax.axhline(100.1,lw=2,color=C[3],label='立即买入');ax.scatter([100.2,100.4],[100.08,100.16],s=65,color=C[0]);ax.set(xlabel='限价单未成交后的补买价格',ylabel='预期买入价格');ax.legend(frameon=False);save(fig,'limit-order-choice')

fig,ax=single();q=np.arange(1,801);cost=(np.minimum(q,100)*100.05+np.minimum(np.maximum(q-100,0),200)*100.1+np.maximum(q-300,0)*100.2)/q;ax.plot(q,(cost/100-1)*10000,color=C[0],lw=2.5)
for n in [100,300,600]:ax.scatter([n],[(cost[n-1]/100-1)*10000],s=60,color=C[3])
ax.set(xlabel='立即买入数量（股）',ylabel='相对 100 元的平均成本（基点）');save(fig,'depth-cost')

fig,ax=single();rng=random.Random(20);v=100.;values=[];prices=[]
for _ in range(80):v+=rng.gauss(0,.03);values.append(v);prices.append(v+.1*rng.choice((-1,1)))
ax.plot(prices,color=C[1],alpha=.85,lw=1.3,label='成交价');ax.plot(values,color=C[0],lw=2.2,label='有效价格');ax.set(xlabel='成交序号',ylabel='价格');ax.legend(frameon=False);save(fig,'bid-ask-bounce')

fig,ax=single();values=[8,15,30,5];bottom=np.cumsum([0]+values[:-1]);labels=['第一笔成交','第二笔成交','未成交部分','费用'];x=np.arange(5)
ax.bar(x[:4],values,bottom=bottom,color=[C[1],C[1],C[2],C[4]],width=.55);ax.bar(4,sum(values),color=C[0],width=.55)
for i,(b,v) in enumerate(zip(bottom,values)):ax.text(i,b+v+1,str(v),ha='center')
ax.text(4,59,'58',ha='center');ax.set(xticks=x,xticklabels=labels+['实现缺口'],ylabel='成本（元）',ylim=(0,68));save(fig,'implementation-shortfall')

fig,ax=single();normal=NormalDist();years=np.linspace(1,90,250);critical=normal.inv_cdf(.95);power=np.array([1-normal.cdf(critical-.02*np.sqrt(y)/.07) for y in years]);required=((critical+normal.inv_cdf(.75))*.07/.02)**2;ax.plot(years,power*100,lw=2.5,color=C[0]);ax.plot([required,required],[0,75],ls=':',color=C[3]);ax.plot([0,required],[75,75],ls=':',color=C[3]);ax.scatter([required],[75],color=C[3],s=65);ax.text(required+2,45,f'{required:.1f} 年',color=C[3]);ax.set(xlabel='观察年数',ylabel='检验功效（%）',xlim=(0,90),ylim=(0,100));save(fig,'performance-power')

fig,axs=plt.subplots(1,2,figsize=(9,4.4),layout='constrained');x=np.array([0,1]);a=axs[0];a.bar(x,[55,55],width=.5,color=C[0]);a.plot(x,[55,30],'o--',color=C[3],label='仍用旧除数');a.set(xticks=x,xticklabels=['拆股前','拆股后'],ylabel='价格加权指数',ylim=(0,70));a.legend(frameon=False,loc='upper left');a=axs[1];a.bar(x,[110,110],width=.5,color=C[1]);a.set(xticks=x,xticklabels=['1 股 + 1 股','2 股 + 1 股'],ylabel='持仓价值',ylim=(0,140));save(fig,'split-adjustment')

fig,ax=single();x=np.arange(2);ax.bar(x-.17,[20,20.01],.34,color=C[1],label='报价');ax.bar(x+.17,[20.02,20.015],.34,color=C[0],label='含费单价');ax.set(xticks=x,xticklabels=['场所 A','场所 B'],ylabel='每股成本（元）',ylim=(19.995,20.03));ax.legend(frameon=False);save(fig,'routing-fees')

fig,ax=single();r=np.linspace(0,.85,150);ax.plot(r,1/(1-r),color=C[3],lw=2.5);ax.scatter([0,.3,.6,.8],[1,1/.7,2.5,5],s=60,color=C[3]);ax.set(xlabel='每轮反馈系数',ylabel='1% 初始冲击对应的累计跌幅（%）');save(fig,'feedback')

fig,ax=single();a=np.linspace(0,1,101);ax.plot(a,(1+a)/2,color=C[0],lw=2.5,label='买单到达后');ax.plot(a,(1-a)/2,color=C[3],lw=2.5,label='卖单到达后');ax.axhline(.5,color='#a3b1b7',ls=':');ax.set(xlabel='知情交易者比例',ylabel='高价值状态的条件概率',ylim=(0,1));ax.legend(frameon=False);save(fig,'conditional-information')

fig,ax=single();n=np.arange(1,101);direct=n*(n-1);brokers=2*n+20*19;ax.plot(n,direct,color=C[3],lw=2,label='逐一核验');ax.plot(n,brokers,color=C[0],lw=2,label='20 家中介');ax.set(xlabel='客户数量',ylabel='有向信用关系数量');ax.legend(frameon=False);save(fig,'credit-network')
print(f'Generated {len(list(OUT.glob("*.svg")))} figures')
