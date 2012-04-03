"▶1 
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('1.0', {'@/os': '0.0',
                \     '@aurum/cmdutils': '1.0',
                \         '@aurum/edit': '1.3',
                \               '@/fwc': '0.0',
                \          '@/mappings': '0.0',
                \         '@/resources': '0.0',
                \          '@/commands': '0.0',
                \         '@/functions': '0.0',
                \           '@/options': '0.0',}, 0)
    call FraworLoad('@/commands')
    call FraworLoad('@/functions')
    let s:vimdcomp=[]
    let s:vimdfunc={}
    call s:_f.command.add('AuVimDiff', s:vimdfunc, {'nargs': '*',
                \                                'complete': s:vimdcomp})
    finish
elseif s:_pluginloaded
    finish
endif
let s:_options={
            \'vimdiffusewin': {'default': 0, 'filter': 'bool'},
        \}
let s:_messages={
            \'nodfile': 'Failed to deduce which file to diff with',
            \ 'cndiff': 'Can’t show diff for file %s',
            \ 'nodrev': 'Unsure what revision should be diffed with',
        \}
let s:lastfullid=0
"▶1 diffrestore
let s:diffsaveopts=['diff', 'foldcolumn', 'foldenable', 'foldmethod',
            \       'foldlevel', 'scrollbind', 'cursorbind', 'wrap']
call filter(s:diffsaveopts, 'exists("+".v:val)')
function s:F.diffrestore(buf, onenter)
    if !bufexists(a:buf) || !exists('t:auvimdiff_origbufvar') ||
                \t:auvimdiff_origbufvar.bufnr!=a:buf
        return
    endif
    let dbvar=t:auvimdiff_origbufvar
    if a:onenter
        if has_key(dbvar, 'diffbuf')
            if bufexists(dbvar.diffbuf)
                return
            else
                call s:F.diffrestore(a:buf, 0)
            endif
        elseif !has_key(dbvar, 'diffsaved')
            return
        endif
        augroup AuVimDiff
            autocmd! BufEnter <buffer>
        augroup END
        unlet t:auvimdiff_origbufvar
        if b:changedtick!=dbvar.diffsaved.changedtick
            return
        endif
        let curpos=getpos('.')
        call winrestview(dbvar.diffsaved.winview)
        normal! zR
        for line in dbvar.diffsaved.closedfolds
            try
                execute line.'foldclose'
            catch /\VVim(foldclose):E490:/
                normal! zM
                break
            endtry
        endfor
        call setpos('.', curpos)
    else
        for option in s:diffsaveopts
            call setbufvar(a:buf, '&'.option, dbvar.diffsaved[option])
        endfor
        if has_key(dbvar, 'diffbuf')
            if exists('t:auvimdiff_diffbufvar')
                unlet t:auvimdiff_diffbufvar
            endif
            unlet dbvar.diffbuf
        endif
        if bufnr('%')==a:buf
            call s:F.diffrestore(a:buf, 1)
        endif
        if exists('t:auvimdiff_prevbuffers')
            unlet t:auvimdiff_prevbuffers
        endif
    endif
endfunction
"▶1 findwindow
function s:F.findwindow()
    let curwin=winnr()
    let curwinh=winheight(curwin)
    let curwinw=winwidth(curwin)
    let r=0
    let vertical=(stridx(&diffopt, 'vertical')!=-1)
    for wc in vertical ? ['l', 'h'] : ['j', 'k']
        execute 'wincmd' wc
        if winnr()!=curwin && ((vertical)?(winheight(0)==curwinh):
                    \                     (winwidth(0) ==curwinw))
            let r=1
            break
        endif
        execute curwin 'wincmd w'
    endfor
    return r
