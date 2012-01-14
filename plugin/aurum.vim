"▶1 Первая загрузка
scriptencoding utf-8
if !exists('s:_pluginloaded')
    "▶2 frawor#Setup
    execute frawor#Setup('0.1', {'@/commands': '0.0',
                \               '@/functions': '0.0',
                \                   '@/table': '0.0',
                \                '@/mappings': '0.0',
                \                 '@/options': '0.0',
                \                      '@/os': '0.1',
                \           '@aurum/cmdutils': '0.0',
                \                     '@/fwc': '0.2',
                \           '@aurum/annotate': '0.0',
                \             '@aurum/status': '0.0',
                \                '@aurum/log': '0.0',
                \             '@aurum/commit': '0.0',
                \               '@aurum/repo': '2.0',
                \               '@aurum/edit': '1.0',
                \            '@aurum/bufvars': '0.0',
                \            '@aurum/vimdiff': '0.0',}, 0)
    "▶2 Команды
    call FraworLoad('@/commands')
    call FraworLoad('@/functions')
    " TODO improve files completion
    " TODO :AuMerge ?
    " TODO :AuExplore
    let s:addargs={'Update': {'bang': 1}, 'Move': {'bang': 1},
                \  'Branch': {'bang': 1}, 'Name': {'bang': 1}}
    for s:cmd in ['Update', 'Move', 'Junk', 'Track', 'Hyperlink', 'Grep',
                \ 'Branch', 'Name']
        let s:part=tolower(s:cmd[:3])
        if len(s:cmd)>4 && stridx('aeiouy', s:part[-1:])!=-1
            let s:part=s:part[:-2]
        endif
        let s:{s:part}func={}
        let s:{s:part}comp=[]
        let s:args={'nargs': '*', 'complete': s:{s:part}comp}
        if has_key(s:addargs, s:cmd)
            call extend(s:args, s:addargs[s:cmd])
        endif
        call s:_f.command.add('Au'.s:cmd, s:{s:part}func, s:args)
    endfor
    unlet s:cmd s:addargs s:args s:part
    "▶2 Global mappings
    call FraworLoad('@/mappings')
    " TODO mapping that closes status window
    call s:_f.mapgroup.add('Aurum', {
                \'Commit':    {'lhs':  'i', 'rhs': ':<C-u>AuCommit<CR>'          },
                \'CommitAll': {'lhs':  'I', 'rhs': ':<C-u>AuCommit **<CR>'       },
                \'ROpen':     {'lhs':  'o', 'rhs': ':<C-u>AuFile<CR>'            },
                \'Revert':    {'lhs':  'O', 'rhs': ':<C-u>AuFile . : replace<CR>'},
                \'Vdiff':     {'lhs':  'D', 'rhs': ':<C-u>AuVimDiff<CR>'         },
                \'FVdiff':    {'lhs': 'gD', 'rhs': ':<C-u>AuVimDiff full<CR>'    },
                \'Diff':      {'lhs':  'd', 'rhs': ':<C-u>AuDiff :<CR>'          },
                \'Fdiff':     {'lhs': 'gd', 'rhs': ':<C-u>AuDiff<CR>'            },
                \'Annotate':  {'lhs':  'a', 'rhs': ':<C-u>AuAnnotate<CR>'        },
                \'Status':    {'lhs':  's', 'rhs': ':<C-u>AuStatus|wincmd p<CR>' },
                \'Record':    {'lhs':  'r', 'rhs': ':<C-u>AuRecord<CR>'          },
                \'Log':       {'lhs':  'L', 'rhs': ':<C-u>AuLog<CR>'             },
                \'LogFile':   {'lhs':  'l', 'rhs': ':<C-u>AuLog : files :<CR>'   },
                \'URL':       {'lhs':  'H', 'rhs': ':<C-u>AuHyperlink<CR>'       },
                \'LineURL':   {'lhs':  'h', 'rhs': ':<C-u>AuHyperlink line 0<CR>'},
                \'Track':     {'lhs':  'A', 'rhs': ':<C-u>AuTrack<CR>'           },
                \'Forget':    {'lhs':  'R', 'rhs': ':<C-u>AuJunk forget :<CR>'   },
            \}, {'mode': 'n', 'silent': 1, 'leader': '<Leader>a'})
    "▲2
    finish
