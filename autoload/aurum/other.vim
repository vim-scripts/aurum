scriptencoding utf-8
execute frawor#Setup('0.0', {'@aurum': '1.0',
            \      '@%aurum/cmdutils': '4.0',
            \                  '@/os': '0.0',})
function s:cmd.function(bang, action, rev, url, repopath)
    let repo=s:_r.cmdutils.checkedgetrepo(a:repopath)
    if a:url isnot# ':' && stridx(a:url, '://')==-1 && isdirectory(a:url)
        let url=s:_r.os.path.realpath(a:url)
    else
        let url=a:url
    endif
    let key=((index(s:_r.otheractions.push, a:action)==-1)?('pull'):('push'))
    return repo.functions[key](repo, (a:action[0] isnot# 'p'), a:bang,
                \              ((  url is# ':')?(0):(  url)),
                \              ((a:rev is# ':')?(0):(a:rev)))
endfunction
"▶1
call frawor#Lockvar(s:, '')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
