"▶1 Setup
scriptencoding utf-8
execute frawor#Setup('1.0', {'@/commands': '0.0',
            \               '@/functions': '0.0',
            \                '@/mappings': '0.0',
            \                     '@/fwc': '0.3',
            \            '@/autocommands': '0.0',
            \               '@/resources': '0.0',
            \              '@aurum/cache': '2.1',})
"▶1 Messages
let s:_messages={
            \'afail': 'Failed to load aurum:// function from %s',
            \'anofu': 'Plugin %s did not provide any functions for aurum://',
            \'lfail': 'Failed to load Au%s’s function from %s',
            \'nofun': 'Plugin %s did not provide any functions for Au%s',
        \}
"▶1 Command descriptions
" XXX Normally I use “type ""”. Things below are used to make these parts 
"     unique.
let s:revarg='type string'
let s:filearg='type String'
let s:cmdarg='type STRING'
"XXX AuRecord notes:
" options message, user, date and closebranch are used by com.commit
" documentation says that options are the same as for `:AuCommit' except for 
" `type' option
let s:datereg='%(\d\d%(\d\d)?|[*.])'.
            \ '%(\-%(\d\d?|[*.])'.
            \ '%(\-%(\d\d?|[*.])'.
            \ '%([ _]%(\d\d?|[*.])'.
            \ '%(\:%(\d\d?|[*.]))?)?)?)?'
let s:patharg='either (path d, match @\v^\w+%(\+\w+)*\V://\v|^\:$@)'
let s:nogetrepoarg=':":" ('.s:patharg.')'
unlet s:patharg
let s:compbranchrevarg='in *F.branchlist'
let s:comprevarg='in *F.revlist'
let s:compcmdarg='first (in compcmds, idof cmd)'
" XXX Some code relies on the fact that all options from s:diffoptslst are
"     numeric
let s:diffoptslst=['git', 'reverse', 'ignorews', 'iwsamount', 'iblanks',
            \      'numlines', 'showfunc', 'alltext', 'dates']
let s:diffoptsstr=join(map(copy(s:diffoptslst),
            \          'v:val is# "numlines" ? '.
            \               '" ?".v:val." range 0 inf" : '.
            \               '"!?".v:val'))
