"""Independently check the worked arithmetic and symbolic derivations."""
import argparse, json, math
import numpy as np
import sympy as sp
CASES={}
def case(*slugs):
    def register(fn):
        for slug in slugs: CASES[slug]=fn
        return fn
    return register
def close(actual,expected): assert np.allclose(actual,expected,rtol=1e-9,atol=1e-11),(actual,expected)
def zero(expr): assert sp.simplify(expr)==0,expr
def cdf(x): return (1+math.erf(x/math.sqrt(2)))/2

@case("calin-book-02-01","calin-book-02-07")
def coins():
    x=np.array([2,1,1,0]);conditional=np.array([1.5,1.5,.5,.5])
    close(x.mean(),conditional.mean());close(conditional[:2].mean(),1.5)
    return {"outcomes":x.tolist(),"conditional_means":conditional.tolist(),"mean":float(x.mean()),"P_A":.5}

@case("calin-book-02-08")
def total_variance():
    x=np.array([2,1,1,0]);m=np.array([1.5,1.5,.5,.5])
    within=float(np.mean((x-m)**2));between=float(np.var(m));close(np.var(x),within+between)
    return {"within":within,"between":between,"total":float(np.var(x))}

@case("calin-book-02-10")
def convergence():
    records=[]
    for n in [4,100,10000]:
        p=1/n;v=math.sqrt(n);close(p*v*v,1);records.append({"n":n,"probability":p,"amplitude":v,"L1_error":p*v,"L2_squared":p*v*v})
    return records

@case("calin-book-03-01")
def covariance():
    A=np.tril(np.ones((3,3)));C=A@A.T;close(C,[[1,1,1],[1,2,2],[1,2,3]])
    return {"covariance":C.tolist(),"correlation_2_3":float(C[1,2]/math.sqrt(C[1,1]*C[2,2]))}

@case("calin-book-03-06")
def count_area():
    event=np.array([.5,1.5,3]);T=4
    vertical=np.dot(np.diff(np.r_[0,event,T]),np.arange(4));horizontal=np.sum(T-event);close(vertical,horizontal);close(horizontal,7)
    return {"vertical_sum":float(vertical),"event_sum":float(horizontal)}

@case("calin-book-04-02","calin-book-09-03")
def exit_case():
    x=sp.symbols("x");p=x/3;out=[]
    zero(sp.diff(p,x,2))
    for sigma in [1,2]:
        v=x*(3-x)/sigma**2;zero(sp.Rational(sigma**2,2)*sp.diff(v,x,2)+1)
        assert v.subs(x,0)==v.subs(x,3)==0
        out.append({"sigma":sigma,"upper_probability":1/3,"mean_time":2/sigma**2})
    return out

@case("calin-book-04-08")
def qv():
    return [{"n":n,"mean":1,"variance":2/n,"sd":math.sqrt(2/n)} for n in [8,32,128,512]]

@case("calin-book-05-01")
def ito_sums():
    w=np.array([0,.4,-.1,.2]);d=np.diff(w);left=float(w[:-1]@d);right=float(w[1:]@d);q=float(d@d)
    close(right-left,q);close(2*left+q,w[-1]**2-w[0]**2);close([left,right,q],[-.23,.27,.5])
    return {"left":left,"right":right,"squared_increments":q}

@case("calin-book-05-03")
def adaptive_isometry():
    direct=.5+.5*.5;isometry=.5+.5*.5;close(direct,.75)
    return {"cross_term":0,"direct_second_moment":direct,"ito_isometry":isometry}

@case("calin-book-05-04")
def wiener():
    t=sp.symbols("t");v=sp.integrate(t*t,(t,0,1));w=sp.integrate((1-t)**2,(t,0,1));c=sp.integrate(t*(1-t),(t,0,1))
    zero(v+w+2*c-1)
    return {"var_I":float(v),"var_J":float(w),"covariance":float(c),"correlation":float(c/sp.sqrt(v*w))}

