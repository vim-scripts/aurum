"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/resources': '0.0',
                \                       '@/os': '0.0',
                \                '@aurum/repo': '2.0',
                \                '@aurum/edit': '1.0',
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
    let lnr=search(diffre, 'bcnW')
    if !lnr
        return 0
    endif
    return a:bvar.repo.functions.diffname(a:bvar.repo, getline(lnr), diffre,
                \                         a:bvar.opts)
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
"▶1 rrf buffer functions :: bvar, opts, act, failmsg → scope
let s:rrf={}
"▶2 rrf.file : bvar → (repo, rev, file)
function s:rrf.file(bvar, opts, act, failmsg)
    return {'hasbuf': 1,
           \  'repo': a:bvar.repo,
           \   'rev': a:bvar.rev,
           \  'file': a:bvar.file,}
endfunction
"▶2 rrf.copy : bvar → (file), file → (repo), 0 → (rev)
function s:rrf.copy(bvar, opts, act, failmsg)
    let r={}
    if a:act is# 'getfile'
        let r.file=a:bvar.file
    else
        let r.repo=s:_r.repo.get(s:_r.os.path.dirname(a:bvar.file))
        let r.file=r.repo.functions.reltorepo(r.repo, a:bvar.file)
    endif
    let r.rev=0
    let r.hasbuf=1
    return r
endfunction
"▶2 rrf.edit : same as copy
let s:rrf.edit=s:rrf.copy
"▶2 rrf.status : bvar → (repo, rev), . → (file)
function s:rrf.status(bvar, opts, act, failmsg)
    let r={}
    let r.repo=a:bvar.repo
    let  r.rev=get(a:bvar.opts, 'rev1', 0)
    if empty(a:bvar.files)
        if a:failmsg isnot 0
            call s:_f.throw(a:failmsg)
        endif
    elseif a:act is# 'getfiles'
        let r.files=a:bvar.files
    else
        let r.file=a:bvar.files[line('.')-1]
    endif
    if a:act is# 'annotate' || a:act is# 'open'
        topleft new
    endif
    return r
endfunction
"▶2 rrf.diff : bvar → (repo, rev, file(s))
function s:rrf.diff(bvar, opts, act, failmsg)
    let r={}
    let r.repo=a:bvar.repo
    let  r.rev=empty(a:bvar.rev2) ? a:bvar.rev1 : a:bvar.rev2
    " XXX Maybe it should pull in all filenames instead when act='getfiles'?
    let r.file=s:F.getdifffile(a:bvar)
    if r.file is 0 && a:failmsg isnot 0
        return 0
    endif
    if a:act is# 'annotate' || a:act is# 'open'
        leftabove vnew
    endif
    return r
endfunction
"▶2 rrf.commit : bvar → (repo, file(s))
function s:rrf.commit(bvar, opts, act, failmsg)
    let r={}
    let r.repo=a:bvar.repo
    if a:act is# 'getfiles'
        let r.files=a:bvar.files
    else
        let r.file=s:F.getfile(a:bvar.files)
        if r.file is 0 && a:failmsg isnot 0
            return 0
        endif
        if a:act is# 'annotate' || a:act is# 'open'
            topleft new
        endif
    endif
    return r
endfunction
"▶2 rrf.annotate : bvar → (repo), . → (rev, file)
function s:rrf.annotate(bvar, opts, act, failmsg)
    let r={}
    let r.repo=a:bvar.repo
    if a:act is# 'getfiles'
        let r.file=a:bvar.file
    else
        let r.file=a:bvar.files[line('.')-1]
        if !has_key(a:opts, 'rev')
            let r.rev=a:bvar.revisions[line('.')-1]
            if r.rev is# r.repo.functions.getrevhex(r.repo, a:bvar.rev)
                if a:act isnot# 'annotate'
                    " Don't do the following if we are not annotating
                elseif has_key(a:bvar, 'annbuf') &&
                            \bufwinnr(a:bvar.annbuf)!=-1
                    execute bufwinnr(a:bvar.annbuf).'wincmd w'
                else
                    setlocal scrollbind
                    call s:_r.run('silent rightbelow vsplit',
                                \ 'file', r.repo, r.rev, r.file)
                    let a:bvar.annbuf=bufnr('%')
                    setlocal scrollbind
                endif
                return 0
            endif
        endif
        if a:act is# 'annotate' || a:act is# 'open'
            if winnr('$')>1
                close
            endif
            if has_key(a:bvar, 'annbuf') && bufwinnr(a:bvar.annbuf)!=-1
                execute bufwinnr(a:bvar.annbuf).'wincmd w'
            endif
        endif
    endif
    return r
endfunction
"▶2 rrf.log : bvar → repo, . → (rev), 0 → (file)
function s:rrf.log(bvar, opts, act, failmsg)
    return {'repo': a:bvar.repo,
           \ 'rev': a:bvar.getblock(a:bvar)[2],
           \'file': 0,}
endfunction
"▲2
"▶1 getrrf :: opts, failmsg, act + buf → (hasbuf, repo, rev, file)
let s:rrffailresult=[0, 0, 0, 0]
function s:F.getrrf(opts, failmsg, act)
    let hasbuf=0
    let file=0
    "▶2 a:opts.file file → (repo?)
    if has_key(a:opts, 'file') && a:opts.file isnot# ':'
        if a:act isnot# 'getfile' && a:opts.repo is# ':'
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
            let [repo, rev, file]=s:F.getrrf(newopts, 'nocurf', 'getfile')[1:]
            if repo is 0
                unlet repo
                let repo=s:_r.repo.get(file)
            endif
            if repo isnot 0
                let file=repo.functions.reltorepo(repo, file)
            endif
            let files+=[file]
        else
            let repo=s:_r.repo.get(a:opts.files[0])
        endif
    "▶2 aurum:// buffers
    elseif has_key(s:_r.bufvars, bufnr('%')) &&
                \has_key(s:_r.bufvars[bufnr('%')], 'command')
        let bvar=s:_r.bufvars[bufnr('%')]
        if has_key(s:rrf, bvar.command)
            let res=call(s:rrf[bvar.command], [bvar,a:opts,a:act,a:failmsg], {})
            if res is 0
                return s:rrffailresult
            else
                for [var, val] in items(res)
                    let {var}=val
                    unlet val
                endfor
            endif
        elseif a:failmsg isnot 0
            call s:_f.throw(a:failmsg)
        endif
    "▶2 buf → (repo, file), (rev=0)
    elseif filereadable(expand('%'))
        if a:act is# 'getfile'
            let file=expand('%')
        else
            let repo=s:_r.repo.get(':')
            let file=repo.functions.reltorepo(repo, expand('%'))
        endif
        let  rev=0
        let hasbuf=2
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
    if a:act isnot# 'getfile'
        "▶2 repo
        if !exists('repo')
            let repo=s:_r.repo.get(a:opts.repo)
            if type(repo)!=type({})
                call s:_f.throw('nrepo')
            endif
            if file isnot 0
                let file=repo.functions.reltorepo(repo, file)
            endif
        endif
        "▶2 rev
        if a:act is# 'getfiles'
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
                \((a:act is# 'getfiles')?
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
