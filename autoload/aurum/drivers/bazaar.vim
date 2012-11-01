"▶1
scriptencoding utf-8
execute frawor#Setup('0.0', {'@%aurum/drivers/common/hypsites': '0.0',
            \                                   '@%aurum/repo': '5.0',
            \                   '@%aurum/drivers/common/utils': '1.0',
            \                                           '@/os': '0.1',
            \                                      '@/options': '0.0',})
let s:_messages={
            \   'revnof': 'Failed to get working directory revision '.
            \             'from the repository %s: %s',
            \     'logf': 'Failed to list all revisions '.
            \             'in the repository %s: %s',
            \      'csf': 'Failed to get information about revision %s '.
            \             'in the repository %s: %s',
            \      'lsf': 'Failed to list files in the changeset %s '.
            \             'from the repository %s: %s',
            \    'statf': 'Failed to get status in the repository %s: %s',
            \'lsignoref': 'Failed to list ignored files '.
            \             'in the repository %s: %s',
            \   'labelf': 'Failed to set %s “%s” for the changeset %s '.
            \             'in the repository %s: %s',
            \  'revertf': 'Failet to revert to the changeset %s '.
            \             'in the repository %s: %s',
            \  'updatef': 'Failed to update to the changeset %s '.
            \             'in the repository %s: %s',
            \      'mvf': 'Failed to move %s to %s in the repository %s: %s',
            \     'addf': 'Failed to add file %s to the repository %s: %s',
            \      'fgf': 'Failed to forget file %s in the repository %s: %s',
            \      'rmf': 'Failed to removed file %s in the repository %s: %s',
            \  'ignoref': 'Failed to ignore %s in the repository %s: %s',
            \     'catf': 'Failed to get file %s in the changeset %s '.
            \             'of the repository %s: %s',
            \'annotatef': 'Failed to annotate file %s in the changeset %s '.
            \             'of the repository %s: %s',
            \    'difff': 'Failed to get diff between %s and %s for files %s '.
            \             'in the repository %s: %s',
            \    'nickf': 'Failed to get branch name for the repository %s: %s',
            \ 'nicksetf': 'Failed to set nick %s for the repository %s: %s',
            \  'configf': 'Failed to get parent_location '.
            \             'of the repository %s: %s',
            \     'tagf': 'Failed to list tags in the repository %s: %s',
            \    'pushf': 'Failed to push the repository %s: %s',
            \    'pullf': 'Failed to pull to the repository %s: %s',
            \  'commitf': 'Failed to commit changes to the repository %s: %s',
            \  'p_empty': 'Parser error: expected 60 dashes, but got nothing',
            \  'p_nobeg': 'Parser error: expected 60 dashes, but got %s',
            \ 'p_nospec': 'Parser error: expected “spec: value”, but got %s',
            \'p_dateerr': 'Parser error: date exited with code %u '.
            \             'while trying to parse “%s”: %s',
            \    'ndate': 'You must install “date” programm in order to get '.
            \             'time information for bazaar revisions',
            \     'rene': 'Failed to get rename information: '.
            \             'no “ => ” in string %s',
            \    'renze': 'Failed to get rename information: '.
            \             '“ => ” found at the start of the string %s',
            \   'renz2e': 'Failed to get rename information: '.
            \             '“ => ” found at the end of the string %s',
            \   'cbnimp': 'Bazaar driver is not able to close branch',
            \  'upfnimp': 'Bazaar driver is not able to force update',
            \  'revnimp': 'In order to get reverse diff you must specify '.
            \             'both revisions',
            \   'bfnimp': 'Can’t force branch nick creation',
            \   'drnimp': 'Dry run not implemented',
            \    'nocfg': 'Can’t get property %s of the repository %s',
        \}
let s:bzr={}
let s:_options={
        \}
