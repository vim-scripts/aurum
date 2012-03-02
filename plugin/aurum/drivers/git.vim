"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.1', {   '@aurum/repo': '3.0',
                \                          '@/os': '0.1',
                \   '@aurum/drivers/common/utils': '0.0',
                \'@aurum/drivers/common/hypsites': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
let s:_messages={
            \   'hexf': 'Failed to obtain hex string for revision %s '.
            \           'in the repository %s: %s',
            \   'logf': 'Failed to list all revisions in the repository %s: %s',
            \  'rlogf': 'Failed to list revisions %s..%s '.
            \           'in the repository %s: %s',
            \    'csf': 'Failed to obtain information about revision %s '.
            \           'in the repository %s: %s',
            \    'cif': 'Failed to commit changes to the repository %s: %s',
            \   'updf': 'Failed to checkout commit %s in the repository %s: %s',
            \    'mvf': 'Failed to move file %s to %s in the repository %s: %s',
            \    'rmf': 'Failed to remove file %s in the repository %s: %s',
            \    'fgf': 'Failed to forget file %s in the repository %s: %s',
            \  'filef': 'Failed to get revision %s of the file %s '.
            \           'from the repository %s: %s',
            \   'annf': 'Failet to annotate revision %s of the file %s '.
            \           'in the repository %s: %s',
            \  'difff': 'Failed to get diff between %s and %s for files %s '.
            \           'in the repository %s: %s',
            \ 'sdifff': 'Failed to get status information '.
            \           'for the repository %s: %s',
            \ 'rdifff': 'Failed to property %s for changeset %s '.
            \           'in the repository %s: %s',
            \    'lsf': 'Failed to list files in the changeset %s '.
            \           'of the repository %s: %s',
            \'statusf': 'Failed to obtain status of the repository %s: %s',
            \    'rlf': 'Failed to list commits in repository %s: %s',
            \    'lbf': 'Failed to create/remove %s %s for revision %s '.
            \           'in the repository %s: %s',
            \'branchf': 'Failed to get list of branches '.
            \           'from the repository %s: %s',
            \  'grepf': 'Failed to search through the repository %s: %s',
            \   'tagf': 'Failed to get list of tags from the repository %s: %s',
            \   'addf': 'Failed to add file %s to the repository %s: %s',
            \ 'cbnimp': 'Git driver is not able to close branch',
            \   'nloc': 'Git driver does not suppport local tags or branches',
            \   'chbf': 'Failed to create branch %s in the repository %s: %s',
            \  'nocfg': 'Failed to get property %s of repository %s',
            \ 'invrng': 'Range %s..%s is invalid for the repository %s, '.
            \           'as well as reverse',
        \}
let s:git={}
"▶1 s:hypsites
let s:hypsites=s:_r.hypsites.git
"▶1 refile :: gitfname → path
function s:F.refile(fname)
    return a:fname[0] is# '"' ? eval(a:fname) : a:fname
endfunction
"▶1 gitcmd :: repo, cmd, args, kwargs, esc → String
function s:F.gitcmd(repo, ...)
    return 'git --git-dir='.  shellescape(a:repo.path.'/.git', a:4).
                \' --work-tree='.shellescape(a:repo.path,         a:4).
                \' '.call(s:_r.utils.getcmd, a:000, {})
endfunction
"▶1 git :: repo, cmd, args, kwargs, has0[, msgid[, marg1[, …]]] → [String] + ?
function s:F.git(repo, cmd, args, kwargs, hasnulls, ...)
    let cmd=s:F.gitcmd(a:repo, a:cmd, a:args, a:kwargs, a:hasnulls)
    let r=s:_r.utils.run(cmd, a:hasnulls, a:repo.path)
    if v:shell_error && a:0
        call call(s:_f.throw, a:000+[a:repo.path, join(r[:-1-(a:hasnulls)],
                    \                                  "\n")], {})
    endif
    return r
endfunction
"▶1 gitm :: {git args} → + :echom
function s:F.gitm(...)
    return s:_r.utils.printm(call(s:F.git, a:000, {}))
