"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/resources': '0.0',
                \                       '@/os': '0.0',
                \                '@aurum/repo': '0.0',
                \                '@aurum/edit': '0.0',
                \               '@aurum/cache': '0.0',
                \             '@aurum/bufvars': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
let s:patharg='either (path d, match @\v^\w+%(\+\w+)*\V://\v|^\:$@)'
let s:nogetrepoarg=':":" ('.s:patharg.')'
let s:_messages={
            \  'nrepo': 'Failed to find a repository',
            \'noafile': 'Failed to deduce which file to annotate',
            \'noffile': 'Failed to deduce which file to show',
            \ 'nocurf': 'Failed to deduce which file was meant',
            \'nocfile': 'Unsure what should be commited',
        \}
"▶1 globescape :: path → glob
function s:F.globescape(path)
    return escape(a:path, '\*?[]{}')
endfunction
"▶1 getdifffile :: bvar + cursor → file
function s:F.getdifffile(bvar)
    if len(a:bvar.files)==1
        return a:bvar.files[0]
    endif
    let diffre=a:bvar.repo.functions.diffre(a:bvar.repo, a:bvar.opts)
    let lnum=search(diffre, 'bcnW')
    if !lnum
        return 0
    endif
    return get(matchlist(getline(lnum), diffre), 1, 0)
endfunction
"▶1 getfile :: [path] → path
function s:F.getfile(files)
    let file=0
    if !empty(a:files)
        if len(a:files)==1
            let file=a:files[0]
        else
            let choice=inputlist(['Select file (0 to cancel):']+
                        \               map(copy(a:files),
                        \                   '(v:key+1).". ".v:val'))
            if choice
                let file=a:files[choice-1]
            endif
        endif
    endif
    return file