"▶1 s:hypsites
" TODO Support for git and subversion hypsites
let s:hypsites=s:_r.hypsites.bzr
"▶1 bzrcmd :: cmd, args, kwargs → String
function s:F.bzrcmd(...)
    return ['bzr', '--no-aliases']+call(s:_r.utils.getcmd, a:000, {})
endfunction
"▶1 bzr :: repo, cmd, args, kwargs, has0[, msgid[, marg1[, …]]] → [String] + ?
function s:F.bzr(repo, cmd, args, kwargs, hasnulls, ...)
    let cmd=s:F.bzrcmd(a:cmd, a:args, a:kwargs)
    let [r, exit_code]=s:_r.utils.run(cmd, a:hasnulls, a:repo.path)
    if a:0
        if a:1 is 0
            return [r, exit_code]
        elseif exit_code
            call call(s:_f.throw, a:000+[a:repo.path, join(r[:-1-(a:hasnulls)],
                        \                                  "\n")], {})
        endif
    endif
    return r
endfunction
"▶1 bzrm :: {bzr args} → + :echom
function s:F.bzrm(...)
    return s:_r.utils.printm(call(s:F.bzr, a:000, {}))
endfunction
"▶1 parsecs :: csdata, lstart::UInt → (cs, line::UInt)
" hash-parent hashes-timestamp
"  (refs)
" author name
" author email
" 1-indented commit message
let s:logkwargs={'long': 1, 'show-ids': 1}
let s:hasdateexe=executable('date')
function s:F.parsecs(csdata, ...)
    if empty(a:csdata)
        call s:_f.throw('p_empty')
    elseif a:csdata[0]!~#'\v^\s*\-{60}$'
        call s:_f.throw('p_nobeg', a:csdata[0])
    endif
    let indent=stridx(remove(a:csdata, 0), '-')
    " FIXME children:[]
    let cs={'parents': [], 'copies': {}, 'children': [], 'phase': 'unknown',
                \'bookmarks': [], 'tags': []}
    while !empty(a:csdata) && a:csdata[0]!~#'\v^\s*\-{60}$'
        let line=remove(a:csdata, 0)[(indent):]
        if line is# 'message:'
            let description=[]
            " XXX message can have line “----”
            let regex='\v^('.((indent)?
                        \       (join(map(range(0, indent/4),
                        \                 '"\\s{".(v:val*4)."}"'), '|')):
                        \       ('')).'|\s{'.(indent+4).'})\-{60}$'
            while !empty(a:csdata) && a:csdata[0] !~# regex
                call add(description, remove(a:csdata, 0)[(indent+2):])
            endwhile
            let cs.description=join(description, "\n")
            break
        endif
        let match=matchlist(line, '\v^([^:]+)\: ?(.*)$')[1:2]
        if empty(match)
            call s:_f.throw('p_nospec', line)
        endif
        let [spec, value]=match
        if spec is# 'revno'
            let cs.rev=matchstr(value, '\v^\S+')
        elseif spec is# 'revision-id'
            if a:0 && has_key(a:1, value)
                let spaces=repeat(' ', indent-1)
                while a:csdata[:(indent-1)] is# spaces
                    call remove(a:csdata, 0)
                endwhile
                return {'hex': value}
            else
                let cs.hex=value
            endif
        elseif spec is# 'parent'
            let cs.parents+=[value]
        elseif spec is# 'author'
            let cs.user=value
        elseif spec is# 'committer' && !has_key(cs, 'user')
            let cs.user=value
        elseif spec is# 'branch nick'
            let cs.branch=value
        elseif spec is# 'tags'
            " FIXME There may be “, ” in the tag, use “bzr tags” to fix it
            " XXX Can’t fix with “bzr tags” completely: tag may contain spaces 
            "     at the end
            let cs.tags=split(value, ', ')
        elseif spec is# 'timestamp'
            if s:hasdateexe || executable('date')
                let s:hasdateexe=1
                let time=system('date --date='.shellescape(value).' +%s')
                if v:shell_error
                    call s:_f.throw('p_dateerr', v:shell_error, value, time)
                endif
                let cs.time=+time
            else
                call s:_f.warn('ndate')
                let cs.time=0
            endif
        endif
    endwhile
    return cs