endfunction
"▶1 diffsplit
function s:F.diffsplit(difftarget, usewin)
    if !empty(filter(range(1, winnr('$')), 'getwinvar(v:val, "&diff")'))
        tab split
    endif
    let buf=bufnr('%')
    let t:auvimdiff_origbufvar={'bufnr': buf}
    let existed=bufexists(a:difftarget)
    let dbvar=t:auvimdiff_origbufvar
    let diffsaved={}
    let filetype=&filetype
    let dbvar.diffsaved=diffsaved
    for option in s:diffsaveopts
        let diffsaved[option]=getbufvar(buf, '&'.option)
    endfor
    let diffsaved.winview=winsaveview()
    let cursor=getpos('.')[1:]
    let diffsaved.changedtick=b:changedtick
    let closedfolds=[]
    let diffsaved.closedfolds=closedfolds
    for line in range(1, line('$'))
        if foldclosed(line)!=-1
            execute line.'foldopen'
            call insert(closedfolds, line)
        endif
    endfor
    call s:_f.mapgroup.map('AuVimDiff', buf)
    "▶2 `usewin' option support
    " Uses left/right or upper/lower window if it has similar dimensions
    if (a:usewin==-1 ? s:_f.getoption('vimdiffusewin') : a:usewin)
                \&& winnr('$')>1
        diffthis
        if s:F.findwindow()
            let prevbuf=s:_r.prevbuf()
            execute 'silent edit' fnameescape(a:difftarget)
            diffthis
        else
            execute 'silent diffsplit' fnameescape(a:difftarget)
        endif
    else
        execute 'silent diffsplit' fnameescape(a:difftarget)
    endif
    "▲2
    if bufwinnr(buf)!=-1
        execute bufwinnr(buf).'wincmd w'
        call cursor(cursor)
        wincmd p
    endif
    if &filetype isnot# filetype
        let &filetype=filetype
    endif
    let dbuf=bufnr('%')
    let t:auvimdiff_prevbuffers={dbuf : 0}
    let t:auvimdiff_diffbufvar={'bufnr': dbuf}
    let ddbvar=t:auvimdiff_diffbufvar
    let ddbvar.srcbuf=dbuf
    let ddbvar.existed=existed
    if exists('prevbuf')
        let ddbvar.prevbuf=prevbuf
        let t:auvimdiff_prevbuffers[dbuf]=prevbuf
    endif
    let dbvar.diffbuf=dbuf
    call s:_f.mapgroup.map('AuVimDiff', dbuf)
    augroup AuVimDiff
        execute 'autocmd BufWipeOut <buffer> '.
                    \':call s:F.diffrestore('.buf.', 0)'
        execute 'autocmd BufEnter   <buffer='.buf.'> '.
                    \':call s:F.diffrestore('.buf.', 1)'
    augroup END
