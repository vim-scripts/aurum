"▶1 
scriptencoding utf-8
setlocal textwidth=80
setlocal nonumber
if exists('+relativenumber')
    setlocal norelativenumber
endif
setlocal noswapfile
setlocal nomodeline
execute frawor#Setup('0.0', {'@/mappings': '0.0',
            \           '@%aurum/bufvars': '0.0',
            \            '@%aurum/commit': '1.0',})
"▶1 com.runcommap
function s:F.runcommap(count, action)
    let buf=bufnr('%')
    let bvar=s:_r.bufvars[buf]
    if a:action is# 'commit'
        call s:_r.commit.finish(bvar)
    elseif a:action is# 'discard'
        bwipeout!
        stopinsert
    elseif a:action[:5] is# 'recall'
        if has_key(bvar, 'recallcs')
            let cnt=(a:count ? a:count : 1)
            let oldmsg=split(bvar.recallcs.description, "\n", 1)
            if !empty(oldmsg)
                let morelen=len(oldmsg)-1
                let moremsg=oldmsg[1:]
                for line in range(1, line('$'))
                    if getline(line) is# oldmsg[0] &&
                                \(morelen ?
                                \   getline(line+1, line+morelen) ==# moremsg :
                                \   1)
                        execute 'silent' line.','.(line+morelen).'delete _'
                        undojoin
                        break
                    endif
                endfor
            endif
        else
            let bvar.recallcs=bvar.repo.functions.getwork(bvar.repo)
            let cnt=a:count
            if empty(getline(1))
                silent 1 delete _
                undojoin
            endif
        endif
        let cnt=((a:action[6:] is# 'prev')?(cnt):(-cnt))
        let bvar.recallcs=bvar.repo.functions.getnthparent(bvar.repo,
                    \                                      bvar.recallcs.hex,
                    \                                      cnt)
        call append(0, split(bvar.recallcs.description, "\n", 1))
    endif
    if has_key(bvar, 'sbvar')
        call bvar.sbvar.recunload(bvar.sbvar)
    endif
endfunction
"▶1 AuCommitMessage mapping group
function s:F.mapwrapper(...)
    return "\<C-\>\<C-n>".
                \":call call(\<SNR>".s:_sid."_Eval('s:F.runcommap'), ".
                \            string([v:count]+a:000).', '.
                \           "{})\n"
endfunction
call s:_f.mapgroup.add('AuCommitMessage', {
            \ 'Commit': {'lhs': 'i', 'rhs': ['commit']    },
            \   'Prev': {'lhs': 'J', 'rhs': ['recallprev']},
            \   'Next': {'lhs': 'K', 'rhs': ['recallnext']},
            \   'Exit': {'lhs': 'X', 'rhs': ['discard']   },
        \}, {'mode': 'in', 'silent': 1, 'leader': '<LocalLeader>',
        \    'func': s:F.mapwrapper})
"▶1
call frawor#Lockvar(s:, '_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
