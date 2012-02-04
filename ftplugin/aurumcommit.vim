"▶1 
scriptencoding utf-8
setlocal textwidth=80
setlocal nonumber
if exists('+relativenumber')
    setlocal norelativenumber
endif
setlocal noswapfile
setlocal nomodeline
execute frawor#Setup('0.0', {'@aurum/bufvars': '0.0',
            \                    '@/mappings': '0.0',
            \                 '@aurum/commit': '1.0',})
"▶1 com.runcommap
function s:F.runcommap(action)
    let buf=bufnr('%')
    let bvar=s:_r.bufvars[buf]
    if a:action is# 'commit'
        call s:_r.commit.finish(bvar)
    elseif a:action is# 'discard'
        bwipeout!
        stopinsert
    endif
    if has_key(bvar, 'sbvar')
        call bvar.sbvar.recunload(bvar.sbvar)
    endif
endfunction
"▶1 AuCommitMessage mapping group
function s:F.gm(...)
    return '<C-\><C-n>'.
                \':call call(<SID>Eval("s:F.runcommap"), '.string(a:000).', '.
                \           '{})<CR>'
endfunction
call s:_f.mapgroup.add('AuCommitMessage', {
            \ 'Commit': {'lhs': 'i', 'rhs': s:F.gm('commit') },
            \   'Exit': {'lhs': 'X', 'rhs': s:F.gm('discard')},
        \}, {'mode': 'in', 'silent': 1, 'leader': '<LocalLeader>'})
"▶1
call frawor#Lockvar(s:, '_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