endfunction
"▶1 parsecs :: csdata, lstart::UInt → (cs, line::UInt)
" hash-parent hashes-timestamp
"  (refs)
" author name
" author email
" 1-indented commit message
let s:logformat='%h-%H-%P-%at%n%an%n%ae%n%d%n%w(0,1,1)%B'
let s:logkwargs={'format': s:logformat, 'encoding': 'utf-8', 'date-order': 1}
function s:F.parsecs(csdata, lstart)
    let line=a:lstart
    let cs={'branch': 'default'}
    let [rev, hex, parents, time]=split(a:csdata[line], '-', 1) | let line+=1
    let cs.hex=hex
    let cs.parents=split(parents)
    let cs.time=+time
    let cs.rev=rev
    let aname=a:csdata[line]                                    | let line+=1
    let aemail=a:csdata[line]                                   | let line+=1
    let cs.user=aname.' <'.aemail.'>'
    let cs.tags=split(a:csdata[line][2:-2], ', ')               | let line+=1
    let cs.bookmarks=[]
    "▶2 get description
    let description=[]
    let lcsdata=len(a:csdata)
    while line<lcsdata && a:csdata[line][0] is# ' '
        let description+=[a:csdata[line][1:]]
        let line+=1
    endwhile
    let cs.description=join(description, "\n")
    if empty(get(a:csdata, line, 0))
        let line+=1
    endif
    "▲2
    return [cs, line]
endfunction
"▶1 git.getcs :: repo, rev → cs
function s:git.getcs(repo, rev)
    let cs=s:F.parsecs(s:F.git(a:repo, 'log', ['-n1', a:rev], s:logkwargs,
                \              0, 'csf', a:rev),
                \      0)[0]
    " XXX This construct is used to preserve information like “allfiles” etc
    let a:repo.changesets[cs.hex]=extend(get(a:repo.changesets, cs.hex, {}), cs)
    return a:repo.changesets[cs.hex]
endfunction
"▶1 git.getwork :: repo → cs
function s:git.getwork(repo)
    return a:repo.functions.getcs(a:repo, 'HEAD')
endfunction
"▶1 git.getchangesets :: repo → []
function s:git.getchangesets(repo, ...)
    "▶2 Prepare s:F.git arguments
    let args=[]
    let kwargs=copy(s:logkwargs)
    if a:0
        let args+=[a:1.'^..'.a:2]
    else
        let kwargs.all=1
        let kwargs['full-history']=1
    endif
    let gitargs=[a:repo, 'log', args, kwargs, 0]
    if a:0
        let gitargs+=['rlogf', a:1, a:2]
    else
        let gitargs+=['logf']
    endif
    "▲2
    let log=call(s:F.git, gitargs, {})[:-2]
    "▶2 If log has shown nothing, try reversing range
    if a:0 && empty(log)
        let args[0]=a:2.'..'.a:1
        let gitargs[-1]=a:1
        let gitargs[-2]=a:2
        let log=call(s:F.git, gitargs, {})[:-2]
        if empty(log)
            call s:_f.throw('invrng', a:1, a:2, a:repo.path)
        endif
    endif
    "▶2 Parse changeset information
    let i=0
    let llog=len(log)
    let cslist=[]
    while i<llog
        let [cs, i]=s:F.parsecs(log, i)
        let a:repo.changesets[cs.hex]=extend(get(a:repo.changesets, cs.hex, {}),
                    \                        cs)
        call insert(cslist, a:repo.changesets[cs.hex])
    endwhile
    "▲2
    return cslist
endfunction
"▶1 git.revrange :: repo, rev1, rev2 → [cs]
let s:git.revrange=s:git.getchangesets
"▶1 git.updatechangesets :: repo → _
let s:git.updatechangesets=s:git.getchangesets
"▶1 git.getrevhex :: repo, rev → hex
let s:prevrevhex={}
function s:git.getrevhex(repo, rev)
    if a:rev=~#'\v^[0-9a-f]{40}$'
        if has_key(s:prevrevhex, a:repo.path)
            unlet s:prevrevhex[a:repo.path]
        endif
        return a:rev
    endif
    let r=s:F.git(a:repo, 'rev-parse', [a:rev], {}, 0, 'hexf', a:rev)[0]
    let s:prevrevhex[a:repo.path]=[a:rev, r]
    return r