let s:allcachekeys=['branch', 'changeset', 'repository', 'status']
let s:cmds={
            \'Update':    {'opts': {'bang': 1},
            \               'fwc': '[:=(0) '.s:revarg.
            \                      '['.s:nogetrepoarg.']',
            \              'wipe': ['branch', 'changeset', 'status'],
            \             },
            \'Move':      {'opts': {'bang': 1},
            \               'fwc': '{  repo '.s:nogetrepoarg.
            \                      ' ?!copy'.
            \                      ' ?!rightrepl'.
            \                      ' ?!leftpattern'.
            \                      ' ?!pretend'.
            \                      '} '.
            \                      '+ '.s:filearg,
            \              'wipe': ['status'],
            \             },
            \'Junk':      { 'fwc': '{?!forget '.
            \                       '?!ignore '.
            \                       '?!remove '.
            \                       '?!ignoreglobs '.
            \                      '} + '.s:filearg,
            \              'wipe': ['status'],
            \             },
            \'Track':     { 'fwc': '+ '.s:filearg,
            \              'wipe': ['status'],
            \             },
            \'Hyperlink': {'opts': {'range': '%'},
            \               'fwc': '{   ?repo '.s:nogetrepoarg.
            \                      '    ?rev   '.s:revarg.
            \                      '    ?file  '.s:filearg.
            \                      ' !+1?line  range 1 inf'.
            \                      ' !+2?lines (range 1 inf)(range 1 inf)'.
            \                      '    ?cmd   '.s:cmdarg.
            \                      '    ?url   in utypes ~start'.
            \                      '}',
            \             },
            \'Grep':      {'fwc': 'type "" '.
            \                     '{     repo     '.s:nogetrepoarg.
            \                     ' ?*+2 revrange   '.s:revarg.' '.s:revarg.
            \                     ' ?*   revision   '.s:revarg.
            \                     ' ?*   files      '.s:filearg.
            \                     ' ?    location   range 0 $=winnr("$")'.
            \                     ' ?   !workmatch'.
            \                     ' ?   !wdfiles'.
            \                     ' ?   !ignorecase '.
            \                     '}',
            \             },
            \'Branch':    {'opts': {'bang': 1},
            \               'fwc': 'type "" '.
            \                      '{  repo '.s:nogetrepoarg.
            \                      '}',
            \              'wipe': ['branch', 'changeset'],
            \             },
            \'Name':      {'opts': {'bang': 1},
            \               'fwc': 'type ""'.
            \                      '{  repo '.s:nogetrepoarg.
            \                      ' ? type   type ""'.
            \                      ' ?!delete'.
            \                      ' ?!local'.
            \                      '} '.
            \                      '+ type ""',
            \              'wipe': ['branch', 'changeset'],
            \             },
            \'Other':     {'opts': {'bang': 1},
            \               'fwc': 'in ppactions ~ smart '.
            \                      '[:":" '.s:revarg.
            \                      '[:":" '.s:filearg.
            \                      '['.s:nogetrepoarg.']]]',
            \              'wipe': s:allcachekeys,
            \             },
            \'Annotate':  { 'fwc': '{  repo  '.s:nogetrepoarg.
            \                      '  ?file  '.s:filearg.
            \                      '  ?rev   '.s:revarg.
            \                      '}',
            \             },
            \'Commit':    { 'fwc': '{  repo '.s:nogetrepoarg.
            \                      ' *?type      (either (in [modified added '.
            \                                                'removed deleted '.
            \                                                'unknown all] '.
            \                                               '~start,'.
            \                                            'match /\v^[MARDU?!]+$/))'.
            \                      '  ?message   type ""'.
            \                      '  ?user      type ""'.
            \                      '  ?date      match /\v%(^%(\d*\d\d-)?'.
            \                                               '%(%(1[0-2]|0?[1-9])-'.
            \                                                 '%(3[01]|0?[1-9]|[12]\d)))?'.
            \                                            '%(%(^|[ _])%(2[0-3]|[01]\d)'.
            \                                                       '\:[0-5]\d'.
            \                                                       '%(\:[0-5]\d)?)?$/'.
            \                      ' !?closebranch'.
            \                      '}'.
            \                      '+ '.s:filearg,
            \              'wipe': s:allcachekeys,
            \             },
            \'Diff':      { 'fwc': '{  repo     '.s:nogetrepoarg.
            \                      '  ?rev1     '.s:revarg.
            \                      '  ?rev2     '.s:revarg.
            \                      '  ?changes  '.s:revarg.
            \                      s:diffoptsstr.
            \                      '  ?cmd      '.s:cmdarg.
            \                      '}'.
            \                      '+ '.s:filearg,
            \             },
            \'File':      { 'fwc': '[:=(0)   type ""'.
            \                      '[:=(0)   either (match /\L/, path fr)]]'.
            \                      '{  repo '.s:nogetrepoarg.
            \                      ' !?replace'.
            \                      ' !?prompt'.
            \                      '  ?cmd    '.s:cmdarg.
            \                      '}',
            \              'subs': [['\V:=(0)\s\+either (\[^)]\+)', 'path', ''],
            \                       ['\V:=(0)\s\+type ""',
            \                         'either (type "" '.s:comprevarg.')',  ''],
            \                       ['\v\[(.{-})\]',                '\1',   ''],
            \                      ],
            \             },
            \'Record':    { 'fwc': '{  repo '.s:nogetrepoarg.
            \                      '  ?message           type ""'.
            \                      '  ?date              type ""'.
            \                      '  ?user              type ""'.
            \                      ' !?closebranch'.
            \                      '} '.
            \                      '+ '.s:filearg,
            \             },
            \'Status':    { 'fwc': '['.s:nogetrepoarg.']'.
            \                      '{ *?files     '.s:filearg.
            \                      '   ?rev       '.s:revarg.
            \                      '   ?wdrev     '.s:revarg.
            \                      '   ?changes   '.s:revarg.
            \                      '  *?show      (either (in [modified added '.
            \                                                 'removed deleted '.
            \                                                 'unknown ignored '.
            \                                                 'clean all] ~start, '.
            \                                             'match /\v^[MARDUIC!?]+$/))'.
            \                      '   ?cmd       '.s:cmdarg.
            \                      '}',
            \             },
            \'VimDiff':   { 'fwc': '{  repo  '.s:nogetrepoarg.
            \                      '  ?file  '.s:filearg.
            \                      ' *?files (match /\W/)'.
            \                      ' !?full'.
            \                      ' !?untracked'.
            \                      ' !?onlymodified'.
            \                      ' !?curfile'.
            \                      ' !?usewin'.
            \                      '}'.
            \                      '+ '.s:revarg,
            \              'subs': [['\V(match /\\W/)', '(path)', '']],
            \             },
            \'Log':       { 'fwc': '['.s:nogetrepoarg.']'.
            \                      '{ *  ?files    '.s:filearg.
            \                      '  *  ?ignfiles in ignfiles ~start'.
            \                      '     ?date     match /\v[<>]?\=?'.s:datereg.'|'.
            \                                             s:datereg.'\<\=?\>'.s:datereg.'/'.
            \                      '     ?search   isreg'.
            \                      '     ?user     isreg'.
            \                      '     ?branch   type ""'.
            \                      ' ! +1?limit    range 1 inf'.
            \                      '     ?revision '.s:revarg.
            \                      '   +2?revrange '.s:revarg.' '.s:revarg.
            \                      '     ?style    in tlist'.
            \                      '     ?template idof variable'.
            \                      ' !   ?merges'.
            \                      ' !   ?patch'.
            \                      ' !   ?stat'.
            \                      ' !   ?showfiles'.
            \                      ' !   ?showrenames'.
            \                      ' !   ?showcopies'.
            \                      ' !   ?procinput'.
            \                      ' !   ?autoaddlog'.
            \                      ' !   ?progress'.
            \                      s:diffoptsstr.
            \                      '    ?cmd      '.s:cmdarg.
            \                      '}',
            \              'subs': [['\vbranch\s+\Vtype ""',
            \                                'branch '.s:compbranchrevarg, '']],
            \             },
        \}