endfunction
"▶1 bzr.getcs :: repo, rev → cs
let s:gcslogkwargs=extend({'levels': '1'}, s:logkwargs)
function s:bzr.getcs(repo, rev)
    let kwargs=copy(s:gcslogkwargs)
    let kwargs.revision=''.a:rev
    let log=s:F.bzr(a:repo, 'log', [], kwargs, 0, 'csf', a:rev)
    let cs=s:F.parsecs(log)
    " XXX This construct is used to preserve information like “allfiles” etc
    let a:repo.changesets[cs.hex]=extend(get(a:repo.changesets, cs.hex, {}), cs)
    return a:repo.changesets[cs.hex]
endfunction
"▶1 bzr.getwork :: repo → cs
function s:bzr.getwork(repo)
    let rev=+s:F.bzr(a:repo, 'revno', [], {'tree': 1}, 0, 'revnof')[0]
    return a:repo.functions.getcs(a:repo, rev)
endfunction
"▶1 bzr.getchangesets :: repo[, rangestart, rangeend] → [cs]
let s:gcsslogkwargs=extend({'levels': '0'}, s:logkwargs)
function s:bzr.getchangesets(repo, ...)
    let kwargs=copy(s:gcsslogkwargs)
    if a:0
        let kwargs.revision=a:1.'..'.a:2
    endif
    let log=s:F.bzr(a:repo, 'log', [], kwargs, 0, 'logf')
    let cslist=[]
    let csmap={}
    while !empty(log)
        let cs=s:F.parsecs(log, csmap)
        if has_key(csmap, cs.hex)
            let pos=remove(csmap, cs.hex)
            call map(csmap, '(v:val>'.pos.')?(v:val-1):(v:val)')
            let cs=remove(cslist, pos)
        else
            let a:repo.changesets[cs.hex]=cs
        endif
        let csmap[cs.hex]=len(cslist)
        call insert(cslist, cs)
    endwhile
    return cslist
endfunction
"▶1 bzr.revrange :: repo, rev1, rev2 → [cs]
let s:bzr.revrange=s:bzr.getchangesets
"▶1 bzr.updatechangesets :: repo → _
function s:bzr.updatechangesets(...)
    " FIXME Get new changesets
endfunction
"▶1 bzr.getrevhex :: repo, rev → hex
let s:prevrevhex={}
function s:bzr.getrevhex(repo, rev)
    return a:repo.functions.getcs(a:repo, a:rev).hex
endfunction
"▶1 bzr.getworkhex :: repo → hex
function s:bzr.getworkhex(repo)
    return a:repo.functions.getwork(a:repo).hex
endfunction
"▶1 bzr.gettiphex :: repo → hex
function s:bzr.gettiphex(repo)
    return a:repo.functions.getrevhex(a:repo, '-1')
endfunction
"▶1 getstatdict :: repo, kwargs → statdict
function s:F.getstatdict(repo, args, kwargs)
    let status=s:F.bzr(a:repo, 'status', a:args,
                \      extend({'no-classify': 1}, a:kwargs), 0,
                \      'statf')[:-2]
    let curstatus=0
    let statdict={}
    while !empty(status)
        let line=remove(status, 0)
        if line[:1] is# '  '
            " XXX File name is not expected to contain " => "
            let statdict[curstatus]+=[line[2:]]
        elseif line =~# '\v^[a-z]+%(\ [a-z]+)*\:$'
            let curstatus=line[:-2]
            let statdict[curstatus]=[]
        elseif !empty(get(statdict, curstatus, 0))
            " XXX Support for file with newlines is very limited here: it 
            "     does not expect them containing "\n  " or "\nabc:". Bazaar 
            "     crashes when trying to commit file with newline in its 
            "     name, though it is probably not a problem
            let statdict[curstatus][-1].="\n".line
        endif
    endwhile
    return statdict
