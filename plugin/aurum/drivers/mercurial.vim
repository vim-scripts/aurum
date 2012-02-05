"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.2', {      '@/python': '0.0',
                \                   '@aurum/repo': '2.0',
                \                          '@/os': '0.0',
                \                     '@/options': '0.0',
                \   '@aurum/drivers/common/utils': '0.0',
                \'@aurum/drivers/common/hypsites': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
let s:hg={}
let s:iterfuncs={}
let s:usepythondriver=0
if has_key(s:_r, 'py')
    try
        execute s:_r.py.cmd 'import aurum'
        let s:usepythondriver=1
    catch
        " s:usepythondriver stays equal to 0, errors are ignored
    endtry
endif
let s:_messages={
            \ 'norepo': 'Repository %s not found',
            \ 'norev' : 'No revision %s in repository %s',
            \ 'nofile': 'File %s is not present in revision %s '.
            \           'from repository %s',
            \  'csuns': 'Unable to get changeset from repository %s: '.
            \           'operation not supported',
            \'statuns': 'Unable to get working directory status '.
            \           'of repository %s: operation not supported',
            \ 'comuns': 'Unable to commit to repository %s: '.
            \           'operation not supported',
            \'diffuns': 'Unable to create a diff for repository %s: '.
            \           'operation not supported',
            \ 'upduns': 'Unable to update working directory state for '.
            \           'repository %s: operation not supported',
            \ 'destex': 'Cannot copy %s to %s: destination already exists',
            \ 'nhgiwr': 'File %s is either a directory or not writeable',
            \'reponwr': 'Unable to write to repository root (%s)',
            \  'nocfg': 'Failed to get property %s of repository %s',
            \'nlocbms': 'Bookmarks can’t be local',
            \'parsefail': 'Failed to parse changeset information',
            \ 'filefail': 'Failed to get file %s '.
            \             'from the repository %s: %s',
            \ 'difffail': 'Failed to get diff between %s and %s '.
            \             'for files %s from the repository %s: %s',
            \ 'statfail': 'Failed to obtain status information '.
            \             'for the repository %s: %s',
            \  'annfail': 'Failed to annotate revision %s of file %s '.
            \             'in the repository %s: %s',
            \  'cspfail': 'Failed to get property %s for changeset %s '.
            \             'in the repository %s: %s',
            \  'logfail': 'Failed to get log for the repository %s: %s',
            \  'keyfail': 'Failed to get %s for the repository %s: %s',
            \   'csfail': 'Failed to get changeset %s '.
            \             'from the repository %s: %s',
            \  'renfail': 'Failed to get renames list for revision %s '.
            \             'in the repository %s: %s',
            \  'cmdfail': 'Failure while running command %s '.
            \             'for the repository %s: %s',
            \ 'grepfail': 'Failed to search through the repository %s: %s',
            \   'scfail': 'Failed to show [paths] section '.
            \             'for the repository %s: %s',
            \ 'stat1mis': 'You must specify first revision as well',
        \}
let s:nullrev=repeat('0', 40)
let s:_options={
            \'hg_useshell': {'default': [],
            \                 'filter':
            \                   '(if type "" (|=split(@.@,''\L\+'')) any '.
            \                    'list match /\v^\l+$/)'},
        \}
"▶1 s:hypsites
let s:hypsites=[]
let s:bookmarks='repo.functions.getcsprop(repo, hex, "bookmarks")'
let s:tags='repo.functions.getcsprop(repo, hex, "tags")'
let s:gitrev='((!empty('.s:bookmarks.'))?'.
            \      '('.s:bookmarks.'[0]):'.
            \   '((!empty('.s:tags.'))?'.
            \      '(matchstr(get(filter(copy('.s:tags.'), "stridx(v:val, ''/'')!=-1"), 0, '.
            \           '"master"), "\\v[^/]+$"))'.
            \   ':'.
            \      '("master")))'
unlet s:bookmarks s:tags
let s:hypsites+=map(copy(s:_r.hypsites.git), '["protocol[:2] is# ''git'' && (".v:val[0].")", '.
            \                                 'map(copy(v:val[1]), '.
            \                                     '''(v:key is# "clone" || v:key is# "push")?'.
            \                                           '(substitute(v:val, "\\v^\"%(git)@!", "\"git+", "")):'.
            \                                           '(substitute(v:val, "\\v<hex>", s:gitrev, "g"))'')]')
unlet s:gitrev
let s:hypsites+=s:_r.hypsites.mercurial
let s:svnrev='"HEAD"'
let s:hypsites+=map(copy(s:_r.hypsites.svn), '[v:val[0], map(copy(v:val[1]), '.
            \                                               '''substitute(v:val, "\\v<hex>", s:svnrev, "g")'')]')
unlet s:svnrev
"▶1 removechangesets :: repo, start_rev_num → + repo
function s:F.removechangesets(repo, start)
    let changesets=a:repo.changesets
    for cs in remove(a:repo.cslist, a:start, -1)
        let hex=cs.hex
        for parenthex in filter(cs.parents, 'has_key(changesets, v:val)')
            call filter(changesets[parenthex].children, 'v:val isnot# cs.hex')
        endfor
        for childhex in filter(cs.children, 'has_key(changesets, v:val)')
            call filter(changesets[childhex].parents, 'v:val isnot# cs.hex')
        endfor
    endfor
endfunction
"▶1 hgcmd :: repo, cmd, args, kwargs, esc → String
function s:F.hgcmd(repo, ...)
    return 'hg -R '.shellescape(a:repo.path, a:4).' '.
                \call(s:_r.utils.getcmd, a:000, {})
