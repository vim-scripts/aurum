"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('1.3', {'@/resources': '0.0',
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
            \    'nrm': 'Failed to remove file %s from repository %s',
            \  'iname': 'Error while registering driver for plugin %s: '.
            \           'invalid name: it must be a non-empty sting, '.
            \           'containing only latin letters, digits and underscores',
            \   'nimp': 'Function %s was not implemented in driver %s',
            \  'tgtex': 'Target already exists: %s',
            \ 'cpfail': 'Failed to copy %s to %s: %s',
            \ 'wrfail': 'Failed to write copy of %s to %s',
        \}
call extend(s:_messages, map({
            \   'dreg': 'driver was already registered by plugin %s',
            \  'fndct': 'second argument is not a dictionary',
            \   'fmis': 'some required functions are missing',
            \   'nfun': 'some of dictionary values are not '.
            \           'callable function references',
        \}, '"Error while registering driver %s for plugin %s: ".v:val'))
let s:deffuncs={}
"▶1 setlines :: [String], read::Bool → + buffer
function s:F.setlines(lines, read)
    let d={'set': function((a:read)?('append'):('setline'))}
    if len(a:lines)>1 && empty(a:lines[-1])
        call d.set('.', a:lines[:-2])
    else
        if !a:read
            setlocal binary noendofline
        endif
        call d.set('.', a:lines)
    endif
endfunction
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
"▶1 reltorepo :: repo, path → rpath
function s:deffuncs.reltorepo(repo, path)
    return join(s:_r.os.path.split(s:_r.os.path.relpath(a:path,
                \                                       a:repo.path))[1:], '/')
endfunction
"▶1 getcsprop :: repo, Either cs rev, propname → a
function s:deffuncs.getcsprop(repo, csr, propname)
    if type(a:csr)==type({})
        let cs=a:csr
    else
        let cs=a:repo.functions.getcs(a:repo, a:csr)
    endif
    if has_key(cs, a:propname)
        return cs[a:propname]
    endif
    call a:repo.functions.setcsprop(a:repo, cs, a:propname)
    " XXX There is much code relying on the fact that after getcsprop property 
    " with given name is added to changeset dictionary
    return cs[a:propname]
endfunction
"▶1 revrange :: repo, rev, rev → [cs]
function s:F.getrev(repo, rev, cslist)
    if type(a:rev)==type(0)
        if a:rev<0
            return len(a:cslist)+a:rev
        else
            return a:rev
        endif
    else
        return a:repo.functions.getcs(a:repo, a:rev).rev
    endif
endfunction
function s:deffuncs.revrange(repo, rev1, rev2)
    if empty(a:repo.cslist)
        let cslist=a:repo.functions.getchangesets(a:repo)
    else
        let cslist=a:repo.cslist
    endif
    let rev1=s:F.getrev(a:repo, a:rev1, cslist)
    let rev2=s:F.getrev(a:repo, a:rev2, cslist)
    if rev1>rev2
        let [rev1, rev2]=[rev2, rev1]
    endif
    return cslist[(rev1):(rev2)]
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
"▶1 diffname :: _, line, diffre, _ → rpath
function s:deffuncs.diffname(repo, line, diffre, opts)
    return get(matchlist(a:line, a:diffre), 1, 0)
endfunction
"▶1 getstats :: _, diff, diffopts → stats
" stats :: { ( "insertions" | "deletions" ): UInt,
"            "files": { ( "insertions" | "deletions" ): UInt } }
function s:deffuncs.getstats(repo, diff, opts)
    let diffre=a:repo.functions.diffre(a:repo, a:opts)
    let i=0
    let llines=len(a:diff)
    let stats={'files': {}, 'insertions': 0, 'deletions': 0}
    let file=0
    while i<llines
        let line=a:diff[i]
        if line[:3] is# 'diff'
            let file=a:repo.functions.diffname(a:repo, line, diffre, a:opts)
            if file isnot 0
                let stats.files[file]={'insertions': 0, 'deletions': 0,}
                let i+=1
                let oldi=i
                let pmlines=2
                while pmlines && i<llines
                    let lstart=a:diff[i][:2]
                    if lstart is# '+++' || lstart is# '---'
                        let pmlines-=1
                    endif
                    let i+=1
                    if i-oldi>=4
                        let i=oldi
                        break
                    endif
                endwhile
                continue
            endif
        elseif file is 0
        elseif line[0] is# '+'
            let stats.insertions+=1
            let stats.files[file].insertions+=1
        elseif line[0] is# '-'
            let stats.deletions+=1
            let stats.files[file].deletions+=1
        endif
        let i+=1
    endwhile
    return stats
endfunction
"▶1 copy
function s:deffuncs.copy(repo, force, source, target)
    let src=s:_r.os.path.normpath(s:_r.os.path.join(a:repo.path, a:source))
    let tgt=s:_r.os.path.normpath(s:_r.os.path.join(a:repo.path, a:target))
    if filewritable(tgt)==1
        if a:force
            call delete(tgt)
        else
            call s:_f.throw('tgtex', tgt)
        endif
    elseif s:_r.os.path.exists(tgt)
        " Don’t try to delete directories and non-writable files.
        call s:_f.throw('tgtex', tgt)
    endif
    let cmd=0
    if executable('cp')
        let cmd='cp --'
    elseif executable('copy')
        let cmd='copy'
    endif
    if cmd is 0
        try
            if writefile(readfile(src, 'b'), tgt, 'b')!=0
                call s:_f.throw('wrfail', src, tgt)
            endif
        endtry
    else
        let hasnls=(stridx(src.tgt, "\n")==-1)
        let cmd.=' '.shellescape(src, hasnls).' '.shellescape(tgt, hasnls)
        if hasnls
            let shout=system(cmd)
        else
            noautocmd tabnew
            noautocmd setlocal buftype=nofile
            noautocmd execute 'silent! %!'.cmd
            let shout=join(getline(1, '$'), "\n")
            noautocmd tabclose
        endif
        if v:shell_error
            call s:_f.throw('cpfail', src, tgt, shout)
        endif
    endif
    call a:repo.functions.add(a:repo, tgt)
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
    let repo.functions=copy(driver.functions)
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
call s:_f.postresource('setlines', s:F.setlines)
"▶1 regdriver feature
let s:requiredfuncs=['repo', 'getcs', 'checkdir']
let s:optfuncs=['readfile', 'annotate', 'diff', 'status', 'commit', 'update',
            \   'dirty', 'diffre', 'getrepoprop', 'forget', 'branch', 'label']
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
    for funname in filter(copy(s:optfuncs), '!has_key(driver.functions, v:val)')
        execute      "function driver.functions.".funname."(...)\n".
                    \"    call s:_f.throw('nimp', '".funname."', ".
                    \                    "'".a:name."')\n".
                    \"endfunction"
    endfor
    lockvar! driver
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