elseif s:_pluginloaded
    finish
endif
"▶1 Globals
let s:_messages={
            \ 'uknurl': 'Failed to process url %s of repository %s',
            \ 'uunsup': 'Url type “%s” is not supported for repository %s '.
            \           'linked with %s',
            \'nofiles': 'No files were specified',
            \   'nogf': 'No files found',
            \  'nrepo': 'Not a repository: %s',
            \ 'bexsts': 'Error while creating branch %s for repository %s: '.
            \           'branch already exists',
            \ 'nunsup': 'Naming is not supported for repository %s',
            \'ukntype': 'Unknown label type: %s. Supported types: %s',
            \   'ldef': 'Label %s with type %s was alredy defined',
            \'_mvheader': ['Source', 'Destination'],
        \}
let s:utypes=['html', 'raw', 'annotate', 'filehist', 'bundle', 'changeset',
            \ 'log', 'clone', 'push']
let s:_options={
            \'workdirfiles': {'default': 1,
            \                  'filter': 'bool',},
            \'hypsites': {'default': [],
            \             'checker': 'list tuple ((type ""), '.
            \                                    'dict {?in utypes     type ""'.
            \                                          '/\v^[ah]line$/ type ""'.
            \                                         '})'
            \            },
        \}
"▶1 getexsttrckdfiles
function s:F.getexsttrckdfiles(repo, ...)
    let cs=a:repo.functions.getwork(a:repo)
    let r=copy(a:repo.functions.getcsprop(a:repo, cs, 'allfiles'))
    let status=a:repo.functions.status(a:repo)
    call filter(r, 'index(status.removed, v:val)==-1 && '.
                \  'index(status.deleted, v:val)==-1')
    let r+=status.added
    if a:0 && a:1
        let r+=status.unknown
    endif
    return r
endfunction
"▶1 getaddedermvdfiles
function s:F.getaddedermvdfiles(repo)
    let status=a:repo.functions.status(a:repo)
    return status.unknown+filter(copy(status.removed),
                \         'filereadable(s:_r.os.path.join(a:repo.path, v:val))')
endfunction
"▶1 filterfiles
function s:F.filterfiles(repo, globs, files)
    let r=[]
    for pattern in map(copy(a:globs), 's:_r.globtopat('.
                \                     'a:repo.functions.reltorepo(a:repo, '.
                \                                                'v:val))')
        let r+=filter(copy(a:files), 'v:val=~#pattern && index(r, v:val)==-1')
    endfor
    return r
endfunction
"▶1 urlescape :: String → String
function s:F.urlescape(str)
    let r=''
    let lstr=len(a:str)
    let i=0
    while i<lstr
        let c=a:str[i]
        if c=~#'^[^A-Za-z0-9\-_.!~*''()/]'
            let r.=printf('%%%02X', char2nr(c))
        else
            let r.=c
        endif
        let i+=1
    endwhile
    return r
endfunction
"▶1 updfunc
function s:updfunc.function(bang, rev, repopath)
    let repo=s:_r.repo.get(a:repopath)
    call s:_r.cmdutils.checkrepo(repo)
    if a:rev is 0
        let rev=repo.functions.gettiphex(repo)
    else
        let rev=repo.functions.getrevhex(repo, a:rev)
    endif
    return repo.functions.update(repo, rev, a:bang)
endfunction
let s:updfunc['@FWC']=['-onlystrings _ '.
            \          '[:=(0) type ""'.
            \          '['.s:_r.cmdutils.nogetrepoarg.']]', 'filter']
call add(s:updcomp,
            \substitute(substitute(substitute(s:updfunc['@FWC'][0],
            \'\V _',                '',            ''),
            \'\V|*_r.repo.get',     '',            ''),
            \'\V:=(0)\s\+type ""', s:_r.comp.rev, ''))
