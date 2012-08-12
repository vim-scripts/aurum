"▶1 
scriptencoding utf-8
execute frawor#Setup('1.0', {'@/resources': '0.0',
            \                  '@/options': '0.0',
            \                     '@aurum': '1.0',
            \             '@%aurum/status': '1.0',
            \           '@%aurum/cmdutils': '3.0',
            \            '@%aurum/bufvars': '0.0',
            \               '@%aurum/edit': '1.0',
            \               '@aurum/cache': '2.1',})
let s:_messages={
            \'emptmsg': 'Message must contain at least one non-blank character',
            \'nocfile': 'Unsure what should be commited',
            \'nocread': 'Cannot read aurum://commit',
            \  'nocom': 'Nothing to commit',
        \}
let s:_options={
            \'remembermsg':         {'default': 1, 'filter': 'bool'},
            \'bufleaveremembermsg': {'default': 1, 'filter': 'bool'},
        \}
"▶1 parsedate string → [year, month, day, hour, minute, second]
" Date must have one of the following formats (XXX it is not validated):
" %Y-%m-%d %H:%M:%S
" %Y-%m-%d %H:%M
" %Y-%m-%d
"    %m-%d %H:%M:%S
"    %m-%d %H:%M
"    %m-%d
"          %H:%M:%S
"          %H:%M
function s:F.parsedate(str)
    let parts=split(a:str)
    if len(parts)==1
        if stridx(parts[0], ':')==-1
            let day=parts[0]
            let time=0
        else
            let day=0
            let time=parts[0]
        endif
    else
        let [day, time]=parts
    endif
    let r=[]
    if day is# 0
        let r+=[0, 0, 0]
    else
        let parts=split(day, '-')
        if len(parts)==2
            let r+=[0]
        else
            let year=remove(parts, 0)
            if len(year)<=2
                let y=str2nr(year)
                let cy=str2nr(strftime('%y'))
                let c=str2nr(strftime('%Y')[:-3])
                if y<=cy
                    let year=''.((c*100)+y)
                else
                    let year=''.(((c-1)*100)+y)
                endif
            endif
            let r+=[year]
        endif
        let r+=map(parts, 'len(v:val)==1 ? "0".v:val : v:val')
    endif
    if time is# 0
        let r+=[0, 0, 0]
    else
        let parts=map(split(time, ':'), 'len(v:val)==1 ? "0".v:val : v:val')
        let r+=parts
        if len(parts)==2
            let r+=[0]
        endif
    endif
    return r
endfunction
"▶1 commit :: repo, opts, files, status, types → + repo
let s:defdate=['strftime("%Y")',
            \  'strftime("%m")',
            \  'strftime("%d")',
            \  '"00"',
            \  '"00"',
            \  '"00"']
let s:statmsgs={
            \'added': 'Added',
            \'removed': 'Removed',
            \'modified': 'Modified',
        \}
let s:statmsgs.unknown=s:statmsgs.added
let s:statmsgs.deleted=s:statmsgs.removed
" TODO Investigate why closing commit buffer on windows consumes next character
" XXX Do not change names of options used here, see :AuRecord
function s:F.commit(repo, opts, files, status, types)
    let user=''
    let date=''
    let message=''
    let cb=get(a:opts, 'closebranch', 0)
    let revstatus={}
    call map(filter(copy(a:status), 'index(a:types, v:key)!=-1'),
                \'map(copy(v:val),"extend(revstatus,{v:val : ''".v:key."''})")')
    if !empty(a:files)
        call filter(revstatus, 'index(a:files, v:key)!=-1')
    endif
    for key in filter(['user', 'date', 'message'], 'has_key(a:opts, v:val)')
        let l:{key}=a:opts[key]
    endfor
    "▶2 Normalize date
    if has_key(a:opts, 'date')
        let date=substitute(date, '_', ' ', '')
        let dparts=map(s:F.parsedate(date), 'v:val is 0 ? '.
                    \                               'eval(s:defdate[v:key]) : '.
                    \                               'v:val')
        let date=join(dparts[:2], '-').' '.join(dparts[3:], ':')
    endif
    "▲2
    if empty(message)
        call s:_r.run('silent new', 'commit', a:repo, user, date, cb, a:files)
        if exists('g:AuPreviousRepoPath') &&
                    \   g:AuPreviousRepoPath is# a:repo.path &&
                    \exists('g:AuPreviousTip') &&
                    \   g:AuPreviousTip is# a:repo.functions.gettiphex(a:repo)&&
                    \exists('g:AuPreviousCommitMessage')
            call setline('.', split(g:AuPreviousCommitMessage, "\n", 1))
            call cursor(line('$'), col([line('$'), '$']))
            unlet g:AuPreviousRepoPath g:AuPreviousTip g:AuPreviousCommitMessage
        endif
        let fmessage=[]
        for [file, state] in items(revstatus)
            let fmessage+=['# '.s:statmsgs[state].' '.file]
        endfor
        call sort(fmessage)
        call append('.', fmessage)
        startinsert!
        return 0
    else
        call a:repo.functions.commit(a:repo, message, a:files, user, date, cb)
        return 1
    endif
