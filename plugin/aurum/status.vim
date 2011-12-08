"▶1 
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/resources': '0.0',
                \            '@aurum/cmdutils': '0.0',
                \                      '@/fwc': '0.2',
                \                '@aurum/repo': '1.0',
                \                '@aurum/edit': '0.0',
                \                 '@/commands': '0.0',
                \                  '@/options': '0.0',
                \                '@/functions': '0.0',}, 0)
    call FraworLoad('@/commands')
    call FraworLoad('@/functions')
    let s:statcomp=[]
    let s:statfunc={}
    call s:_f.command.add('AuStatus', s:statfunc, {'nargs': '*',
                \                               'complete': s:statcomp})
    finish
elseif s:_pluginloaded
    finish
endif
let s:statchars={
            \ 'deleted': '!',
            \ 'unknown': '?',
        \}
let s:_options={
            \'usestatwin': {'default': 1, 'filter': 'bool'},
        \}
let s:defshow=['modified', 'added', 'removed', 'deleted', 'unknown']
let s:allshow=s:defshow+['ignored', 'clean']
let s:showchars={}
call map(copy(s:statchars), 'extend(s:showchars, {v:val            : v:key})')
call map(copy(s:allshow),   'extend(s:showchars, {toupper(v:val[0]): v:val})')
"▶1 parseshow :: [Either type tabbr] → [type]
function s:F.parseshow(show)
    let r=[]
    for type in a:show
        if type[0]=~#'^\l'
            let r+=[type]
        else
            let r+=map(split(type, '\v.@='), 's:showchars[v:val]')
        endif
    endfor
    return r
endfunction
"▶1 setup
function s:F.setup(read, repo, opts)
    let opts=a:opts
    for key in filter(['rev1', 'rev2'], 'has_key(opts, v:val)')
        let opts[key]=a:repo.functions.getrevhex(a:repo, opts[key])
    endfor
    let bvar={}
    let status=a:repo.functions.status(a:repo, get(opts, 'rev1', 0),
                \                              get(opts, 'rev2', 0))
    let bvar.status=status
    let bvar.types=[]
    let bvar.chars=[]
    let bvar.files=[]
    if has_key(opts, 'show')
        if index(opts.show, 'all')==-1
            let show=s:F.parseshow(opts.show)
        else
            let show=s:allshow
        endif
    else
        let show=s:defshow
    endif
    let isrecord=get(opts, 'record', 0)
    let statlines=[]
    for [type, files] in filter(sort(items(status)), 'index(show,v:val[0])!=-1')
        let char=has_key(s:statchars, type)? s:statchars[type]: toupper(type[0])
        for file in files
            let ignore=0
            if has_key(opts, 'files')
                let ignore=1
                for pattern in opts.filepats
                    if file=~#pattern
                        let ignore=0
                        break
                    endif
                endfor
            endif
            if ignore
                continue
            endif
            let statlines+=[((isrecord)?('-'):('')).char.' '.file]
            let bvar.types+=[type]
            let bvar.chars+=[char]
            let bvar.files+=[file]
        endfor
    endfor
    if empty(statlines)
        let statlines=['No changes found']
    endif
    if a:read
        call append('.', statlines)
    else
        call setline('.', statlines)
        setlocal readonly nomodifiable
        augroup AuStatusNoInsert
            autocmd InsertEnter <buffer> :call feedkeys("\e", 'n')
        augroup END
    endif
    return bvar
endfunction
let s:_augroups+=['AuStatusNoInsert']
"▶1 statfunc
let s:defcmd='silent botright new'
function s:statfunc.function(repopath, opts)
    if has_key(a:opts, 'files') && a:repopath is# ':'
        let repo=s:_r.repo.get(a:opts.files[0])
    else
        let repo=s:_r.repo.get(a:repopath)
    endif
    call s:_r.cmdutils.checkrepo(repo)
    let opts=[]
    if has_key(a:opts, 'files')
        call map(a:opts.files, 'repo.functions.reltorepo(repo, v:val)')
    endif
    if has_key(a:opts, 'cmd')
        call s:_r.run(a:opts.cmd, 'status', repo, a:opts)
    elseif s:_f.getoption('usestatwin') &&
                \!empty(filter(tabpagebuflist(),
                \              'bufname(v:val)=~#''\v^aurum:(.)\1status'''))
        let statf=s:_r.fname('status', repo, a:opts)
        if bufexists(statf) && bufwinnr(statf)!=-1
            execute bufwinnr(statf).'wincmd w'
            silent edit
        else
            call s:_r.run(s:defcmd, 'status', repo, a:opts)
        endif
    else
        call s:_r.run(s:defcmd, 'status', repo, a:opts)
    endif
    if !has_key(a:opts, 'cmd')
        let lnum=line('$')
        if winnr('$')>1 && ((winheight(0)>lnum) ||
                    \       (winheight(0)!=lnum && lnum<(&lines/3)))
            execute 'resize' lnum
        endif
        setlocal bufhidden=wipe
    endif
endfunction
let s:statfunc['@FWC']=['-onlystrings '.
            \           '['.s:_r.cmdutils.nogetrepoarg.']'.
            \           '{ *?files     (type "")'.
            \           '   ?rev1      (type "")'.
            \           '   ?rev2      (type "")'.
            \           '  *?show      (either (in [modified added removed '.
            \                                      'deleted unknown ignored '.
            \                                      'clean all] ~start, '.
            \                                  'match /\v^[MARDUIC!?]+$/))'.
            \           '   ?cmd       (type "")'.
            \           '}', 'filter']
call add(s:statcomp,
            \substitute(substitute(substitute(substitute(s:statfunc['@FWC'][0],
            \'\V|*_r.repo.get',             '',                    ''),
            \'\vfiles\s+\([^)]*\)',       'files path',            ''),
            \'\Vcmd\s\+(type "")',        'cmd '.  s:_r.comp.cmd,  ''),
            \'\vrev([12])\s+\V(type "")', 'rev\1 '.s:_r.comp.rev,  'g'))
"▶1 aurum://status
call s:_f.newcommand({
            \'function': s:F.setup,
            \ 'options': {'list': ['files', 'show'],
            \             'bool': ['record'],
            \              'str': ['rev1', 'rev2'],
            \             'pats': ['files'],},
            \'filetype': 'aurumstatus',
            \})
"▶1 status resource
call s:_f.postresource('status', {'parseshow': s:F.parseshow})
"▶1
call frawor#Lockvar(s:, '_r,_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