endfunction
let s:_augroups+=['AuVimDiff']
"▶1 exit
function s:F.exit()
    let buf=bufnr('%')
    let cmd="\<C-\>\<C-n>"
    "▶2 AuV full was used
    if exists('t:auvimdiff_full')
        let vdid=t:auvimdiff_full
        let tabnr=tabpagenr()
        for tabnr in range(1, tabnr)
            if gettabvar(tabnr, 'auvimdiff_full') is vdid
                break
            endif
        endfor
        let vdtabcond="exists('t:auvimdiff_full') && t:auvimdiff_full is ".vdid
        let cmd.=":tabnext ".tabnr."\n"
        let cmd.=":while tabpagenr('$')>1 && ".vdtabcond." | ".
                    \"tabclose! | ".
                    \"endwhile\n"
        let cmd.=":if ".vdtabcond." | ".
                    \"only! | ".
                    \"enew! | ".
                    \"endif\n"
        return cmd
    "▶2 diffsplit() was not used
    elseif !exists('t:auvimdiff_diffbufvar') ||
                \!exists('t:auvimdiff_origbufvar') ||
                \(buf!=t:auvimdiff_diffbufvar.bufnr &&
                \ buf!=t:auvimdiff_origbufvar.bufnr)
        if &diff && exists('t:auvimdiff_prevbuffers')
            for dbuf in map(filter(range(1, winnr('$')),
                      \            'getwinvar(v:val, "&diff")'),
                      \     'winbufnr(v:val)')
                if has_key(t:auvimdiff_prevbuffers, dbuf)
                    let prevbuf=remove(t:auvimdiff_prevbuffers, dbuf)
                    if prevbuf
                        let cmd.=':buffer '.prevbuf."\n"
                    endif
                    let cmd.=':bwipeout! '.dbuf."\n"
                endif
                call s:_f.mapgroup.unmap('AuVimDiff', dbuf)
            endfor
            let cmd.=":diffoff!\n"
        else
            call s:_f.mapgroup.unmap('AuVimDiff', buf)
        endif
        if exists('t:auvimdiff_prevbuffers')
            unlet t:auvimdiff_prevbuffers
        endif
        return cmd
    endif
    "▲2
    let dbvar=t:auvimdiff_origbufvar
    let ddbvar=t:auvimdiff_diffbufvar
    let isorig=(buf==dbvar.bufnr)
    call s:_f.mapgroup.unmap('AuVimDiff', buf)
    let cmd.=":diffoff!\n"
    "▶2 Original buffer
    if isorig
        if bufexists(dbvar.diffbuf)
            call s:_f.mapgroup.unmap('AuVimDiff', dbvar.diffbuf)
            if bufwinnr(dbvar.diffbuf)!=-1
                if has_key(ddbvar, 'prevbuf') && bufexists(ddbvar.prevbuf)
                    let cmd.=':'.bufwinnr(dbvar.diffbuf)."wincmd w\n".
                                \':buffer '.ddbvar.prevbuf."\n".
                                \"\<C-w>p"
                endif
                if !ddbvar.existed
                    let cmd.=':if bufexists('.dbvar.diffbuf.') | '.
                                \   'bwipeout '.dbvar.diffbuf.' | '.
                                \"endif\n"
                endif
            else
                let cmd.=':if bufexists('.dbvar.diffbuf.') | '.
                            \   'bwipeout '.dbvar.diffbuf.' | '.
                            \"endif\n"
            endif
        endif
        let cmd.=':call <SNR>'.s:_sid."_Eval(".
                    \               "'s:F.diffrestore(".buf.", 0)')\n"
    "▶2 Opened buffer
    else
        if has_key(ddbvar, 'prevbuf') && bufexists(ddbvar.prevbuf)
            let cmd.=':buffer '.ddbvar.prevbuf."\n"
        endif
        if bufexists(ddbvar.srcbuf)
            call s:_f.mapgroup.unmap('AuVimDiff', ddbvar.srcbuf)
            if bufwinnr(ddbvar.srcbuf)!=-1
                let cmd.=':'.bufwinnr(ddbvar.srcbuf)."wincmd w\n"
            endif
        endif
        if !ddbvar.existed
            let cmd.=':if bufexists('.buf.') | '.
                        \   'bwipeout '.buf.' | '.
                        \"endif\n"
        endif
        let cmd.=':call <SNR>'.s:_sid."_Eval(".
                    \           "'s:F.diffrestore(".ddbvar.srcbuf.", 0)')\n"
    endif
    "▲2
    return cmd
endfunction
"▶1 AuVimDiff mappings
call s:_f.mapgroup.add('AuVimDiff', {
            \  'Exit': {'lhs': 'X', 'rhs': s:F.exit},
        \}, {'mode': 'n', 'silent': 1, 'dontmap': 1, 'leader': '<Leader>',})
