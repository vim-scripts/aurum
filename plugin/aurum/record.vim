"▶1 
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@aurum/bufvars': '0.0',
                \                          '@/os': '0.0',
                \                         '@/fwc': '0.0',
                \                    '@/mappings': '0.0',
                \                    '@/commands': '0.0',
                \                   '@/functions': '0.0',
                \                 '@aurum/commit': '0.0',
                \               '@aurum/cmdutils': '0.0',
                \                   '@aurum/repo': '0.0',
                \                   '@aurum/edit': '0.0',
                \                     '@/options': '0.0',}, 0)
    call FraworLoad('@/commands')
    call FraworLoad('@/functions')
    let s:reccomp=[]
    let s:recfunc={}
    call s:_f.command.add('AuRecord', s:recfunc, {'nargs': '*',
                \                              'complete': s:reccomp})
    finish
elseif s:_pluginloaded
    finish
endif
let s:_options={
            \'recheight': {'default': 0,
            \               'filter': '(if type "" earg _  range 0 inf)'},
        \}
let s:_messages={
            \ 'bkpmis': 'Backup file %s not found',
            \'delfail': 'Failed to remove file %s',
            \'renfail': 'Failed to move file %s to %s',
            \ 'uchngs': 'Found changes done manually. Resetting buffer, '.
            \           'please retry.',
            \ 'noundo': 'Your vim is too old, thus undo is not supported. '.
            \           'Update to version of Vim that has undotree() '.
            \           'function available',
            \ 'recnof': 'No files were selected for commiting',
        \}
"▶1 write
function s:F.write(bvar)
    call feedkeys("\<C-\>\<C-n>:call ".
            \      "call(<SNR>".s:_sid."_Eval('s:F.runstatmap'), ".
            \           "['commit', ".expand('<abuf>')."], {})\n", 'n')
endfunction
"▶1 recfunc
" TODO investigate why closing record tab is causing next character consumption
"      under wine
function s:recfunc.function(opts, ...)
    let files=copy(a:000)
    if !empty(files) && a:opts.repo is# ':'
        let repo=s:_r.repo.get(s:_r.os.path.dirname(files[0]))
    else
        let repo=s:_r.repo.get(a:opts.repo)
    endif
    call map(files, 'repo.functions.reltorepo(repo, v:val)')
    tabnew
    setlocal bufhidden=wipe
    let t:aurecid='AuRecordTab'
    let w:aurecid='AuRecordLeft'
    rightbelow vsplit
    let w:aurecid='AuRecordRight'
    let sopts={'record': 1}
    if !empty(files)
        let sopts.files=files
    endif
    let height=s:_f.getoption('recheight')
    if height<=0
        let height=winheight(0)/5
    endif
    call s:_r.run('silent botright '.height.'split', 'status', repo, sopts)
    setlocal bufhidden=wipe
    let w:aurecid='AuRecordStatus'
    setlocal nomodifiable
    call s:_f.mapgroup.map('AuRecord', bufnr('%'))
    let bvar=s:_r.bufvars[bufnr('%')]
    " 0: not included, unmodified
    " 1: not included,   modified
    " 2:     included, unmodified
    " 3:     included,   modified
    let bvar.statuses=repeat([0], len(bvar.types))
    let bvar.prevct=b:changedtick
    let bvar.reset=0
    let bvar.backupfiles={}
    let bvar.filesbackup={}
    let bvar.newfiles=[]
    let bvar.lines=map(copy(bvar.chars), 'v:val." ".bvar.files[v:key]')
    let bvar.swheight=height
    let bvar.startundo=s:F.curundo()
    let bvar.recopts=extend(copy(a:opts), {'repo': repo})
    let bvar.bufnr=bufnr('%')
    let bvar.oldbufs={}
    let bvar.bwfunc=s:F.unload
    let bvar.getwnrs=s:F.getwnrs
    let bvar.recrunmap=s:F.runstatmap
    let bvar.write=s:F.write
    if !bvar.startundo
        setlocal undolevels=-1
    endif
    setlocal noreadonly buftype=acwrite
    if empty(bvar.chars)
        bwipeout!
    endif
