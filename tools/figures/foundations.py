from pathlib import Path
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle,Rectangle,FancyArrowPatch
from matplotlib.font_manager import FontProperties
from scipy import stats
SITE=Path(__file__).resolve().parents[2]
ROOT=SITE/'.quantlab-work/foundations-20261018'
ROOT.mkdir(parents=True,exist_ok=True)
OUT=SITE/'source-quant/assets/figures/foundations'
OUT.mkdir(parents=True,exist_ok=True)
font=FontProperties(fname=r'C:\Windows\Fonts\msyh.ttc').get_name()
plt.rcParams.update({'font.family':font,'font.size':11,'axes.spines.top':False,'axes.spines.right':False,
 'axes.labelcolor':'#334954','text.color':'#334954','xtick.color':'#334954','ytick.color':'#334954',
 'axes.edgecolor':'#81949b','axes.prop_cycle':plt.cycler(color=['#287f8e','#d59142','#659d69','#866f9e']),
 'svg.fonttype':'path','svg.hashsalt':'quant-foundations-v1','figure.facecolor':'white','axes.facecolor':'white'})
C=['#287f8e','#d59142','#659d69','#866f9e']
rng=np.random.default_rng(20261018)
manifest={}
def canvas(n=1):
    fig,axs=plt.subplots(1,n,figsize=(10,4.6),squeeze=False)
    return fig,list(axs[0])
def finish(fig,key,alt):
    fig.tight_layout(pad=1.8)
    fig.savefig(OUT/(key+'.svg'),metadata={'Date':None},bbox_inches='tight')
    target=OUT/(key+'.svg')
    target.write_text('\n'.join(l.rstrip() for l in target.read_text('utf-8').splitlines())+'\n','utf-8')
    plt.close(fig);manifest[key]={'url':'/assets/figures/foundations/'+key+'.svg','alt':alt}
def line(ax,x,y,label=None,**kw):ax.plot(x,y,label=label,linewidth=2,**kw)
def labels(ax,x,y):ax.set_xlabel(x);ax.set_ylabel(y);ax.grid(alpha=.16)
def node(ax,x,y,t,color=C[0],r=.18):
    ax.add_patch(Circle((x,y),r,facecolor='white',edgecolor=color,lw=1.8))
    ax.text(x,y,t,ha='center',va='center',fontsize=11)
def edge(ax,p,q,text=None):
    ax.add_patch(FancyArrowPatch(p,q,arrowstyle='->',mutation_scale=12,color='#83969d',lw=1.4,shrinkA=30,shrinkB=30))
    if text is not None:ax.text((p[0]+q[0])/2,(p[1]+q[1])/2+.09,text,ha='center',fontsize=10)
def blank(ax,x=(-.5,5),y=(-.5,3)):ax.set(xlim=x,ylim=y);ax.axis('off')
def bars(ax,values,offset=0,color=C[0]):
    ax.bar(np.arange(len(values)),values,bottom=offset,width=.62,color=color,alpha=.8)

fig,(ax,)=canvas();x=np.linspace(0,1,200)
line(ax,x,2*x,label='密度 2x');ax.fill_between(x[x<=.5],2*x[x<=.5],alpha=.18,color=C[0])
ax.text(.21,.27,'面积 = 1/4');labels(ax,'x','密度');ax.legend(frameon=False)
finish(fig,'calculus','密度 2x 下的面积，0 到 0.5 的面积为四分之一。')
fig,axs=canvas(2)
for ax,n in zip(axs,[4,64]):
    values=rng.normal(0,6,(10000,n)).mean(axis=1)
    ax.hist(values,bins=45,density=True,color=C[0],alpha=.65);ax.text(.05,.9,f'n = {n}',transform=ax.transAxes)
    ax.set_xlim(-10,10);labels(ax,'样本均值','密度')
