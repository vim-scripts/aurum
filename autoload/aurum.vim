"▶1 
scriptencoding utf-8
execute frawor#Setup('0.1', {'@%aurum/repo': '5.0',
            \                '@aurum/cache': '2.0',
            \            '@%aurum/cmdutils': '4.0',})
"▶1 getcrf
function s:F.id(val)
    return a:val
endfunction
function s:F.getcrf()
    let cbvar=s:_r.cache.getcbvar()
    if has_key(cbvar, '__relfname') && has_key(cbvar, 'repo') &&
                \localtime()-cbvar._timerepo<cbvar._maxtimerepo
        return [cbvar, cbvar.repo, cbvar.__relfname]
    endif
    try
        silent let [repo, rev, file]=s:_r.cmdutils.getrrf({'repo': ':'}, 0,
                    \                                     'getsilent')[1:]
    catch /^Frawor:[^:]\+:nrepo:/
        return [cbvar, 0, 0]
    endtry
    if repo isnot 0 && file isnot 0
        call s:_r.cache.get('repo', s:F.id, [repo], {})
        let cbvar.__relfname=file
    endif
    return [cbvar, repo, file]
endfunction
"▶1 aurum#repository
function aurum#repository()
    let repo=s:_r.cache.get('repo', s:_r.repo.get, [':'], {})
    if repo is 0
        return {}
    endif
    return repo
endfunction
let s:_functions+=['aurum#repository']
"▶1 aurum#changeset
function aurum#changeset(...)
    let repo=((a:0)?(a:1):(aurum#repository()))
    if empty(repo)
        return {}
    endif
    return s:_r.cache.get('cs', repo.functions.getwork, [repo], {})
endfunction
let s:_functions+=['aurum#changeset']
"▶1 aurum#status
function aurum#status(...)
    if !empty(&buftype)
        return ''
    endif
    let [cbvar, repo, file]=s:F.getcrf()
    if repo is 0 || file is 0
        return ''
    endif
    augroup AuInvalidateStatusCache
        autocmd! BufWritePost <buffer> :call s:_r.cache.del('status')
    augroup END
    return get(keys(filter(copy(s:_r.cache.get('status', repo.functions.status,
                \                              [repo, 0, 0, [file], 1, 1], {})),
                \          'index(v:val, file)!=-1')), 0, '')
endfunction
let s:_functions+=['aurum#status']
let s:_augroups+=['AuInvalidateStatusCache']
"▶1 aurum#branch
function aurum#branch(...)
    let repo=((a:0)?(a:1):(aurum#repository()))
    if empty(repo)
        return ''
    endif
    return s:_r.cache.get('branch', repo.functions.getrepoprop,
                \         [repo, 'branch'], {})
endfunction
let s:_functions+=['aurum#branch']
"▶1
call frawor#Lockvar(s:, '_pluginloaded,_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
