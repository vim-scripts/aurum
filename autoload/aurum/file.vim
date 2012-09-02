"▶1 
scriptencoding utf-8
execute frawor#Setup('0.1', {'@%aurum/cmdutils': '4.1',
            \                '@%aurum/maputils': '0.0',
            \                 '@%aurum/bufvars': '0.0',
            \               '@%aurum/lineutils': '0.0',
            \                 '@%aurum/vimdiff': '1.0',
            \                    '@%aurum/edit': '1.2',
            \                          '@aurum': '1.0',
            \                            '@/os': '0.0',
            \                      '@/mappings': '0.0',})
let s:_messages={
            \'wfail': 'Writing to %s failed',
            \'dfail': 'Failed to delete %s',
        \}
"▶1 callbacks
let s:F.callbacks={}
"▶2 callbacks.open
function s:F.callbacks.open(file, repo, rev, cmd, hasbuf)
    if a:hasbuf
        let filetype=&filetype
    endif
    let oldlastbuf=bufnr('$')
    let existed=s:_r.run(a:cmd, 'file', a:repo, a:rev, a:file)
    if exists('filetype') && &filetype isnot# filetype
        let &filetype=filetype
    endif
    let buf=bufnr('%')
    if !existed && buf>oldlastbuf
        setlocal bufhidden=wipe
    endif
    call s:_f.mapgroup.map('AuFile', buf)
endfunction
"▶2 callbacks.replace
function s:F.callbacks.replace(file, repo, rev, cmd, hasbuf)
    let winview=winsaveview()
    silent %delete _
    call s:_r.lineutils.setlines(a:repo.functions.readfile(a:repo,a:rev,a:file),
                \                0)
    call winrestview(winview)
endfunction
"▶1 AuFile
function s:cmd.function(rev, file, opts)
    let opts=copy(a:opts)
    if a:rev isnot 0 && a:rev isnot ':'
        let opts.rev=a:rev
    endif
    let prompt=get(a:opts, 'prompt', 0)
    if !prompt && a:file isnot 0 && a:file isnot# ':'
        let opts.file=a:file
    endif
    let action=((prompt)?('getrr'):('open'))
    let [hasbuf, repo, rev, file]=s:_r.cmdutils.getrrf(opts, 'noffile', action)
    if repo is 0
        return
    endif
    if rev is 0
        let rev=repo.functions.getworkhex(repo)
    else
        let rev=repo.functions.getrevhex(repo, a:rev)
    endif
    if get(a:opts, 'replace', 0)
        let cbargs=[s:F.callbacks.replace]
    else
        let cbargs=[s:F.callbacks.open]
    endif
    let cbargs+=[repo, rev, get(a:opts, 'cmd', 'silent edit'), hasbuf]
    let pvargs=[s:_r.maputils.readfilewrapper, repo, rev]
    if prompt
        let files=repo.functions.getcsprop(repo, rev, 'allfiles')
        if a:file isnot# ':'
            let pattern=s:_r.globtopat(a:file)
            let files=filter(copy(files), 'v:val =~# pattern')
        endif
        return s:_r.maputils.promptuser(files, cbargs, pvargs)
    else
        call call(cbargs[0], [file]+cbargs[1:], {})
    endif
endfunction
"▶1 docmd :: [String], read::0|1|2 → _ + ?
function s:F.docmd(lines, read)
    if a:read==0 || a:read==1
        return s:_r.lineutils.setlines(a:lines, a:read)
    elseif a:read==2
        let tmpname=tempname()
        if writefile(a:lines, tmpname, 'b')==-1
            call s:_f.throw('wfail', tmpname)
        endif
        try
            execute 'source' fnameescape(tmpname)
        finally
            if delete(tmpname)
                call s:_f.throw('dfail', tmpname)
            endif
        endtry
    endif
endfunction
"▶1 aurum://file
let s:file={'arguments': 2, 'sourceable': 1, 'mgroup': 'AuFile'}
function s:file.function(read, repo, rev, file)
    let rev=a:repo.functions.getrevhex(a:repo, a:rev)
    call s:F.docmd(a:repo.functions.readfile(a:repo, rev, a:file), a:read)
    if !a:read && exists('#filetypedetect#BufRead')
        execute 'doautocmd filetypedetect BufRead'
                    \ fnameescape(s:_r.os.path.normpath(
                    \             s:_r.os.path.join(a:repo.path, a:file)))
    endif
    return {'rev': rev, 'file': a:file}
endfunction
call s:_f.newcommand(s:file)
unlet s:file
"▶1 aurum://file mappings
let s:mmgroup=':call <SNR>'.s:_sid.'_Eval("s:_f.mapgroup.map(''AuFile'', '.
            \                                               "bufnr('%'))\")\n"
function s:F.runfilemap(action)
    let buf=bufnr('%')
    let bvar=s:_r.bufvars[buf]
    let cmd="\<C-\>\<C-n>"
    if a:action is# 'exit'
        let cmd.=s:_r.cmdutils.closebuf(bvar)
    elseif a:action is# 'update'
        call s:_r.maputils.update(bvar.repo, bvar.rev, v:count)
        return ''
    elseif a:action is# 'previous' || a:action is# 'next'
        let c=((a:action is# 'previous')?(v:count1):(-v:count1))
        let rev=bvar.repo.functions.getnthparent(bvar.repo, bvar.rev, c).hex
        let cmd.=':edit '.fnameescape(s:_r.fname('file', bvar.repo, rev,
                    \                            bvar.file))."\n"
        let cmd.=s:mmgroup
        let cmd.=":bwipeout ".buf."\n"
    elseif a:action is# 'vimdiff' || a:action is# 'revvimdiff'
        if a:action is# 'vimdiff'
            let file=s:_r.os.path.normpath(s:_r.os.path.join(bvar.repo.path,
                        \                                    bvar.file))
            let cmd.=':diffsplit '.fnameescape(file)."\n"
        else
            let rev=bvar.repo.functions.getnthparent(bvar.repo, bvar.rev, 1).hex
            let file=s:_r.fname('file', bvar.repo, rev, bvar.file)
            let cmd.=':call call(<SNR>'.s:_sid.'_Eval("s:_r.vimdiff.split"), '.
                        \       '['.string(file).", 0], {})\n"
        endif
    elseif a:action is# 'diff' || a:action is# 'revdiff'
        let opts='repo '.escape(bvar.repo.path, ' ')
        if a:action is# 'diff'
            let opts.=' rev2 '.bvar.rev
        else
            let opts.=' rev1 '.bvar.rev
        endif
        let cmd.=':AuDiff '.opts."\n"
    endif
    return cmd
endfunction
call s:_f.mapgroup.add('AuFile', {
            \  'Next': {'lhs': 'K', 'rhs': ['next'      ]},
            \  'Prev': {'lhs': 'J', 'rhs': ['previous'  ]},
            \'Update': {'lhs': 'U', 'rhs': ['update'    ]},
            \  'Exit': {'lhs': 'X', 'rhs': ['exit'      ]},
            \  'Diff': {'lhs': 'd', 'rhs': [      'diff']},
            \ 'Rdiff': {'lhs': 'c', 'rhs': ['rev'.'diff']},
            \ 'Vdiff': {'lhs': 'D', 'rhs': [   'vimdiff']},
            \'RVdiff': {'lhs': 'C', 'rhs': ['revvimdiff']},
        \}, {'func': s:F.runfilemap, 'silent': 1, 'mode': 'n', 'dontmap': 1,})
"▶1
call frawor#Lockvar(s:, '_r,_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
