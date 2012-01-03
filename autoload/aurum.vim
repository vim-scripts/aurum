"▶1 
execute frawor#Setup('0.0', {'@aurum/repo': '1.0',
            \               '@aurum/cache': '0.0',})
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
    let repo=((a:0)?(a:1):(aurum#repository()))
    if empty(repo)
        return {}
    endif
    return get(keys(filter(copy(s:_r.cache.get('status', repo.functions.status,
                \                              [repo, 0, 0,
                \                               [repo.functions.reltorepo(repo,
                \                                                         @%)]],
                \                              {})),
                \          '!empty(v:val)')), 0, 0)
endfunction
let s:_functions+=['aurum#status']
"▶1
call frawor#Lockvar(s:, '_pluginloaded,_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