unlet s:datereg s:nogetrepoarg s:compbranchrevarg
"▶1 Related globals
let s:utypes=['html', 'raw', 'annotate', 'filehist', 'bundle', 'changeset',
            \ 'log', 'clone', 'push']
call s:_f.postresource('utypes', s:utypes)
let s:pushactions=['push', 'outgoing']
let s:pullactions=['pull', 'incoming']
let s:ppactions=s:pushactions+s:pullactions
call s:_f.postresource('otheractions', {'push': s:pushactions,
            \                           'pull': s:pullactions})
let s:ignfiles=['patch', 'renames', 'copies', 'files', 'diff', 'open']
call s:_f.postresource('ignfiles', s:ignfiles)
call s:_f.postresource('diffopts', s:diffoptslst)
let s:tlist=['default', 'compact', 'git', 'svn', 'hgdef', 'hgdescr', 'cdescr',
            \'gitoneline', 'bzr', 'bzrshort', 'bzrline']
call s:_f.postresource('tlist', s:tlist)
call s:_f.postresource('allcachekeys', s:allcachekeys)
"▶1 Completion helpers
let s:compcmds=['new', 'vnew', 'edit',
            \   'leftabove vnew', 'rightbelow vnew',
            \   'topleft vnew',   'botright vnew',
            \   'aboveleft new',  'belowright new',
            \   'topleft new',    'botright new',]
call map(s:compcmds, 'escape(v:val, " ")')
function s:F.revlist(...)
    let repo=aurum#repository()
    return       repo.functions.getrepoprop(repo, 'tagslist')+
                \repo.functions.getrepoprop(repo, 'brancheslist')+
                \repo.functions.getrepoprop(repo, 'bookmarkslist')