endfunction
"▶1 getrrf :: opts, failmsg, ann + buf → (hasbuf, repo, rev, file)
let s:rrffailresult=[0, 0, 0, 0]
function s:F.getrrf(opts, failmsg, ann)
    let hasbuf=0
    let file=0
    "▶2 a:opts.file file → (repo?)
    if has_key(a:opts, 'file') && a:opts.file isnot# ':'
        if a:ann!=-1 && a:opts.repo is# ':'
            let repo=s:_r.repo.get(s:_r.os.path.dirname(a:opts.file))
            let file=repo.functions.reltorepo(repo, a:opts.file)
        else
            let file=a:opts.file
        endif
        if !has_key(a:opts, 'rev')
            let rev=0
        endif
    "▶2 a:opts.files files → repo?
    elseif has_key(a:opts, 'files') && !empty(a:opts.files)
        let files=[]
        if index(a:opts.files, ':')!=-1
            let newopts=copy(a:opts)
            unlet newopts.files
            let [repo, rev, file]=s:F.getrrf(newopts, 'nocurf', -1)[1:]
            if repo is 0
                unlet repo
                let repo=s:_r.repo.get(file)
            endif
            if a:ann!=-2 && repo isnot 0
                let file=repo.functions.reltorepo(repo, file)
            endif
            let files+=[file]
        else
            let repo=s:_r.repo.get(a:opts.files[0])
        endif
    "▲2
    elseif has_key(s:_r.bufvars, bufnr('%')) &&
                \has_key(s:_r.bufvars[bufnr('%')], 'command')
        let bvar=s:_r.bufvars[bufnr('%')]
        "▶2 +aurum://file bvar → (repo, rev, file)
        if bvar.command is# 'file'
            let repo=bvar.repo
            let  rev=bvar.rev
            let file=bvar.file
            let hasbuf=1
        "▶2 +aurum://copy bvar → (file), file → (repo), (rev=0)
        elseif bvar.command is# 'copy'
            if a:ann==-1
                let file=bvar.file
            else
                let repo=s:_r.repo.get(s:_r.os.path.dirname(bvar.file))
                let file=repo.functions.reltorepo(repo, bvar.file)
            endif
            let  rev=0
            let hasbuf=1
        "▶2 *aurum://status bvar → (repo, rev), "." → (file)
        elseif bvar.command is# 'status'
            let repo=bvar.repo
            let  rev=get(bvar.opts, 'rev1', 0)
            if empty(bvar.files)
                if a:failmsg isnot 0
                    call s:_f.throw(a:failmsg)
                endif
            else
                let file=bvar.files[line('.')-1]
            endif
            if a:ann>=0
                topleft new
            endif
        "▶2 |aurum://diff bvar → (repo, rev, file?)
        elseif bvar.command is# 'diff'
            let repo=bvar.repo
            let  rev=empty(bvar.rev2) ? bvar.rev1 : bvar.rev2
            if a:ann==-2
                let files=bvar.files
            else
                let file=s:F.getdifffile(bvar)
                if file is 0 && a:failmsg isnot 0
                    return s:rrffailresult
                endif
                if a:ann>=0
                    leftabove vnew
                endif
            endif
        "▶2 *aurum://commit bvar → (repo, file?)
        elseif bvar.command is# 'commit'
            let repo=bvar.repo
            if a:ann==-2
                let files=bvar.files
            else
                let file=s:F.getfile(bvar.files)
                if file is 0 && a:failmsg isnot 0
                    return s:rrffailresult
                endif
                if a:ann>=0
                    topleft new
                endif
            endif
        "▶2 -aurum://annotate bvar → (repo), "." → (rev, file)
        elseif bvar.command is# 'annotate'
            let repo=bvar.repo
            let file=bvar.files[line('.')-1]
            if a:ann!=-2
                if !has_key(a:opts, 'rev')
                    let rev=bvar.revisions[line('.')-1]
                    let annrev=repo.functions.getrevhex(repo, bvar.rev)
                    if rev is# annrev
                        if a:ann!=1
                            " Don't do the following if we are not annotating
                        elseif has_key(bvar, 'annbuf') &&
                                    \bufwinnr(bvar.annbuf)!=-1
                            execute bufwinnr(bvar.annbuf).'wincmd w'
                        else
                            setlocal scrollbind
                            call s:_r.run('silent rightbelow vsplit',
                                        \ 'file', repo, rev, file)
                            let bvar.annbuf=bufnr('%')
                            setlocal scrollbind
                        endif
                        return s:rrffailresult
                    endif
                endif
                if a:ann>=0
                    if winnr('$')>1
                        wincmd c
                    endif
                    if has_key(bvar, 'annbuf') && bufwinnr(bvar.annbuf)!=-1
                        execute bufwinnr(bvar.annbuf).'wincmd w'
                    endif
                endif
            endif
        "▶2 Unknown command
        elseif a:failmsg isnot 0
            call s:_f.throw(a:failmsg)
        endif
    "▶2 buf → (repo, file), (rev=0)
    elseif filereadable(expand('%'))
        if a:ann==-1
            let file=expand('%')
        else
            let repo=s:_r.repo.get(':')
            let file=repo.functions.reltorepo(repo, expand('%'))
        endif
        let  rev=0
        let hasbuf=1
    "▲2
    elseif a:failmsg isnot 0
        call s:_f.throw(a:failmsg)
    endif
    "▶2 Update repository if appropriate
    if exists('repo') && exists('bvar.repo') &&
                \repo is bvar.repo && !empty(repo.cslist)
        call repo.functions.updatechangesets(repo)
    endif
    "▲2
    if a:ann!=-1
        "▶2 repo
        if !exists('repo')
            let repo=s:_r.repo.get(a:opts.repo)
            if type(repo)!=type({})
                call s:_f.throw('nrepo')
            endif
            let file=repo.functions.reltorepo(repo, file)
        endif
        "▶2 rev
        if a:ann==-2
            let rev=0
        elseif has_key(a:opts, 'rev')
            let oldrev=0
            if exists('rev') && rev isnot 0
                let oldrev=repo.functions.getrevhex(repo, rev)
            endif
            let rev=repo.functions.getrevhex(repo, a:opts.rev)
            if hasbuf && rev isnot# oldrev
                let hasbuf=0
            endif
        elseif exists('rev')
            if rev isnot 0
                let rev=repo.functions.getrevhex(repo, rev)
            endif
        else
            let rev=0
        endif
        "▲2
    endif
    return [hasbuf, exists('repo') ? repo : 0, rev,
                \((a:ann==-2)?
                \   ((exists('files'))?
                \       (files):
                \   ((file is 0)?
                \       (0)
                \   :
                \       ([file]))):
                \   (file))]