endfunction
" XXX options message, user, date and closebranch are used by com.commit
" XXX documentation says that options are the same as for `:AuCommit' except for 
" `type' option
let s:recfunc['@FWC']=['-onlystrings '.
            \          '{  repo '.s:_r.cmdutils.nogetrepoarg.
            \          '  ?message           type ""'.
            \          '  ?date              type ""'.
            \          '  ?user              type ""'.
            \          ' !?closebranch'.
            \          '} '.
            \          '+ type ""', 'filter']
call add(s:reccomp,
            \substitute(substitute(s:recfunc['@FWC'][0],
            \'\V|*F.comm.getrepo',  '',           ''),
            \'\V+ type ""', '+ (path)', ''))
"▶1 curundo :: () → UInt
if exists('*undotree')
    function s:F.curundo()
        return undotree().seq_cur
    endfunction
else
    function s:F.curundo()
        return 0
    endfunction
endif
"▶1 reset
function s:F.reset(bvar)
    for idx in range(0, len(a:bvar.lines)-1)
        call setline(idx+1, s:statchars[a:bvar.statuses[idx]].a:bvar.lines[idx])
    endfor
    let a:bvar.prevct=b:changedtick
    let a:bvar.reset=1
    if a:bvar.startundo
        let a:bvar.undolevels=&undolevels
        let a:bvar.startundo=s:F.curundo()
        setlocal undolevels=-1
    endif
endfunction
"▶1 supdate
function s:F.supdate(bvar)
    if b:changedtick!=a:bvar.prevct
        let a:bvar.prevct=b:changedtick
        if a:bvar.reset
            if has_key(a:bvar, 'undolevels')
                let &l:undolevels=a:bvar.undolevels
                unlet a:bvar.undolevels
            endif
            let a:bvar.reset=0
        endif
    endif
    setlocal nomodifiable
endfunction
"▶1 restorebackup
function s:F.restorebackup(file, backupfile)
    if a:backupfile isnot 0
        if !filereadable(a:backupfile)
            call s:_f.warn('bkpmis', a:backupfile)
            return
        endif
    endif
    if delete(a:file)
        call s:_f.warn('delfail', a:file)
    endif
    if a:backupfile isnot 0
        if rename(a:backupfile, a:file)
            call s:_f.warn('renfail', a:backupfile, a:file)
        endif
    endif
endfunction
"▶1 unload
function s:F.unload(bvar)
    let sbvar=get(a:bvar, 'sbvar', a:bvar)
    if bufexists(sbvar.bufnr)
        call setbufvar(sbvar.bufnr, '&modified', 0)
    endif
    if exists('t:aurecid') && t:aurecid is# 'AuRecordTab'
        unlet t:aurecid
        if tabpagenr('$')>1
            tabclose!
        else
            let wlist=range(1, winnr('$'))
            while !empty(wlist)
                for wnr in wlist
                    call remove(wlist, 0)
                    if !empty(getwinvar(wnr, 'aurecid'))
                        execute wnr.'wincmd w'
                        close!
                        let wlist=range(1, winnr('$'))
                        break
                    endif
                endfor
            endwhile
        endif
    else
        return
    endif
    call map(copy(sbvar.backupfiles), 's:F.restorebackup(v:val, v:key)')
    call map(copy(sbvar.newfiles),    's:F.restorebackup(v:val,   0  )')
    for [buf, savedopts] in items(filter(sbvar.oldbufs, 'bufexists(v:key)'))
        for [opt, optval] in items(savedopts)
            call setbufvar(buf, '&'.opt, optval)
        endfor
    endfor
