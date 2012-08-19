scriptencoding utf-8
execute frawor#Setup('0.0', {'@aurum': '1.0',
            \      '@%aurum/cmdutils': '4.0',})
function s:cmd.function(bang, rev, repopath)
    let repo=s:_r.cmdutils.checkedgetrepo(a:repopath)
    if a:rev is 0
        let rev=repo.functions.gettiphex(repo)
    else
        let rev=repo.functions.getrevhex(repo, a:rev)
    endif
    return repo.functions.update(repo, rev, a:bang)
endfunction
"▶1
call frawor#Lockvar(s:, '')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