endfunction
"▶1 getrenames :: statdict → renames
function s:F.getrenames(statdict)
    if !has_key(a:statdict, 'renamed')
        return {}
    endif
    let renames={}
    for rename in a:statdict.renamed
        let idx=stridx(rename, " => ")
        if idx==-1
            call s:_f.throw('rene', rename)
        elseif idx==0
            call s:_f.throw('renze', rename)
        endif
        let old=rename[:(idx-1)]
        let new=rename[idx+4:]
        try
            let renames[new]=old
        catch /^Vim(let):E713:/
            call s:_f.throw('renz2e', rename)
        endtry
    endfor
    return renames
endfunction
"▶1 bzr.setcsprop :: repo, cs, propname → propvalue
function s:bzr.setcsprop(repo, cs, prop)
    if a:prop is# 'allfiles'
        let r=s:_r.utils.nullnl(
                    \s:F.bzr(a:repo, 'ls', [], {'revision': 'revid:'.a:cs.hex,
                    \                          'recursive': 1,
                    \                               'null': 1}, 2,
                    \        'lsf', a:cs.hex))[:-2]
    elseif       a:prop is# 'renames' || a:prop is# 'changes' ||
                \a:prop is# 'files'   || a:prop is# 'removes'
        let statdict=s:F.getstatdict(a:repo, [], {'change': 'revid:'.a:cs.hex})
        let a:cs.removes=[]
        let a:cs.files=[]
        call map(['added', 'modified', 'kind changed'],
                    \'extend(a:cs.files, get(statdict, v:val, []))')
        if has_key(statdict, 'removed')
            let a:cs.removes+=statdict.removed
        endif
        let a:cs.renames=s:F.getrenames(statdict)
        let a:cs.removes+=sort(values(a:cs.renames))
        let a:cs.files  +=sort(keys(  a:cs.renames))
        let a:cs.changes=a:cs.removes+a:cs.files
        return a:cs[a:prop]
    endif
    let a:cs[a:prop]=r
    return r
endfunction
"▶1 bzr.status :: repo[, rev1[, rev2[, files[, clean[, ign]]]]] → {type:[file]}
let s:statstats={'added': 'added', 'removed': 'removed', 'modified': 'modified',
            \    'kind changed': 'modified', 'unknown': 'unknown',
            \    'missing': 'deleted'}
function s:bzr.status(repo, ...)
    let args=['--']+((a:0>2 && a:3 isnot 0)?(a:3):([]))
    let statdict=s:F.getstatdict(a:repo, args,
                \                ((a:0>1 && a:1 isnot 0 && a:2 isnot 0)?
                \                   ({'revision': a:1.'..'.a:2}):
                \                ((a:0>0 && a:1 isnot 0)?
                \                   ({'revision': a:1.'..'}):
                \                ((a:0>1 && a:2 isnot 0)?
                \                   ({'revision': a:2.'..'}):
                \                   ({})))))
    let r=deepcopy(s:_r.utils.emptystatdct)
    " XXX There cannot be deleted files similar to mercurial, but there can be 
    "     files that have 2 statuses
    "     (missing is a bit different: it is shown after deleting added file)
    for [sdkey, skey] in items(filter(copy(s:statstats),
                \                     'has_key(statdict, v:key)'))
        let r[skey]+=statdict[sdkey]
    endfor
    let renames=s:F.getrenames(statdict)
    call filter(r.modified, '!has_key(renames, v:val)')
    let r.added+=sort(keys(renames))
    let r.removed+=sort(values(renames))
    if a:0>1 && a:1 is 0 && a:2 isnot 0
        let [r.deleted, r.unknown]=[r.unknown, r.deleted]
        let [r.added,   r.removed]=[r.removed, r.added  ]
    endif
    if a:0>3 && a:4
        if a:1 is 0
            if a:2 is 0
                let rev=a:repo.functions.getworkhex(a:repo)
            else
                let rev=a:2
            endif
        else
            let rev=a:1
        endif
        let allfiles=copy(a:repo.functions.getcsprop(a:repo, rev, 'allfiles'))
        if !empty(a:3)
            let allfiles=filter(allfiles, 'index(a:3, v:val)!=-1')
        endif
        let files=r.modified+r.added+r.removed+r.deleted+r.unknown
        let r.clean=filter(allfiles, 'index(files, v:val)==-1')
    endif
    if (a:0>4 && a:5 && a:1 is 0 && a:2 is 0)
        let r.ignored=s:_r.utils.nullnl(
                    \ s:F.bzr(a:repo, 'ls', args, {'ignored': 1, 'null': 1}, 2,
                    \                 'lsignoref', a:repo))[:-2]
    endif
    return r
