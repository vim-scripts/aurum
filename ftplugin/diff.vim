"▶1 
scriptencoding utf-8
if !has('folding')
    finish
endif
if !exists('s:_sid')
    function s:Eval(expr)
        return eval(a:expr)
    endfunction
    let s:_sid=matchstr(s:Eval('expand("<sfile>")'), '\v\d+')
endif
let &l:foldexpr='<SNR>'.s:_sid.'_FoldExpr()'
let &l:foldtext='<SNR>'.s:_sid.'_FoldText()'
"▶1 foldexpr
function! s:FoldExpr()
    let line=getline(v:lnum)
    let nextline=getline(v:lnum+1)
    if line[:4] is# 'diff '
        return 1
    elseif nextline[:4] is# 'diff '
        return '<1'
    elseif line[:2] is# '@@ '
        return 2
    elseif nextline[:2] is# '@@ '
        return '<2'
    endif
    return '='
endfunction
"▶1 foldtext
function! s:FoldText()
    let line=getline(v:foldstart)
    if v:foldlevel==1
        if line =~# '\v^diff\ a\/(.{-})\ b\/\1'
            return matchlist(line, '\v^diff\ a\/(.{-})\ b\/\1')[1]
        elseif line =~# '\v^diff%(\ \-r\ \x+){1,2}'
            return substitute(line, '\v^diff%(\ \-r\ \x+){1,2}\ ', '', '')
        endif
    elseif v:foldlevel==2
        return substitute(line, '\m^@@[^@]\+@@ ', '', '')
    endif
endfunction
"▶1
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
