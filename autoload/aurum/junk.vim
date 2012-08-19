scriptencoding utf-8
execute frawor#Setup('0.0', {'@aurum': '1.0',
            \      '@%aurum/cmdutils': '4.0',})
let s:_messages={
            \'nofiles': 'No files were specified',
        \}
function s:cmd.function(opts, ...)
    if !a:0
        call s:_f.throw('nofiles')
    endif
    let repo=s:_r.cmdutils.checkedgetrepo(a:1)
    let forget=get(a:opts, 'forget',      0)
    let ignore=get(a:opts, 'ignore',      0)
    let igglob=get(a:opts, 'ignoreglobs', 0)
    let remove=get(a:opts, 'remove',      !(forget || ignore || igglob))
    let allfiles=s:_r.cmdutils.getexsttrckdfiles(repo, ignore)
    let globs=filter(copy(a:000), 'v:val isnot# ":"')
    let hascur=(len(globs)!=a:0)
    let files=s:_r.cmdutils.filterfiles(repo, globs, allfiles)
    if hascur
        let rrfopts={'repo': repo.path}
        let files+=[repo.functions.reltorepo(repo,
                    \s:_r.cmdutils.getrrf(rrfopts, 'nocurf', 'getfile')[3])]
    endif
    for key in filter(['forget', 'remove', 'ignore'], 'eval(v:val)')
        call map(copy(files), 'repo.functions[key](repo, v:val)')
    endfor
    if igglob
        call map(copy(globs), 'repo.functions.ignoreglob(repo, '.
                    \         'repo.functions.reltorepo(repo, v:val))')
    endif
endfunction
"▶1
call frawor#Lockvar(s:, '')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