endfunction
"▶1 savemsg :: message, bvar → + g:
function s:F.savemsg(message, bvar)
    if a:message!~#"[^[:blank:]\n]"
        return
    endif
    let g:AuPreviousCommitMessage=a:message
    let g:AuPreviousTip=a:bvar.repo.functions.gettiphex(a:bvar.repo)
    let g:AuPreviousRepoPath=a:bvar.repo.path
endfunction
"▶1 finish :: bvar → + bvar.repo
function s:F.finish(bvar)
    let message=join(filter(getline(1, '$'), 'v:val[0] isnot# "#"'), "\n")
    if message!~#"[^[:blank:]\n]"
        call s:_f.throw('emptmsg')
    endif
    if s:_f.getoption('remembermsg')
        call s:F.savemsg(message, a:bvar)
    endif
    call a:bvar.repo.functions.commit(a:bvar.repo, message, a:bvar.files,
                \                     a:bvar.user, a:bvar.date,
                \                     a:bvar.closebranch)
    let a:bvar.did_message=1
    call feedkeys("\<C-\>\<C-n>:bwipeout!\n")
endfunction
"▶1 commfunc
function s:cmd.function(opts, ...)
    let rrfopts=copy(a:opts)
    let hasall=index(a:000, 'all')!=-1
    if a:0 && !hasall
        let rrfopts.files=a:000
    endif
    let [repo, rev, files]=s:_r.cmdutils.getrrf(rrfopts,
                \                               ((a:0)?(0):('nocfile')),
                \                               'getfiles')[1:]
    call s:_r.cmdutils.checkrepo(repo)
    let status=repo.functions.status(repo)
    "▶2 Get file list
    let types=['modified', 'added', 'removed']
    if hasall
        unlet files
        let files=[]
    elseif a:0
        if has_key(a:opts, 'type')
            let types=s:_r.status.parseshow(a:opts.type)
            call filter(types, 'v:val isnot# "clean" && v:val isnot# "ignored"')
        endif
        let filepats=map(filter(copy(a:000), 'v:val isnot# ":"'),
                    \    's:_r.globtopat('.
                    \    'repo.functions.reltorepo(repo, v:val))')
        let statfiles={}
        for [type, sfiles] in items(status)
            if index(types, type)==-1
                continue
            endif
            let curfiles=[]
            for pattern in filepats
                let curfiles+=filter(copy(sfiles), 'v:val=~#pattern')
            endfor
            if !empty(curfiles)
                let statfiles[type]=curfiles
                let files+=curfiles
            endif
        endfor
    elseif files is 0
        call s:_f.throw('nocfile')
    endif
    "▲2
    return s:F.commit(repo, a:opts, files, status, types)
endfunction
"▶1 aurum://commit
let s:commit={'arguments': 3,
            \  'listargs': 1,
            \'modifiable': 1,
            \  'filetype': 'aurumcommit',
            \}
function s:F.bufleave()
    let bvar=s:_r.bufvars[+expand('<abuf>')]
    if !bvar.did_message && s:_f.getoption('bufleaveremembermsg')
        let message=join(filter(getline(1,'$'),'v:val[0] isnot# "#"'), "\n")
        call s:F.savemsg(message, bvar)
    endif
endfunction
function s:commit.function(read, repo, user, date, cb, files)
    if a:read
        call s:_f.throw('nocread')
    endif
    augroup AuCommit
        autocmd! BufLeave <buffer> :call s:F.bufleave()
    augroup END
    return {'user': a:user, 'date': a:date, 'files': a:files,
                \'closebranch': !!a:cb, 'write': s:F.finish,
                \'did_message': 0}
endfunction
let s:_augroups+=['AuCommit']
function s:commit.write(lines, repo, user, date, cb, files)
    let message=join(filter(copy(a:lines), 'v:val[0] isnot# "#"'), "\n")
    call a:repo.functions.commit(a:repo, message, a:files, a:user, a:date, a:cb)
    call map(copy(s:_r.allcachekeys), 's:_r.cache.wipe(v:val)')
endfunction
call s:_f.newcommand(s:commit)
"▶1 Post resource
call s:_f.postresource('commit', {'commit': s:F.commit,
            \                     'finish': s:F.finish,})
"▶1
call frawor#Lockvar(s:, '_r,_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
