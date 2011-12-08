"▶1
scriptencoding utf-8
setlocal textwidth=0
setlocal nolist
if has('conceal')
    setlocal concealcursor+=n conceallevel=2
endif
setlocal nonumber
if exists('+relativenumber')
    setlocal norelativenumber
endif
setlocal noswapfile
setlocal nomodeline
execute frawor#Setup('0.0', {'@aurum/cmdutils': '0.0',
            \                 '@aurum/bufvars': '0.0',
            \                    '@aurum/repo': '1.0',
            \                    '@aurum/edit': '0.0',
            \                           '@/os': '0.0',
            \                     '@/mappings': '0.0',})
let s:_messages={
            \'nocontents': 'Log is empty',
        \}
let s:ignkeys=['crrestrict', 'filepats', 'revs', 'cmd', 'repo']
"▶1 bisect :: [a], function + self → a
function s:F.bisect(list, function)
    let llist=len(a:list)
    let lborder=0
    let rborder=llist-1
    let lres=call(a:function, [a:list[lborder]], self)
    if lres<=0
        return a:list[lborder]
    endif
    let rres=call(a:function, [a:list[rborder]], self)
    if rres>=0
        return a:list[rborder]
    endif
    let totest='r'
    let cur=(((rborder+1)/2)-1)
    while lborder!=rborder
        let res=call(a:function, [a:list[cur]], self)
        if res==0
            return a:list[cur]
        else
            let shift=((rborder-lborder)/2)
            if shift==0
                let shift=1
            endif
            let {(res>0)?('l'):('r')}border=cur
            let cur=lborder+shift
        endif
    endwhile
    return a:list[lborder]
endfunction
"▶1 checkinblock :: block → -1|0|1
function s:F.checkinblock(block)
    let curline=line('.')-1
    return       ((curline<a:block[0][0])?(-1):
                \((curline>a:block[1][0])?( 1):
                \                         ( 0)))
endfunction
"▶1 getblock :: bvar + cursor, bvar → block
function s:F.getblock(bvar)
    if empty(a:bvar.rectangles)
        call s:_f.throw('nocontents')
    endif
    return s:F.bisect(a:bvar.rectangles, s:F.checkinblock)
