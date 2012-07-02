scriptencoding utf-8
execute frawor#Setup('0.0', {'@aurum': '1.0',
            \      '@%aurum/cmdutils': '3.0',})
let s:_messages={
            \ 'bexsts': 'Error while creating branch %s for repository %s: '.
            \           'branch already exists',
        \}
function s:cmd.function(bang, branch, opts)
    let repo=s:_r.cmdutils.checkedgetrepo(a:opts.repo)
    let force=a:bang
    if !force && index(repo.functions.getrepoprop(repo, 'brancheslist'),
                \      a:branch)!=-1
        call s:_f.throw('bexsts', a:branch, repo.path)
    endif
    call repo.functions.branch(repo, a:branch, force)
endfunction
"▶1
call frawor#Lockvar(s:, '')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