endfunction
"▶1 getwnrs
function s:F.getwnrs()
    let lwnr=0
    let rwnr=0
    let swnr=0
    for wnr in range(1, winnr('$'))
        let wid=getwinvar(wnr, 'aurecid')
        if wid is# 'AuRecordLeft'
            let lwnr=wnr
        elseif wid is# 'AuRecordRight'
            let rwnr=wnr
        elseif wid is# 'AuRecordStatus'
            let swnr=wnr
        endif
    endfor
    if lwnr is 0 || rwnr is 0
        execute swnr.'wincmd w'
        let bvar=s:_r.bufvars[bufnr('%')]
        if winnr('$')>1
            only!
        endif
        topleft new
        setlocal bufhidden=wipe
        let w:aurecid='AuRecordLeft'
        let lwnr=winnr()
        rightbelow vnew
        setlocal bufhidden=wipe
        let w:aurecid='AuRecordRight'
        let rwnr=winnr()
        wincmd j
        let swnr=winnr()
        execute 'resize' bvar.swheight
    endif
    return [lwnr, rwnr, swnr]
endfunction
"▶1 edit
function s:F.edit(bvar, fname, ro)
    if type(a:fname)==type('')
        let existed=bufexists(a:fname)
        execute 'silent edit' fnameescape(a:fname)
    else
        let existed=call(s:_r.run, ['silent edit']+a:fname, {})
    endif
    let buf=bufnr('%')
    if existed
        let a:bvar.oldbufs[buf]={'readonly': &readonly,
                    \          'modifiable': &modifiable,}
    else
        setlocal bufhidden=wipe
    endif
    if a:ro
        setlocal   readonly nomodifiable
    else
        setlocal noreadonly   modifiable
    endif
    if getwinvar(0, 'aurecid') is# 'AuRecordLeft'
        call s:_f.mapgroup.map('AuRecordLeft', bufnr('%'))
    endif
endfunction
"▶1 runstatmap
let s:statchars='-^+*'
let s:ntypes={
            \'modified': 'm',
            \'added':    'a',
            \'unknown':  'a',
            \'removed':  'r',
            \'deleted':  'r',
        \}