finish(fig,'sampling','样本量从 4 增至 64 后，独立观测的样本均值分布变窄。')
fig,(ax,)=canvas();blank(ax,(-.3,3.9),(-.3,2.6))
ax.add_patch(Rectangle((0,0),3.6,2.3,fill=False,edgecolor='#81949b'))
for xy,c,t in [((1.4,1.1),C[0],'A'),((2.2,1.1),C[1],'B')]:
    ax.add_patch(Circle(xy,.8,fc=c,alpha=.23,ec=c));ax.text(xy[0],1.9,t)
ax.text(1.8,1.1,'A ∩ B',ha='center');ax.text(.1,2.1,'Ω')
finish(fig,'sets','事件 A 和 B 的重叠区域对应交集，并集计算需要减去重复部分。')
fig,(ax,)=canvas();blank(ax,(-.5,6),(-.4,3))
for p,q,t in [((0,1.4),(2,2.3),'0.6'),((0,1.4),(2,.5),'0.4'),((2,2.3),(4.5,2.5),'0.05'),((2,.5),(4.5,.3),'0.10')]:edge(ax,p,q,t)
for x,y,t in [(0,1.4,'产品'),(2,2.3,'A'),(2,.5,'B')]:node(ax,x,y,t,r=.25)
ax.text(4.5,2.5,'缺陷：0.03',ha='center');ax.text(4.5,.3,'缺陷：0.04',ha='center')
finish(fig,'bayes','两车间缺陷概率的树形计算，分支概率分别为 0.03 和 0.04。')
fig,(ax,)=canvas();n=np.arange(1,5001);draw=rng.random(5000)<.3;est=np.cumsum(draw)/n
line(ax,n,est);ax.axhline(.3,color=C[1],ls='--');ax.fill_between(n,.3-1.96*np.sqrt(.21/n),.3+1.96*np.sqrt(.21/n),alpha=.12,color=C[0]);ax.set_ylim(.15,.5);labels(ax,'模拟次数','成功比例')
finish(fig,'monte-carlo','模拟比例随样本量变化，参考误差带按样本量平方根收窄。')
fig,(ax,)=canvas();x=np.arange(0,4)
ax.bar(x-.16,stats.binom.pmf(x,3,.4),width=.3,label='放回抽样');ax.bar(x+.16,stats.hypergeom.pmf(x,10,4,3),width=.3,label='不放回抽样')
labels(ax,'成功次数','概率');ax.set_xticks(x);ax.legend(frameon=False)
finish(fig,'counts','二项分布与超几何分布在相同抽样比例下的概率差异。')
fig,(ax,)=canvas();ax.step([-1,0,1,2,3],[0,.25,.75,1,1],where='post',lw=2);ax.scatter([0,1,2],[.25,.75,1],color=C[0]);labels(ax,'x','F(x)')
finish(fig,'cdf','离散分布函数在取值 0、1、2 处跳跃。')
manifest['density']=manifest['calculus']
fig,(ax,)=canvas();xy=rng.multivariate_normal([0,0],[[4,2.4],[2.4,4]],size=200)
ax.scatter(xy[:,0],xy[:,1],s=13,alpha=.45);labels(ax,'X','Y')
finish(fig,'covariance','具有正协方差的两个随机变量，散点呈右上倾斜。')
fig,(ax,)=canvas();p=np.array([[.1,.2],[.3,.4]]);ax.imshow(p,cmap='Blues',vmin=0,vmax=.5)
for i in range(2):
 for j in range(2):ax.text(j,i,f'{p[i,j]:.1f}',ha='center',va='center',fontsize=18,color='#183743')