"▶1 movefunc
" :AuM          — move current file to current directory
" :AuM dir      — move current file to given directory
" :AuM pat  pat — act like `zmv -W': use second pat to construct new file name
" :AuM pat+ dir — move given file(s) to given directory
" :AuM pat+     — move given file(s) to current directory
function s:movefunc.function(bang, opts, ...)
    if a:0 && !get(a:opts, 'leftpattern', 0) && a:opts.repo is# ':'
        let repo=s:_r.repo.get(a:1)
    else
        let repo=s:_r.repo.get(a:opts.repo)
    endif
    call s:_r.cmdutils.checkrepo(repo)
    let allfiles=s:F.getexsttrckdfiles(repo)
    if get(a:opts, 'copy', 0)
        let key='copy'
    else
        let key='move'
    endif
    let rrfopts={'repo': repo.path}
    if a:0==0
        let target='.'
        let files=[repo.functions.reltorepo(repo,
                    \s:_r.cmdutils.getrrf(rrfopts, 'nocurf', -1)[3])]
    elseif a:0==1 && isdirectory(a:1)
        let target=a:1
        let files=[repo.functions.reltorepo(repo,
                    \s:_r.cmdutils.getrrf(rrfopts, 'nocurf', -1)[3])]
    elseif a:0>1 && get(a:opts, 'rightrepl', 0)
        let patterns=map(a:000[:-2], 's:_r.globtopat('.
                    \                'repo.functions.reltorepo(repo,v:val), 1)')
        let moves={}
        let repl=a:000[-1]
        for pattern in patterns
            for file in filter(copy(allfiles), 'v:val=~#pattern && '.
                        \                      '!has_key(moves, v:val)')
                let moves[file]=repo.functions.reltorepo(repo,
                            \               substitute(file, pattern, repl, ''))
            endfor
        endfor
    elseif a:0>1 && get(a:opts, 'leftpattern', 0)
        let moves={}
        let repl=a:000[-1]
        for pattern in a:000[:-2]
            for file in filter(copy(allfiles), 'v:val=~#pattern && '.
                        \                      '!has_key(moves, v:val)')
                let moves[file]=substitute(file, pattern, repl, '')
            endfor
        endfor
    elseif a:0==2 && a:2=~#'[*?]' &&
                \substitute(a:1, '\v%(^|$|\\.|[^*])[^*?]*', '-', 'g') is#
                \substitute(a:2, '\v%(^|$|\\.|[^*])[^*?]*', '-', 'g')
        let pattern=s:_r.globtopat(repo.functions.reltorepo(repo, a:1),
                    \                       1)
        let repl=split(a:2, '\V\(**\?\|?\)', 1)
        let moves={}
        for [file, match] in filter(map(copy(allfiles),
                    \                   '[v:val, matchlist(v:val, pattern)]'),
                    \               '!empty(v:val[1])')
            let target=''
            let i=1
            for s in repl
                let target .= s . get(match, i, '')
                let i+=1
            endfor
            let moves[file]=repo.functions.reltorepo(repo, target)
        endfor
    elseif a:0==2 && !isdirectory(a:2) && filewritable(a:1)
        let fst=a:1
        if fst is# ':'
            let fst=s:_r.cmdutils.getrrf(rrfopts, 'nocurf', -1)[3]
        endif
        let moves = {repo.functions.reltorepo(repo, fst):
                    \repo.functions.reltorepo(repo, a:2)}
    else
        let globs=filter(copy(a:000), 'v:val isnot# ":"')
        let hascur=(len(globs)!=a:0)
        if a:0==1 || !isdirectory(globs[-1])
            let target='.'
        else
            let target=remove(globs, -1)
        endif
        let files=s:F.filterfiles(repo, globs, allfiles)
        if hascur
            let files+=[s:_r.cmdutils.getrrf(rrfopts, 'nocurf', -1)[3]]
        endif
    endif
    if exists('files')
        let target=repo.functions.reltorepo(repo, target)
        if !exists('moves')
            let moves={}
        endif
        for file in files
            let dest=s:_r.os.path.basename(file)
            if !empty(target)
                let dest=s:_r.os.path.join(target, dest)
            endif
            let moves[file]=dest
        endfor
    endif
    if get(a:opts, 'pretend', 0)
        call s:_r.printtable(items(moves), {'header': s:_messages._mvheader})
    else
        call map(moves,'repo.functions.'.key.'(repo, '.a:bang.', v:key, v:val)')
    endif
