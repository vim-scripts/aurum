"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/resources': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
let s:utils={}
"▶1 utils.getcmd :: cmd, args, kwargs, esc → sh
function s:utils.getcmd(cmd, args, kwargs, esc)
    let cmd=a:cmd
    if !empty(a:kwargs)
        let cmd.=' '.join(map(filter(items(a:kwargs), 'v:val[1] isnot 0'),
                \             '((v:val[1] is 1)?'.
                \               '(repeat("-", 1+(len(v:val[0])>1)).v:val[0]):'.
                \               '(repeat("-", 1+(len(v:val[0])>1)).v:val[0].'.
                \                              '" ="[len(v:val[0])>1].'.
                \                              'shellescape(v:val[1],a:esc)))'))
    endif
    if !empty(a:args)
        let cmd.=' '.join(map(copy(a:args), 'shellescape(v:val, a:esc)'))
    endif
    return cmd
endfunction
"▶1 utils.run :: sh, hasnulls::Bool → [String] + shell
function s:utils.run(cmd, hasnulls, cdpath)
    if a:hasnulls
        let savedlazyredraw=&lazyredraw
        set lazyredraw
        noautocmd tabnew
        if !empty(a:cdpath)
            noautocmd execute 'lcd' fnameescape(a:cdpath)
        endif
        " XXX this is not able to distinguish between output with and without 
        " trailing newline
        noautocmd execute '%!'.a:cmd
        let r=getline(1, '$')
        noautocmd bwipeout!
        let &lazyredraw=savedlazyredraw
    else
        let cmd=a:cmd
        if !empty(a:cdpath)
            let cmd='cd '.shellescape(a:cdpath).' && '.cmd
        endif
        let r=split(system(cmd), "\n", 1)
    endif
    return r
endfunction
"▶1 utils.printm :: sh, hasnulls::Bool → + :echom, shell
function s:utils.printm(m)
    let prevempty=0
    for line in a:m
        if empty(line)
            let prevempty+=1
        else
            if prevempty
                while prevempty
                    echom ' '
                    let prevempty-=1
                endwhile
            endif
            echom line
        endif
    endfor
endfunction
"▶1 utils.diffopts :: opts, opts, difftrans → diffopts
function s:utils.diffopts(opts, defaultdiffopts, difftrans)
    let opts=extend(copy(a:defaultdiffopts), a:opts)
    let r={}
    call map(filter(copy(a:difftrans), 'has_key(opts, v:key)'),
            \'extend(r, {v:val : opts[v:key]})')
    if has_key(opts, 'dates') && has_key(a:difftrans, 'dates')
        let r[a:difftrans.dates]=!opts.dates
    endif
    return r
endfunction
"▶1 utils.addfiles :: repo, files + status → + add, forget
function s:utils.addfiles(repo, files)
    let status=a:repo.functions.status(a:repo, 0, 0, a:files)
    for file in status.unknown
        call a:repo.functions.add(a:repo, file)
    endfor
    for file in status.deleted
        call a:repo.functions.forget(a:repo, file)
    endfor
endfunction
"▶1 utils.usefile :: repo, message, kw, kw, func, args, kwargs, emes
function s:utils.usefile(repo, message, kwfile, kwmes, Func, args, kwargs, ...)
    if a:message=~#'\v[\r\n]'
        let tmpfile=tempname()
        call writefile(split(a:message, "\n", 1), tmpfile, 'b')
        let a:kwargs[a:kwfile]=tmpfile
        let usingfile=1
    else
        let a:kwargs[a:kwmes]=a:message
        let usingfile=0
    endif
    try
        return call(a:Func, [a:repo, 'commit', a:args, a:kwargs]+a:000, {})
    finally
        if usingfile && filereadable(tmpfile)
            call delete(tmpfile)
        endif
    endtry
endfunction
"▶1 post resource
call s:_f.postresource('utils', s:utils)
unlet s:utils
"▶1
call frawor#Lockvar(s:, '_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