endfunction
"▶1 runshellcmd :: repo, attr, args, kwargs → + ?
function s:F.runshellcmd(repo, attr, args, kwargs, ...)
    let e=(a:0 && a:1)
    let args=copy(a:args)
    if !empty(args)
        call insert(args, '--')
    endif
    return s:_r.utils.printm(s:F.hg(a:repo, a:attr, args, a:kwargs, e)[:-2+e])
endfunction
"▶1 hg :: repo, cmd, args, kwargs, esc, msgid[, throwarg1[, …]] → [String]
function s:F.hg(repo, cmd, args, kwargs, hasnulls, ...)
    let cmd=s:F.hgcmd(a:repo, a:cmd, a:args, a:kwargs, a:hasnulls)
    let r=s:_r.utils.run(cmd, a:hasnulls, a:repo.path)
    if v:shell_error && a:0
        let args=copy(a:000)
        let args[0].='fail'
        call call(s:_f.throw, args+[a:repo.path, join(r[:-1-(a:hasnulls)],
                    \                                 "\n")], {})
    endif
    return r
endfunction
if s:usepythondriver "▶1
"▶2 addchangesets :: repo, [cs] → _ + repo
function s:F.addchangesets(repo, css)
    call map(copy(a:css), 'extend(a:repo.changesets, {v:val.hex : v:val})')
    for cs in a:css
        for parenthex in cs.parents
            call add(a:repo.changesets[parenthex].children, cs.hex)
        endfor
    endfor
endfunction
"▶2 runcmd :: repo, attr, args, kwargs → + ?
function s:F.runcmd(repo, attr, args, kwargs)
    if index(s:_f.getoption('hg_useshell'), a:attr)!=-1
        return s:F.runshellcmd(a:repo, a:attr, a:args, a:kwargs)
    endif
    execute s:_r.py.cmd 'aurum.call_cmd(vim.eval("a:repo.path"), '.
                \                      'vim.eval("a:attr"), '.
                \                      '*vim.eval("a:args"), '.
                \                      '**vim.eval("a:kwargs"))'
endfunction
"▲2
else "▶1
"▶2 addchangesets :: repo, [cs] → _ + repo
function s:F.addchangesets(repo, css)
    call map(copy(a:css), 'extend(a:repo.changesets, {v:val.hex : v:val})')
    for cs in a:css
        call map(cs.parents, 'type(v:val)=='.type(0).' ? '.
                    \           'a:repo.cslist[v:val].hex : '.
                    \           'v:val')
        for parenthex in cs.parents
            call add(a:repo.changesets[parenthex].children, cs.hex)
        endfor
    endfor
endfunction
"▶2 unesc :: String → String
let s:F.unesc=function('eval')
"▶2 refile :: path → path
function s:F.refile(path)
    return join(s:_r.os.path.split(a:path)[1:], '/')
endfunction
"▶2 parsecs :: csdata, lstart::UInt → (cs, line::UInt)
let s:stylefile=s:_r.os.path.join(s:_frawor.runtimepath,
                \                 'misc', 'map-cmdline.csinfo')
let s:chars = [['P', 'parents'  ],
            \  ['T', 'tags'     ],
            \  ['B', 'bookmarks']]
let s:fchars= [['C', 'changes'  ],
            \  ['R', 'removes'  ]]
function s:F.parsecs(csdata, lstart)
    "▶3 Initialize variables, check for changeset start
    let cs={}
    let line=a:lstart
    let lcsdata=len(a:csdata)
    if lcsdata<6 || a:csdata[line] isnot# ':'
        call s:_f.throw('parsefail')
    endif
    let line+=1
    "▶3 Simple keys: rev, hex, branch, time, user
    let cs.rev    = str2nr(a:csdata[line])    | let line+=1
    let cs.hex    = a:csdata[line]            | let line+=1
    let cs.branch = s:F.unesc(a:csdata[line]) | let line+=1
    let cs.time   = str2nr(a:csdata[line])    | let line+=1
    let cs.user   = s:F.unesc(a:csdata[line]) | let line+=1
    "▶3 List keys: parents, tags, bookmarks, changes, removes
    for [char, key] in s:chars
        let cs[key]=[]
        while line<lcsdata && a:csdata[line][0] is# char
            let cs[key]+=[s:F.unesc(a:csdata[line][1:])]
            let line+=1
        endwhile
    endfor
    "▶3 List file keys: changes, removes
    for [char, key] in s:fchars
        let cs[key]=[]
        while line<lcsdata && a:csdata[line][0] is# char
            let cs[key]+=[s:F.refile(s:F.unesc(a:csdata[line][1:]))]
            let line+=1
        endwhile
    endfor
    "▶3 Add data to cs.parents in case it is empty
    if empty(cs.parents)
        if cs.rev>0
            let cs.parents=[cs.rev-1]
        else
            let cs.parents=[s:nullrev]
        endif
    endif
    "▶3 Filter cs.removes, add cs.files
    call filter(cs.removes, 'index(cs.changes, v:val)!=-1')
    let cs.files=filter(copy(cs.changes), 'index(cs.removes, v:val)==-1')
    "▶3 Copies, renames
    let copies={}
    while line<lcsdata && a:csdata[line][0] is# 'D'
        let copies[s:F.refile(s:F.unesc(a:csdata[line][1:]))]=
                    \                   s:F.refile(s:F.unesc(a:csdata[line+1]))
        let line+=2
    endwhile
    let cs.copies  = filter(copy(copies), 'index(cs.removes, v:val)==-1')
    let cs.renames = filter(copy(copies), '!has_key(cs.copies, v:key)')
    "▶3 Description
    let cs.description=s:F.unesc(a:csdata[line][1:])
    let line+=1
    "▲3
    return [cs, line]
