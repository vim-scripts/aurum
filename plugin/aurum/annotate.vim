"▶1 
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/table': '0.1',
                \        '@aurum/cmdutils': '0.0',
                \         '@aurum/bufvars': '0.0',
                \            '@aurum/edit': '1.0',
                \                  '@/fwc': '0.3',
                \             '@/commands': '0.0',
                \            '@/functions': '0.0',
                \            '@/resources': '0.0',}, 0)
    call FraworLoad('@/commands')
    call FraworLoad('@/functions')
    let s:anncomp=[]
    let s:annfunc={}
    call s:_f.command.add('AuAnnotate', s:annfunc, {'nargs': '*',
                \                                'complete': s:anncomp})
    finish
elseif s:_pluginloaded
    finish
endif
"▶1 formatann :: repo, cs, lnum, numlen → String
function s:F.formatann(repo, cs, lnum, numlen)
    if !has_key(self, a:cs.hex)
        let description=matchstr(a:cs.description, '\v[^\r\n]+')
        while s:_r.strdisplaywidth(description, a:numlen+1)>30
            let description=substitute(description, '.$', '', '')
        endwhile
        if len(description)<len(a:cs.description)
            let description.='…'
        endif
        let descwidth=s:_r.strdisplaywidth(description, a:numlen+1)
        if descwidth<31
            let description.=repeat(' ', 31-descwidth)
        endif
        let user=substitute(a:cs.user, '\m\s*<[^>]\+>$', '', '')
        let self[a:cs.hex]=printf('%*s %s / %s', a:numlen, a:cs.rev,
                    \                            description, user)
    endif
    return self[a:cs.hex]
endfunction
"▶1 setup
"▶2 getcs :: rev + self → cs + self
function s:F.getcs(rev)
    if has_key(self, a:rev)
        return self[a:rev]
    endif
    let cs=self.repo.functions.getcs(self.repo, a:rev)
    let self[a:rev]=cs
    return cs
endfunction
"▲2
function s:F.setup(read, repo, rev, file)
    let rev=a:repo.functions.getrevhex(a:repo, a:rev)
    let bvar={'rev': rev, 'file': a:file}
    let ann=copy(a:repo.functions.annotate(a:repo, rev, a:file))
    let d={'repo': a:repo, 'getcs': s:F.getcs}
    let css=map(copy(ann), 'd.getcs(v:val[1])')
    let d={}
    let nl=max(map(copy(css), 'len(v:val.rev)'))
    let bvar.files=map(copy(ann), 'v:val[0]')
    let bvar.linenumbers=map(copy(ann), 'v:val[2]')
    let bvar.revisions=map(copy(css), 'v:val.hex')
    let lines=map(copy(css), 'call(s:F.formatann, [a:repo, v:val, v:key, '.
                \                                  nl.'],d)')
    if a:read
        call append('.', lines)
    else
        call setline('.', lines)
        setlocal readonly nomodifiable
    endif
    return bvar
endfunction
"▶1 setannbuf
function s:F.setannbuf(bvar, buf, annbuf)
    let a:bvar.annbuf=a:annbuf
    if bufwinnr(a:annbuf)!=-1
        execute bufwinnr(a:annbuf).'wincmd w'
        augroup AuAnnotateBW
            execute 'autocmd BufWipeOut,BufHidden <buffer='.a:annbuf.'> '.
                        \':if bufexists('.a:buf.') | '.
                        \   'call feedkeys("\<C-\>\<C-n>'.
                        \                 ':silent! bw '.a:buf.'\n") | '.
                        \ 'endif'
        augroup END
    endif
endfunction
let s:_augroups+=['AuAnnotateBW']
"▶1 foldopen
if has('folding')
    function s:F.foldopen()
        if &foldenable
            try
                " XXX Using silent! here because I am unable to catch E490 for 
                " unknown reason
                silent! %foldopen!
            catch /^Vim:(foldopen):E490:/
                " No folds found — ignore
            endtry
        endif
    endfunction
else
    function s:F.foldopen()
        " Doing nothing if there is no folding support
    endfunction
endif
"▶1 annfunc
" TODO Investigate why wiping out annotate buffer causes consumption of next
"      character under wine
function s:annfunc.function(opts)
    let [hasannbuf, repo, rev, file]=s:_r.cmdutils.getrrf(a:opts, 'noafile',
                \                                         'annotate')
    if repo is 0
        return
    endif
    if rev is 0
        let rev=repo.functions.getworkhex(repo)
    endif
    if hasannbuf==2
        let hasannbuf=!repo.functions.dirty(repo, file)
    endif
    if hasannbuf
        let annbuf=bufnr('%')
    else
        " TODO Check for errors
        let existed=s:_r.run('silent edit', 'file', repo, rev, file)
        let annbuf=bufnr('%')
        if !existed
            setlocal bufhidden=wipe
        endif
    endif
    call s:F.foldopen()
    setlocal scrollbind cursorbind nowrap
    let lnr=line('.')
    let anwidth=min([42, winwidth(0)/2-1])
    call s:_r.run('silent leftabove '.anwidth.'vsplit', 'annotate', repo,
                \ rev, file)
    execute lnr
    setlocal scrollbind cursorbind
    setlocal bufhidden=wipe
    let buf=bufnr('%')
    call s:F.setannbuf(s:_r.bufvars[buf], buf, annbuf)
endfunction
let s:_augroups+=['AuAnnotateBW']
let s:annfunc['@FWC']=['-onlystrings'.
            \          '{  repo  '.s:_r.cmdutils.nogetrepoarg.
            \          '  ?file  type ""'.
            \          '  ?rev   type ""'.
            \          '}', 'filter']
call add(s:anncomp,
            \substitute(substitute(s:annfunc['@FWC'][0],
            \'\vfile\s+type\s*\V""', 'file path',          ''),
            \'\vrev\s+type\s*\V""',  'rev '.s:_r.comp.rev, ''))
"▶1 aurum://annotate
call s:_f.newcommand({'function': s:F.setup,
            \        'arguments': 2,
            \         'filetype': 'aurumannotate',})
"▶1 Post resource
call s:_f.postresource('annotate', {'setannbuf': s:F.setannbuf,
            \                        'foldopen': s:F.foldopen,})
"▶1
call frawor#Lockvar(s:, '_r,_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