endfunction
"▶1 checkrepo
function s:F.checkrepo(repo)
    if type(a:repo)!=type({})
        call s:_f.throw('nrepo')
    endif
    return 1
endfunction
"▶1 closebuf :: bvar → + buf
function s:F.closebuf(bvar)
    let r=''
    if has_key(a:bvar, 'prevbuf') && bufexists(a:bvar.prevbuf)
        let r.=':buffer '.a:bvar.prevbuf."\n"
    endif
    let buf=bufnr('%')
    return r.':if bufexists('.buf.')|bwipeout '.buf."|endif\n"
endfunction
"▶1 getprevbuf :: () + bufvars → buf
function s:F.prevbuf()
    let r=bufnr('%')
    if has_key(s:_r.bufvars, r) && (&bufhidden is# 'wipe' ||
                \                   &bufhidden is# 'delete') &&
                \has_key(s:_r.bufvars[r], 'prevbuf')
        let r=s:_r.bufvars[r].prevbuf
    endif
    return r
endfunction
"▶1 Post cmdutils resource
call s:_f.postresource('cmdutils', {'globescape': s:F.globescape,
            \                           'getrrf': s:F.getrrf,
            \                      'getdifffile': s:F.getdifffile,
            \                        'checkrepo': s:F.checkrepo,
            \                         'closebuf': s:F.closebuf,
            \                          'prevbuf': s:F.prevbuf,
            \                     'nogetrepoarg': s:nogetrepoarg,
            \})
"▶1 Some completion-related globals
let s:cmds=['new', 'vnew', 'edit',
            \'leftabove vnew', 'rightbelow vnew', 'topleft vnew', 'botright vnew',
            \'aboveleft new',  'belowright new',  'topleft new',  'botright new',
            \]
call map(s:cmds, 'escape(v:val, " ")')
"▶1 getcrepo :: [ repo] → repo
function s:F.getcrepo(...)
    if a:0
        return a:1
    endif
    return s:_r.cache.get('repo', s:_r.repo.get, [':'], {})
endfunction
"▶1 getrevlist :: [ repo] → [String]
function s:F.getrevlist(...)
    let repo=call(s:F.getcrepo, a:000, {})
    return       repo.functions.getrepoprop(repo, 'tagslist')+
                \repo.functions.getrepoprop(repo, 'brancheslist')+
                \repo.functions.getrepoprop(repo, 'bookmarkslist')
endfunction
"▶1 getbranchlist :: [ repo] → [String]
function s:F.getbranchlist(...)
    let repo=call(s:F.getcrepo, a:000, {})
    return repo.functions.getrepoprop(repo, 'brancheslist')
endfunction
"▶1 Post comp resource
call s:_f.postresource('comp', {'rev': 'in *_r.comp.revlist',
            \                   'cmd': 'first (in _r.comp.cmdslst, idof cmd)',
            \                   'branch': 'in *_r.comp.branchlist',
            \                   'revlist': s:F.getrevlist,
            \                   'branchlist': s:F.getbranchlist,
            \                   'cmdslst': s:cmds,
            \})
"▶1
call frawor#Lockvar(s:, '_pluginloaded,_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