endfunction
function s:F.branchlist()
    let repo=aurum#repository()
    return repo.functions.getrepoprop(repo, 'brancheslist')
endfunction
"▶1 Commands setup
let s:plpref='autoload/aurum/'
let s:d={}
let s:cmdfuncs={}
for [s:cmd, s:cdesc] in items(s:cmds)
    let s:cdesc.opts=extend(get(s:cdesc, 'opts', {}), {'nargs': '*',
                \                                   'complete': []})
    "▶2 Completion substitutions
    let s:cdesc.subs=get(s:cdesc, 'subs', [])
    if stridx(s:cdesc.fwc, s:revarg)!=-1
        let s:cdesc.subs+=[['\V'.s:revarg,    s:comprevarg, 'g']]
    endif
    if stridx(s:cdesc.fwc, s:filearg)!=-1
        let s:cdesc.subs+=[['\V'.s:filearg,   '(path)',     'g']]
    endif
    if stridx(s:cdesc.fwc, s:cmdarg)!=-1
        let s:cdesc.subs+=[['\V'.s:cmdarg,    s:compcmdarg, '' ]]
    endif
    "▲2
    let s:compfwc='-onlystrings '.s:cdesc.fwc
    for s:args in s:cdesc.subs
        let s:compfwc=call('substitute', [s:compfwc]+s:args)
        unlet s:args
    endfor
    let s:cdesc.opts.complete+=[s:compfwc]
    unlet s:compfwc
    " Number of arguments that should not be checked or completed
    let s:skipcount=  has_key(s:cdesc.opts, 'bang')+
                \   2*has_key(s:cdesc.opts, 'range')
    let s:cdesc.fwc='-onlystrings '.repeat('_ ', s:skipcount).s:cdesc.fwc
    unlet s:skipcount
    let s:eplid=string((s:plpref).(tolower(s:cmd)))
    execute      "function s:d.function(...)\n".
                \"    if !has_key(s:cmdfuncs, ".s:eplid.")\n".
                \"        if !has_key(s:cmddicts, ".s:eplid.")\n".
                \"            call FraworLoad(".s:eplid.")\n".
                \"            if !has_key(s:cmddicts, ".s:eplid.")\n".
                \"                call s:_f.throw('lfail', '".s:cmd."', ".
                \                                             s:eplid.")\n".
                \"            endif\n".
                \"        endif\n".
                \"        if !has_key(s:cmddicts[".s:eplid."], ".
                \                        "'function')\n".
                \"            call s:_f.throw('nofun', ".s:eplid.", ".
                \                                    "'".s:cmd."')\n".
                \"        endif\n".
                \"        let s:cmdfuncs[".s:eplid."]=s:_f.wrapfunc(".
                \                  "extend({'@FWC': [".string(s:cdesc.fwc).", ".
                \                                   "'filter']}, ".
                \                         "s:cmddicts[".s:eplid."]))\n".
                \"    endif\n".
                \"    call call(s:cmdfuncs[".s:eplid."], a:000, {})\n".
                \((has_key(s:cdesc, 'wipe'))?
                \    ("    call map(".string(s:cdesc.wipe).", ".
                \                  "'s:_r.cache.wipe(v:val)')\n"):
                \    ("")).
                \"endfunction"
    unlet s:eplid
    call s:_f.command.add('Au'.s:cmd, remove(s:d, 'function'), s:cdesc.opts)
    unlet s:cmd s:cdesc
endfor
unlet s:d
unlet s:comprevarg s:compcmdarg
"▶1 aurumcmd feature
let s:feature={}
let s:cmddicts={}
function s:feature.register(plugdict, fdict)
    let a:plugdict.g.cmd={}
    let s:cmddicts[a:plugdict.id]=a:plugdict.g.cmd