endfunction
"▶1 git.gettiphex
" XXX Uses master or working directory revision instead of latest revision
function s:git.gettiphex(repo)
    try
        return a:repo.functions.getrevhex(a:repo, 'master')
    catch
        return a:repo.functions.gettiphex(a:repo)
    endtry
endfunction
"▶1 git.getworkhex :: repo → hex
function s:git.getworkhex(repo)
    return a:repo.functions.getrevhex(a:repo, 'HEAD')
endfunction
"▶1 git.setcsprop :: repo, cs, propname → propvalue
function s:git.setcsprop(repo, cs, prop)
    if a:prop is# 'allfiles'
        let r=map(s:F.git(a:repo, 'ls-tree', ['--', a:cs.hex],
                    \                        {'name-only': 1, 'r': 1}, 0,
                    \     'lsf', a:cs.hex)[:-2], 's:F.refile(v:val)')
    elseif a:prop is# 'children'
        let lines=filter(map(s:F.git(a:repo, 'rev-list', [], {'all': 1,
                    \                                'full-history': 1,
                    \                                    'children': 1}, 0,
                    \                'rlf')[:-2],
                    \        'split(v:val)'),
                    \    'has_key(a:repo.changesets, v:val[0])')
        for [hex; children] in lines
            let a:repo.changesets[hex].children=children
        endfor
        return a:cs.children
    elseif       a:prop is# 'renames' || a:prop is# 'copies' ||
                \a:prop is# 'changes' || a:prop is# 'files'  ||
                \a:prop is# 'removes'
        let lparents=len(a:cs.parents)
        if lparents==0
            let allfiles=a:repo.functions.getcsprop(a:repo, a:cs, 'allfiles')
            let a:cs.renames={}
            let a:cs.copies={}
            let a:cs.changes=copy(allfiles)
            let a:cs.files=copy(a:cs.changes)
            let a:cs.removes=[]
        elseif lparents==1
            let args=[a:cs.parents[0].'..'.a:cs.hex]
            let kwargs={'name-status': 1, 'M': 1, 'diff-filter': 'ADMR'}
            if a:prop is# 'copies'
                let kwargs.C=1
                let kwargs['find-copies-harder']=1
                let kwargs['diff-filter'].='C'
            endif
            let d=map(s:F.git(a:repo, 'diff', args, kwargs, 'rdifff', a:prop,
                        \     a:cs.hex)[:-2], 'split(v:val, "\t")')
            if a:prop is# 'copies'
                let a:cs.copies={}
            endif
            let a:cs.renames={}
            let a:cs.files=[]
            let a:cs.removes=[]
            for [status; files] in d
                call map(files, 's:F.refile(v:val)')
                if status[0] is# 'M' || status[0] is# 'A'
                    let a:cs.files+=[files[0]]
                elseif status[0] is# 'D'
                    let a:cs.removes+=[files[0]]
                elseif status[0] is# 'R'
                    let a:cs.renames[files[1]]=files[0]
                elseif status[0] is# 'C'
                    let a:cs.copies[files[1]]=files[0]
                endif
            endfor
            let a:cs.changes=a:cs.files+a:cs.removes
        elseif lparents>=2
            " FIXME Here must be files that had merge conflicts
            let a:cs.renames={}
            let a:cs.copies={}
            let a:cs.changes=[]
            let a:cs.files=[]
            let a:cs.removes=[]
        endif
        return a:cs[a:prop]
    endif
    let a:cs[a:prop]=r
    return r