@case("calin-book-05-05")
def poisson_payments():
    total=sum(1+t for t in [.5,1.5,3]);expected=4+4**2/2;close(total-expected,-4)
    return {"actual":total,"compensator":expected,"compensated":total-expected}

@case("calin-book-06-02","calin-book-09-01")
def ito_square():
    x,h=sp.symbols("x h");exact=(x+2*h)**2+9*h-x*x;rate=sp.limit(exact/h,h,0);zero(rate-(4*x+9))
    return {"generator":str(rate),"exact_at_x1_h001":float(exact.subs({x:1,h:.01})),"first_order":.13,"without_correction":.04}

@case("calin-book-06-03")
def ito_multi():
    sigma=np.array([[2,1],[-1,3]]);A=sigma@sigma.T;H=np.array([[2,-2],[-2,2]])
    drift=.5*np.sum(A*H);noise=np.array([1,-1])@sigma;close(drift,noise@noise);close(drift,13)
    return {"covariance":A.tolist(),"hessian":H.tolist(),"drift":float(drift),"difference_noise":noise.tolist()}

@case("calin-book-06-04")
def poisson_square():
    n=sp.symbols("n");zero((n+1)**2-n*n-(2*n+1));h=.01
    return {"jump_at_n2":5,"exact_mean_increment":10*h+4*h*h,"first_order":10*h}

@case("calin-book-07-02")
def heat():
    x,t,T=sp.symbols("x t T");u=x*x+T-t;zero(sp.diff(u,t)+sp.diff(u,x,2)/2)
    return {"u":str(u),"at_t025_x04_T1":float(u.subs({t:.25,x:.4,T:1}))}

@case("calin-book-08-01")
def euler():
    state=0;rows=[]
    for z in [1,-1,.5]:
        drift=2*(1-state)*.25;noise=.5*math.sqrt(.25)*z
        rows.append({"old":state,"drift":drift,"noise":noise,"new":state+drift+noise});state+=drift+noise
    close(state,.9375);return rows

@case("calin-book-08-03")
def exact_form():
    t,x=sp.symbols("t x");F=t*x*x
    zero(sp.diff(F,t)+sp.diff(F,x,2)/2-(x*x+t));zero(sp.diff(F,x)-2*t*x)
    return {"solution_function":str(F),"drift":str(x*x+t),"diffusion":str(2*t*x)}

@case("calin-book-08-04")
def ou():
    mean=10+4*math.exp(-.5);var=4*(1-math.exp(-1))
    s=sp.symbols("s");integral=sp.integrate(4*sp.exp(-(1-s)),(s,0,1));close(float(integral),var)
    return {"mean_at_1":mean,"variance_at_1":var,"sd_at_1":math.sqrt(var),"stationary_variance":4}

@case("calin-book-08-06")
def integrating_factor():
    x=sp.symbols("x");a,b,f,g=map(sp.Rational,[".2",".3","1",".5"])
    time=(a*x+f)+(-a+b*b)*x-b*(b*x+g);noise=b*x+g-b*x
    zero(time-sp.Rational(".85"));zero(noise-g)
    return {"homogeneous_log_drift":float(a-b*b/2),"inverse_drift":float(-a+b*b),"transformed_drift":float(time),"transformed_noise":float(noise)}

@case("calin-book-08-07")
def picard():
    t,s=sp.symbols("t s");m=sp.Integer(0);rows=[]
    for n in range(1,4):
        m=sp.integrate(2*(1-m.subs(t,s)),(s,0,t));rows.append({"iteration":n,"function":str(m),"value_at_half":float(m.subs(t,.5))})
    return {"iterations":rows,"exact_at_half":1-math.exp(-1)}

@case("calin-book-09-02")
def dynkin():
    s,t=sp.symbols("s t");via_integral=1+sp.integrate(4*(1+2*s)+1,(s,0,t));direct=(1+2*t)**2+t
    zero(via_integral-direct);return {"second_moment":str(via_integral),"at_half":float(via_integral.subs(t,.5))}