endfunction
"▶2 getcslist :: repo, start, end
function s:F.getcslist(repo, start, end)
    let kwargs={'style': s:stylefile}
    let lines=s:F.hg(a:repo, 'log', [],
                \    extend({'rev': a:start.'..'.a:end}, kwargs), 0, 'log')[:-2]
    let css=[]
    if has_key(a:repo.changesets, s:nullrev)
        let cs0=a:repo.changesets[s:nullrev]
    else
        let lines0=s:F.hg(a:repo, 'log', [], extend({'rev': s:nullrev}, kwargs),
                    \     0, 'log')
        let cs0=s:F.parsecs(lines0, 0)[0]
    endif
    let llines=len(lines)
    let line=0
    let prevrev=-1
    while line<llines
        let [cs, line]=s:F.parsecs(lines, line)
        if cs.rev-prevrev!=1
            let css+=map(range(prevrev+1, cs.rev-1),
                        \'s:F.parsecs(s:F.hg(a:repo, "log", [], '.
                        \            'extend({"rev": "".v:val}, kwargs), 0, '.
                        \            '"log"), 0)[0]')
        endif
        let css+=[cs]
        let prevrev=cs.rev
    endwhile
    let cs0.rev=len(css)
    let css+=[cs0]
    return css
endfunction
"▶2 getkeylist :: repo, key → [(name, rev)]
function s:F.getkeylist(repo, key)
    let lines=s:F.hg(a:repo, a:key, [], {}, 0, 'key', a:key)[:-2]
    if len(lines)==1 && lines[0]!~#'\v\ [1-9]\d*\:\x{12}$'
        return []
    endif
    return map(copy(lines), 'matchlist(v:val, '.
                \                         '''\v^(.{-})\ +(\d+)\:\x{12}'')[1:2]')
endfunction
"▲2
let s:F.runcmd=s:F.runshellcmd
endif
"▶1 hg.updatechangesets :: repo → + repo
"▶2 python
if s:usepythondriver
    function s:F.getupdates(repo, start)
        let d={}
        try
            " XXX get_updates also modifies a:repo
            execute s:_r.py.cmd 'aurum.get_updates(vim.eval("a:repo.path"), '.
                        \                          a:start.')'
        endtry
        return d
    endfunction
"▶2 no python
else
    function s:F.getupdates(repo, start)
        let r={}
        let tip_hex=a:repo.functions.getrevhex(a:repo, 'tip')
        if a:start
            try
                let oldtip=a:repo.functions.getcs(a:repo, a:start)
                if tip_hex is# oldtip.hex
                    return r
                endif
                let startrev=oldtip.rev
            catch
                let startrev=0
            endtry
        else
            let startrev=0
        endif
        let r.startrev=startrev
        let r.css=s:F.getcslist(a:repo, startrev, -1)
        for key in ['tags', 'bookmarks']
            let list=s:F.getkeylist(a:repo, key)
            let r[key]={}
            for [name, rev] in filter(copy(list), 'v:val[1]<'.a:start)
                let r[key][name]=a:repo.cslist[rev].hex
            endfor
        endfor
        let a:repo.csnum=a:start+len(r.css)
        return r
    endfunction
endif
"▶2 hg.updatechangesets
" TODO test updating in cases of rollback
function s:hg.updatechangesets(repo)
    let d={}
    let start=len(a:repo.cslist)-2
    if start<0
        let start=0
    endif
    " XXX getupdates may also modify repo
    let d=s:F.getupdates(a:repo, start)
    if empty(d)
        return a:repo
    endif
    call map(d.css, 'extend(v:val, {"children": []})')
    if !empty(a:repo.cslist)
        call s:F.removechangesets(a:repo, d.startrev)
    endif
    for key in ['tags', 'bookmarks']
        call map(a:repo.cslist, 'extend(v:val, {key : []})')
        for [name, hex] in filter(items(d[key]),
                    \             'has_key(a:repo.changesets, v:val[1])')
            let cs=a:repo.changesets[hex]
            let cs[key]+=[name]
            call sort(cs[key])
        endfor
    endfor
    let a:repo.cslist+=d.css
    call s:F.addchangesets(a:repo, d.css)
    return a:repo
endfunction
"▶1 gettiphex :: repo → hex
function s:hg.gettiphex(repo)
    return a:repo.functions.getrevhex(a:repo, 'tip')
endfunction
"▶1 getworkhex :: repo → hex
function s:hg.getworkhex(repo)
    return a:repo.functions.getrevhex(a:repo, '.')
endfunction
"▶1 getwork :: repo → hex
function s:hg.getwork(repo)
    return a:repo.functions.getcs(a:repo, '.')
endfunction
"▶1 hg.repo :: path + ? → repo
if s:usepythondriver "▶2
function s:hg.repo(path)
    let repo={}
    try
        " execute s:_r.py.cmd 'import cProfile as profile'
        " execute s:_r.py.cmd 'profile.run("aurum.new_repo(vim.eval(''a:path''))", "python.profile")'
        execute s:_r.py.cmd 'aurum.new_repo(vim.eval("a:path"))'
    catch /\V\^Frawor:\[^:]\+:norepo:/
        return 0
    endtry
    let repo.hypsites=deepcopy(s:hypsites)
    let repo.iterfuncs=deepcopy(s:iterfuncs)
    return repo
endfunction
else "▶2
function s:hg.repo(path)
    " TODO remove bookmark label type if it is not available
    let repo={'path': a:path, 'changesets': {}, 'cslist': [],
                \'local': (stridx(a:path, '://')==-1),
                \'labeltypes': ['tag', 'bookmark'],
                \'has_octopus_merges': 0, 'requires_sort': 0,
                \'iterfuncs': deepcopy(s:iterfuncs),
                \'hypsites': deepcopy(s:hypsites),
                \'initprops': ['rev', 'hex', 'parents', 'tags', 'bookmarks',
                \              'branch', 'time', 'user', 'changes', 'removes',
                \              'copies', 'renames', 'files', 'description']}
    return repo
endfunction
endif
"▶1 hg.getchangesets :: repo → changesets + repo.changesets
function s:hg.getchangesets(repo)
    call a:repo.functions.updatechangesets(a:repo)
    return a:repo.cslist[:-2]
endfunction
"▶1 hg.revrange :: repo, rev, rev → [cs]
function s:hg.revrange(repo, rev1, rev2)
    if empty(a:repo.cslist)
        let cslist=a:repo.functions.getchangesets(a:repo)
    else
        let cslist=a:repo.cslist
    endif
    let rev1=a:repo.functions.getcs(a:repo, a:rev1).rev
    let rev2=a:repo.functions.getcs(a:repo, a:rev2).rev
    if rev1>rev2
        let [rev1, rev2]=[rev2, rev1]
    endif
    return cslist[(rev1):(rev2)]
endfunction
"▶1 iterfuncs
"▶2 iterfuncs.ancestors
let s:iterfuncs.ancestors={}
function s:iterfuncs.ancestors.start(repo, opts)
    let cs=a:repo.functions.getcs(a:repo,
                \a:repo.functions.getrevhex(a:repo, a:opts.revision))
    return {'addrevs': [cs], 'revisions': {}, 'repo': a:repo,
                \'hasrevisions': get(a:repo, 'hasrevisions', 1)}
endfunction
function! s:RevCmp(cs1, cs2)
    let rev1=a:cs1.rev
    let rev2=a:cs2.rev
    return ((rev1==rev2)?(0):((rev1<rev2)?(1):(-1)))
endfunction
let s:_functions+=['s:RevCmp']
function s:iterfuncs.ancestors.next(d)
    if empty(a:d.addrevs)
        return 0
    endif
    let cs=remove(a:d.addrevs, 0)
    if has_key(a:d.revisions, cs.hex)
        return s:iterfuncs.ancestors.next(a:d)
    endif
    let a:d.revisions[cs.hex]=cs
    let parents=map(copy(cs.parents),'a:d.repo.functions.getcs(a:d.repo,v:val)')
    call extend(a:d.addrevs, parents)
    if a:d.hasrevisions
        call sort(a:d.addrevs, 's:RevCmp')
    endif
    return cs
endfunction
"▶2 iterfuncs.revrange
let s:iterfuncs.revrange={}
function s:iterfuncs.revrange.start(repo, opts)
    let rev1=a:repo.functions.getcs(a:repo, a:opts.revrange[0]).rev
    let rev2=a:repo.functions.getcs(a:repo, a:opts.revrange[1]).rev
    if rev1>rev2
        let [rev1, rev2]=[rev2, rev1]
    endif
    return {'cur': rev2, 'last': rev1, 'repo': a:repo}
endfunction
function s:iterfuncs.revrange.next(d)
    if a:d.cur<a:d.last
        return 0
    endif
    let r=a:d.repo.functions.getcs(a:d.repo, a:d.cur)
    let a:d.cur-=1
    return r
endfunction
"▶2 iterfuncs.changesets
let s:iterfuncs.changesets={}
function s:iterfuncs.changesets.start(repo, opts)
    return {'cur': a:repo.functions.getcs(a:repo, 'tip').rev, 'last': 0,
                \'repo': a:repo}
endfunction
let s:iterfuncs.changesets.next=s:iterfuncs.revrange.next
"▶1 hg.getrevhex :: repo, rev → rev(hex)
if s:usepythondriver "▶2
function s:hg.getrevhex(repo, rev)
    try
        execute s:_r.py.cmd
                    \ 'vim.command(''return "''+'.
                    \    'aurum.g_cs(aurum.g_repo(vim.eval("a:repo.path")), '.
                    \               'vim.eval("a:rev")).hex()+''"'')'
    catch /\v^Frawor:/
        throw v:exception
    catch
        call s:_f.throw('norev', a:rev, a:repo.path)
    endtry
endfunction
else "▶2
let s:getrevhextemplate='{node}'
function s:hg.getrevhex(repo, rev)
    if type(a:rev)==type('') && (has_key(a:repo.changesets, a:rev) ||
                \                a:rev=~#'\v^[0-9a-f]{40}$')
        return a:rev
    elseif type(a:rev)==type(0) && a:rev<len(a:repo.cslist)
        return a:repo.cslist[a:rev].hex
    endif
    let hex=get(s:F.hg(a:repo, 'log', [], {'template': s:getrevhextemplate,
                \                               'rev': ''.a:rev}, 0, 'log'),0,0)
    if hex is 0
        call s:_f.throw('norev', a:rev, a:repo.path)
    endif
    return hex
endfunction
endif
"▶1 hg.readfile :: repo, rev, file → [String]
if s:usepythondriver "▶2
function s:hg.readfile(repo, rev, file)
    let r=[]
    try
        execute s:_r.py.cmd 'aurum.get_file(vim.eval("a:repo.path"), '.
                    \                      'vim.eval("a:rev"), '.
                    \                      'vim.eval("a:file"))'
    endtry
    return r
endfunction
else "▶2
function s:hg.readfile(repo, rev, file)
    return s:F.hg(a:repo, 'cat', ['--',a:file], {'rev': ''.a:rev}, 2,
                \ 'file', a:file)
endfunction
endif
"▶1 hg.annotate :: repo, rev, file → [(file, rev, linenumber)]
if s:usepythondriver "▶2
function s:hg.annotate(repo, rev, file)
    let r=[]
    try
        execute s:_r.py.cmd 'aurum.annotate(vim.eval("a:repo.path"), '.
                    \                      'vim.eval("a:rev"), '.
                    \                      'vim.eval("a:file"))'
    endtry
    return r
endfunction
else "▶2
function s:hg.annotate(repo, rev, file)
    let r=[]
    let lines=s:F.hg(a:repo, 'annotate', ['--', a:file],
                \    {'rev': ''.a:rev, 'file':1, 'number':1, 'line-number':1},
                \    1, 'ann', a:rev, a:file)
    for line in lines
        " XXX This won't work for files that start with spaces and also with 
        " some other unusual filenames that can be present in a repository
        let match=matchlist(line, '\v^\s*(\d+)\ +(.{-})\:\s*([1-9]\d*)\:\ ')
        if empty(match)
            call s:_f.throw('annfail', a:rev, a:file, line)
        endif
        let r+=[[match[2], match[1], str2nr(match[3])]]
    endfor
    return r
endfunction
endif
"▶1 hg.setcsprop :: repo, cs, propname → a
if s:usepythondriver "▶2
function s:hg.setcsprop(repo, cs, prop)
    try
        execute s:_r.py.cmd 'aurum.get_cs_prop(vim.eval("a:repo.path"), '.
                    \                         'vim.eval("a:cs.hex"), '.
                    \                         'vim.eval("a:prop"))'
    endtry
endfunction
else "▶2
function s:hg.setcsprop(repo, cs, prop)
    if a:prop is# 'allfiles'
        let r=s:F.hg(a:repo, 'manifest', [], {'rev': a:cs.hex}, 0,
                    \'csp', a:prop, a:cs.rev)[:-2]
    elseif a:prop is# 'children'
        " XXX str2nr('123:1f6de') will return number 123
        let r=map(split(s:F.hg(a:repo, 'log', [],
                    \          {'rev': a:cs.hex, 'template': '{children}'},
                    \          0, 'csp', a:prop, a:cs.rev)[0]), 'str2nr(v:val)')
        if empty(a:repo.cslist)
            call map(r, 'a:repo.functions.getrevhex(a:repo, v:val)')
        else
            call map(r, 'a:repo.cslist[v:val].hex')
        endif
    endif
    let a:cs[a:prop]=r
    return r
endfunction
endif
"▶1 hg.getcs :: repo, rev → cs
"▶2 getcs
if s:usepythondriver "▶3
function s:F.getcs(repo, rev)
    let cs={}
    try
        execute s:_r.py.cmd 'aurum.get_cs(vim.eval("a:repo.path"), '.
                    \                    'vim.eval("a:rev"))'
    endtry
    return cs
endfunction
else "▶3
function s:F.getcs(repo, rev)
    let csdata=s:F.hg(a:repo, 'log', [], {'rev': a:rev, 'style': s:stylefile},0,
                \     'cs', a:rev)
    let cs=s:F.parsecs(csdata, 0)[0]
    call map(cs.parents,
                \'type(v:val)=='.type(0).'? '.
                \   'a:repo.functions.getrevhex(a:repo, v:val): '.
                \   'v:val')
    return cs
endfunction
endif
"▲2
function s:hg.getcs(repo, rev)
    if !empty(a:repo.cslist)
        if type(a:rev)==type('') && has_key(a:repo.changesets, a:rev)
            return a:repo.changesets[a:rev]
        elseif type(a:rev)==type(0) && a:rev<a:repo.csnum
            return a:repo.cslist[a:rev]
        endif
    endif
    let hex=a:repo.functions.getrevhex(a:repo, a:rev)
    if has_key(a:repo.changesets, hex) && !empty(a:repo.cslist)
        return a:repo.changesets[hex]
    else
        let cs=s:F.getcs(a:repo, hex)
        let a:repo.changesets[hex]=cs
        return cs
    endif
endfunction
"▶1 hg.diff :: repo, rev1, rev2, [path], opts → diff::[String]
"▶2 s:difftrans
let s:difftrans={
            \      'git': 'git',
            \  'reverse': 'reverse',
            \ 'ignorews': 'ignore_all_space',
            \'iwsamount': 'ignore_space_change',
            \  'iblanks': 'ignore_blank_lines',
            \ 'numlines': 'unified',
            \ 'showfunc': 'show_function',
            \  'alltext': 'text',
            \    'dates': 'nodates',
        \}
if s:usepythondriver "▶2
function s:hg.diff(repo, rev1, rev2, files, opts)
    let r=[]
    let diffopts=s:_r.utils.diffopts(a:opts, a:repo.diffopts, s:difftrans)
    try
        execute s:_r.py.cmd 'aurum.diff(vim.eval("a:repo.path"), '.
                    \                  'vim.eval("a:rev1"), '.
                    \                  'vim.eval("a:rev2"), '.
                    \                  'vim.eval("a:files"), '.
                    \                  'vim.eval("diffopts"))'
    endtry
    return r
endfunction
else "▶2
"▶3 getdiffargs
function s:F.getdiffargs(repo, rev1, rev2, files, opts)
    let diffopts=s:_r.utils.diffopts(a:opts, a:repo.diffopts, s:difftrans)
    let args=[]
    let kwargs={}
    let rev1=((empty(a:rev1))?(0):(''.a:rev1))
    let rev2=((empty(a:rev2))?(0):(''.a:rev2))
    if rev2 is 0
        if rev1 isnot 0
            let kwargs.change=''.rev1
        endif
    elseif rev1 isnot 0
        let args+=['--rev', rev2, '--rev', rev1]
    else
        let kwargs.rev=rev2
    endif
    for [o, v] in items(diffopts)
        if o is# 'unified'
            let kwargs[o]=''.v
        elseif v
            let kwargs[tr(o, '_', '-')]=1
        endif
    endfor
    if !empty(a:files)
        let args+=['--']+a:files
    endif
    return [a:repo, 'diff', args, kwargs, 1]
endfunction
"▲3
function s:hg.diff(repo, rev1, rev2, files, opts)
    let args=s:F.getdiffargs(a:repo, a:rev1, a:rev2, a:files, a:opts)
    return call(s:F.hg, args+['diff', a:rev1, a:rev2, join(a:files, ', ')], {})
                \+['']
endfunction
endif
"▶1 hg.difftobuffer :: repo, buf, rev1, rev2, [path], opts → [String]
if s:usepythondriver "▶2
function s:hg.difftobuffer(repo, buf, rev1, rev2, files, opts)
    let r=[]
    let oldbuf=bufnr('%')
    if oldbuf!=a:buf
        execute 'buffer' a:buf
    endif
    try
        let diffopts=s:_r.utils.diffopts(a:opts, a:repo.diffopts, s:difftrans)
        execute s:_r.py.cmd 'aurum.diffToBuffer(vim.eval("a:repo.path"), '.
                    \                          'vim.eval("a:rev1"), '.
                    \                          'vim.eval("a:rev2"), '.
                    \                          'vim.eval("a:files"), '.
                    \                          'vim.eval("diffopts"))'
    finally
        if oldbuf!=a:buf
            execute 'buffer' oldbuf
        endif
    endtry
endfunction
else "▶2
function s:hg.difftobuffer(repo, buf, rev1, rev2, files, opts)
    let args=s:F.getdiffargs(a:repo, a:rev1, a:rev2, a:files, a:opts)
    let cmd=call(s:F.hgcmd, args, {})
    let oldbuf=bufnr('%')
    if oldbuf!=a:buf
        execute 'buffer' a:buf
    endif
    try
        execute '%!'.cmd
    finally
        if oldbuf!=a:buf
            execute 'buffer' oldbuf
        endif
    endtry
endfunction
endif
"▶1 hg.status :: repo[, rev1[, rev2[, files[, clean]]]] → {type : [file]}
" type :: "modified" | "added" | "removed" | "deleted" | "unknown" | "ignored"
"       | "clean"
if s:usepythondriver "▶2
function s:hg.status(repo, ...)
    let revargs=join(map(copy(a:000), 'v:val is 0? "None": string(v:val)'), ',')
    let r={}
    try
        execute s:_r.py.cmd 'aurum.get_status(vim.eval("a:repo.path"), '.
                    \                         revargs.')'
    endtry
    return r
endfunction
else "▶2
let s:statchars={
            \'M': 'modified',
            \'A': 'added',
            \'R': 'removed',
            \'!': 'deleted',
            \'?': 'unknown',
            \'I': 'ignored',
            \'C': 'clean',
        \}
let s:initstatdct={}
call map(values(s:statchars), 'extend(s:initstatdct, {v:val : []})')
" TODO test whether zero revision may cause bugs in some commands
function s:hg.status(repo, ...)
    let args=[]
    let kwargs={'modified': 1,
                \  'added': 1,
                \'removed': 1,
                \'deleted': 1,
                \'unknown': 1,
                \'ignored': 1}
    if (a:0>3 && a:4)
        let kwargs.clean=1
    endif
    let reverse=0
    if a:0
        if a:1 is 0
            if a:0>1 && a:2 isnot 0
                let reverse=1
            endif
        else
            let args+=['--rev', a:1]
        endif
        if a:0>1 && a:2 isnot 0
            let args+=['--rev', a:2]
        endif
        if a:0>2 && !empty(a:3)
            let args+=['--']+a:3
        endif
    endif
    let slines=s:F.hg(a:repo, 'status', args, kwargs, 0, 'stat')[:-2]
    if !empty(filter(copy(slines), '!has_key(s:statchars, v:val[0])'))
        call s:_f.throw('statfail', a:repo.path, join(slines, "\n"))
    endif
    let r=deepcopy(s:initstatdct)
    call map(copy(slines),'add(r[s:statchars[v:val[0]]],s:F.refile(v:val[2:]))')
    if reverse
        let [r.deleted, r.unknown]=[r.unknown, r.deleted]
        let [r.added,   r.removed]=[r.removed, r.added  ]
    endif
    return r
endfunction
endif
"▶1 hg.commit :: repo, message[, files[, user[, date[, closebranch[, force]]]]]
function s:hg.commit(repo, message, ...)
    let kwargs={}
    let args=[]
    if a:0
        if !empty(a:1)
            let args+=a:1
            let kwargs.addremove=1
        endif
        if a:0>1 && !empty(a:2)
            let kwargs.user=a:2
        endif
        if a:0>2 && !empty(a:3)
            let kwargs.date=a:3
        endif
        if a:0>3 && !empty(a:4)
            let kwargs.close_branch=1
        endif
    endif
    return s:_r.utils.usefile(a:repo, a:message, 'logfile', 'message',
                \             s:F.runcmd, args, kwargs)
endfunction
"▶1 hg.update :: repo, rev, force
if s:usepythondriver "▶2
function s:hg.update(repo, rev, force)
    try
        execute s:_r.py.cmd 'aurum.update(vim.eval("a:repo.path"), '.
                    \                    'vim.eval("a:rev"), '.
                    \                    'int(vim.eval("a:force")))'
    endtry
endfunction
else "▶2
function s:hg.update(repo, rev, force)
    call s:F.runcmd(a:repo, 'update', [], {'clean': !empty(a:force),
                \                            'rev': ((type(a:rev)==type(0))?
                \                                       string(a:rev):
                \                                       a:rev)})
endfunction
endif
"▶1 hg.dirty :: repo, file → Bool
if s:usepythondriver "▶2
function s:hg.dirty(repo, file)
    try
        let r=0
        execute s:_r.py.cmd 'aurum.dirty(vim.eval("a:repo.path"), '.
                    \                   'vim.eval("a:file"))'
        return r
    endtry
endfunction
endif
"▶1 diffre :: _, opts → regex
function s:hg.diffre(repo, opts)
    " XXX first characters must be identical for hg.getstats(), but it must not 
    " match lines not containing filename for getdifffile()
    if get(a:opts, 'git', 0)
        return '\m^diff \V--git a/\(\.\{-}\) b/'
    else
        return '\m^diff \v.*\-r\ \w+\s(.*)$'
    endif
endfunction
"▶1 hg.getrepoprop :: repo, prop → a
if s:usepythondriver "▶2
function s:hg.getrepoprop(repo, prop)
    let d={}
    try
        execute s:_r.py.cmd 'aurum.get_repo_prop(vim.eval("a:repo.path"), '.
                    \                           'vim.eval("a:prop"))'
    endtry
    return a:repo[a:prop]
endfunction
else "▶2
function s:hg.getrepoprop(repo, prop)
    if a:prop is# 'tagslist' || a:prop is# 'brancheslist' ||
                \               a:prop is# 'bookmarkslist'
        return map(copy(s:F.getkeylist(a:repo, a:prop[:-5])), 'v:val[0]')
    elseif a:prop is# 'url'
        let lines=s:F.hg(a:repo, 'showconfig', ['paths'], {}, 0, 'sc')[:-2]
        let confs={}
        call map(lines, 'matchlist(v:val, ''\v^paths\.([^=]+)\=(.*)$'')[1:2]')
        call map(copy(lines), 'extend(confs, {v:val[0]: v:val[1]})')
        if has_key(confs, 'default-push')
            return confs['default-push']
        elseif has_key(confs, 'default')
            return confs.default
        endif
    endif
    call s:_f.throw('nocfg', a:prop, a:repo.path)
endfunction
endif
"▶1 hg.move :: repo, force, source, target → + FS
function s:hg.move(repo, force, ...)
    return s:F.runcmd(a:repo, 'rename', a:000, a:force ? {'force': 1} : {})
endfunction
"▶1 hg.copy :: repo, force, source, target → + FS
function s:hg.copy(repo, force, ...)
    return s:F.runcmd(a:repo, 'copy', a:000, a:force ? {'force': 1} : {})
endfunction
"▶1 hg.forget :: repo, file → + FS
function s:hg.forget(repo, ...)
    return s:F.runcmd(a:repo, 'forget', a:000, {})
endfunction
"▶1 hg.remove :: repo, file → + FS
function s:hg.remove(repo, ...)
    return s:F.runcmd(a:repo, 'remove', a:000, {})
endfunction
"▶1 hg.add :: repo, file → + FS
function s:hg.add(repo, ...)
    return s:F.runcmd(a:repo, 'add', a:000, {})
endfunction
"▶1 hg.branch :: repo, branchname, force → + FS
function s:hg.branch(repo, branch, force)
    return s:F.runcmd(a:repo, 'branch', [a:branch], a:force ? {'force': 1} : {})
endfunction
"▶1 hg.label :: repo, type, label, rev, force, local → + FS
function s:hg.label(repo, type, label, rev, force, local)
    let kwargs={}
    if a:force
        let kwargs.force=1
    endif
    if a:type is# 'tag'
        if a:local
            let kwargs.local=1
        endif
        if a:rev is 0
            let kwargs.remove=1
        else
            let kwargs.rev=a:rev
        endif
    elseif a:type is# 'bookmark'
        if a:local
            call s:_f.throw('nlocbms')
        endif
        if a:rev is 0
            let kwargs.delete=1
        else
            let kwargs.rev=a:rev
        endif
    endif
    return s:F.runcmd(a:repo, a:type, [a:label], kwargs)
endfunction
"▶1 addtosection :: repo, hgignore::path, section, line → + FS(hgignore)
function s:F.addtosection(repo, hgignore, section, line)
    let addsect=['syntax: '.a:section,
                \a:line,
                \'']
    if s:_r.os.path.exists(a:hgignore)
        if filewritable(a:hgignore)==1
            let lines=readfile(a:hgignore, 'b')
            let r=[]
            let addedline=0
            let foundsyntax=0
            for line in lines
                if !addedline
                    if line is# 'syntax: '.a:section
                        let foundsyntax=1
                    elseif line[:6] is# 'syntax:' && foundsyntax
                        if empty(r[-1])
                            call remove(r, -1)
                            let r+=[a:line, '']
                        else
                            let r+=[a:line]
                        endif
                        let addedline=1
                    endif
                endif
                let r+=[line]
            endfor
            if !addedline
                if foundsyntax
                    if empty(r[-1])
                        call remove(r, -1)
                        let r+=[a:line, '']
                    else
                        let r+=[a:line]
                    endif
                else
                    let r+=addsect
                endif
            endif
            return writefile(r, a:hgignore, 'b')
        else
            call s:_f.throw('nhgiwr', a:hgignore)
        endif
    elseif filewritable(a:repo.path)==2
        return writefile(addsect, a:hgignore, 'b')
    else
        call s:_f.throw('reponwr', a:repo.path)
    endif
endfunction
"▶1 hg.ignore :: repo, file → +FS
let s:usepython=0
if has_key(s:_r, 'py')
    try
        execute s:_r.py.cmd 'import json, re'
        let s:usepython=1
    catch
        " s:usepython stays equal to 0, errors are ignored
    endtry
endif
if s:usepython "▶2
function s:hg.ignore(repo, file)
    let d={}
    execute s:_r.py.cmd 'vim.eval("extend(d, {''pattern'': "+'.
                \              'json.dumps(re.escape(vim.eval("a:file")))+"})")'
    let hgignore=s:_r.os.path.join(a:repo.path, '.hgignore')
    let reline='^'.d.pattern.'$'
    return s:F.addtosection(a:repo, hgignore, 'regexp', reline)
endfunction
else "▶2
function s:hg.ignore(repo, file)
    let hgignore=s:_r.os.path.join(a:repo.path, '.hgignore')
    return s:F.addtosection(a:repo, hgignore, 'glob', escape(a:file, '\*[{}]?'))
endfunction
endif
"▶1 hg.ignoreglob :: repo, glob → + FS
function s:hg.ignoreglob(repo, glob)
    let hgignore=s:_r.os.path.join(a:repo.path, '.hgignore')
    return s:F.addtosection(a:repo, hgignore, 'glob', a:glob)
endfunction
"▶1 hg.grep :: repo, pattern, files, revisions, ignore_case, wdfiles → qflist
" revisions :: [Either rev (rev, rev)]
if s:usepythondriver "▶2
function s:hg.grep(repo, pattern, files, revisions, ignore_case, wdfiles)
    let r=[]
    execute s:_r.py.cmd 'aurum.grep(vim.eval("a:repo.path"), '.
                \                  'vim.eval("a:pattern"), '.
                \                  'vim.eval("a:files"), '.
                \                  'vim.eval("a:revisions"), '.
                \                  'bool(int(vim.eval("a:ignore_case"))), '.
                \                  'bool(int(vim.eval("a:wdfiles"))))'
    return r
endfunction
else "▶2
"▶3 checknotmodifiedsince
function s:F.checknotmodifiedsince(repo, rev, file, cache)
    let key=a:rev.':'.a:file
    if has_key(a:cache, key)
        return a:cache[key]
    endif
    let status=a:repo.functions.status(a:repo, a:rev, 0, [a:file])
    let r=(!empty(status.clean) && a:file is# status.clean[0])
    let a:cache[key]=r
    return r
endfunction
"▲3
function s:hg.grep(repo, pattern, files, revisions, ignore_case, wdfiles)
    let args=map(copy(a:revisions),
            \                '((type(v:val)=='.type([]).')?'.
            \                   '("--rev=".join(v:val, "..")):'.
            \                   '("--rev=".v:val))')+
            \['--', a:pattern]+a:files
    let kwargs={'follow': 1, 'line-number': 1}
    if a:ignore_case
        let kwargs['ignore-case']=1
    endif
    let lines=s:F.hg(a:repo, 'grep', args, kwargs, 1)
    if v:shell_error
        " Grep failed because it has found nothing
        if lines ==# ['']
            return []
        " Grep failed for another reason
        else
            call s:_f.throw('grepfail', a:repo.path, join(lines, "\n"))
        endif
    endif
    let r=[]
    let cnmscache={}
    for line in lines
        let match=matchlist(line, '\v^(.{-})\:(0|[1-9]\d*)\:([1-9]\d*)\:(.*)$')
        if empty(match)
            call s:_f.throw('grepfail', a:repo.path, line)
        endif
        let [file, rev, lnum, text]=match[1:4]
        if a:wdfiles && s:F.checknotmodifiedsince(a:repo, rev, file, cnmscache)
            let filename=s:_r.os.path.normpath(s:_r.os.path.join(a:repo.path,
                        \                      file))
        else
            let filename=[rev, file]
        endif
        let r+=[{'filename': filename, 'lnum': lnum, 'text': text}]
        unlet filename
    endfor
    return r
endfunction
endif
"▶1 hg.checkdir :: dir → Bool
function s:hg.checkdir(dir)
    return s:_r.os.path.isdir(s:_r.os.path.join(a:dir, '.hg'))
endfunction
"▶1 Register driver
call s:_f.regdriver('Mercurial', s:hg)
"▶1
call frawor#Lockvar(s:, '_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