"▶1 openfile
function s:F.openfile(usewin, hasbuf, repo, revs, file)
    "▶2 Open first buffer
    let frev=a:revs[0]
    if a:hasbuf
        let fbuf=bufnr('%')
    else
        let t:auvimdiff_prevbuffers={}
        let prevbuf=s:_r.prevbuf()
        if frev is 0
            execute 'silent edit' fnameescape(s:_r.os.path.join(a:repo.path,
                        \                     a:file))
        else
            call s:_r.run('silent edit', 'file', a:repo, frev, a:file)
        endif
        let t:auvimdiff_prevbuffers[bufnr('%')]=prevbuf
        let fbuf=bufnr('%')
    endif
    call s:_f.mapgroup.map('AuVimDiff', fbuf)
    "▶2 Open subsequent buffers
    let i=0
    for rev in a:revs[1:]
        if rev is 0
            let f=a:file
        else
            let f=s:_r.fname('file', a:repo, rev, a:file)
        endif
        if !i && a:hasbuf && len(a:revs)==2
            let existed=bufexists(f)
            call s:F.diffsplit(f, a:usewin)
            if !existed
                setlocal bufhidden=wipe
            endif
        else
            if !i && a:usewin && winnr('$')>1
                diffthis
                if s:F.findwindow()
                    let prevbuf=s:_r.prevbuf()
                    execute 'silent edit' fnameescape(f)
                    diffthis
                    let t:auvimdiff_prevbuffers[bufnr('%')]=prevbuf
                else
                    execute 'silent diffsplit' fnameescape(f)
                    let t:auvimdiff_prevbuffers[bufnr('%')]=0
                endif
            else
                execute 'silent diffsplit' fnameescape(f)
                let t:auvimdiff_prevbuffers[bufnr('%')]=0
            endif
            call s:_f.mapgroup.map('AuVimDiff', bufnr('%'))
        endif
        let i+=1
    endfor
    "▲2
    return fbuf
endfunction
"▶1 opentab
function s:F.opentab(repo, revs, file, fdescr)
    "▶2 Open first revision
    let frev=a:revs[0]
    if !has_key(a:fdescr, 1) || a:fdescr[1] is# 'removed'
                \            || a:fdescr[1] is# 'deleted'
        tabnew
        let existed=0
    elseif frev is 0
        let fname=fnameescape(s:_r.os.path.join(a:repo.path, a:file))
        let existed=bufexists(fname)
        execute 'silent tabedit' fname
    else
        let existed=s:_r.run('silent tabedit', 'file', a:repo, frev, a:file)
    endif
    if !existed
        setlocal bufhidden=wipe
    endif
    let t:auvimdiff_full=s:lastfullid
    call s:_f.mapgroup.map('AuVimDiff', bufnr('%'))
    "▶2 Open subsequent revisions
    let i=1
    let vertical=(stridx(&diffopt, 'vertical')!=-1)
    for rev in a:revs[1:]
        if !has_key(a:fdescr, i) || a:fdescr[i] is# 'added'
                    \            || a:fdescr[i] is# 'unknown'
            diffthis
            if vertical
                vnew
            else
                new
            endif
            diffthis
            let existed=0
        else
            let existed=s:_r.run('silent diffsplit','file', a:repo, rev, a:file)
        endif
        if !existed
            setlocal bufhidden=wipe
        endif
        call s:_f.mapgroup.map('AuVimDiff', bufnr('%'))
        let i+=1
    endfor
    1 wincmd w
    "▲2
endfunction
"▶1 fullvimdiff
function s:F.fullvimdiff(repo, revs, mt, files, areglobs, ...)
    let statuses=map(a:revs[1:],
                \    'a:repo.functions.status(a:repo, v:val, a:revs[0])')
    let files={}
    let i=1
    let stypes=['modified']
    "▶2 Get accepted statuses list
    if a:mt
        let stypes+=['added', 'removed']
        if a:mt==2
            let stypes+=['deleted', 'unknown']
        endif
    endif
    "▶2 Get file statuses
    for status in statuses
        for [k, fs] in filter(items(status), 'index(stypes, v:val[0])!=-1')
            for f in fs
                if !has_key(files, f)
                    let files[f]={}
                endif
                let files[f][i]=k
            endfor
        endfor
        let i+=1
    endfor
    "▶2 Filter out requested files
    if !empty(a:files)
        let files2={}
        if a:areglobs
            let filepats=map(filter(copy(a:files), 'v:val isnot# ":"'),
                        \    's:_r.globtopat(v:val)')
            "▶3 Current file
            if a:0 && !empty(a:1)
                for f in a:1
                    if has_key(files, f)
                        let files2[f]=remove(files, f)
                    else
                        call s:_f.throw('cndiff', f)
                    endif
                endfor
            endif
            "▲3
            for pattern in filepats
                call map(filter(keys(files), 'v:val=~#pattern'),
                            \'extend(files2, {v:val : remove(files, v:val)})')
            endfor
        else
            for f in filter(copy(a:files), 'has_key(files, v:val)')
                let files2[f]=remove(files, f)
            endfor
        endif
        let files=files2
    endif
    "▶2 Open tabs
    let s:lastfullid+=1
    for [f, d] in items(files)
        call s:F.opentab(a:repo, a:revs, f, d)
    endfor
    "▲2