endfunction
let s:movefunc['@FWC']=['-onlystrings _ '.
            \           '{  repo '.s:_r.cmdutils.nogetrepoarg.
            \           ' ?!copy ?!rightrepl ?!leftpattern ?!pretend } '.
            \           '+ type ""', 'filter']
call add(s:movecomp,
            \substitute(substitute(s:movefunc['@FWC'][0],
            \'\V _',        '',         ''),
            \'\V+ type ""', '+ (path)', ''))
"▶1 junkfunc
function s:junkfunc.function(opts, ...)
    if !a:0
        call s:_f.throw('nofiles')
    endif
    let repo=s:_r.repo.get(a:1)
    call s:_r.cmdutils.checkrepo(repo)
    let forget=get(a:opts, 'forget',      0)
    let ignore=get(a:opts, 'ignore',      0)
    let igglob=get(a:opts, 'ignoreglobs', 0)
    let remove=get(a:opts, 'remove',      !(forget || ignore || igglob))
    let allfiles=s:F.getexsttrckdfiles(repo, ignore)
    let globs=filter(copy(a:000), 'v:val isnot# ":"')
    let hascur=(len(globs)!=a:0)
    let files=s:F.filterfiles(repo, globs, allfiles)
    if hascur
        let rrfopts={'repo': repo.path}
        let files+=[repo.functions.reltorepo(repo,
                    \s:_r.cmdutils.getrrf(rrfopts, 'nocurf', -1)[3])]
    endif
    for key in filter(['forget', 'remove', 'ignore'], 'eval(v:val)')
        call map(copy(files), 'repo.functions[key](repo, v:val)')
    endfor
    if igglob
        call map(copy(globs), 'repo.functions.ignoreglob(repo, '.
                    \         'repo.functions.reltorepo(repo, v:val))')
    endif
endfunction
let s:junkfunc['@FWC']=['-onlystrings '.
            \           '{?!forget '.
            \            '?!ignore '.
            \            '?!remove '.
            \            '?!ignoreglobs '.
            \           '} + type ""', 'filter']
call add(s:junkcomp,
            \substitute(s:junkfunc['@FWC'][0],
            \'\V+ type ""', '+ (path)', ''))
"▶1 tracfunc
function s:tracfunc.function(...)
    let globs=filter(copy(a:000), 'v:val isnot# ":"')
    let hascur=!(a:0 && len(globs)==a:0)
    let repo=s:_r.repo.get(a:0 ? a:1 : ':')
    call s:_r.cmdutils.checkrepo(repo)
    let allfiles=s:F.getaddedermvdfiles(repo)
    let files=s:F.filterfiles(repo, globs, allfiles)
    if hascur
        let rrfopts={'repo': repo.path}
        let files+=[repo.functions.reltorepo(repo,
                    \s:_r.cmdutils.getrrf(rrfopts, 'nocurf', -1)[3])]
    endif
    call map(copy(files), 'repo.functions.add(repo, v:val)')
endfunction
let s:tracfunc['@FWC']=['-onlystrings + type ""', 'filter']
call add(s:traccomp,
            \substitute(s:tracfunc['@FWC'][0],
            \'\V+ type ""', '+ (path)', ''))