endfunction
"▶1 bzr.commit :: repo, message[, files[, user[, date[, _]]]]
function s:bzr.commit(repo, message, ...)
    let kwargs={}
    let args=[]
    if a:0
        if !empty(a:1)
            let args+=['--']+a:1
            call s:_r.utils.addfiles(a:repo, a:1)
        endif
        if a:0>1 && !empty(a:2)
            let kwargs.author=a:2
        endif
        if a:0>2 && !empty(a:3)
            let kwargs['commit-time']=a:3.' +0000'
        endif
        if a:0>3 && !empty(a:4)
            call s:_f.throw('cbnimp')
        endif
    endif
    return s:_r.utils.usefile(a:repo, a:message, 'file', 'message',
                \             s:F.bzrm, args, kwargs, 0, 'commitf')
endfunction
"▶1 bzr.branch :: repo, branchname, force → + FS
function s:bzr.branch(repo, branch, force)
    if a:force
        call s:_f.throw('bfnimp')
    endif
    return s:F.bzrm(a:repo, 'nick', ['--', a:branch], {}, 0,
                \   'nicksetf', a:branch)
endfunction
"▶1 bzr.label :: repo, type, label, rev, force, local → + FS
function s:bzr.label(repo, type, label, rev, force, local)
    if a:local
        call s:_f.throw('nloc')
    endif
    let args=['--', a:label]
    let kwargs={}
    if a:force
        let kwargs.force=1
    endif
    if a:rev is 0
        let kwargs.delete=1
    else
        let kwargs.revision=''.a:rev
    endif
    return s:F.bzrm(a:repo, a:type, args, kwargs, 0,
                \   'labelf', a:type, a:label, a:rev)
endfunction
"▶1 bzr.update :: repo, rev, force → + FS
function s:bzr.update(repo, rev, force)
    let kwargs={}
    let kwargs.revision=''.a:rev
    if a:force
        call s:F.bzrm(a:repo, 'revert', [], kwargs, 0, 'revertf', a:rev)
    endif
    return s:F.bzrm(a:repo, 'update', [], kwargs, 0, 'updatef', a:rev)
endfunction
"▶1 bzr.move :: repo, force, source, destination → + FS
function s:bzr.move(repo, force, source, destination)
    return s:F.bzrm(a:repo, 'mv', ['--', a:source, a:destination], {}, 0,
                \   'mvf', a:source, a:destination)
endfunction
"▶1 bzr.add :: repo, file → + FS
function s:bzr.add(repo, file)
    return s:F.bzrm(a:repo, 'add', ['--', a:file], {}, 0, 'addf', a:file)
endfunction
"▶1 bzr.forget :: repo, file → + FS
function s:bzr.forget(repo, file)
    return s:F.bzrm(a:repo, 'rm', ['--', a:file], {'keep': 1}, 0,
                \   'fgf', a:file)
