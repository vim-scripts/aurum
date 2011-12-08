"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('1.0', {'@/resources': '0.0',
                \                       '@/os': '0.0',
                \                  '@/options': '0.0',
                \             '@aurum/bufvars': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
let s:drivers={}
let s:repos={}
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
let s:_messages={
            \  'nrm': 'Failed to remove file %s from repository %s',
            \'iname': 'Error while registering driver for plugin %s: '.
            \         'invalid name: it must be a non-empty sting, '.
            \         'containing only latin letters, digits and underscores',
            \ 'nimp': 'Function %s was not implemented in driver %s',
            \'uprop': 'Unable to obtain property %s from changeset %s '.
            \         'in repository %s',
        \}
call extend(s:_messages, map({
            \ 'dreg': 'driver was already registered by plugin %s',
            \'fndct': 'second argument is not a dictionary',
            \ 'fmis': 'some required functions are missing',
            \ 'nfun': 'some of dictionary values are not '.
            \         'callable function references',
        \}, '"Error while registering driver %s for plugin %s: ".v:val'))
let s:deffuncs={}
"▶1 dirty :: repo, file → Bool
function s:deffuncs.dirty(repo, file)
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
function s:deffuncs.getnthparent(repo, rev, n)
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
"▶1 getcsprop :: repo, cs|rev, prop → prop
function s:deffuncs.getcsprop(repo, cs, prop)
    if type(a:cs)!=type({})
        let cs=a:repo.functions.getcs(a:repo, a:cs)
    else
        let cs=a:cs
    endif
    if has_key(cs, a:prop)
        return cs[a:prop]
    else
        call s:_f.throw('uprop', a:prop, a:cs.hex, a:repo.path)
    endif
endfunction
"▶1 reltorepo :: repo, path → rpath
function s:deffuncs.reltorepo(repo, path)
    return join(s:_r.os.path.split(s:_r.os.path.relpath(a:path,
                \                                       a:repo.path))[1:], '/')
endfunction
"▶1 difftobuffer
function s:deffuncs.difftobuffer(repo, buf, ...)
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
"▶1 move
function s:deffuncs.move(repo, force, source, target)
    call a:repo.functions.copy(a:repo, a:force, a:source, a:target)
    call a:repo.functions.remove(a:repo, a:source)
endfunction
"▶1 remove
function s:deffuncs.remove(repo, file)
    call a:repo.functions.forget(a:repo, a:file)
    let file=s:_r.os.path.join(a:repo.path, a:file)
    if s:_r.os.path.isfile(file)
        if delete(file)
            call s:_f.throw('nrm', a:file, a:repo.path)
        endif
    endif
endfunction
"▶1 checkremote
function s:deffuncs.checkremote(...)
    return 0
endfunction
"▶1 getrevhex
function s:deffuncs.getrevhex(repo, rev)
    return a:rev.''
endfunction
"▶1 getdriver :: path, type → Maybe driver
function s:F.getdriver(path, ptype)
    for driver in values(s:drivers)
        if driver.functions['check'.a:ptype](a:path)
            return driver
        endif
    endfor
    return 0
endfunction
"▶1 getrepo :: path → repo
function s:F.getrepo(path)
    "▶2 Pull in drivers if there are no
    if empty(s:drivers)
        for src in s:_r.os.listdir(s:_r.os.path.join(s:_frawor.runtimepath,
                    \              'plugin', 'aurum', 'drivers'))
            if len(src)<5 || src[-4:] isnot# '.vim'
                continue
            endif
            call FraworLoad('@aurum/drivers/'.src[:-5])
        endfor
    endif
    "▶2 Get path
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
    "▶2 Get driver
    if stridx(path, '://')==-1
        let olddir=''
        let driver=0
        while path isnot# olddir
            unlet driver
            let driver=s:F.getdriver(path, 'dir')
            if driver isnot 0
                break
            endif
            let olddir=path
            let path=fnamemodify(path, ':h')
        endwhile
    else
        let driver=s:F.getdriver(path, 'remote')
    endif
    if driver is 0
        return 0
    endif
    "▲2
    if has_key(s:repos, path)
        let repo=s:repos[path]
        if !empty(repo.cslist)
            call repo.functions.updatechangesets(repo)
        endif
        return repo
    endif
    let repo=driver.functions.repo(path)
    if repo is 0
        return 0
    endif
    let repo.type=driver.id
    let repo.path=path
    if !has_key(repo, 'functions')
        let repo.functions=copy(driver.functions)
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
"▶1 regdriver feature
let s:requiredfuncs=['repo', 'getcs', 'checkdir']
let s:optfuncs=['readfile', 'annotate', 'diff', 'status', 'commit', 'update',
            \   'dirty', 'diffre', 'getstats', 'getrepoprop', 'copy', 'forget']
"▶2 regdriver :: {f}, name, funcs → + s:drivers
function s:F.regdriver(plugdict, fdict, name, funcs)
    "▶3 Check arguments
    if type(a:name)!=type('') || a:name!~#'\v^\w+$'
        call s:_f.throw('iname', a:plugdict.id)
    elseif has_key(s:drivers, a:name)
        call s:_f.throw('dreg', a:name, a:plugdict.id, s:drivers[a:name].plid)
    elseif type(a:funcs)!=type({})
        call s:_f.throw('fndct', a:name, a:plugdic.id)
    elseif !empty(filter(copy(s:requiredfuncs), '!exists("*a:funcs[v:val]")'))
        call s:_f.throw('fmis', a:name, a:plugdict.id)
    elseif !empty(filter(copy(a:funcs), '!exists("*v:val")'))
        call s:_f.throw('nfun', a:name, a:plugdict.id)
    endif
    "▲3
    let driver={'functions': copy(a:funcs)}
    let driver.plid=a:plugdict.id
    let driver.id=a:name
    call extend(driver.functions, s:deffuncs, 'keep')
    for funname in filter(copy(s:optfuncs),
                \         '!exists("*driver.functions[v:val]")')
        execute      "function driver.functions.".funname."(...)\n".
                    \"    call s:_f.throw('nimp', '".funname."', ".
                    \                    "'".a:name."')\n".
                    \"endfunction"
    endfor
    lockvar driver
    let a:fdict[a:name]=driver
    let s:drivers[a:name]=driver
endfunction
"▶2 deldriver :: {f} → + s:drivers
function s:F.deldriver(plugdict, fdict)
    call map(keys(a:fdict), 'remove(s:drivers, v:val)')
endfunction
"▶2 Register feature
call s:_f.newfeature('regdriver', {'cons': s:F.regdriver,
            \                    'unload': s:F.deldriver})
"▶1
call frawor#Lockvar(s:, '_pluginloaded,_r,repos,drivers')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