endfunction
"▶1 nullnl :: [String] → [String]
" Convert between lines (NL separated strings with NULLs represented as NLs) and 
" NULL separated strings with NLs represented by NLs.
function s:F.nullnl(text)
    let r=['']
    for nlsplit in map(copy(a:text), 'split(v:val, "\n", 1)')
        let r[-1].="\n".nlsplit[0]
        call extend(r, nlsplit[1:])
    endfor
    if empty(r[0])
        call remove(r, 0)
    else
        let r[0]=r[0][1:]
    endif
    return r
endfunction
"▶1 git.status :: repo[, rev1[, rev2[, files[, clean]]]]
let s:statchars={
            \'A': 'added',
            \'M': 'modified',
            \'D': 'removed',
        \}
let s:initstatdct={
            \'modified': [],
            \   'added': [],
            \ 'removed': [],
            \ 'deleted': [],
            \ 'unknown': [],
            \ 'ignored': [],
            \   'clean': [],
        \}
function s:git.status(repo, ...)
    let r=deepcopy(s:initstatdct)
    let requiresclean=(a:0>3 && a:4)
    if a:0 && (a:1 isnot 0 || (a:0>1 && a:2 isnot 0))
        let args=((a:0>2 && !empty(a:3))?(['--']+a:3):([]))
        let rspec=[]
        let reverse=0
        if a:1 is 0
            if a:0>1 && a:2 isnot 0
                let reverse=1
            endif
        else
            let rspec+=[a:1]
        endif
        if a:0>1 && a:2 isnot 0
            let rspec+=[a:2]
        endif
        call insert(args, join(rspec, '..'))
        let kwargs={'diff-filter': 'AMD', 'name-status': 1, 'no-renames': 1}
        let d=s:F.git(a:repo, 'diff', args, kwargs, 0, 'sdifff')[:-2]
        let files=map(copy(d), 's:F.refile(v:val[2:])')
        call map(copy(d), 'add(r[s:statchars[v:val[0]]], files[v:key])')
        if reverse
            let [r.deleted, r.unknown]=[r.unknown, r.deleted]
            let [r.added,   r.removed]=[r.removed, r.added  ]
        endif
        if requiresclean
            let allfiles=a:repo.functions.getcsprop(a:repo,rspec[0],'allfiles')
        endif
    else
        let args=((a:0>2 && !empty(a:3))?(['--']+a:3):([]))
        let kwargs={'porcelain': 1, 'z': 1}
        let s=s:F.nullnl(s:F.git(a:repo,'status',args,kwargs,1,'statusf'))[:-2]
        let files={}
        while !empty(s)
            let line=remove(s, 0)
            let status=line[:1]
            let file=line[3:]
            let files[file]=1
            if status[0] is# 'R'
                let r.added+=[file]
                let r.removed+=[remove(s, 0)]
            elseif status[0] is# 'C'
                let r.added+=[file]
                let origfile=remove(s, 0)
                " FIXME What should be done with origfile?
            elseif status[0] is# 'D'
                let r.removed+=[file]
            elseif status[1] is# 'D'
                let r.deleted+=[file]
            elseif status[0] is# 'A'
                let r.added+=[file]
            elseif stridx(status, 'M')!=-1
                let r.modified+=[file]
            elseif status is# '??'
                let r.unknown+=[file]
            endif
        endwhile
        if requiresclean
            let allfiles=a:repo.functions.getcsprop(a:repo, 'HEAD', 'allfiles')
        endif
    endif
    if exists('allfiles')
        if a:0>2 && !empty(a:3)
            let allfiles=filter(copy(allfiles), 'index(a:3, v:val)!=-1')
        endif
        let r.clean=filter(copy(allfiles), '!has_key(files, v:val)')
    endif
    return r