endfunction
"▶1 bzr.remove :: repo, file → + FS
function s:bzr.remove(repo, file)
    return s:F.bzrm(a:repo, 'rm', ['--', a:file], {'no-backup': 1}, 0,
                \   'rmf', a:file)
endfunction
"▶1 bzr.ignore :: repo, file → + FS
function s:bzr.ignore(repo, file)
    return a:repo.functions.ignoreglob(a:repo,
                \'RE:'.substitute(a:file, '\W', '\\\0', 'g'))
endfunction
"▶1 bzr.ignoreglob :: repo, glob → + FS
function s:bzr.ignoreglob(repo, glob)
    return s:F.bzrm(a:repo, 'ignore', ['--', a:glob], {}, 0, 'ignoref', a:glob)
endfunction
"▶1 bzr.readfile :: repo, rev, file → [String]
function s:bzr.readfile(repo, rev, file)
    return s:F.bzr(a:repo, 'cat', ['--', a:file], {'revision': ''.a:rev}, 2,
                \  'catf', a:rev, a:file)
endfunction
"▶1 bzr.annotate :: repo, rev, file → [(file, hex, linenumber)]
" XXX Bazaar supports annotating current state, it uses id=current:
function s:bzr.annotate(repo, rev, file)
    let ann=s:F.bzr(a:repo, 'annotate', ['--', a:file],
                \   {'rev': a:rev, 'show-ids': 1, 'all': 1}, 2,
                \   'annotatef', a:file, a:rev)[:-2]
    let lastid=0
    let r=[]
    let idamap={}
    for line in ann
        let id=line[match(line, '\S'):(stridx(line, '|')-2)]
        let r+=[[id, 0]]
        let idamap[id]=get(idamap, id, [])+[r[-1]]
    endfor
    " XXX Bazaar annotation respects renames, but it does not show old filename, 
    "     thus rename information is to be used
    for [id, lists] in items(idamap)
        let renames=s:F.getrenames(s:F.getstatdict(a:repo, ['--', a:file],
                    \                              {'revision': a:rev.'..'.id}))
        let file=get(renames, a:file, a:file)
        call map(lists, 'insert(v:val, '.string(file).')')
    endfor
    return r
endfunction
"▶1 bzr.diff :: repo, rev, rev, files, opts → [String]
let s:difftrans={
            \ 'numlines': 'unified',
            \ 'ignorews': 'ignore-all-space',
            \'iwsamount': 'ignore-space-change',
            \  'iblanks': 'ignore-blank-lines',
            \ 'showfunc': 'show-c-function',
            \  'alltext': 'text',
        \}
function s:bzr.diff(repo, rev1, rev2, files, opts)
    let reverse=get(a:opts, 'reverse', 0)
    let diffopts=s:_r.utils.diffopts(a:opts, a:repo.diffopts, s:difftrans)
    let kwargs={}
    if !empty(diffopts)
        let kwargs['diff-options']=join(s:_r.utils.kwargstolst(diffopts))
    endif
    let args=[]
    if empty(a:rev2)
        if reverse
            call s:_f.throw('revnimp')
        endif
        if !empty(a:rev1)
            let kwargs.change=''.a:rev1
        endif
    else
        if reverse
            if empty(a:rev1)
                call s:_f.throw('revnimp')
            endif
            let kwargs.revision=a:rev1.'..'.a:rev2
        else
            let kwargs.revision=''.a:rev2
            if !empty(a:rev1)
                let kwargs.revision.='..'.a:rev1
            endif
        endif
    endif
    if !empty(a:files)
        let args+=['--']+a:files
    endif
    let [r, exit_code]=s:F.bzr(a:repo, 'diff', args, kwargs, 1, 0)
    " 0 is returned when repository is unchanged
    " 1 is returned when repository has changes
    " 2 and further indicate an error
    if exit_code>1
        call s:_f.throw('difff', a:rev1, a:rev2, join(a:files, ', '),
                    \            a:repo.path, join(r, "\n"))
    endif
    return r