endfunction
"▶1 vimdfunc
" TODO exclude binary files from full diff
function s:vimdfunc.function(opts, ...)
    "▶2 repo and revisions
    let full=get(a:opts, 'full', 0)
    let [hasbuf, repo, rev, file]=s:_r.cmdutils.getrrf(a:opts, 0,
                \                                      ((full)?('getfiles'):
                \                                              ('open')))
    call s:_r.cmdutils.checkrepo(repo)
    let revs=[]
    if rev isnot 0
        let rev=repo.functions.getrevhex(repo, rev)
    endif
    if get(a:opts, 'curfile', 0)
        let revs+=[0]
    endif
    if a:0
        let revs+=map(copy(a:000), 'repo.functions.getrevhex(repo, v:val)')
        if len(revs)==1
            call insert(revs, rev)
        endif
    else
        if empty(revs)
            let revs+=[rev]
        endif
        let revs+=[repo.functions.getworkhex(repo)]
    endif
    if revs[1] is# revs[0]
        let revs[1]=get(repo.functions.getwork(repo).parents, 0, 0)
        if revs[1] is 0
            call s:_f.throw('nodrev')
        endif
    endif
    "▲2
    if get(a:opts, 'full', 0)
        let args=[repo, revs,
                    \((get(a:opts, 'untracked', 0))?
                    \   (2):
                    \   (!get(a:opts, 'onlymodified', 1)))]
        if has_key(a:opts, 'files')
            let files=map(filter(copy(a:opts.files), 'v:val isnot# ":"'),
                        \        'repo.functions.reltorepo(repo, v:val)')
            let args+=[files, 1]
            if len(files)!=len(a:opts.files)
                if empty(file)
                    call s:_f.throw('nodfile')
                else
                    let args+=[file]
                endif
            endif
        elseif empty(file)
            let args+=[[], 0]
        else
            let args+=[file, 0]
        endif
        return call(s:F.fullvimdiff, args, {})
    else
        if file is 0
            call s:_f.throw('nodfile')
        endif
        let usewin=get(a:opts, 'usewin', -1)
        let usewin=(usewin==-1 ? s:_f.getoption('vimdiffusewin') : usewin)
        let fbuf=s:F.openfile(usewin, hasbuf, repo, revs, file)
        if bufwinnr(fbuf)!=-1
            execute bufwinnr(fbuf).'wincmd w'
        endif
    endif
endfunction
let s:vimdfunc['@FWC']=['-onlystrings '.
            \           '{  repo  '.s:_r.cmdutils.nogetrepoarg.
            \           '  ?file  type ""'.
            \           ' *?files (match /\W/)'.
            \           ' !?full'.
            \           ' !?untracked'.
            \           ' !?onlymodified'.
            \           ' !?curfile'.
            \           ' !?usewin'.
            \           '}'.
            \           '+ type ""', 'filter']
call add(s:vimdcomp,
            \substitute(substitute(s:vimdfunc['@FWC'][0],
            \'\vfile\s+type\s*\V""', 'file path',        ''),
            \'\V+ type ""',          '+ '.s:_r.comp.rev, ''))
"▶1 Post resource
call s:_f.postresource('vimdiff', {'split': s:F.diffsplit,
            \                       'full': s:F.fullvimdiff,})
"▶1
call frawor#Lockvar(s:, '_r,_pluginloaded,lastfullid')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