"▶1 hypfunc
" TODO diff ?
function s:hypfunc.function(opts)
    let opts=copy(a:opts)
    let utype=get(opts, 'url', 'html')
    if utype is# 'html' || utype is# 'annotate' || utype is# 'raw'
                \       || utype is# 'filehist'
        let [hasbuf, repo, rev, file]=s:_r.cmdutils.getrrf(a:opts, 'nocurf', 0)
        call s:_r.cmdutils.checkrepo(repo)
        let file=s:F.urlescape(file)
        if rev is 0
            if has_key(opts, 'line') &&
                        \index(repo.functions.status(repo).clean, file)==-1
                call remove(opts, 'line')
            endif
            let cs=repo.functions.getwork(repo)
        else
            let cs=repo.functions.getcs(repo, rev)
        endif
    else
        let repo=s:_r.repo.get(a:opts.repo)
        call s:_r.cmdutils.checkrepo(repo)
        if utype is# 'bundle' || utype is# 'changeset' || utype is# 'log'
            if has_key(a:opts, 'rev')
                let cs=repo.functions.getwork(repo)
            else
                let cs=repo.functions.getcs(repo, a:opts.rev)
            endif
        endif
    endif
    let url=repo.functions.getrepoprop(repo, 'url')
    let [protocol, user, domain, port, path]=
                \matchlist(url, '\v^%(([^:]+)\:\/\/)?'.
                \                  '%(([^@/:]+)\@)?'.
                \                   '([^/:]*)'.
                \                  '%(\:(\d+))?'.
                \                   '(.*)$')[1:5]
    for [matcher, dict] in s:_f.getoption('hypsites')+repo.hypsites
        if eval(matcher)
            if !has_key(dict, utype)
                call s:_f.throw('uunsup', utype, repo.path, url)
            endif
            let r=eval(dict[utype])
            if (utype is# 'html' || utype is# 'annotate') &&
                        \has_key(opts, 'line')
                let lkey=utype[0].'line'
                if has_key(dict, lkey)
                    if opts.line
                        let line=opts.line
                    elseif hasbuf
                        let line=line('.')
                    endif
                    if exists('line')
                        let r.='#'.eval(dict[lkey])
                    endif
                else
                    call s:_f.warn('uunsup', 'line', repo.path, url)
                endif
            endif
            let cmd=get(opts, 'cmd', 'let @+=%s')
            execute printf(cmd, string(r))
            return
        endif
    endfor
    call s:_f.throw('uknurl', url, repo.path)
endfunction
let s:hypfunc['@FWC']=['-onlystrings {?repo '.s:_r.cmdutils.nogetrepoarg.
            \                       ' ?rev   type ""'.
            \                       ' ?file  type ""'.
            \                       ' ?line  range 0 inf'.
            \                       ' ?cmd   type ""'.
            \                       ' ?url   in utypes ~start'.
            \                       '}', 'filter']
call add(s:hypcomp,
            \substitute(substitute(substitute(s:hypfunc['@FWC'][0],
            \'\Vfile\s\+type ""', 'file path',           ''),
            \'\Vcmd\s\+type ""',  'cmd '.s:_r.comp.cmd,  ''),
            \'\Vrev\s\+type ""',  'rev '.s:_r.comp.rev,  ''))
"▶1 grepfunc
function s:grepfunc.function(pattern, opts)
    if has_key(a:opts, 'files') && a:opts.repo is# ':'
        let repo=s:_r.repo.get(a:opts.files[0])
    else
        let repo=s:_r.repo.get(a:opts.repo)
    endif
    call s:_r.cmdutils.checkrepo(repo)
    let revisions=copy(get(a:opts, 'revision', []))
    let revrange=get(a:opts, 'revrange', [])
    while !empty(revrange)
        let [rev1, rev2; revrange]=revrange
        let cs1=repo.functions.getcs(repo, rev1)
        let cs2=repo.functions.getcs(repo, rev2)
        if type(cs1.rev)==type(0) && cs1.rev>cs2.rev
            let [cs1, cs2]=[cs2, cs1]
        elseif cs1 is cs2
            let revisions+=[cs1.hex]
            continue
        endif
        let revisions+=[[cs1.hex, cs2.hex]]
    endwhile
    let files=[]
    if has_key(a:opts, 'files')
        if empty(revisions)
            if get(a:opts, 'workmatch', 1)
                let css=[repo.functions.getwork(repo)]
            else
                call repo.functions.getchangesets(repo)
                let css=values(repo.changesets)
            endif
        else
            let css=[]
            for s in revisions
                if type(s)==type([])
                    let css+=repo.functions.revrange(a:repo, s[0], s[1])
                else
                    let css+=[repo.functions.getcs(repo, s)]
                endif
                unlet s
            endfor
        endif
        let allfiless=map(copy(css), 'repo.functions.getcsprop(repo, v:val,'.
                    \                                         '"allfiles")')
        let allfiles=[]
        call map(copy(allfiless),
                    \'extend(allfiles, filter(v:val, '.
                    \                        '"index(allfiles, v:val)==-1"))')
        for pattern in map(copy(a:opts.files),
                    \'s:_r.globtopat(repo.functions.reltorepo(repo, v:val))')
            let files+=filter(copy(allfiles),
                        \     'v:val=~#pattern && index(files, v:val)==-1')
        endfor
        if empty(files)
            call s:_f.warn('nogf')
            call setqflist([])
            return
        endif
    endif
    let wdfiles=((has_key(a:opts, 'wdfiles'))?(a:opts.wdfiles):
                \                             (s:_f.getoption('workdirfiles')))
    let qf=repo.functions.grep(repo, a:pattern, files, revisions,
                \              get(a:opts, 'ignorecase', 0), wdfiles)
    for item in filter(copy(qf), 'type(v:val.filename)=='.type([]))
        let item.filename=s:_r.fname('file', repo, item.filename[0],
                    \                item.filename[1])
    endfor
    call setqflist(qf)
endfunction
let s:grepfunc['@FWC']=['-onlystrings '.
            \           'type "" '.
            \           '{     repo     '.s:_r.cmdutils.nogetrepoarg.
            \           ' ?*+2 revrange   type ""  type ""'.
            \           ' ?*   revision   type ""'.
            \           ' ?*   files      type ""'.
            \           ' ?   !workmatch'.
            \           ' ?   !wdfiles'.
            \           ' ?   !ignorecase '.
            \           '}', 'filter']
call add(s:grepcomp,
            \substitute(substitute(s:grepfunc['@FWC'][0],
            \'\Vfiles \+type ""', 'files (path)', ''),
            \'\v(rev%(ision|range))\ +\Vtype ""', '\1 '.s:_r.comp.rev, 'g'))
"▶1 branfunc
function s:branfunc.function(bang, branch, opts)
    let repo=s:_r.repo.get(a:opts.repo)
    call s:_r.cmdutils.checkrepo(repo)
    let force=a:bang
    if !force && index(repo.functions.getrepoprop(repo, 'brancheslist'),
                \      a:branch)!=-1
        call s:_f.throw('bexsts', a:branch, repo.path)
    endif
    call repo.functions.branch(repo, a:branch, force)
endfunction
let s:branfunc['@FWC']=['-onlystrings _ '.
            \           'type "" '.
            \           '{  repo '.s:_r.cmdutils.nogetrepoarg.
            \           '}', 'filter']
call add(s:brancomp, s:branfunc['@FWC'][0])
"▶1 namefunc
function s:namefunc.function(bang, name, opts, ...)
    let repo=s:_r.repo.get(a:opts.repo)
    call s:_r.cmdutils.checkrepo(repo)
    if !has_key(repo, 'labeltypes') || empty(repo.labeltypes)
        call s:_f.throw('nunsup', repo.path)
    endif
    if get(a:opts, 'delete', 0)
        let rev=0
    elseif a:0
        let rev=repo.functions.getrevhex(repo, a:1)
    else
        let rev=repo.functions.getworkhex(repo)
    endif
    if has_key(a:opts, 'type')
        let type=a:opts.type
        let lts=repo.labeltypes
        if index(lts, type)==-1
            let type=get(filter(copy(lts),
                        \       'v:val[:'.(len(type)-1).'] is# type'), 0, 0)
            if type is 0
                call s:_f.throw('ukntype', a:opts.type, join(lts, ', '))
            endif
        endif
    else
        let type=repo.labeltypes[0]
    endif
    let force=a:bang
    if rev isnot 0 && !force
        try
            let labels=repo.functions.getrepoprop(repo, type.'slist')
            if index(labels, a:name)!=-1
                let rev=0
            endif
        catch
            let rev=0
        endtry
        if rev is 0
            call s:_f.throw('ldef', a:name, type)
        endif
    endif
    call repo.functions.label(repo, type, a:name, rev, force,
                \             get(a:opts, 'local', 0))
endfunction
let s:namefunc['@FWC']=['-onlystrings _ '.
            \           'type ""'.
            \           '{  repo '.s:_r.cmdutils.nogetrepoarg.
            \           ' ? type   type ""'.
            \           ' ?!delete'.
            \           ' ?!local'.
            \           '} '.
            \           '+ type ""', 'filter']
call add(s:namecomp, s:namefunc['@FWC'][0])
"▶1
call frawor#Lockvar(s:, '_pluginloaded,_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