ax.set_xticks([0,1]);ax.set_yticks([0,1]);labels(ax,'Y','X');ax.grid(False)
finish(fig,'joint','联合概率表，四个单元格之和为一，沿行列求和得到边际概率。')
fig,(ax,)=canvas();x=np.linspace(0,2,200);line(ax,x,np.maximum(0,1-abs(x-1)));labels(ax,'两个均匀变量之和','密度')
finish(fig,'transform','两个独立零到一均匀变量之和呈三角形密度。')
fig,(ax,)=canvas();x=np.linspace(0,1,250)
for k,c in [(1,C[1]),(2,C[0]),(3,C[2])]:line(ax,x,stats.beta.pdf(x,k,4-k),label=f'第 {k} 个次序统计量',color=c)
labels(ax,'x','密度');ax.legend(frameon=False)
finish(fig,'order','三个均匀样本的最小值、中位数与最大值密度。')
fig,(ax,)=canvas();x=np.arange(16)
for l in [1,3,7]:ax.plot(x,stats.poisson.pmf(x,l),'o-',label=f'λ = {l}',lw=1.5)
labels(ax,'事件次数','概率');ax.legend(frameon=False)
finish(fig,'poisson','泊松分布随事件强度增加向右移动并变宽。')
fig,axs=canvas(3)
for ax,n in zip(axs,[1,5,30]):
    values=(rng.exponential(size=(20000,n)).mean(axis=1)-1)*np.sqrt(n)
    ax.hist(values,bins=55,density=True,color=C[0],alpha=.45)
    x=np.linspace(-3,4,180);line(ax,x,stats.norm.pdf(x),color=C[1]);ax.set_xlim(-3,4);ax.text(.05,.9,f'n = {n}',transform=ax.transAxes);labels(ax,'标准化均值','密度')
finish(fig,'clt','指数样本的标准化均值分布随样本量增加接近正态曲线。')
fig,(ax,)=canvas();x=np.linspace(.001,8,250)
for k in [1,2,4]:line(ax,x,stats.gamma.pdf(x,k),label=f'形状 = {k}，速率 = 1')
labels(ax,'等待时间','密度');ax.legend(frameon=False)
finish(fig,'gamma','Gamma 分布从一次等待扩展到多次到达的总等待时间。')
fig,(ax,)=canvas();p=np.linspace(.001,.999,300);y=p**3*(1-p)**2;line(ax,p,y);ax.axvline(.6,color=C[1],ls='--');labels(ax,'参数 p','似然')
finish(fig,'likelihood','三次成功两次失败的似然在 p 等于 0.6 处最大。')
fig,(ax,)=canvas()
samples=rng.normal(0,1,(40,20));means=samples.mean(axis=1);half=1.96/np.sqrt(20)
for i,m in enumerate(means):ax.plot([m-half,m+half],[i,i],color=C[0] if abs(m)<half else C[1]);ax.scatter(m,i,s=8,color='#334954')
ax.axvline(0,ls='--',color='#334954');labels(ax,'均值区间','重复样本编号')
finish(fig,'intervals','重复抽样构造的置信区间，有的覆盖固定总体均值，有的没有覆盖。')
fig,(ax,)=canvas();x=np.linspace(-1,3,200)
line(ax,x,stats.norm.pdf(x,0,.35),label='无偏、方差较小');line(ax,x,stats.norm.pdf(x,.8,.22),label='有偏、方差较小');line(ax,x,stats.norm.pdf(x,0,.8),label='无偏、方差较大')
ax.axvline(0,color='#83969d',ls='--');labels(ax,'估计值（真值为 0）','密度');ax.legend(frameon=False)
finish(fig,'bias-variance','估计量的偏差控制中心位置，方差控制分布宽度。')
fig,(ax,)=canvas();data=np.array([1,2,2,5,9]);b=rng.choice(data,(20000,5),replace=True).mean(axis=1)
ax.hist(b,bins=35,density=True,color=C[0],alpha=.65);ax.axvline(data.mean(),color=C[1],ls='--');labels(ax,'自助样本均值','密度')
finish(fig,'bootstrap','从五个观测中有放回抽样得到样本均值的自助分布。')
fig,(ax,)=canvas();p=np.linspace(.001,.999,250)
line(ax,p,stats.beta.pdf(p,2,2),label='先验 Beta(2,2)');line(ax,p,stats.beta.pdf(p,8,6),label='后验 Beta(8,6)')
labels(ax,'成功概率 p','密度');ax.legend(frameon=False)
finish(fig,'beta-update','观察十次试验中六次成功后，Beta 先验更新为后验。')
fig,(ax,)=canvas();x=np.linspace(-4,5,300);line(ax,x,stats.norm.pdf(x),label='原假设');line(ax,x,stats.norm.pdf(x,2),label='备择分布')
mask=x>1.645;ax.fill_between(x[mask],stats.norm.pdf(x[mask]),color=C[0],alpha=.25);ax.axvline(1.645,ls='--',color='#334954');labels(ax,'检验统计量','密度');ax.legend(frameon=False)
finish(fig,'testing','单侧检验拒绝域的原假设面积对应第一类错误概率。')
fig,(ax,)=canvas();effect=np.linspace(0,2,200)
for n in [10,25,50]:line(ax,effect,stats.norm.sf(stats.norm.ppf(.95)-effect*np.sqrt(n)/2),label=f'n = {n}')
labels(ax,'真实均值差','功效');ax.legend(frameon=False)
finish(fig,'power','单侧检验的功效随效应大小和样本量增加。')
fig,(ax,)=canvas();x=np.linspace(-5,5,300)
for df in [2,5,30]:line(ax,x,stats.t.pdf(x,df),label=f't，自由度 {df}')
line(ax,x,stats.norm.pdf(x),label='标准正态',color='#83969d',linestyle='--');labels(ax,'统计量','密度');ax.legend(frameon=False)
finish(fig,'t-distribution','自由度较小时 t 分布尾部更厚，随自由度增大接近正态。')
fig,(ax,)=canvas();blank(ax,(-.5,6),(-.5,3))
for i in range(3):
 for j in range(4):
    ax.add_patch(Rectangle((j*1.2,i*.8),.85,.55,fc=C[(j+i)%2],alpha=.65));ax.text(j*1.2+.42,i*.8+.27,'A' if (j+i)%2==0 else 'B',ha='center',va='center',color='white')
 ax.text(5,i*.8+.27,f'区组 {i+1}',va='center')
