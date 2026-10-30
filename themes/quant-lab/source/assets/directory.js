'use strict';
(() => {
 const L=window.QuantLab,esc=L.esc;
 const D=window.FoamDirectory={nodes:[],available:false};
 const directoryIndexes=new WeakMap();
 function indexFor(nodes=D.nodes){
  let index=directoryIndexes.get(nodes);if(index)return index;
  const byId=new Map(nodes.map(n=>[n.id,n])),children=new Map();
  for(const n of nodes){const parent=n.parent_id||null;if(!children.has(parent))children.set(parent,[]);children.get(parent).push(n.id);}
  for(const list of children.values())list.sort((a,b)=>(byId.get(a).sort_order||0)-(byId.get(b).sort_order||0)||String(byId.get(a).name||'').localeCompare(String(byId.get(b).name||'')));
  index={byId,children,descendants:new Map(),ancestors:new Map()};directoryIndexes.set(nodes,index);return index;
 }
 D.get=id=>indexFor().byId.get(id);
 D.children=id=>(indexFor().children.get(id||null)||[]).map(D.get);
 // Flatten the same sibling lists used by the sidebar, keeping each branch
 // together instead of interleaving unrelated nodes by their numeric order.
 D.orderedNodes=(rootId=null)=>{
  const result=[],seen=new Set();
  const visit=node=>{if(!node||seen.has(node.id))return;seen.add(node.id);result.push(node);D.children(node.id).forEach(visit);};
  if(rootId)visit(D.get(rootId));
  else{D.children(null).forEach(visit);D.nodes.forEach(visit);}
  return result;
 };
 D.descendants=(id,nodes=D.nodes)=>{
  const index=indexFor(nodes);
  if(!index.descendants.has(id)){const seen=new Set([id]),queue=[id];for(let i=0;i<queue.length;i++)for(const child of index.children.get(queue[i])||[])if(!seen.has(child)){seen.add(child);queue.push(child);}index.descendants.set(id,queue);}
  return [...index.descendants.get(id)];
 };
 D.ancestors=id=>{const index=indexFor();if(!index.ancestors.has(id)){const out=[],seen=new Set();for(let n=D.get(id);n&&!seen.has(n.id);n=D.get(n.parent_id)){seen.add(n.id);out.unshift(n);}index.ancestors.set(id,out);}return [...index.ancestors.get(id)];};
 D.path=id=>D.ancestors(id).map(n=>n.name).join(' / ');
 D.isVisible=n=>D.ancestors(n.id).every(x=>x.visible);
 // A database array is an unordered set of placements. Prefer the programming
 // module for its lessons, even when they are also referenced by a physics topic.
 D.primary=item=>(item?.section_ids||[]).map(D.get).find(n=>n&&D.isVisible(n));
 D.url=n=>{if(n?.href&&!n.href.startsWith('/read/?')&&!(n.key==='programming-examples'&&n.href.startsWith('/programming/?'))){try{const u=new URL(n.href,location.origin);if(u.origin===location.origin)return u.pathname+u.search+u.hash;}catch{}}return '/section/?id='+encodeURIComponent(n.id);};
 D.locations=row=>(row.section_ids||[]).map(D.path).filter(Boolean);
 D.optionLabel=node=>{const depth=Math.max(0,D.ancestors(node.id).length-1);return '　'.repeat(Math.min(depth,8))+(depth?'↳ ':'')+D.path(node.id);};
 D.option=(node,selected='')=>'<option value="'+esc(node.id)+'" title="'+esc(D.path(node.id))+'" '+(node.id===selected?'selected':'')+'>'+esc(D.optionLabel(node))+'</option>';
 D.options=(selected='',exclude=[],rootId=null)=>(rootId?'':'<option value="">顶层模块</option>')+D.orderedNodes(rootId).filter(n=>!exclude.includes(n.id)).map(n=>D.option(n,selected)).join('');
 D.current=(nodes=D.nodes)=>{const u=new URL(location.href),id=u.searchParams.get('id');if(u.pathname==='/section/')return nodes.find(n=>n.id===id);return nodes.filter(n=>n.href&&n.href!=='/admin/'&&(()=>{const v=new URL(n.href,location.origin);return v.pathname===u.pathname&&(!v.hash||v.hash===u.hash)&&[...v.searchParams].every(([k,x])=>u.searchParams.get(k)===x);})()).sort((a,b)=>(new URL(b.href,location.origin).search+new URL(b.href,location.origin).hash).length-(new URL(a.href,location.origin).search+new URL(a.href,location.origin).hash).length)[0];};

 D.ready=Promise.all([fetch('/assets/navigation-data.json').then(r=>r.json()),fetch('/assets/catalog.json').then(r=>r.json())]).then(([nodes,rows])=>{D.nodes=nodes;D.rows=rows;D.available=true;return D;}).catch(()=>D);
 D.content=async node=>{await D.ready;const ids=new Set(D.descendants(node.id));return D.rows.filter(r=>(r.section_ids||[]).some(id=>ids.has(id)));};
 document.dispatchEvent(new Event('foamlab:directory-init'));
})();
