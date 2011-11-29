"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/resources': '0.0',
                \                  '@/options': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
let s:_options={
            \'cscachetime':     {'default': 3, 'checker': 'range 0 inf'},
            \'statuscachetime': {'default': 5, 'checker': 'range 0 inf'},
            \'repocachetime':   {'default': 7, 'checker': 'range 0 inf'},
        \}
let s:cachebvars={}
"▶1 bufwipeout
function s:F.bufwipeout()
    let buf=+expand('<abuf>')
    if has_key(s:cachebvars, buf)
        unlet s:cachebvars[buf]
    endif
endfunction
augroup AurumCacheBufVars
    autocmd BufWipeOut * :call s:F.bufwipeout()
augroup END
let s:_augroups+=['AurumCacheBufVars']
"▶1 getcachedval :: key, func, args, dict → val + cbvar
function s:F.getcachedval(key, Func, args, dict)
    let buf=bufnr('%')
    if !has_key(s:cachebvars, buf)
        let s:cachebvars[buf]={}
    endif
    let cbvar=s:cachebvars[buf]
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
"▶1 Post cache resource
call s:_f.postresource('cache', {'get': s:F.getcachedval})
"▶1
call frawor#Lockvar(s:, '_pluginloaded,cachebvars')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