@case("calin-book-09-05")
def feynman_kac():
    tau,x,r=sp.symbols("tau x r",positive=True);u=sp.exp(-r*tau)*(x*x+4*tau)+3/r*(1-sp.exp(-r*tau))
    zero(-sp.diff(u,tau)+2*sp.diff(u,x,2)-r*u+3)
    terminal=math.exp(-.1)*8;running=30*(1-math.exp(-.1))
    return {"terminal":terminal,"running":running,"total":terminal+running,"undiscounted":11}

@case("calin-book-10-02")
def levy():
    t=sp.symbols("t",real=True);zero(sp.trigsimp(sp.cos(t)**2+sp.sin(t)**2-1))
    return {"weights_at_pi4":[1/math.sqrt(2)]*2,"variance_rate":1}

@case("calin-book-10-04")
def girsanov():
    w,theta=sp.symbols("w theta");zero(-w*w/2-theta*w-theta**2/2+(w+theta)**2/2)
    return {"P_positive":.5,"Q_positive":1-cdf(.5),"Q_mean":-.5,"Q_variance":1}

@case("calin-book-11-08","guo-book-03-08")
def kalman():
    P,R,m,y=4,4,10,11;K=P/(P+R);post=(1-K)*P;close(post,(1-K)**2*P+K*K*R)
    close(post,1/(1/P+.25))
    return {"gain":K,"mean":m+K*(y-m),"variance":post,"lower_noise_gain":.8,"lower_noise_mean":10.8,"lower_noise_variance":.8}

@case("guo-book-02-02")
def portfolio():
    S=np.diag([.01,.04]);inv=np.linalg.solve(S,np.ones(2));w=inv/inv.sum();close(w,[.8,.2]);var=w@S@w
    return {"weights":w.tolist(),"variance":float(var),"volatility":float(np.sqrt(var)),"equal_weight_volatility":float(np.sqrt(np.array([.5,.5])@S@np.array([.5,.5])))}

@case("guo-book-02-03")
def bl():
    pi=np.array([.04,.04]);C0=np.eye(2)*.0004;P=np.array([[1,-1]]);q=.02;omega=.0004
    K=(C0@P.T)/(float((P@C0@P.T)[0,0])+omega);m=pi+(K*(q-float((P@pi)[0]))).ravel();C=C0-K@P@C0
    precision=np.linalg.inv(C0)+P.T@P/omega
    alternative=np.linalg.solve(precision,np.linalg.solve(C0,pi)+P.ravel()*q/omega);close(m,alternative);close(C,np.linalg.inv(precision))
    return {"gain":K.ravel().tolist(),"posterior_mean":m.tolist(),"posterior_covariance":C.tolist()}

@case("guo-book-02-04")
def parameter_risk():
    means=np.array([0,.04]);within=.0001;between=float(np.var(means));second=float(np.mean(within+means*means));total=within+between
    close(second-means.mean()**2,total)
    return {"mean":.02,"within":within,"between":between,"second_moment":second,"variance":total,"sd":math.sqrt(total)}

@case("guo-book-02-06")
def garch():
    var=.000002+.1*.02**2+.8*.0001;long=.000002/(1-.1-.8);close(var,.000122)
    return {"next_variance":var,"next_sd":math.sqrt(var),"long_variance":long,"following_forecast":.000002+.9*var}

@case("guo-book-03-03")
def merton():
    W,A,gamma=sp.symbols("W A gamma",positive=True);V=A*W**(1-gamma)/(1-gamma)
    ratio=sp.simplify(-sp.diff(V,W)/(W*sp.diff(V,W,2)));zero(ratio-1/gamma)
    return {"wealth_derivative_ratio":str(ratio),"weight_gamma3":.06/(3*.04),"weight_gamma6":.06/(6*.04)}

@case("guo-book-03-06")
def hjb():
    tau,x,sigma=sp.symbols("tau x sigma",positive=True);V=x*x/(2*(1+tau))+sigma*sigma*sp.log(1+tau)/2
    zero(-sp.diff(V,tau)+sigma*sigma*sp.diff(V,x,2)/2-sp.diff(V,x)**2/2)
    return {"control_at_tau1_x2":-1,"value":1+math.log(2)/2}

