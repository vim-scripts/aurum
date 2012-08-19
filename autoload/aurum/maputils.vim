"▶1
scriptencoding utf-8
execute frawor#Setup('0.0', {'@/resources': '0.0',
            \                       '@/os': '0.0',})
let s:_messages={
            \'plinst': 'If you install Command-T, Ctrlp or FuzzyFinder '.
            \          'you will be prompted with much less sucking interface',
        \}
let s:r={}
"▶1 update
function s:r.update(repo, rev, count)
    let rev=a:rev
    if a:count>1
        let rev=a:repo.functions.getnthparent(a:repo, rev, a:count-1).hex
    endif
    return a:repo.functions.update(a:repo, rev, 0)
endfunction
"▶1 listplugs
let s:F.listplugs={}
let s:plug=0
"▶2 commandt
let s:F.listplugs.commandt={}
function s:F.listplugs.commandt.init()
    try
        execute 'rubyfile' fnameescape(s:_r.os.path.join(s:_frawor.runtimepath,
                    \'ruby', 'aurum-command-t-rubyinit.rb'))
        return 1
    catch
        return 0
    endtry
endfunction
function s:F.listplugs.commandt.call(files, cbargs, pvargs)
    let [b:aurum_callback_fun; b:aurum_addargs]=a:cbargs
    ruby $aurum_old_command_t = $command_t
    ruby $command_t = $aurum_command_t
    ruby $command_t.show_aurum_finder
    autocmd BufUnload <buffer> ruby $command_t = $aurum_old_command_t
endfunction
"▶2 ctrlp
function s:Accept(mode, str)
    let d={}
    let d.cbfun=b:aurum_callback_fun
    let addargs=b:aurum_addargs
    call ctrlp#exit()
    return call(d.cbfun, [a:str]+addargs, {})
endfunction
let s:_functions+=['s:Accept']
let s:ctrlp_ext_var={
            \'init': '<SNR>'.s:_sid.'_Eval("s:ctrlp_files")',
            \'accept': '<SNR>'.s:_sid.'_Accept',
            \'lname': 'changeset files',
            \'sname': 'changeset file',
            \'type': 'path',
        \}
let s:ctrlp_id=0
let s:ctrlp_files=[]
let s:F.listplugs.ctrlp={}
function s:F.listplugs.ctrlp.init()
    try
        runtime plugin/ctrlp.vim
        call add(g:ctrlp_ext_vars, s:ctrlp_ext_var)
        let s:ctrlp_id=g:ctrlp_builtins+len(g:ctrlp_ext_vars)
        lockvar! s:ctlp_id
        return 1
    catch
        return 0
    endtry
endfunction
function s:F.listplugs.ctrlp.call(files, cbargs, pvargs)
    let s:ctrlp_files=a:files
    call ctrlp#init(s:ctrlp_id)
    let [b:aurum_callback_fun; b:aurum_addargs]=a:cbargs
endfunction
"▶2 fuf
let s:F.listplugs.fuf={}
function s:F.listplugs.fuf.init()
    try
        runtime plugin/fuf.vim
        call fuf#addMode('aurum')
        return 1
    catch
        return 0
    endtry
endfunction
function s:F.listplugs.fuf.call(files, cbargs, pvargs)
    call fuf#aurum#setAuVars({'files': a:files, 'cbargs': a:cbargs,
                \                               'pvargs': a:pvargs})
    call fuf#launch('aurum', '', 0)
endfunction
"▶1 promptuser
function s:r.promptuser(files, cbargs, pvargs)
    if s:plug is 0
        for plug in values(s:F.listplugs)
            if plug.init()
                unlet s:plug
                let s:plug=plug
                break
            endif
        endfor
        if s:plug is 0
            let s:plug=-1
        endif
        lockvar s:plug
    endif
    if s:plug is -1
        try
            let choice=inputlist(['Select file (0 to cancel):']+
                        \        map(copy(a:files), '(v:key+1).". ".v:val'))
            if choice
                return call(a:cbargs[0], [a:files[choice-1]]+a:cbargs[1:], {})
            endif
        finally
            call s:_f.warn('plinst')
        endtry
    else
        return s:plug.call(a:files, a:cbargs, a:pvargs)
    endif
endfunction
"▶1 readfilewrapper :: file, repo, rev → [String]
function s:r.readfilewrapper(file, repo, rev)
    return a:repo.functions.readfile(a:repo, a:rev, a:file)
endfunction
"▶1 Post maputils resource
call s:_f.postresource('maputils', s:r)
"▶1
call frawor#Lockvar(s:, 'plug,ctrlp_id,ctrlp_files')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