function s:F.runstatmap(action, ...)
    "▶2 buf, bvar, reset
    let buf=get(a:000, 0, bufnr('%'))
    let bvar=s:_r.bufvars[buf]
    setlocal modifiable
    if !a:0 && b:changedtick!=bvar.prevct
        call s:_f.warn('uchngs')
        call s:F.reset(bvar)
        setlocal nomodifiable
        return
    endif
    "▶2 add/remove
    if a:action[-3:] is# 'add' || a:action[-6:] is# 'remove'
        if a:action[0] is# 'v'
            let sline=line("'<")
            let eline=line("'>")
            if sline>eline
                let [sline, eline]=[eline, sline]
            endif
        else
            let sline=line('.')
            let eline=line('.')+v:count1-1
            if eline>line('$')
                let eline=line('$')
            endif
        endif
        let add=(a:action[-3:] is# 'add')
        for line in range(sline, eline)
            let status=bvar.statuses[line-1]
            if add
                if status<2
                    let status+=2
                endif
            else
                if status>1
                    let status-=2
                endif
            endif
            let bvar.statuses[line-1]=status
            call setline(line, s:statchars[status].bvar.lines[line-1])
        endfor
    "▶2 discard
    elseif a:action is# 'discard'
        call s:F.unload(bvar)
        return
    "▶2 undo
    elseif a:action is# 'undo'
        if !bvar.startundo
            call s:_f.warn('noundo')
            return
        endif
        if bvar.reset || s:F.curundo()<=bvar.startundo
            setlocal nomodifiable
            return
        endif
        silent undo
        for line in range(1, line('$'))
            let bvar.statuses[line-1]=stridx(s:statchars, getline(line)[0])
        endfor
        if s:F.curundo()<bvar.startundo
            silent redo
        endif
    "▶2 redo
    elseif a:action is# 'redo'
        if !bvar.startundo
            call s:_f.warn('noundo')
            return
        endif
        if bvar.reset || s:F.curundo()<=bvar.startundo
            setlocal nomodifiable
            return
        endif
        silent redo
        for line in range(1, line('$'))
            let bvar.statuses[line-1]=stridx(s:statchars, getline(line)[0])
        endfor
    "▶2 edit
    elseif a:action is# 'edit'
        let [lwnr, rwnr, swnr]=s:F.getwnrs()
        let file=bvar.lines[line('.')-1][2:]
        let type=bvar.types[line('.')-1]
        let status=bvar.statuses[line('.')-1]
        let modified=status%2
        execute lwnr.'wincmd w'
        let fullpath=s:_r.os.path.join(bvar.repo.path, file)
        let ntype=get(s:ntypes, type, 0)
        if !modified
            if ntype is# 'm' || ntype is# 'a'
                let backupfile=fullpath.'.orig'
                let i=0
                while s:_r.os.path.exists(backupfile)
                    let backupfile=fullpath.'.'.i.'.orig'
                    let i+=1
                endwhile
            elseif ntype is# 'r'
                let bvar.newfiles+=[fullpath]
            endif
        endif
        if ntype isnot 0
            if !modified
                execute swnr.'wincmd w'
                let status=3
                let bvar.statuses[line('.')-1]=status
                call s:F.reset(bvar)
                setlocal nomodifiable
                execute lwnr.'wincmd w'
            endif
            call s:F.edit(bvar, fullpath, 0)
            if ntype is# 'm' || (modified && ntype is# 'a')
                if !modified
                    let fcontents=bvar.repo.functions.readfile(
                                \     bvar.repo,
                                \     bvar.repo.functions.getworkhex(bvar.repo),
                                \     file)
                endif
                diffthis
                execute rwnr.'wincmd w'
                call s:F.edit(bvar, 'aurum://copy:'.
                            \((modified)?(bvar.filesbackup[fullpath]):
                            \            (fullpath)), 1)
                diffthis
                wincmd p
            elseif modified
                if ntype is# 'r'
                    diffthis
                    execute rwnr.'wincmd w'
                    call s:F.edit(bvar,
                                \ ['file', bvar.repo,
                                \  bvar.repo.functions.getworkhex(bvar.repo),
                                \  file], 1)
                    diffthis
                    wincmd p
                endif
            else
                if ntype is# 'a'
                    let fcontents=readfile(fullpath, 'b')
                elseif ntype is# 'r'
                    let fcontents=bvar.repo.functions.readfile(
                                \     bvar.repo,
                                \     bvar.repo.functions.getworkhex(bvar.repo),
                                \     file)
                endif
            endif
            if !modified
                if exists('backupfile')
                    let isexe=executable(fullpath)
                    if rename(fullpath, backupfile)
                        call s:_f.warn('renfail', fullpath, backupfile)
                        setlocal readonly nomodifiable
                        execute swnr.'wincmd w'
                        return
                    endif
                    let bvar.backupfiles[backupfile]=fullpath
                    let bvar.filesbackup[fullpath]=backupfile
                else
                    let isexe=0
                endif
                let diff=&diff
                if exists('fcontents')
                    silent %delete _
                    call s:_r.setlines(fcontents, 0)
                    if diff
                        diffupdate
                    endif
                endif
                silent write
                if isexe && s:_r.os.name is# 'posix'
                    call s:_r.os.run(['chmod', '+x', fullpath])
                endif
            endif
            if !has_key(s:_r.bufvars, bufnr('%'))
                let s:_r.bufvars[bufnr('%')]={}
            endif
            call extend(s:_r.bufvars[bufnr('%')], {'recfile': file,
                        \                      'recmodified': modified,
                        \                      'recfullpath': fullpath,
                        \                       'recnewfile': 0,})
            if exists('backupfile')
                let s:_r.bufvars[bufnr('%')].recbackupfile=backupfile
            else
                let s:_r.bufvars[bufnr('%')].recnewfile=1
            endif
        endif
    "▶2 commit
    elseif a:action is# 'commit'
        let files=filter(copy(bvar.files), 'bvar.statuses[v:key]>1')
        if empty(files)
            call s:_f.warn('recnof')
            return
        endif
        aboveleft let r=s:_r.commit.commit(bvar.repo, bvar.recopts, files,
                    \                      bvar.status)
        if r
            call s:F.unload(bvar)
        else
            let w:aurecid='AuRecordCommitMessage'
            let cbvar=s:_r.bufvars[bufnr('%')]
            let cbvar.sbvar=bvar
            let cbvar.bwfunc=s:F.unload
        endif
        return
    endif
    "▶2 bvar.prevct, bvar.reset, bvar.undolevels
    if bufnr('%')==buf
        call s:F.supdate(bvar)
    endif
endfunction
let s:_augroups+=['AuRecordLeft']
"▶1 runleftmap
function s:F.runleftmap(action)
    let [lwnr, rwnr, swnr]=s:F.getwnrs()
    let bvar=s:_r.bufvars[bufnr('%')]
    if a:action is# 'discard'
        execute lwnr.'wincmd w'
        let lbuf=bufnr('%')
        silent enew!
        setlocal bufhidden=wipe
        let ebuf=bufnr('%')
        execute rwnr.'wincmd w'
        let rbuf=bufnr('%')
        silent execute 'buffer!' ebuf
        execute swnr.'wincmd w'
        if !bvar.recmodified
            let sbvar=s:_r.bufvars[bufnr('%')]
            if bvar.recnewfile
                call s:F.restorebackup(bvar.recfullpath, 0)
                call filter(sbvar.newfiles, 'v:val isnot# bvar.recfullpath')
            else
                call s:F.restorebackup(bvar.recfullpath, bvar.recbackupfile)
                unlet sbvar.backupfiles[bvar.recbackupfile]
            endif
            let fidx=index(sbvar.files, bvar.recfile)
            let sbvar.statuses[fidx]=0
            setlocal modifiable
            call setline(fidx+1, s:statchars[0].sbvar.lines[fidx])
            call s:F.supdate(sbvar)
        endif
    elseif a:action is# 'commit'
        silent update
        execute swnr.'wincmd w'
        return s:F.runstatmap('commit')
    elseif a:action is# 'discardall'
        execute swnr.'wincmd w'
        return s:F.runstatmap('discard')
    elseif a:action is# 'remove'
        call s:F.runleftmap('discard')
        let sbvar=s:_r.bufvars[bufnr('%')]
        let fidx=index(sbvar.files, bvar.recfile)
        if sbvar.statuses[fidx]>1
            let sbvar.statuses[fidx]-=2
            setlocal modifiable
            call setline(fidx+1, s:statchars[sbvar.statuses[fidx]].
                        \        sbvar.lines[fidx])
            call s:F.supdate(sbvar)
        endif
    endif
endfunction
"▶1 rec mappings
function s:F.gm(...)
    return ':<C-u>call call(<SID>Eval("s:F.runstatmap"),'.string(a:000).','.
                \          '{})<CR>'
endfunction
function s:F.gml(...)
    return ':<C-u>call call(<SID>Eval("s:F.runleftmap"),'.string(a:000).','.
                \          '{})<CR>'
endfunction
call s:_f.mapgroup.add('AuRecord', {
            \   'Edit': {'lhs': 'O', 'rhs': s:F.gm('edit')  },
            \   'Undo': {'lhs': 'u', 'rhs': s:F.gm('undo')  },
        \}, {'mode': 'n', 'silent': 1, 'dontmap': 1})
call s:_f.mapgroup.add('AuRecordLeft', {
            \'Discard': {'lhs': 'x', 'rhs': s:F.gml('discard')   },
            \   'Exit': {'lhs': 'X', 'rhs': s:F.gml('discardall')},
            \ 'Commit': {'lhs': 'i', 'rhs': s:F.gml('commit')    },
            \ 'Remove': {'lhs': 'R', 'rhs': s:F.gml('remove')    },
        \}, {'mode': 'n', 'silent': 1, 'dontmap': 1, 'leader': '<Leader>'})
"▶1
call frawor#Lockvar(s:, '_r,_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