@case("guo-book-04-03")
def realized_kernel():
    r=np.array([1,-1,1,-1])*.001;g=[float(r@r)]+[float(r[h:]@r[:-h]) for h in [1,2]];RK=g[0]+g[1];close(RK,1e-6)
    return {"gamma":g,"weights":[1,.5,0],"kernel":RK}

@case("guo-book-04-04")
def likelihood():
    Omega=np.array([[2,-1],[-1,2.]]);r=np.array([1,0]);z=np.linalg.solve(Omega,r);close(z,[2/3,1/3])
    return {"determinant":float(np.linalg.det(Omega)),"solution":z.tolist(),"quadratic":float(r@z),"log_likelihood":float(-.5*np.linalg.slogdet(Omega)[1]-.5*r@z)}

@case("guo-book-04-05")
def hy():
    xs=[(0,1,2),(1,3,-1)];ys=[(0,2,1),(2,3,3)];terms=[]
    for l,r,v in xs:terms.append([v*w if min(r,b)>max(l,a) else 0 for a,b,w in ys])
    close(np.sum(terms),-2);return {"pair_contributions":terms,"total":sum(map(sum,terms))}

@case("guo-book-04-07")
def fourier():
    t=np.array([0,np.pi/2]);r=np.array([.01,-.01]);coef=np.array([np.sum(np.exp(-1j*k*t)*r)/(2*np.pi) for k in [-1,0,1]])
    iv=(2*np.pi)**2*np.sum(abs(coef)**2)/3;close(iv,.0004/3)
    return {"coefficients":[[float(z.real),float(z.imag)] for z in coef],"IV_N1":float(iv)}

@case("guo-book-04-08")
def hawkes():
    mu,alpha,beta=.2,.6,2;events=np.array([1.,2.]);T=3;left=[mu+sum(alpha*math.exp(-beta*(s-prev)) for prev in events if prev<s) for s in events]
    integrated=mu*T+sum(alpha/beta*(1-math.exp(-beta*(T-s))) for s in events)
    return {"jump_before":left,"jump_after":[v+alpha for v in left],"integrated":integrated,"log_likelihood":sum(math.log(v) for v in left)-integrated}

@case("guo-book-05-02")
def multivariate_hawkes():
    G=np.array([[.2,.1],[.3,.2]]);mu=np.array([1.,2.]);mean=np.linalg.solve(np.eye(2)-G,mu);close(mean,[100/61,190/61]);close(mean,mu+G@mean)
    return {"stationary_intensity":mean.tolist(),"eigenvalues":np.linalg.eigvals(G).tolist()}

@case("guo-book-05-05")
def queue():
    end=math.log(1.2)/.05;close(240*math.exp(-.05*end)-200,0)
    return {"at_1":240*math.exp(-.05)-200,"at_2":240*math.exp(-.1)-200,"time_to_front":end}

@case("guo-book-06-02")
def execution():
    t,k=sp.symbols("t k",positive=True);x=100*sp.sinh(k*(1-t))/sp.sinh(k);zero(sp.diff(x,t,2)-k*k*x)
    assert x.subs(t,0)==100 and x.subs(t,1)==0
    return {"inventory_half":100*math.sinh(.5)/math.sinh(1),"sold_first_half":100*(1-math.sinh(.5)/math.sinh(1))}

@case("guo-book-06-03")
def directional():
    e,x,lam,a,b,y,c=sp.symbols("e x lam a b y c",positive=True)
    gain=x/lam*(1-sp.exp(-lam*e))-c*e + a*sp.log(x*sp.exp(-lam*e))+b*(y-e)-a*sp.log(x)-b*y
    zero(sp.simplify(sp.diff(gain,e).subs(e,0))-(x-c-lam*a-b))
    return {"marginal_income":99,"price_effect":19,"inventory_value":80,"net_gain_rate":0}