endfunction
function s:feature.unload(plugdict, fdict)
    unlet s:cmddicts[a:plugdict.id]
    if has_key(s:cmdfuncs, a:plugdict.id)
        unlet s:cmdfuncs[a:plugdict.id]
    endif
endfunction
call s:_f.newfeature('aurumcmd', s:feature)
"▶1 Global mappings
" TODO mapping that closes status window
call s:_f.mapgroup.add('Aurum', {
            \'Commit':    {'lhs':  'i', 'rhs': ':<C-u>AuCommit<CR>'          },
            \'CommitAll': {'lhs':  'I', 'rhs': ':<C-u>AuCommit all<CR>'      },
            \'Open':      {'lhs':  'o', 'rhs': ':<C-u>AuFile<CR>'            },
            \'OpenAny':   {'lhs':  'O', 'rhs': ':<C-u>AuFile : : prompt<CR>' },
            \'Revert':    {'lhs': 'go', 'rhs': ':<C-u>AuFile : : replace<CR>'},
            \'Vdiff':     {'lhs':  'D', 'rhs': ':<C-u>AuVimDiff<CR>'         },
            \'FVdiff':    {'lhs': 'gD', 'rhs': ':<C-u>AuVimDiff full<CR>'    },
            \'Diff':      {'lhs':  'd', 'rhs': ':<C-u>AuDiff :<CR>'          },
            \'Fdiff':     {'lhs': 'gd', 'rhs': ':<C-u>AuDiff<CR>'            },
            \'Annotate':  {'lhs':  'a', 'rhs': ':<C-u>AuAnnotate<CR>'        },
            \'Status':    {'lhs':  's', 'rhs': ':<C-u>AuStatus|wincmd p<CR>' },
            \'Record':    {'lhs':  'r', 'rhs': ':<C-u>AuRecord<CR>'          },
            \'Log':       {'lhs':  'L', 'rhs': ':<C-u>AuLog<CR>'             },
            \'LogFile':   {'lhs':  'l', 'rhs': ':<C-u>AuLog : files :<CR>'   },
            \'URL':       {'lhs':  'H', 'rhs': ':<C-u>AuHyperlink<CR>'       },
            \'LineURL':   {'lhs':  'h', 'rhs': ':<C-u>AuHyperlink line 0<CR>'},
            \'Track':     {'lhs':  'A', 'rhs': ':<C-u>AuTrack<CR>'           },
            \'Forget':    {'lhs':  'R', 'rhs': ':<C-u>AuJunk forget :<CR>'   },
            \'Push':      {'lhs':  'P', 'rhs': ':<C-u>AuOther push<CR>'      },
            \'Pull':      {'lhs':  'p', 'rhs': ':<C-u>AuOther pull<CR>'      },
        \}, {'mode': 'n', 'silent': 1, 'leader': '<Leader>a'})
"▶1 Autocommands
function s:F.aurun(...)
    let plid='autoload/aurum/edit'
    if !has_key(s:cmdfuncs, plid)
        if !has_key(s:cmddicts, plid)
            call FraworLoad(plid)
            if !has_key(s:cmddicts, plid)
                call s:_f.throw('afail', plid)
            endif
        endif
        if !has_key(s:cmddicts[plid], 'function')
            call s:_f.throw('anofu', plid)
        endif
        let s:cmdfuncs[plid]=s:cmddicts[plid].function
    endif
    return call(s:cmdfuncs[plid], a:000, {})
endfunction
call s:_f.augroup.add('Aurum',
            \[['BufReadCmd',   'aurum://*', 1, [s:F.aurun,  0]],
            \ ['FileReadCmd',  'aurum://*', 1, [s:F.aurun,  1]],
            \ ['SourceCmd',    'aurum://*', 1, [s:F.aurun,  2]],
            \ ['BufWriteCmd',  'aurum://*', 1, [s:F.aurun, -1]],
            \ ['FileWriteCmd', 'aurum://*', 1, [s:F.aurun, -2]],
            \])
"▶1
call frawor#Lockvar(s:, 'cmddicts,cmdfuncs')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