endfunction
"▶1 findCurSpecial :: bvar, hex, blockstart + cursor → special
"▶2 s:spSort :: special, special → -1|0|1
let s:sufweights={'-': 3, 'r': 2, 'l': 1, 'R': 0,}
function s:spSort(s1, s2)
    let s1=a:s1[0]
    let s2=a:s2[0]
    let suf1=s:sufweights[((s1[-2:-2] is# '_')?(s1[-1:]):('-'))]
    let suf2=s:sufweights[((s2[-2:-2] is# '_')?(s2[-1:]):('-'))]
    return ((suf1==suf2)?(0):((suf1>suf2)?(-1):(1)))
endfunction
let s:_functions+=['s:spSort']
"▲2
function s:F.findCurSpecial(bvar, hex, blockstartline)
    let special=a:bvar.specials[a:hex]
    let line=line('.')-1-a:blockstartline
    let col=col('.')-1
    if col<len(matchstr(getline('.'), '\v^[@o|+\-/\\ ]+'))
        return 'linestart'
    endif
    for [spname, splist] in sort(items(special), function('s:spSort'))
        let suffix=((spname[-2:-2] is# '_')?(spname[-1:]):('-'))
        let r=matchstr(spname, '\v^\l+\d*')
        if suffix is# '-'
            if [line, col]==splist[:1]
                return r
            endif
        elseif suffix is# 'r'
            if line>=splist[0][0] && line<=splist[1][0] &&
                        \col>=splist[0][1] && col<=splist[1][1]
                return r
            endif
        elseif suffix is# 'R'
            if line>=splist[0][0] && line<=splist[1][0]
                return r
            endif
        elseif suffix is# 'l'
            if line==splist[0]
                return r
            endif
        endif
    endfor
    return 0
endfunction
"▶1 cwin
function s:F.cwin(bvar)
    if a:bvar.cw
        if winnr('$')==1
            return ''
        else
            return ":wincmd c\n"
        endif
    else
        return ":new\n"
    endif
endfunction
"▶1 cr
function s:F.cr(...)
    "▶2 Get changeset, current special, encode options
    let bvar=s:_r.bufvars[bufnr('%')]
    let [blockstart, blockend, hex]=s:F.getblock(bvar)
    if a:0
        let spname=a:1
    else
        let spname=s:F.findCurSpecial(bvar, hex, blockstart[0])
    endif
    let cs=bvar.repo.changesets[hex]
    let crrcond=((has_key(bvar.opts, 'crrestrict'))?
                \   (string(bvar.opts.crrestrict).' isnot# v:key &&'):
                \   (''))
    let opts=filter(copy(bvar.opts), crrcond.'index(s:ignkeys, v:key)==-1')
    "▶2 Commit actions based on current special
    "▶3 branch: add `branch' filter
    if spname is# 'branch'
        let cmd='edit '.fnameescape(s:_r.fname('log', bvar.repo,
                    \                          extend(copy(opts),
                    \                                 {'branch': cs.branch,
                    \                              'crrestrict': 'branch'})))
    "▶3 user: add `user' filter
    elseif spname is# 'user'
        let cmd='edit '.fnameescape(s:_r.fname('log', bvar.repo,
                    \                          extend(copy(opts),
                    \                        {'user': '\V'.escape(cs.user, '\'),
                    \                   'crrestrict': 'user'})))
    "▶3 time: add `date' filter (only show commits done in the current month)
    elseif spname is# 'time'
        let cmd='edit '.fnameescape(s:_r.fname('log', bvar.repo,
                    \                extend(copy(opts),
                    \                       {'date': strftime('%Y-%m', cs.time),
                    \                  'crrestrict': 'date'})))
    "▶3 changeset: show only ancestors of the current changeset
    elseif spname is# 'hex' || spname is# 'rev'
        let cmd='edit '.fnameescape(s:_r.fname('log', bvar.repo,
                    \                         extend(copy(opts),
                    \                                {'revision': hex,
                    \                               'crrestrict': 'revision'})))
    "▶3 file: view file
    elseif spname=~#'\v^file\d+$'
        " XXX If fileN special exists, then files property was definitely added, 
        " so no need to use getcsprop()
        let file=cs.files[str2nr(spname[4:])]
        let cmd='edit '.fnameescape(s:_r.fname('file', bvar.repo, hex, file))
    "▶3 curdiff: view diff between changeset and current state
    elseif spname is# 'curdiff'
        let args=['diff', bvar.repo, '', hex]
        if has_key(bvar.opts, 'files') && !has_key(bvar.opts.ignorefiles,'diff')
            let fargs+=[bvar.opts.csfiles[hex]]
        endif
        let cmd='edit '.fnameescape(call(s:_r.fname, args, {}))
    "▶3 other: view commit diff
    else
        let args=['diff', bvar.repo, hex, '']
        if has_key(bvar.opts, 'files') && !has_key(bvar.opts.ignorefiles,'diff')
            let args+=[bvar.opts.csfiles[hex]]
        endif
        let cmd='edit '.fnameescape(call(s:_r.fname, args, {}))
    endif
    "▲3
    return s:F.cwin(bvar).":silent ".cmd."\n"
endfunction
"▶1 gethexfile
function s:F.gethexfile()
    let bvar=s:_r.bufvars[bufnr('%')]
    let [blockstart, blockend, hex]=s:F.getblock(bvar)
    let spname=s:F.findCurSpecial(bvar, hex, blockstart[0])
    let cs=bvar.repo.changesets[hex]
    let file=0
    if spname=~#'\v^file\d+$'
        " XXX If fileN special exists, then files property was definitely added, 
        " so no need to use getcsprop()
        let file=cs.files[str2nr(spname[4:])]
    " Above is not applicable if we don't know exactly whether such special 
    " exists
    elseif !empty(bvar.repo.functions.getcsprop(bvar.repo, cs, 'files'))
        if len(cs.files)==1
            let file=cs.files[0]
        else
            if has_key(bvar.opts, 'files') &&
                        \!has_key(bvar.opts.ignorefiles, 'diff')
                let files=copy(bvar.opts.csfiles[hex])
                call filter(files, 'index(cs.files, v:val)!=-1')
            else
                let files=copy(cs.files)
            endif
            let choice=inputlist(['Select file (0 to cancel):']+
                        \        map(files, '(v:key+1).". ".v:val'))
            if choice
                let file=cs.files[choice-1]
            endif
        endif
    endif
    return [hex, file]
endfunction
"▶1 open
function s:F.open()
    let [hex, file]=s:F.gethexfile()
    if file is 0
        return ''
    endif
    let bvar=s:_r.bufvars[bufnr('%')]
    return s:F.cwin(bvar).":silent edit ".
                \fnameescape(s:_r.fname('file', bvar.repo, hex, file))."\n"
endfunction
"▶1 annotate
function s:F.annotate()
    let r=s:F.open()
    if empty(r)
        return r
    else
        return r.":AuAnnotate\n"
    endif
endfunction
"▶1 diff
function s:F.diff(...)
    let [hex, file]=s:F.gethexfile()
    if file is 0
        return ''
    endif
    let bvar=s:_r.bufvars[bufnr('%')]
    if a:0 && a:1
        return s:F.cwin(bvar).":silent edit ".
                    \fnameescape(s:_r.fname('diff', bvar.repo, hex, '', file)).
                    \"\n"
    else
        return s:F.cwin(bvar).":silent edit ".
                    \fnameescape(s:_r.fname('diff', bvar.repo, '', hex, file)).
                    \"\n"
    endif
endfunction
"▶1 vimdiff
function s:F.vimdiff(...)
    let [hex, file]=s:F.gethexfile()
    if file is 0
        return ''
    endif
    let bvar=s:_r.bufvars[bufnr('%')]
    let cs=bvar.repo.changesets[hex]
    if a:0 && a:1
        return s:F.cwin(bvar).":silent edit ".
                    \fnameescape(s:_r.os.path.join(bvar.repo.path, file))."\n".
                    \':silent diffsplit '.
                    \fnameescape(s:_r.fname('file', bvar.repo, hex, file))."\n"
    elseif !empty(cs.parents)
        return s:F.cwin(bvar).":silent edit ".
                    \fnameescape(s:_r.fname('file', bvar.repo, hex, file))."\n".
                    \':silent diffsplit '.
                    \fnameescape(s:_r.fname('file', bvar.repo, cs.parents[0],
                    \                       file))."\n"
    endif
    return ''
endfunction
"▶1 next
function s:F.next()
    let bvar=s:_r.bufvars[bufnr('%')]
    let [blockstart, blockend, hex]=s:F.getblock(bvar)
    let hex=bvar.repo.functions.getnthparent(bvar.repo, hex, -v:count1).hex
    return "\<C-\>\<C-n>".(bvar.csstarts[hex]+1).'gg'
endfunction
"▶1 prev
function s:F.prev()
    let bvar=s:_r.bufvars[bufnr('%')]
    let [blockstart, blockend, hex]=s:F.getblock(bvar)
    let hex=bvar.repo.functions.getnthparent(bvar.repo, hex, v:count1).hex
    return "\<C-\>\<C-n>".(bvar.csstarts[hex]+1).'gg'
endfunction
"▶1 filehistory
function s:F.filehistory()
    let [hex, file]=s:F.gethexfile()
    if file is 0
        return ''
    endif
    let bvar=s:_r.bufvars[bufnr('%')]
    let crrcond=((has_key(bvar.opts, 'crrestrict'))?
                \   (string(bvar.opts.crrestrict).' isnot# v:key &&'):
                \   (''))
    let opts=filter(copy(bvar.opts), crrcond.'index(s:ignkeys, v:key)==-1')
    call extend(opts, {'files': [s:_r.cmdutils.globescape(file)],
                \ 'crrestrict': 'files'})
    return ':silent edit '.fnameescape(s:_r.fname('log', bvar.repo, opts))."\n"
endfunction
"▶1 update
function s:F.update()
    let bvar=s:_r.bufvars[bufnr('%')]
    let [blockstart, blockend, hex]=s:F.getblock(bvar)
    call s:_r.repo.update(bvar.repo, hex, v:count)
    return "\<C-\>\<C-n>:silent edit\n"
endfunction
"▶1 AuLog mapping group
call s:_f.mapgroup.add('AuLog', {
            \   'Enter': {'lhs': "\n", 'rhs': [],                             },
            \    'File': {'lhs': 'gF', 'rhs': s:F.filehistory                 },
            \    'User': {'lhs': 'gu', 'rhs': ['user']                        },
            \    'Date': {'lhs': 'gD', 'rhs': ['time']                        },
            \  'Branch': {'lhs': 'gb', 'rhs': ['branch']                      },
            \     'Rev': {'lhs': 'gr', 'rhs': ['rev']                         },
            \   'Fdiff': {'lhs': 'gd', 'rhs': ['curdiff']                     },
            \  'RFdiff': {'lhs': 'gc', 'rhs': ['revdiff']                     },
            \    'Diff': {'lhs':  'd', 'rhs': [1],         'func': s:F.diff   },
            \   'Rdiff': {'lhs':  'c', 'rhs': s:F.diff                        },
            \   'Vdiff': {'lhs':  'D', 'rhs': [1],         'func': s:F.vimdiff},
            \  'RVdiff': {'lhs':  'C', 'rhs': s:F.vimdiff                     },
            \    'Next': {'lhs':  'K', 'rhs': s:F.next                        },
            \    'Prev': {'lhs':  'J', 'rhs': s:F.prev                        },
            \    'Open': {'lhs':  'o', 'rhs': s:F.open                        },
            \'Annotate': {'lhs':  'a', 'rhs': s:F.annotate                    },
            \  'Update': {'lhs':  'U', 'rhs': s:F.update                      },
            \    'Exit': {'lhs':  'X', 'rhs': ':<C-u>bwipeout<CR>'            },
            \}, {'func': s:F.cr, 'silent': 1, 'mode': 'n'})
"▶1
call frawor#Lockvar(s:, '_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