endfunction
"▶1 git.commit :: repo, message[, files[, user[, date[, _]]]]
function s:git.commit(repo, message, ...)
    let kwargs={'cleanup': 'verbatim'}
    let args=[]
    if a:0
        if empty(a:1)
            let kwargs.all=1
        else
            let args+=['--']+a:1
            call s:_r.utils.addfiles(a:repo, a:1)
        endif
        if a:0>1 && !empty(a:2)
            let kwargs.author=a:2
        endif
        if a:0>2 && !empty(a:3)
            let kwargs.date=a:3
        endif
        if a:0>3 && !empty(a:4)
            call s:_f.throw('cbnimp')
        endif
    else
        let kwargs.all=1
    endif
    return s:_r.utils.usefile(a:repo, a:message, 'file', 'message',
                \             s:F.gitm, args, kwargs, 0, 'cif')
endfunction
"▶1 git.branch :: repo, branchname, force → + FS
function s:git.branch(repo, branch, force)
    if a:force
        return s:F.gitm(a:repo, 'checkout', [a:branch], {'B': 1}, 0,
                    \   'chbf', a:branch)
    else
        call a:repo.functions.label(a:repo, 'branch', a:branch, 'HEAD', 0, 0)
        call a:repo.functions.update(a:repo, a:branch, 0)
    endif
endfunction
"▶1 git.label :: repo, type, label, rev, force, local → + FS
function s:git.label(repo, type, label, rev, force, local)
    if a:local
        call s:_f.throw('nloc')
    endif
    let args=['--', a:label]
    let kwargs={}
    if a:force
        let kwargs.force=1
    endif
    if a:rev is 0
        let kwargs.d=1
    else
        let args+=[a:rev]
    endif
    return s:F.gitm(a:repo, a:type, args, kwargs, 0,
                \   'lbf', a:type, a:label, a:rev)
endfunction
"▶1 git.update :: repo, rev, force → + FS
" XXX This must not transform {rev} into hash: it will break rf-branch()
function s:git.update(repo, rev, force)
    let kwargs={}
    if a:force
        let kwargs.force=1
    endif
    "▶2 XXX (hacks): Avoid “detached HEAD” state if possible
    if a:rev=~#'\v^[0-9a-z]{40}$'
        if has_key(s:prevrevhex, a:repo.path) &&
                    \a:rev is# s:prevrevhex[a:repo.path][1] &&
                    \filereadable(s:_r.os.path.join(a:repo.githpath,
                    \                             s:prevrevhex[a:repo.path][0]))
            let rev=s:prevrevhex[a:repo.path][0]
            unlet s:prevrevhex[a:repo.path]
        else
            for [d, ds, fs] in s:_r.os.walk(a:repo.githpath)
                for f in fs
                    let reffile=s:_r.os.path.join(d, f)
                    if a:rev is# get(readfile(reffile, 'b'), 0, 0)
                        let rev=join(s:_r.os.path.split(
                                    \s:_r.os.path.relpath(reffile,
                                    \                     a:repo.githpath))[1:],
                                    \"/")
                        break
                    endif
                endfor
            endfor
            if !exists('rev')
                let rev=a:rev
            endif
        endif
    else
        let rev=a:rev
    endif
    "▲2
    let args=[rev]
    return s:F.gitm(a:repo, 'checkout', args, kwargs, 0, 'updf', a:rev)
endfunction
"▶1 git.move :: repo, force, source, destination → + FS
function s:git.move(repo, force, source, destination)
    return s:F.gitm(a:repo, 'mv', ['--', a:source, a:destination],
                \   a:force ? {'force': 1} : {}, 0, 'mvf',
                \   a:source, a:destination)