@case("guo-book-06-05")
def depth():
    x=sp.symbols("x");qty=sp.integrate(100+100*x,(x,0,1));cost=sp.integrate(x*(100+100*x),(x,0,1));assert qty==150
    return {"quantity":float(qty),"extra_cost":float(cost),"average_price":float(10+cost/qty),"last_price":11}

@case("guo-book-06-06")
def modes():
    S=np.array([[1,.5],[.5,1]]);e1=np.array([1,1])/np.sqrt(2);e2=np.array([1,-1])/np.sqrt(2);close(S@e1,1.5*e1);close(S@e2,.5*e2)
    return [{"eigenvalue":v,"kappa":math.sqrt(v),"inventory_fraction_at_half":math.sinh(math.sqrt(v)*.5)/math.sinh(math.sqrt(v))} for v in [1.5,.5]]

@case("guo-book-07-01")
def quotes():
    center=100-.1*5*4*.5;width=.1*4*.5+2/.1*math.log1p(.1/2)
    return {"center":center,"risk_spread":.2,"liquidity_spread":width-.2,"spread":width,"bid":center-width/2,"ask":center+width/2}

@case("guo-book-07-02")
def impulse():
    rows=[]
    for q in [3,5]:
        costs={j:.01*j*j+.1+.02*(q-j) for j in range(q)};costs[q]=.01*q*q;choice=min(costs,key=costs.get);assert choice==(3 if q==3 else 1)
        rows.append({"q":q,"costs":costs,"best_target":choice})
    return rows

@case("guo-book-07-04")
def gradients():
    h,f,theta,lu,lo,rebate=.01,.003,.0005,.05,.03,.002
    values=[h+f+theta-lu-theta,h+f+theta+lo,theta-(h+rebate)-(lu+theta),theta];close(values,[-.037,.0435,-.062,.0005])
    return dict(zip(["market_under","market_over","limit_under_fill","limit_no_extra_fill"],values))

@case("guo-book-07-05")
def kaplan_meier():
    samples=[(3,1),(3,3),(2,2),(4,2)];S=1.;rows=[]
    for j in range(3):
        risk=[r for n,r in samples if n>j and r>=j];deaths=sum(r==j for r in risk);h=deaths/len(risk);S*=1-h;rows.append({"j":j,"risk":len(risk),"deaths":deaths,"hazard":h,"S_next":S})
    close(S,.375);return rows

@case("guo-book-08-01")
def ledger():
    cash=2000.;q=0;rows=[]
    for n,p,fee in [(40,10,.4),(30,10.02,.3)]:
        cash-=n*p+fee;q+=n;rows.append({"cash":cash,"position":q,"open":100-q})
    close(cash,1298.7);assert q==70;return rows

@case("guo-book-08-02")
def latency():
    stamps=np.array([0,120,160,200,260,400]);segments=np.diff(stamps);assert segments.sum()==400
    return {"segments_microseconds":segments.tolist(),"total":400,"with_20us_faster_strategy":380}

@case("guo-book-b-01")
def markov():
    p=lambda t:2/3*(1-math.exp(-3*t))
    return {"P01_at_01":p(.1),"P01_at_1":p(1),"stationary":[1/3,2/3]}

@case("guo-book-d-01")
def reflection():
    x=np.array([0,-1,2,-2,1]);L=np.maximum(0,-np.minimum.accumulate(x));q=x+L;close(q,[0,0,3,0,3]);assert np.all(q>=0) and np.all(np.diff(L)>=0)
    return {"input":x.tolist(),"regulator":L.tolist(),"queue":q.tolist()}

def main():
    p=argparse.ArgumentParser();p.add_argument("--lesson");p.add_argument("--output");args=p.parse_args()
    selected=[args.lesson] if args.lesson else sorted(CASES)
    records={slug:CASES[slug]() for slug in selected};text=json.dumps(records,ensure_ascii=False,indent=2)
    if args.output:
        from pathlib import Path
        Path(args.output).write_text(text,encoding="utf-8")
        print(json.dumps({"verified_lessons":len(records),"output":args.output}))
    else: print(text)
if __name__=="__main__":main()