finish(fig,'design','每个区组内分别安排两种处理，用分组控制整体水平差异。')
fig,(ax,)=canvas();x=np.linspace(-3,5,200)
line(ax,x,stats.norm.pdf(x,0,1),label='总体 A');line(ax,x,stats.norm.pdf(x,1,1.4),label='总体 B');labels(ax,'观测值','密度');ax.legend(frameon=False)
finish(fig,'two-sample','比较两个总体时，均值差与组内离散程度共同影响统计量。')
fig,(ax,)=canvas();obs=[18,22,20];ax.bar(np.arange(3)-.17,obs,.33,label='观测频数');ax.bar(np.arange(3)+.17,[20]*3,.33,label='期望频数');ax.set_xticks(range(3),['A','B','C']);labels(ax,'类别','频数');ax.legend(frameon=False)
finish(fig,'goodness-fit','观测频数与期望频数之差用于拟合优度检验。')
fig,(ax,)=canvas();x=np.array([0,1,2,3]);y=np.array([1,2,2,4]);fit=.9+.9*x
ax.scatter(x,y,s=45);line(ax,x,fit)
for a,b,c in zip(x,y,fit):ax.plot([a,a],[b,c],ls='--',color=C[1])
labels(ax,'x','y')
finish(fig,'regression','四个数据点的最小二乘直线，虚线表示观测值到拟合值的残差。')
fig,(ax,)=canvas();x=np.linspace(-3,3,100);xx,yy=np.meshgrid(x,x);density=stats.multivariate_normal.pdf(np.dstack([xx,yy]),cov=[[1,.65],[.65,1]])
ax.contour(xx,yy,density,levels=7,cmap='viridis');line(ax,x,.65*x,color=C[1]);labels(ax,'X','Y');ax.set_aspect('equal')
finish(fig,'bivariate','二维正态密度等高线与条件均值直线。')
fig,(ax,)=canvas()
for i,values in enumerate([[1,2,3],[3,4,5],[5,6,7]]):
    ax.scatter(np.full(3,i),values,s=42);ax.plot([i-.18,i+.18],[np.mean(values)]*2,color=C[i],lw=3)
