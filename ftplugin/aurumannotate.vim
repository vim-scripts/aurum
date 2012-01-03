"▶1 
scriptencoding utf-8
setlocal textwidth=0
setlocal nolist nowrap
if has('conceal')
    setlocal concealcursor+=n conceallevel=2
endif
setlocal nonumber
if exists('+relativenumber')
    setlocal norelativenumber
endif
setlocal noswapfile
setlocal nomodeline
execute frawor#Setup('0.0', {'@aurum/repo': '1.0',
            \             '@aurum/bufvars': '0.0',
            \             '@aurum/vimdiff': '0.0',
            \            '@aurum/annotate': '0.0',
            \                '@aurum/edit': '1.0',
            \                 '@/mappings': '0.0',
            \                       '@/os': '0.0',})
let s:_messages={
            \  'nofile': 'File %s was added in revision %s',
            \ 'norfile': 'File %s is not present in the working directory',
        \}
"▶1 getfile :: repo, cs → path
function s:F.getfile(repo, cs)
    let file=0
    let files=a:repo.functions.getcsprop(a:repo, a:cs, 'files')
    if !empty(files)
        if len(files)==1
            let file=files[0]
        else
            let choice=inputlist(['Select file (0 to cancel):']+
                        \               map(copy(files),
                        \                   '(v:key+1).". ".v:val'))
            if choice
                let file=files[choice-1]
            endif
        endif
    endif
    return file
endfunction
"▶1 runmap
" TODO investigate why Prev mapping is causing next character consumption under
"      wine
function s:F.runmap(action, ...)
    "▶2 Initialize variables
    let buf=bufnr('%')
    let bvar=s:_r.bufvars[buf]
    let hex=bvar.revisions[line('.')-1]
    let file=bvar.files[line('.')-1]
    let hasannbuf = has_key(bvar, 'annbuf') && bufwinnr(bvar.annbuf)!=-1
    "▶2 Various *diff actions
    if a:action[-4:] is# 'diff'
        if a:action[:2] is# 'rev'
            let rev1=get(bvar.repo.functions.getcs(bvar.repo, hex).parents,0,'')
        elseif bvar.rev isnot# bvar.repo.functions.getworkhex(bvar.repo)
            let rev1=bvar.rev
        else
            let rev1=''
        endif
        let rev2=hex
        if hasannbuf
            wincmd c
            execute bufwinnr(bvar.annbuf).'wincmd w'
            setlocal noscrollbind
        endif
        if a:action[-7:-5] is# 'vim'
            if empty(rev1)
                let file1=s:_r.os.path.join(bvar.repo.path, bvar.file)
                let existed=bufexists(file1)
                if filereadable(file1)
                    execute 'silent edit' fnameescape(file1)
                else
                    call s:_f.throw('norfile', file1)
                endif
            else
                try
                    let existed=s:_r.run('silent edit', 'file', bvar.repo, rev1,
                                \        file)
                catch /\V\^Frawor:\[^:]\+:nofile:/
                    call s:_f.throw('nofile', file, rev1)
                endtry
            endif
            if existed
                setlocal bufhidden=wipe
                unlet existed
            endif
            call s:_r.vimdiff.split(s:_r.fname('file',bvar.repo,rev2,file), -1)
            if empty(rev1)
                wincmd p
            endif
        else
            if empty(rev1)
                let rev1=rev2
                let rev2=''
            endif
            if a:action[:2] is# 'rev'
                let dfile=bvar.file
            else
                let dfile=file
            endif
            let existed=s:_r.run('silent edit', 'diff', bvar.repo, rev1, rev2,
                        \        ((a:0 && a:1)?([]):([dfile])), {})
        endif
    "▶2 `open' action
    elseif a:action is# 'open'
        if a:0 && a:1
            let file=bvar.files[line('.')-1]
            let lnr=bvar.linenumbers[line('.')-1]
        else
            let file=s:F.getfile(bvar.repo,
                        \        bvar.repo.functions.getcs(bvar.repo, hex))
            if file is 0
                return
            endif
        endif
        if hasannbuf
            call s:_r.run('silent edit', 'annotate', bvar.repo, hex, file)
            setlocal scrollbind
            let abuf=bufnr('%')
            let newbvar=s:_r.bufvars[abuf]
            execute bufwinnr(bvar.annbuf).'wincmd w'
        endif
        let existed=s:_r.run('silent edit', 'file', bvar.repo, hex, file)
        setlocal scrollbind
        if hasannbuf
            call s:_r.annotate.setannbuf(newbvar, abuf, bufnr('%'))
        endif
        if exists('lnr')
            execute lnr
        endif
    "▶2 `update' action
    elseif a:action is# 'update'
        call s:_r.repo.update(bvar.repo, hex, v:count)
    "▶2 `previous' and `next' actions
    elseif a:action is# 'previous' || a:action is# 'next'
        let c=((a:action is# 'previous')?(v:count1):(-v:count1))
        let rev=bvar.repo.functions.getnthparent(bvar.repo, bvar.rev, c).hex
        if rev is# hex
            return
        endif
        call s:_r.run('silent edit', 'annotate', bvar.repo, rev, bvar.file)
        setlocal scrollbind
        let abuf=bufnr('%')
        let newbvar=s:_r.bufvars[abuf]
        if hasannbuf
            execute bufwinnr(bvar.annbuf).'wincmd w'
            setlocal noscrollbind
        else
            vsplit
            wincmd p
            vertical resize 42
            wincmd p
        endif
        let existed=s:_r.run('silent edit', 'file', bvar.repo, rev, bvar.file)
        setlocal scrollbind
        call s:_r.annotate.setannbuf(newbvar, abuf, bufnr('%'))
    endif
    "▲2
    if exists('existed') && !existed
        setlocal bufhidden=wipe
    endif
endfunction
"▶1 AuAnnotate mapping group
"▶2 getrhs
function s:F.getrhs(...)
    return ':<C-u>call call(<SID>Eval("s:F.runmap"), '.string(a:000).', {})<CR>'
endfunction
"▲2
call s:_f.mapgroup.add('AuAnnotate', {
            \    'Enter': {'lhs': '<CR>', 'rhs': s:F.getrhs(   'vimdiff'   )},
            \    'Fdiff': {'lhs': 'gd',   'rhs': s:F.getrhs(      'diff', 1)},
            \   'RFdiff': {'lhs': 'gc',   'rhs': s:F.getrhs('rev'.'diff', 1)},
            \     'Diff': {'lhs':  'd',   'rhs': s:F.getrhs(      'diff'   )},
            \    'Rdiff': {'lhs':  'c',   'rhs': s:F.getrhs('rev'.'diff'   )},
            \    'Vdiff': {'lhs':  'D',   'rhs': s:F.getrhs(   'vimdiff'   )},
            \   'RVdiff': {'lhs':  'C',   'rhs': s:F.getrhs('revvimdiff'   )},
            \ 'Annotate': {'lhs':  'a',   'rhs': s:F.getrhs('open'      , 1)},
            \     'Open': {'lhs':  'o',   'rhs': s:F.getrhs('open'         )},
            \   'Update': {'lhs':  'U',   'rhs': s:F.getrhs(    'update'   )},
            \     'Next': {'lhs':  'K',   'rhs': s:F.getrhs('next'         )},
            \     'Prev': {'lhs':  'J',   'rhs': s:F.getrhs('previous'     )},
            \     'Exit': {'lhs':  'X',   'rhs': ':<C-u>bwipeout!<CR>'      },
            \}, {'silent': 1, 'mode': 'n'})
"▶1
call frawor#Lockvar(s:, '_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