endfunction
"▶1 git.add :: repo, file → + FS
function s:git.add(repo, file)
    return s:F.gitm(a:repo, 'add', ['--', a:file], {}, 0, 'addf',
                \   escape(a:file, '\'))
endfunction
"▶1 git.forget :: repo, file → + FS
function s:git.forget(repo, file)
    return s:F.gitm(a:repo, 'rm', ['--', a:file], {'cached': 1}, 0, 'fgf',
                \   escape(a:file, '\'))
endfunction
"▶1 git.remove :: repo, file → + FS
function s:git.remove(repo, file)
    return s:F.gitm(a:repo, 'rm', ['--', a:file], {}, 0, 'rmf',
                \   escape(a:file, '\'))
endfunction
"▶1 addtoignfile :: file, line → + FS
function s:F.addtoignfile(ignfile, line)
    let r=[]
    if filereadable(a:ignfile)
        let r+=readfile(a:ignfile, 'b')
    endif
    if !empty(r) && empty(r[-1])
        call remove(r, -1)
    endif
    let r+=[a:line, '']
    return writefile(r, a:ignfile, 'b')
endfunction
"▶1 git.ignore :: repo, file → + FS
function s:git.ignore(repo, file)
    return s:F.addtoignfile(s:_r.os.path.join(a:repo.path, '.gitignore'),
                \           '/'.escape(a:file, '\*?[]'))
endfunction
"▶1 git.ignoreglob :: repo, glob → + FS
function s:git.ignoreglob(repo, glob)
    return s:F.addtoignfile(s:_r.os.path.join(a:repo.path,'.gitignore'), a:glob)
endfunction
"▶1 git.grep :: repo, files, revisions, ignorecase, wdfiles::Bool → qflist
"▶2 parsegrep :: lines → [(file, lnum, String)]
function s:F.parsegrep(lines)
    let r=[]
    let contline=0
    while !empty(a:lines)
        let sp=split(remove(a:lines, 0), "\n", 1)
        if contline
            let r[-1][0].="\n".sp[0]
            if len(sp)>1
                let r[-1]+=sp[1:]
                let contline=0
            endif
        elseif len(sp)==1
            let contline=1
            let r+=[sp]
        else
            let r+=[sp]
        endif
    endwhile
    call map(r, '[v:val[0], str2nr(v:val[1]), v:val[2]]')
    return r
endfunction
"▲2
function s:git.grep(repo, pattern, files, revisions, ic, wdfiles)
    let args=['-e', a:pattern, '--']+a:files
    let kwargs={'full-name': 1, 'extended-regexp': 1, 'n': 1, 'z': 1}
    let gitargs=[a:repo, 'grep', args, kwargs, 1, 0]
    let r=[]
    if !empty(a:revisions)
        let revs=[]
        for s in a:revisions
            if type(s)==type([])
                let revs+=map(copy(a:repo.functions.revrange(a:repo,s[0],s[1])),
                            \ 'v:val.hex')
            else
                let revs+=[a:repo.functions.getrevhex(a:repo, s)]
            endif
            unlet s
        endfor
        call extend(args, revs, 2)
        for [revfile, lnum, text] in s:F.parsegrep(call(s:F.git, gitargs, {}))
            let cidx=stridx(revfile, ':')
            let rev=revfile[:(cidx-1)]
            let file=revfile[(cidx+1):]
            let r+=[{'filename': [rev, file], 'lnum': lnum, 'text': text}]
        endfor
    else
        for [file, lnum, text] in s:F.parsegrep(call(s:F.git, gitargs, {}))
            let r+=[{'filename': file, 'lnum': lnum, 'text': text}]
        endfor
    endif
    return r
endfunction
"▶1 git.readfile :: repo, rev, file → [String]
function s:git.readfile(repo, rev, file)
    return s:F.git(a:repo, 'cat-file', ['blob', a:rev.':'.a:file], {}, 2,
                \  'filef', a:rev, a:file)
endfunction
"▶1 git.annotate :: repo, rev, file → [(file, hex, linenumber)]
function s:git.annotate(repo, rev, file)
    let args=[a:rev, '--', a:file]
    let kwargs={'porcelain': 1, 'C': 1, 'M': 1}
    let lines=s:F.git(a:repo, 'blame', args, kwargs, 1, 'annf', a:rev, a:file)
    call filter(lines, 'v:val=~#''\v^(\x{40}\ |filename\ )''')
    let r=[]
    let filename=a:file
    while !empty(lines)
        let line=remove(lines, 0)
        if !empty(lines) && lines[0][:8] is# 'filename '
            let filename=s:F.refile(remove(lines, 0)[9:])
        endif
        let r+=[[filename, line[:39], str2nr(line[41:])]]
    endwhile
    return r
endfunction
"▶1 git.diff :: repo, rev, rev, files, opts → [String]
let s:difftrans={
            \  'reverse': 'R',
            \ 'ignorews': 'ignore-all-space',
            \'iwsamount': 'ignore-space-change',
            \ 'numlines': 'unified',
            \  'alltext': 'text',
        \}
function s:git.diff(repo, rev1, rev2, files, opts)
    let diffopts=s:_r.utils.diffopts(a:opts, a:repo.diffopts, s:difftrans)
    if has_key(diffopts, 'unified')
        let diffopts.unified=''.diffopts.unified
    endif
    let kwargs=copy(diffopts)
    let args=[]
    if empty(a:rev2)
        if !empty(a:rev1)
            let args+=[a:rev1.'^..'.a:rev1]
        endif
    else
        let args+=[a:rev2]
        if !empty(a:rev1)
            let args[-1].='..'.a:rev1
        endif
    endif
    if !empty(a:files)
        let args+=['--']+a:files
    endif
    let r=s:F.git(a:repo, 'diff', args, kwargs, 1,
                \ 'difff', a:rev1, a:rev2, join(a:files, ', '))
    return r
endfunction
"▶1 git.diffre :: _, opts → Regex
let s:diffre='\m^diff --git \v((\")?%s\/.{-}\2) \2%s\/'
function s:git.diffre(repo, opts)
    if get(a:opts, 'reverse', 0)
        return printf(s:diffre, 'b', 'a')
    else
        return printf(s:diffre, 'a', 'b')
    endif
endfunction
"▶1 git.diffname :: _, line, diffre, _ → rpath
function s:git.diffname(repo, line, diffre, opts)
    let file=get(matchlist(a:line, a:diffre), 1, 0)
    if file is 0
        return 0
    else
        return s:F.refile(file)[2:]
    endif
endfunction
"▶1 git.getrepoprop :: repo, propname → a
function s:git.getrepoprop(repo, prop)
    if a:prop is# 'url'
        let r=get(s:F.git(a:repo, 'config', ['remote.origin.pushurl'], {}, 0),
                    \0, 0)
        if v:shell_error || r is 0
            let r=get(s:F.git(a:repo, 'config', ['remote.origin.url'], {}, 0),
                        \0, 0)
        endif
        if r isnot 0
            return r
        endif
    elseif a:prop is# 'branchslist' || a:prop is# 'brancheslist'
        " XXX stridx(v:val, " ")==-1 filters out “(no branch)” item
        return filter(map(s:F.git(a:repo, 'branch', [], {'l': 1}, 0,
                    \             'branchf')[:-2], 'v:val[2:]'),
                    \     'stridx(v:val, " ")==-1')
    elseif a:prop is# 'tagslist'
        return s:F.git(a:repo, 'tag', [], {}, 0, 'tagf')[:-2]
    elseif a:prop is# 'bookmarkslist'
        return []
    endif
    call s:_f.throw('nocfg', a:prop, a:repo.path)
endfunction
"▶1 git.repo :: path → repo
function s:git.repo(path)
    let repo={'path': a:path, 'changesets': {}, 'cslist': [],
                \'local': (stridx(a:path, '://')==-1),
                \'labeltypes': ['tag', 'branch'],
                \'hasrevisions': 0, 'requires_sort': 0,
                \'githpath': s:_r.os.path.join(a:path, '.git', 'refs', 'heads'),
                \'hypsites': deepcopy(s:hypsites),}
    if has_key(s:prevrevhex, a:path)
        unlet s:prevrevhex[a:path]
    endif
    return repo
endfunction
"▶1 git.checkdir :: dir → Bool
function s:git.checkdir(dir)
    return s:_r.os.path.isdir(s:_r.os.path.join(a:dir, '.git'))
endfunction
"▶1 Register driver
call s:_f.regdriver('Git', s:git)
"▶1
call frawor#Lockvar(s:, '_pluginloaded,prevrevhex')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
