"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/resources': '0.0',
                \                       '@/os': '0.0',
                \                  '@/options': '0.0',
                \   '@aurum/drivers/mercurial': '0.0',
                \             '@aurum/bufvars': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
let s:drivers={'mercurial': s:_r.mercurial}
let s:_options={
            \'diffopts':  {'default': {},
            \              'checker': 'dict {numlines         range 0 inf '.
            \                               '?in diffoptslst  bool}'},
        \}
" XXX Some code relies on the fact that all options from s:diffoptslst are
"     numeric
let s:diffoptslst=['git', 'reverse', 'ignorews', 'iwsamount', 'iblanks',
            \      'numlines', 'showfunc', 'alltext', 'dates']
let s:diffoptsstr=join(map(copy(s:diffoptslst),
            \          'v:val is# "numlines" ? '.
            \               '" ?".v:val." range 0 inf" : '.
            \               '"!?".v:val'))
let s:repos={}
"▶1 dirty :: repo, file → Bool
function s:F.dirty(repo, file)
    let status=a:repo.functions.status(a:repo, 0, 0, [a:file])
    for [type, files] in items(status)
        if type is# 'ignored' || type is# 'clean'
            continue
        endif
        if index(files, a:file)!=-1
            return 1
        endif
    endfor
    return 0
endfunction
"▶1 getnthparent :: repo, rev, n → cs
function s:F.getnthparent(repo, rev, n)
    let r=a:repo.functions.getcs(a:repo, a:rev)
    let key=((a:n>0)?('parents'):('children'))
    for i in range(1, abs(a:n))
        let rl=a:repo.functions.getcsprop(a:repo, r, key)
        if empty(rl)
            break
        endif
        let r=a:repo.functions.getcs(a:repo, rl[0])
    endfor
    return r
endfunction
"▶1 reltorepo :: repo, path → rpath
function s:F.reltorepo(repo, path)
    return join(s:_r.os.path.split(s:_r.os.path.relpath(a:path,
                \                                       a:repo.path))[1:], '/')
endfunction
"▶1 difftobuffer
function s:F.difftobuffer(repo, buf, ...)
    let diff=call(a:repo.functions.diff, [a:repo]+a:000, {})
    let oldbuf=bufnr('%')
    if oldbuf!=a:buf
        execute 'buffer' a:buf
    endif
    call s:F.setlines(diff, 0)
    if oldbuf!=a:buf
        execute 'buffer' oldbuf
    endif
endfunction
"▶1 repotype :: path → Maybe String
function s:F.repotype(path)
    if a:path=~#'\v^\w+%(\+\w+)*\V://' ||
                \s:_r.os.path.isdir(s:_r.os.path.join(a:path, '.hg'))
        return 'mercurial'
    endif
    return 0
endfunction
"▶1 getrepo :: path → repo
function s:F.getrepo(path)
    if empty(a:path)
        let path=s:_r.os.path.realpath('.')
    elseif a:path is# ':'
        let buf=bufnr('%')
        if has_key(s:_r.bufvars, buf) && has_key(s:_r.bufvars[buf], 'repo')
            let path=s:_r.bufvars[buf].repo.path
        elseif has_key(s:_r.bufvars,buf) && s:_r.bufvars[buf].command is# 'copy'
            let path=s:_r.os.path.dirname(
                        \s:_r.os.path.realpath(s:_r.bufvars[buf].file))
        elseif empty(&buftype) && isdirectory(expand('%:p:h'))
            let path=s:_r.os.path.realpath(expand('%:p:h'))
        else
            let path=s:_r.os.path.realpath('.')
        endif
    elseif stridx(a:path, '://')==-1
        let path=s:_r.os.path.realpath(a:path)
    else
        let path=a:path
    endif
    if stridx(path, '://')==-1
        let olddir=''
        while path isnot# olddir && s:F.repotype(path) is 0
            let olddir=path
            let path=fnamemodify(path, ':h')
        endwhile
    endif
    if has_key(s:repos, path)
        let repo=s:repos[path]
        if !empty(repo.cslist)
            call repo.functions.updatechangesets(repo)
        endif
        return repo
    endif
    let repotype=s:F.repotype(path)
    if repotype is 0
        return 0
    endif
    let repo=s:drivers[repotype].repo(path)
    if repo is 0
        return 0
    endif
    let repo.type=repotype
    let repo.path=path
    if !has_key(repo, 'functions')
        let repo.functions=copy(s:drivers[repotype])
    endif
    if !has_key(repo.functions, 'difftobuffer')
        let repo.functions.difftobuffer=s:F.difftobuffer
    endif
    if !has_key(repo.functions, 'reltorepo')
        let repo.functions.reltorepo=s:F.reltorepo
    endif
    if !has_key(repo.functions, 'dirty')
        let repo.functions.dirty=s:F.dirty
    endif
    if !has_key(repo.functions, 'getnthparent')
        let repo.functions.getnthparent=s:F.getnthparent
    endif
    let repo.diffopts=copy(s:_f.getoption('diffopts'))
    lockvar! repo
    unlockvar! repo.cslist
    unlockvar! repo.changesets
    unlockvar 1 repo
    return repo
endfunction
"▶1 update
function s:F.update(repo, rev, count)
    let rev=a:rev
    if a:count>1
        let rev=a:repo.functions.getnthparent(a:repo, rev, a:count-1).hex
    endif
    return a:repo.functions.update(a:repo, rev, 0)
endfunction
"▶1 Post resource
call s:_f.postresource('repo', {'get': s:F.getrepo,
            \                'update': s:F.update,
            \           'diffoptslst': s:diffoptslst,
            \           'diffoptsstr': s:diffoptsstr,})
"▶1
call frawor#Lockvar(s:, '_pluginloaded,_r,repos')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
