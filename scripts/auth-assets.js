'use strict';
const fs=require('node:fs');
const path=require('node:path');
// Keep the browser SDK aligned with the pinned npm dependency at every build.
(() => {
 const source=path.join(hexo.base_dir,'node_modules/@supabase/supabase-js/dist/umd/supabase.js');
 const target=path.join(hexo.base_dir,'themes/quant-lab/source/assets/vendor/supabase.js');
 fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(source,target);
 fs.copyFileSync(path.join(hexo.base_dir,'node_modules/@supabase/supabase-js/LICENSE'),path.join(path.dirname(target),'supabase.LICENSE.txt'));
})();
