"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('2.1', {'@/resources': '0.0',
                \                  '@/options': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
elseif !exists('s:_loading')
    call FraworLoad(s:_frawor.id)
    finish
endif
let s:_options={
            \'branchcachetime': {'default': 2, 'checker': 'range 0 inf'},
            \'cscachetime':     {'default': 3, 'checker': 'range 0 inf'},
            \'statuscachetime': {'default': 5, 'checker': 'range 0 inf'},
            \'repocachetime':   {'default': 7, 'checker': 'range 0 inf'},
        \}
let s:cachebvars={}
let s:r={}
"▶1 bufwipeout
function s:F.bufwipeout()
    let buf=+expand('<abuf>')
    if has_key(s:cachebvars, buf)
        unlet s:cachebvars[buf]
    endif
endfunction
augroup AurumCacheBufVars
    autocmd BufWipeOut,BufFilePost * :call s:F.bufwipeout()
augroup END
let s:_augroups+=['AurumCacheBufVars']
"▶1 r.getcbvar ::  () + buf, cachebvars → cbvar + cachebvars?
function s:r.getcbvar()
    let buf=bufnr('%')
    if !has_key(s:cachebvars, buf)
        let s:cachebvars[buf]={}
    endif
    return s:cachebvars[buf]
endfunction
"▶1 r.get :: key, func, args, dict → val + cbvar
function s:r.get(key, Func, args, dict)
    let cbvar=s:r.getcbvar()
    if !(has_key(cbvar, a:key) &&
                \localtime()-cbvar['_time'.a:key]<cbvar['_maxtime'.a:key])
        let cbvar[a:key]=call(a:Func, a:args, a:dict)
        let cbvar['_time'.a:key]=localtime()
        if !has_key(cbvar, '_maxtime'.a:key)
            let cbvar['_maxtime'.a:key]=s:_f.getoption(a:key.'cachetime')
        endif
    endif
    return cbvar[a:key]
endfunction
"▶1 r.del :: key → + cbvar
function s:r.del(key)
    let buf=bufnr('%')
    if !has_key(s:cachebvars, buf)
        return
    endif
    let cbvar=s:cachebvars[buf]
    if has_key(cbvar, a:key)
        unlet cbvar[a:key]
    endif
endfunction
"▶1 r.wipe :: key → + cachebvars
function s:r.wipe(key)
    " empty() is here only to avoid possible “Using smth as a number” error
    call map(copy(s:cachebvars), 'has_key(v:val,a:key) && '.
                \                                  'empty(remove(v:val,a:key))')
endfunction
"▶1 Post cache resource
call s:_f.postresource('cache', s:r)
"▶1
call frawor#Lockvar(s:, '_pluginloaded,cachebvars')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