endfunction
"▶1 bzr.diffre :: _, opts → Regex
let s:diffre='\m^=== \v(\a+)\ file\ (.*)'
function s:bzr.diffre(repo, opts)
    return s:diffre
endfunction
"▶1 bzr.diffname :: _, line, diffre, _ → rpath
function s:bzr.diffname(repo, line, diffre, opts)
    let match=matchlist(a:line, a:diffre)[1:2]
    if empty(match)
        return 0
    elseif match[0] is# 'renamed'
        return matchstr(match[1], '\v%(\''.*\''\V => ''\v)@<=.*%(\''$)@=')
    else
        return match[1][1:-2]
    endif
endfunction
"▶1 bzr.getrepoprop :: repo, propname → a
function s:bzr.getrepoprop(repo, prop)
    if a:prop is# 'branch'
        return join(s:F.bzr(a:repo, 'nick', [], {}, 0, 'nickf')[:-2], "\n")
    elseif a:prop is# 'url'
        return s:F.bzr(a:repo, 'config', ['parent_location'], {}, 0,
                    \  'configf')[:-2]
    elseif a:prop is# 'brancheslist'
        return []
        " FIXME Use “bzr branches”?
    elseif a:prop is# 'tagslist'
        return map(s:F.bzr(a:repo, 'tags', [], {}, 0, 'tagf')[:-2],
                    \'substitute(v:val, '' \+\S\+$'', "", "")')
    elseif a:prop is# 'bookmarkslist'
        return []
    endif
    call s:_f.throw('nocfg', a:prop, a:repo.path)
endfunction
"▶1 bzr.push :: repo, dryrun, force[, URL[, rev]]
function s:bzr.push(repo, dryrun, force, ...)
    if a:dryrun
        call s:_f.throw('drnimp')
    endif
    let args=[]
    let kwargs={}
    if a:force
        let kwargs.overwrite=1
        let kwargs['use-existing-dir']=1
        let kwargs['create-prefix']=1
    endif
    if a:0 && a:1 isnot 0
        let args+=['--', a:1]
    endif
    if a:0>1 && a:2 isnot 0
        let kwargs.revision=''.a:2
    endif
    return s:F.bzrm(a:repo, 'push', args, kwargs, 0, 'pushf')
endfunction
"▶1 bzr.pull :: repo, dryrun, force[, URL[, rev]]
function s:bzr.pull(repo, dryrun, force, ...)
    if a:dryrun
        call s:_f.throw('drnimp')
    endif
    let args=[]
    let kwargs={}
    if a:force
        let kwargs.overwrite=1
    endif
    if a:0 && a:1 isnot 0
        let args+=['--', a:1]
    endif
    if a:0>1 && a:2 isnot 0
        let kwargs.revision=''.a:2
    endif
    return s:F.bzrm(a:repo, 'pull', args, kwargs, 0, 'pullf')
endfunction
"▶1 bzr.repo :: path → repo
function s:bzr.repo(path)
    let repo={'path': a:path, 'changesets': {}, 'mutable': {},
                \'local': (stridx(a:path, '://')==-1),
                \'labeltypes': ['tag'],
                \'revreg': '\v\d+(\.\d+)*',
                \'hexreg': '\v[a-zA-Z0-9_.\-+]+\@[a-zA-Z0-9_.\-+]+',
                \'hasrevisions': 1, 'requires_sort': 0,
                \'hypsites': deepcopy(s:hypsites),
                \}
    return repo
endfunction
"▶1 bzr.checkdir :: dir → Bool
function s:bzr.checkdir(dir)
    return s:_r.os.path.isdir(s:_r.os.path.join(a:dir, '.bzr'))
endfunction
"▶1 iterfuncs
" TODO
"▶1 Register driver
call s:_f.regdriver('Bazaar', s:bzr)
"▶1
call frawor#Lockvar(s:, 'hasdateexe')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