ax.axhline(4,color='#83969d',ls='--');ax.set_xticks(range(3),['A','B','C']);labels(ax,'处理组','观测值')
finish(fig,'anova','各组观测围绕组均值变化，组均值又围绕总体均值变化。')
fig,(ax,)=canvas();x=np.arange(3)
line(ax,x,[8,10,13],label='处理 A',marker='o');line(ax,x,[10,11,15],label='处理 B',marker='o');ax.set_xticks(x,['区组 1','区组 2','区组 3']);labels(ax,'区组','结果');ax.legend(frameon=False)
finish(fig,'blocks','同一区组的处理结果相互接近，区组间整体水平有所不同。')
fig,(ax,)=canvas()
for i,v in enumerate([1,2,3,4,5,6]):ax.scatter(v,0,s=100,color=C[i//2]);ax.text(v,-.15,f'秩 {i+1}',ha='center')
ax.set(xlim=(.4,6.6),ylim=(-.4,.4));ax.set_yticks([]);ax.set_xlabel('合并后的观测值')
finish(fig,'ranks','三组观测合并排序，颜色表示分组，位置对应全体秩。')
fig,(ax,)=canvas();seq=[1,1,0,0,1,0,1,1,0,0]
ax.step(range(10),seq,where='mid',lw=2);ax.scatter(range(10),seq,color=[C[s] for s in seq],s=40);ax.set_yticks([0,1],['−','＋']);ax.set_ylim(-.3,1.3);labels(ax,'原始观测顺序','符号')
finish(fig,'runs','连续相同符号构成一个游程，排序会破坏原有游程信息。')
fig,(ax,)=canvas()
for v,t in [([2,4],r'$A_1$'),([6,12],r'$A_2$')]:line(ax,[0,1],v,marker='o',label=t)
ax.set_xticks([0,1],[r'$B_1$',r'$B_2$']);labels(ax,'因素 B 水平','单元格均值');ax.legend(frameon=False)
finish(fig,'interaction','两个 A 水平下 B 的效应不同，非平行线表示交互作用。')
fig,(ax,)=canvas();blank(ax,(-.5,3.5),(-.5,3.5))
for a in [0,1]:
 for b in [0,1]:
    c=(2*a-1)*(2*b-1);x=a*2;y=b*2
    node(ax,x,y,'+' if c==1 else '−',r=.24)
ax.text(1,-.4,'A：− → ＋',ha='center');ax.text(-.5,1,'B',rotation=90);ax.text(1,2.8,'节点符号：C = AB',ha='center')
finish(fig,'factorial','半分数设计中 C 等于 AB，主效应与交互项发生混杂。')

# Algorithm diagrams show state, data and edges; no decorative cover or slide title.
fig,(ax,)=canvas();blank(ax,(-.5,5.5),(-.5,2.5))
for x,t in [(0,'输入'),(2.4,'操作'),(4.8,'输出')]:node(ax,x,1,t,r=.42)
edge(ax,(0,1),(2.4,1));edge(ax,(2.4,1),(4.8,1));ax.text(2.4,.15,'接口约定：输入、返回值、异常',ha='center')
finish(fig,'adt','抽象数据类型通过输入、操作与输出约定行为。')
fig,(ax,)=canvas();blank(ax,(-.5,5.5),(-.5,2.5))
for x,y,t in [(0,1.6,'a'),(0,.4,'b'),(3,1,'[1, 2]')]:node(ax,x,y,t,r=.4 if x else .2)
edge(ax,(0,1.6),(3,1));edge(ax,(0,.4),(3,1))
finish(fig,'references','变量 a 和 b 可以指向同一个可变列表。')
fig,(ax,)=canvas();n=np.arange(2,201)
for y,t in [(np.log2(n),'log2 n'),(n,'n'),(n*np.log2(n),'n log2 n'),(n*n,'n²')]:line(ax,n,y,label=t)
ax.set_yscale('log');labels(ax,'输入规模 n','相对操作次数（对数坐标）');ax.legend(frameon=False)
finish(fig,'complexity','四类增长速度在相同输入规模下的比较。')
fig,(ax,)=canvas();blank(ax,(-.5,6),(-.5,3.5))
for i,v in enumerate([3,7,9]):ax.add_patch(Rectangle((.6,i*.7),1.2,.6,fc=C[0],alpha=.2));ax.text(1.2,i*.7+.3,str(v),ha='center',va='center')
ax.annotate('push',xy=(1.2,2.3),xytext=(3,3),arrowprops={'arrowstyle':'->','color':C[1]});ax.text(2.1,1.75,'栈顶',color=C[0])
finish(fig,'stack','栈只能从顶部压入或弹出，最后加入的元素最先离开。')
fig,(ax,)=canvas();blank(ax,(-.5,6),(-.5,2))
for i,v in enumerate([2,4,7,9]):ax.add_patch(Rectangle((i,0.3),.8,.7,fc=C[0],alpha=.2));ax.text(i+.4,.65,str(v),ha='center',va='center')
ax.text(0,1.3,'出队 ←');ax.text(3,1.3,'← 入队')
finish(fig,'queue','队列从一端加入、另一端取出，保持先进先出顺序。')
fig,(ax,)=canvas();blank(ax,(-.5,6),(-.5,2))
for i,v in enumerate([3,6,8]):node(ax,1.6*i,.7,str(v));edge(ax,(1.6*i,.7),(1.6*(i+1),.7))
ax.text(4.8,.7,'None',ha='center',va='center')
finish(fig,'linked-list','链表节点通过引用连接，最后一个节点指向空引用。')
fig,(ax,)=canvas();blank(ax,(-.5,5.8),(-.5,3.5))
for i in range(4):
    ax.add_patch(Rectangle((i*.7,2.4-i*.65),2.5,.5,fc=C[0],alpha=.15+i*.1))
    ax.text(i*.7+.15,2.65-i*.65,f'factorial({4-i})')
finish(fig,'recursion','递归调用逐层保留栈帧，最深层返回后依次计算。')
fig,(ax,)=canvas()
def tri(a,b,c,d):
 if d==0:ax.fill([a[0],b[0],c[0]],[a[1],b[1],c[1]],color=C[0]);return
 mid=lambda p,q:(p+q)/2
 for corners in [(a,mid(a,b),mid(a,c)),(mid(a,b),b,mid(b,c)),(mid(a,c),mid(b,c),c)]:tri(*corners,d-1)
tri(np.array([0.,0]),np.array([1.,0]),np.array([.5,.866]),4);ax.set_aspect('equal');ax.axis('off')
finish(fig,'fractal','谢尔平斯基三角形由三个更小的同类图形递归组成。')
fig,(ax,)=canvas();grid=np.array([[0,1,0,0,0],[0,1,0,1,0],[0,0,0,1,0],[1,1,0,0,0]])
ax.imshow(grid,cmap='Greys',vmin=0,vmax=2)
path=np.array([[0,0],[1,0],[2,0],[2,1],[2,2],[3,2],[3,3],[3,4]])
ax.plot(path[:,1],path[:,0],'-o',color=C[0]);ax.set_xticks(range(5));ax.set_yticks(range(4));labels(ax,'列','行');ax.grid(False)
finish(fig,'maze','迷宫路径按相邻可通行格子延伸，并记录访问位置避免重复。')
fig,(ax,)=canvas();blank(ax,(-.5,7),(-.5,2))
for i in range(7):
    node(ax,i,.6,str(i),r=.2)
    if i:edge(ax,(i-1,.6),(i,.6))
for i in range(3,7):ax.add_patch(FancyArrowPatch((i-3,.8),(i,.8),connectionstyle='arc3,rad=-.4',arrowstyle='->',color=C[1],mutation_scale=10))
ax.text(3,-.2,'金额状态；边对应增加 1 或 3',ha='center')
finish(fig,'dynamic-programming','凑零钱问题的状态依赖，较大金额由较小金额转移得到。')
fig,(ax,)=canvas();blank(ax,(-.5,8.5),(-.5,2.5))
for i,v in enumerate([1,3,5,7,9,11,13,15]):
    ax.add_patch(Rectangle((i,1),.85,.65,fc=C[1] if i==3 else C[0],alpha=.25));ax.text(i+.42,1.32,str(v),ha='center',va='center')
ax.annotate('中点',xy=(3.4,1),xytext=(3.4,.1),ha='center',arrowprops={'arrowstyle':'->'});ax.text(6.4,2,'查找 13 →',ha='center')
finish(fig,'binary-search','二分查找先比较中点，依据有序性舍弃一半区间。')
fig,(ax,)=canvas();blank(ax,(-.5,7.5),(-.5,2.5))
for i in range(7):
 ax.add_patch(Rectangle((i,.5),.8,.8,fc='white',ec='#83969d'));ax.text(i+.4,.15,str(i),ha='center')
for i,v in [(3,10),(4,17),(5,24)]:ax.text(i+.4,.9,str(v),ha='center')
ax.text(3.8,2,'10、17、24 对 7 取模均为 3',ha='center')
finish(fig,'hashing','线性探测将散列到同一槽位的键依次放入后面的空槽。')
fig,axs=canvas(3)
for ax,values in zip(axs,[[5,2,4,1,3],[2,4,1,3,5],[1,2,3,4,5]]):
    bars(ax,values);ax.set_xticks(range(5));labels(ax,'数组下标','值')
finish(fig,'sorting','冒泡排序从原始数组经过一轮交换到最终有序状态。')
fig,(ax,)=canvas();blank(ax,(-.5,7.5),(-.5,3.2))
for x,y,t in [(3.5,2.7,'[5, 2, 4, 1]'),(1.5,1.5,'[2, 5]'),(5.5,1.5,'[1, 4]'),(3.5,.2,'[1, 2, 4, 5]')]:ax.text(x,y,t,ha='center',va='center',bbox={'boxstyle':'round,pad=.5','fc':'#eaf2f4','ec':'#b6c8ce'})
for p,q in [((3.5,2.7),(1.5,1.5)),((3.5,2.7),(5.5,1.5)),((1.5,1.5),(3.5,.2)),((5.5,1.5),(3.5,.2))]:edge(ax,p,q)
finish(fig,'merge','归并排序将数组分成两部分，分别排序后合并。')
fig,(ax,)=canvas();blank(ax,(-.5,8.5),(-.5,2))
for i,v in enumerate([1,2,3,4,7,6,5]):
 c=C[0] if v<4 else C[1] if v==4 else C[2]
 ax.add_patch(Rectangle((i,.5),.8,.8,fc=c,alpha=.25));ax.text(i+.4,.9,str(v),ha='center')
ax.text(3.4,.1,'枢轴',ha='center')
finish(fig,'partition','快速排序划分后，枢轴两侧分别是不大于和不小于它的元素。')
def treefigure(key,values,alt):
 fig,(ax,)=canvas();blank(ax,(-.5,6.5),(-.4,3))
 pos=[(3,2.5),(1.5,1.5),(4.5,1.5),(.7,.4),(2.3,.4),(3.7,.4),(5.3,.4)]
 for i in range(1,len(values)):edge(ax,pos[(i-1)//2],pos[i])
 for p,t in zip(pos,values):node(ax,*p,str(t),r=.25)
 finish(fig,key,alt)
treefigure('tree',['A','B','C','D','E','F','G'],'二叉树的父子关系与层次。')
treefigure('heap',[1,3,2,7,5,6,4],'最小堆满足每个父节点不大于子节点，但同层元素无需有序。')
treefigure('bst',[4,2,6,1,3,5,7],'二叉搜索树每个节点的左子树更小，右子树更大。')
fig,axs=canvas(2)
for ax,pos in zip(axs,[[(1,2.5),(2,1.5),(3,.5)],[(2,2.5),(1,1.2),(3,1.2)]]):
 blank(ax,(0,4),(0,3))
 if ax is axs[0]:
    for p,q in zip(pos,pos[1:]):edge(ax,p,q)
    vals=[1,2,3]
 else:
    for q in pos[1:]:edge(ax,pos[0],q)
    vals=[2,1,3]
 for p,t in zip(pos,vals):node(ax,*p,str(t),r=.25)
finish(fig,'avl','一次左旋将右侧链条变为平衡子树，同时保持中序次序。')
def graphfigure(key,alt,weighted=False,directed=False):
 fig,(ax,)=canvas();blank(ax,(-.5,5.5),(-.5,3))
 pos=[(0,1.2),(1.7,2.4),(1.7,0),(3.6,1.2),(5,2.4)]
 edges=[(0,1,2),(0,2,4),(1,3,1),(2,3,2),(3,4,3)]
 for a,b,w in edges:edge(ax,pos[a],pos[b],str(w) if weighted else None)
 for i,p in enumerate(pos):node(ax,*p,chr(65+i),r=.22)
 finish(fig,key,alt)
graphfigure('graph','图由顶点和边构成，邻接表只记录实际存在的连接。')
graphfigure('bfs','从 A 开始的宽度优先搜索按距离逐层访问节点。')
graphfigure('dag','有向无环图的边给出先后依赖，拓扑排序必须尊重这些方向。')
graphfigure('shortest-path','带非负权重的图，最短路径比较沿途边权之和。',True)
fig,(ax,)=canvas();board=(np.indices((5,5)).sum(axis=0)%2)
ax.imshow(board,cmap='Greys',vmin=0,vmax=3)
for p in [(0,1),(0,3),(1,0),(1,4),(3,0),(3,4),(4,1),(4,3)]:
 ax.annotate('',xy=p,xytext=(2,2),arrowprops={'arrowstyle':'->','color':C[0]})
ax.scatter([2],[2],s=200,color=C[1]);ax.set_xticks(range(5));ax.set_yticks(range(5))
finish(fig,'knight','棋盘中央骑士可到达的八个位置，每步分别移动一格和两格。')
fig,(ax,)=canvas();n=np.arange(1,65);capacity=2**np.ceil(np.log2(n))
ax.step(n,capacity,where='post',label='容量');line(ax,n,n,label='元素数');labels(ax,'连续追加次数','数量');ax.legend(frameon=False)
finish(fig,'dynamic-array','动态数组按倍增扩容，容量阶梯上升而元素数连续增长。')
fig,(ax,)=canvas();blank(ax,(-.5,7.5),(-.5,3))
for layer,ids in enumerate([range(7),[0,2,4,6],[0,4]]):
 for i in ids:node(ax,i,layer,str(i),r=.17)
 for a,b in zip(ids,list(ids)[1:]):edge(ax,(a,layer),(b,layer))
finish(fig,'skip-list','跳表高层跨过多个节点，逐层下降后定位底层元素。')
fig,axs=canvas(2);rgb=np.zeros((80,120,3));rgb[:,:,0]=np.linspace(0,1,120);rgb[:,:,1]=np.linspace(0,1,80)[:,None];rgb[:,:,2]=.3
for ax,img in zip(axs,[rgb,np.floor(rgb*4)/4]):ax.imshow(img);ax.axis('off')
finish(fig,'quantization','同一颜色渐变在较多和较少调色板颜色下的对比。')
fig,(ax,)=canvas();blank(ax,(-.5,8),(-.5,2.7))
for i,t in enumerate('ABABACA'):
 ax.text(i+.3,1.7,t,ha='center',fontsize=20);ax.text(i+.3,.7,str([0,0,1,2,3,0,1][i]),ha='center',fontsize=15)
ax.text(7.4,1.7,'字符');ax.text(7.4,.7,'前缀长度')
finish(fig,'kmp','模式 ABABACA 的前缀函数记录失配时可以保留的前后缀长度。')
(ROOT/'figure-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
print('figure keys',len(manifest),'SVG files',len(list(OUT.glob('*.svg'))))
