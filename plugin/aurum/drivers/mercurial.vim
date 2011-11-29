"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/python': '0.0',
                \             '@/resources': '0.0',
                \                    '@/os': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
let s:hg={}
let s:usepythondriver=0
if has_key(s:_r, 'py')
    try
        execute s:_r.py.cmd 'import aurum'
        let s:usepythondriver=1
    catch
        " s:usepythondriver stays equal to 0, errors are ignored
    endtry
endif
let s:_messages={
            \ 'norepo': 'Repository %s not found',
            \ 'norev' : 'No revision %s in repository %s',
            \ 'nofile': 'File %s is not present in revision %s '.
            \           'from repository %s',
            \  'csuns': 'Unable to get changeset from repository %s: '.
            \           'operation not supported',
            \'statuns': 'Unable to get working directory status '.
            \           'of repository %s: operation not supported',
            \ 'comuns': 'Unable to commit to repository %s: '.
            \           'operation not supported',
            \'diffuns': 'Unable to create a diff for repository %s: '.
            \           'operation not supported',
            \ 'upduns': 'Unable to update working directory state for '.
            \           'repository %s: operation not supported',
            \ 'destex': 'Cannot copy %s to %s: destination already exists',
            \ 'nhgiwr': 'File %s is either a directory or not writeable',
            \'reponwr': 'Unable to write to repository root (%s)',
            \  'nocfg': 'Failed to get property %s of repository %s ',
        \}
if !s:usepythondriver
    call extend(s:_messages, {
                \'parsefail': 'Failed to parse changeset information',
                \ 'filefail': 'Failed to get file %s '.
                \             'from the repository %s: %s',
                \ 'difffail': 'Failed to get diff between %s and %s '.
                \             'for files %s from the repository %s: %s',
                \ 'statfail': 'Failed to obtain status information '.
                \             'for the repository %s: %s',
                \  'annfail': 'Failed to annotate revision %s of file %s '.
                \             'in the repository %s: %s',
                \  'cspfail': 'Failed to get property %s for changeset %s '.
                \             'in the repository %s: %s',
                \  'logfail': 'Failed to get log for the repository %s: %s',
                \  'keyfail': 'Failed to get %s for the repository %s: %s',
                \   'csfail': 'Failed to get changeset %s '.
                \             'from the repository %s: %s',
                \  'renfail': 'Failed to get renames list for revision %s '.
                \             'in the repository %s: %s',
                \  'cmdfail': 'Failure while running command %s '.
                \             'for the repository %s: %s',
                \ 'grepfail': 'Failed to search through the repository %s: %s',
                \   'scfail': 'Failed to show [paths] section '.
                \             'for the repository %s: %s',
                \ 'stat1mis': 'You must specify first revision as well',
            \})
    let s:nullrev=repeat('0', 40)
endif
"▶1 s:hypsites
" len("hgroot")=6
" examples: (t: only tip is shown; g: git branches only, u: unstable)
"  https://bitbucket.org/ZyX_I/aurum / ssh://hg@bitbucket.org/ZyX_I/aurum
"g git+ssh://git@github.com:MarcWeber/vim-addon-manager /
"       git://github.com/MarcWeber/vim-addon-manager
"  ssh://zyxsf@translit3.hg.sourceforge.net/hgroot/translit3/translit3 /
"       http://translit3.hg.sourceforge.net:8000/hgroot/translit3/translit3
"g git://vimpluginloader.git.sourceforge.net/gitroot/vimpluginloader/vam-test-repository
"       / git+ssh://zyxsf@vimpluginloader.git.sourceforge.net/gitroot/vimpluginloader/vam-test-repository
"t svn+https://vimpluginloader.svn.sourceforge.net/svnroot/vimpluginloader
"  https://vim-pyinteractive-plugin.googlecode.com/hg/
"t svn+http://conque.googlecode.com/svn/trunk
"? (unable to clone with hg-git) https://code.google.com/p/tortoisegit/
"t http://anonscm.debian.org/hg/minicom/
"  http://hg.assembla.com/CMakeLua
"  https://zyx@zyx.codebasehq.com/test/test.hg /
"       ssh://hg@codebasehq.com/zyx/test/test.hg
"  https://hg01.codeplex.com/visualhg
"  http://mercurial.intuxication.org/hg/tryton-client_ru
"  https://mirrors.kilnhg.com/Repo/Mirrors/Hg/Mercurial
"  http://hg.mozdev.org/maf/ / ssh://USER:PASS@hg.mozdev.org/maf
"u https://projectkenai.com/hg/sonichg~test (rev numbers must match)
"  https://hg.kenai.com/hg/sonichg~test / ssh://user@hg.kenai.com/sonichg~test
"  http://hg.savannah.nongnu.org/hgweb/mechsys/
"  https://sharesource.org/hg/alqua/
"  http://mercurial.tuxfamily.org/mercurialroot/slitaz/tazlito/
let s:ghpath='substitute(path, "\\v^[:/]|\\.git$", "", "g")'
let s:gcproj='matchstr(domain, "\\v^[^.]+")'
let s:pkbase='"http://".matchstr(domain, ''\v[^.]+\.[^.]+$'')."/projects/".matchstr(path, ''\v.*\/\zs[^~]+'').'.
            \                                                '"/sources/". matchstr(path, "\\v[^~]+$")'
let s:cpbase='"http://".path[1:].".codeplex.com/SourceControl'
let s:cbbase='"https://".%s.".".domain."/projects/".%s."/repositories/".%s'
let s:cbssh=printf(s:cbbase, 'matchstr(path, "\\v^[^/]+", 1)',
            \                'matchstr(path, ''\v[^/]+%(\/[^/]+\/?$)'')',
            \                'matchstr(path[:-4], "\\v[^/]+$")')
let s:cbhttps=printf(s:cbbase, 'matchstr(domain, "\\v^[^.]+")',
            \                  'matchstr(path, "\\v^[^/]+")',
            \                  'matchstr(path[:-4], "\\v[^/]+$")')
unlet s:cbbase
let s:gb  =  '((!empty(cs.bookmarks))?'.
            \   '(cs.bookmarks[0]):'.
            \'((!empty(cs.tags))?'.
            \   '(get(filter(copy(cs.tags), "v:val[:7] is# ''default/''"), 0, '.
            \        '"default/master")[8:])'.
            \':'.
            \   '("master")))'
let s:hypsites=[
\['domain is? "bitbucket.org"',
\ {     'html': '"https://".domain.path."/src/".cs.hex."/".file',      'hline': '"cl-".line',
\        'raw': '"https://".domain.path."/raw/".cs.hex."/".file',
\   'annotate': '"https://".domain.path."/annotate/".cs.hex."/".file', 'aline': '"line-".line',
\   'filehist': '"https://".domain.path."/history/".file',
\     'bundle': '"https://".domain.path."/get/".cs.hex.".tar.bz2"',
\  'changeset': '"https://".domain.path."/changeset/".cs.hex',
\        'log': '"https://".domain.path."/changesets"',
\      'clone': '"https://".domain.path',
\       'push': '"ssh://hg@".domain.path',}],
\['domain is? "github.com"',
\ {     'html': '"https://".domain."/".'.s:ghpath.'."/blob/".'.s:gb.'."/".file',   'hline': '"L".line',
\        'raw': '"https://".domain."/".'.s:ghpath.'."/raw/". '.s:gb.'."/".file',
\   'annotate': '"https://".domain."/".'.s:ghpath.'."/blame/". '.s:gb.'."/".file', 'aline': '"LID".line',
\   'filehist': '"https://".domain."/".'.s:ghpath.'."/commits/".'.s:gb.'."/".file',
\     'bundle': '"https://".domain."/".'.s:ghpath.'."/zipball/".'.s:gb.'',
\  'changeset': '"https://".domain."/".'.s:ghpath.'."/commit/".'.s:gb.'',
\        'log': '"https://".domain."/".'.s:ghpath.'."/commits"',
\      'clone': '"git://".domain."/".'.s:ghpath,
\       'push': '"git+ssh://git@".domain.":".'.s:ghpath,}],
\['domain =~? "\\Vhg.sourceforge.net\\$"',
\ {     'html': '"http://".domain."/hgweb".path[7:]."/file/".cs.hex."/".file',     'hline': '"l".line',
\        'raw': '"http://".domain."/hgweb".path[7:]."/raw-file/".cs.hex."/".file',
\   'annotate': '"http://".domain."/hgweb".path[7:]."/annotate/".cs.hex."/".file', 'aline': '"l".line',
\   'filehist': '"http://".domain."/hgweb".path[7:]."/log/".cs.hex."/".file',
\  'changeset': '"http://".domain."/hgweb".path[7:]."/rev/".cs.hex',
\        'log': '"http://".domain."/hgweb".path[7:]."/graph"',
\      'clone': '"http://".domain.":8000".path',
\       'push': '"ssh://".user."@".domain.path',}],
\['domain =~? "\\Vgit.sourceforge.net\\$"',
\ {     'html': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=blob;hb=".'.s:gb.'.";f=".file', 'hline': '"l".line',
\        'raw': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=blob_plain;hb=".'.s:gb.'.";f=".file',
\   'filehist': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=history;hb=".'.s:gb.'.";f=".file',
\  'changeset': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=commitdiff;hb=".'.s:gb,
\        'log': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=log"',
\      'clone': '"http://".domain.":8000".path',
\       'push': '"ssh://".user."@".domain.path',}],
\['domain =~? "\\Vsvn.sourceforge.net\\$"',
\ {     'html': '"http://".domain."/viewvc".path[8:]."/".file."?view=log"',
\        'raw': '"http://".domain."/viewvc".path[8:]."/".file',
\   'annotate': '"http://".domain."/viewvc".path[8:]."/".file."?annotate=HEAD"',
\     'bundle': '"http://".domain."/viewvc".path[8:]."?view=tar"',
\        'log': '"http://".domain."/viewvc".path[8:]."?view=log"',
\      'clone': 'url',}],
\['domain =~? "\\Vgooglecode.com\\$" && path[:2] is? "/hg"',
\ {     'html': '"http://code.google.com/p/".'.s:gcproj.'."/source/browse/".file."?r=".cs.hex', 'hline': 'line',
\        'raw': '"http://".domain."/hg-history/".cs.hex."/".file',
\   'filehist': '"http://code.google.com/p/".'.s:gcproj.'."/source/list?path=/".file."&r=".cs.hex',
\  'changeset': '"http://code.google.com/p/".'.s:gcproj.'."/source/detail?r=".cs.hex',
\        'log': '"http://code.google.com/p/".'.s:gcproj.'."/source/list"',
\      'clone': 'url',
\       'push': 'url',}],
\['domain =~? "\\Vgooglecode.com\\$" && path[:3] is? "/svn"',
\ {     'html': '"http://code.google.com/p/".'.s:gcproj.'."/source/browse".path[4:]."/".file', 'hline': 'line',
\        'raw': '"http://".domain.path."/".file',
\   'filehist': '"http://code.google.com/p/".'.s:gcproj.'."/source/list?path=/".file."&r=".cs.hex',
\        'log': '"http://code.google.com/p/".'.s:gcproj.'."/source/list"',
\      'clone': 'url',}],
\['domain is? "code.google.com"',
\ {     'html': '"http://code.google.com/".substitute(path, "/$", "", "")."/source/browse/".file."?r=".'.s:gb,}],
\['domain is? "hg.assembla.com"',
\ {     'html': '"http://trac-".domain.path."/browser/".file."?rev=".cs.hex',                'hline': '"L".line',
\   'annotate': '"http://trac-".domain.path."/browser/".file."?annotate=blame&rev=".cs.hex', 'aline': '"L".line',
\   'filehist': '"http://trac-".domain.path."/log/".file."?rev=".cs.hex',
\  'changeset': '"http://trac-".domain.path."/changeset/".cs.hex',
\        'log': '"http://trac-".domain.path."/log"',
\      'clone': '"http://".domain.path',}],
\['domain is? "codebasehq.com" && path[-3:] is? ".hg"',
\ {     'html': s:cbssh.'."/blob/".cs.hex."/".file', 'hline': '"L".line',
\        'raw': s:cbssh.'."/raw/".cs.hex."/".file',
\   'annotate': s:cbssh.'."/blame/".cs.hex."/".file',
\   'filehist': s:cbssh.'."/commits/".cs.hex."/".file',
\     'bundle': s:cbssh.'."/archive/zip/".cs.hex',
\  'changeset': s:cbssh.'."/commit/".cs.hex',
\        'log': s:cbssh.'."/commits/tip"',
\      'clone': '"https://".matchstr(path, "\\v^[^/]+", 1).".".domain.matchstr(path, ''\v[^/]+\/[^/]+$'')',
\       'push': '"ssh://hg@".domain.path',}],
\['domain =~? "\\Vcodebasehq.com\\$" && path[-3:] is? ".hg"',
\ {     'html': s:cbhttps.'."/blob/".cs.hex."/".file', 'hline': '"L".line',
\        'raw': s:cbhttps.'."/raw/".cs.hex."/".file',
\   'annotate': s:cbhttps.'."/blame/".cs.hex."/".file',
\   'filehist': s:cbhttps.'."/commits/".cs.hex."/".file',
\     'bundle': s:cbhttps.'."/archive/zip/".cs.hex',
\  'changeset': s:cbhttps.'."/commit/".cs.hex',
\        'log': s:cbhttps.'."/commits/tip"',
\      'clone': '"https://".domain.path',
\       'push': '"ssh://hg@".matchstr(domain, ''\v\.@<=.*$'')."/".matchstr(domain, "\\v^[^.]+").path',}],
\['domain =~? "\\V\\^hg\\d\\+.codeplex.com\\$"',
\ {     'html': s:cpbase.'"/changeset/view/".cs.hex[:11]."#".substitute(file, "/", "%2f", "g")',
\     'bundle': '"http://download.codeplex.com/Download/SourceControlFileDownload.ashx'.
\                       '?ProjectName=".path[1:]."&changeSetId=".cs.hex[:11]',
\  'changeset': s:cpbase.'"/changeset/changes/".cs.hex[:11]',
\        'log': s:cpbase.'"/list/changesets"',
\      'clone': '"https://".domain.path',
\       'push': '"https://".domain.path',}],
\['domain =~? "\\Vkilnhg.com\\$"',
\ {     'html': '"https://".domain.path."/File/".file."?rev=".cs.hex',               'hline': 'line',
\        'raw': '"https://".domain.path."/FileDownload/".file."?rev=".cs.hex',
\   'annotate': '"https://".domain.path."/File/".file."?rev=".cs.hex&view=annotate', 'aline': 'line',
\   'filehist': '"https://".domain.path."/FileHistory/".file."?rev=".cs.hex',
\  'changeset': '"https://".domain.path."/History/".cs.hex',
\        'log': '"https://".domain.path',
\      'clone': '"https://".domain.path',}],
\['domain =~? ''\V\%(project\)\?kenai.com\$'' && (path[:2] is? "/hg" || domain[:2] is? "hg.")',
\ {     'html': s:pkbase.'."/content/".file."?rev=".cs.rev',
\        'raw': s:pkbase.'."/content/".file."?raw=true&rev=".cs.rev',
\   'filehist': s:pkbase.'."/history/".file',
\  'changeset': s:pkbase.'."/revision/".cs.rev',
\        'log': s:pkbase.'."/history"',
\      'clone': '"https://".domain."/hg/".matchstr(path, "\\v[^/]+$")',
\       'push': '"ssh://".domain."/".matchstr(path, "\\v[^/]+$")',}],
\['domain is? "sharesource.org" && path[:2] is? "/hg"',
\ {     'html': '"https://".domain.path."/file/".cs.hex."/".file',     'hline': '"l".line',
\        'raw': '"https://".domain.path."/raw-file/".cs.hex."/".file',
\   'annotate': '"https://".domain.path."/annotate/".cs.hex."/".file', 'aline': '"l".line',
\   'filehist': '"https://".domain.path."/log/".cs.hex."/".file',
\  'changeset': '"https://".domain.path."/rev/".cs.hex',
\        'log': '"https://".domain.path."/graph"',
\      'clone': '"https://".domain.path',}],
\[ 'domain =~? ''\v^%(mercurial\.%(intuxication|tuxfamily)|hg\.mozdev|hg\.savannah\.%(non)?gnu)\.org$'' || '.
\ '(domain is? "anonscm.debian.org" && path[:2] is? "/hg")',
\ {     'html': '"http://".domain.path."/file/".cs.hex."/".file',     'hline': '"l".line',
\        'raw': '"http://".domain.path."/raw-file/".cs.hex."/".file',
\   'annotate': '"http://".domain.path."/annotate/".cs.hex."/".file', 'aline': '"l".line',
\   'filehist': '"http://".domain.path."/log/".cs.hex."/".file',
\  'changeset': '"http://".domain.path."/rev/".cs.hex',
\        'log': '"http://".domain.path."/graph"',
\      'clone': '"http://".domain.path',}],
\]
unlet s:ghpath s:gcproj s:cbssh s:cbhttps s:pkbase s:cpbase s:gb
"▶1 removechangesets :: repo, start_rev_num → + repo
function s:F.removechangesets(repo, start)
    let changesets=a:repo.changesets
    for cs in remove(a:repo.cslist, a:start, -1)
        let hex=cs.hex
        for parenthex in filter(cs.parents, 'has_key(changesets, v:val)')
            call filter(changesets[parenthex].children, 'v:val isnot# cs.hex')
        endfor
        for childhex in filter(cs.children, 'has_key(changesets, v:val)')
            call filter(changesets[childhex].parents, 'v:val isnot# cs.hex')
        endfor
    endfor
endfunction
if s:usepythondriver "▶1
"▶2 addchangesets :: repo, [cs] → _ + repo
function s:F.addchangesets(repo, css)
    call map(copy(a:css), 'extend(a:repo.changesets, {v:val.hex : v:val})')
    for cs in a:css
        for parenthex in cs.parents
            call add(a:repo.changesets[parenthex].children, cs.hex)
        endfor
    endfor
endfunction
"▲2
else "▶1
"▶2 addchangesets :: repo, [cs] → _ + repo
function s:F.addchangesets(repo, css)
    call map(copy(a:css), 'extend(a:repo.changesets, {v:val.hex : v:val})')
    for cs in a:css
        call map(cs.parents, 'type(v:val)=='.type(0).' ? '.
                    \           'a:repo.cslist[v:val].hex : '.
                    \           'v:val')
        for parenthex in cs.parents
            call add(a:repo.changesets[parenthex].children, cs.hex)
        endfor
    endfor
endfunction
"▶2 hg :: repo, cmd, hasnulls, msgid[, throwarg1[, …]] → [String]
function s:F.hg(repo, cmd, hasnulls, msgid, ...)
    let cmd='hg -R '.shellescape(a:repo.path, 1).' '.a:cmd
    if a:hasnulls
        let savedlazyredraw=&lazyredraw
        set lazyredraw
        noautocmd tabnew
        if a:repo.local
            noautocmd execute 'lcd' fnameescape(a:repo.path)
        endif
        " XXX this is not able to distinguish between output with and without 
        " trailing newline
        noautocmd execute '%!'.cmd
        let r=getline(1, '$')
        noautocmd bwipeout!
        let &lazyredraw=savedlazyredraw
    else
        let r=split(system(cmd), "\n", 1)
    endif
    if v:shell_error
        if a:msgid isnot 0
            call call(s:_f.throw, [a:msgid.'fail']+a:000+[a:repo.path,
                        \                                 join(r[:-1-(a:hasnulls)],
                        \                                      "\n")], {})
        endif
    endif
    return r
endfunction
"▶2 unesc :: String → String
let s:F.unesc=function('eval')
"▶2 refile :: path → path
function s:F.refile(path)
    return join(s:_r.os.path.split(a:path)[1:], '/')
endfunction
"▶2 parsecs :: csdata, lstart::UInt → [cs, line::UInt]
let s:stylefile=shellescape(s:_r.os.path.join(s:_frawor.runtimepath,
                \                             'misc', 'map-cmdline.csinfo'))
let s:chars = [['P', 'parents'  ],
            \  ['T', 'tags'     ],
            \  ['B', 'bookmarks']]
let s:fchars= [['C', 'changes'  ],
            \  ['R', 'removes'  ]]
function s:F.parsecs(csdata, lstart)
    "▶3 Initialize variables, check for changeset start
    let cs={}
    let line=a:lstart
    let lcsdata=len(a:csdata)
    if lcsdata<6 || a:csdata[line] isnot# ':'
        call s:_f.throw('parsefail')
    endif
    let line+=1
    "▶3 Simple keys: rev, hex, branch, time, user
    let cs.rev    = str2nr(a:csdata[line])    | let line+=1
    let cs.hex    = a:csdata[line]            | let line+=1
    let cs.branch = s:F.unesc(a:csdata[line]) | let line+=1
    let cs.time   = str2nr(a:csdata[line])    | let line+=1
    let cs.user   = s:F.unesc(a:csdata[line]) | let line+=1
    "▶3 List keys: parents, tags, bookmarks, changes, removes
    for [char, key] in s:chars
        let cs[key]=[]
        while line<lcsdata && a:csdata[line][0] is# char
            let cs[key]+=[s:F.unesc(a:csdata[line][1:])]
            let line+=1
        endwhile
    endfor
    "▶3 List file keys: changes, removes
    for [char, key] in s:fchars
        let cs[key]=[]
        while line<lcsdata && a:csdata[line][0] is# char
            let cs[key]+=[s:F.refile(s:F.unesc(a:csdata[line][1:]))]
            let line+=1
        endwhile
    endfor
    "▶3 Add data to cs.parents in case it is empty
    if empty(cs.parents)
        if cs.rev>0
            let cs.parents=[cs.rev-1]
        else
            let cs.parents=[s:nullrev]
        endif
    endif
    "▶3 Filter cs.removes, add cs.files
    call filter(cs.removes, 'index(cs.changes, v:val)!=-1')
    let cs.files=filter(copy(cs.changes), 'index(cs.removes, v:val)==-1')
    "▶3 Copies, renames
    let copies={}
    while line<lcsdata && a:csdata[line][0] is# 'D'
        let copies[s:F.refile(s:F.unesc(a:csdata[line][1:]))]=
                    \                   s:F.refile(s:F.unesc(a:csdata[line+1]))
        let line+=2
    endwhile
    let cs.copies  = filter(copy(copies), 'index(cs.removes, v:val)==-1')
    let cs.renames = filter(copy(copies), '!has_key(cs.copies, v:key)')
    "▶3 Description
    let cs.description=s:F.unesc(a:csdata[line][1:])
    let line+=1
    "▲3
    return [cs, line]
endfunction
"▶2 getcslist :: repo, start, end
function s:F.getcslist(repo, start, end)
    let logbeg='log --style '.s:stylefile.' '
    let lines=s:F.hg(a:repo, logbeg.'-r '.a:start.'..'.a:end, 0, 'log')[:-2]
    let css=[]
    if has_key(a:repo.changesets, s:nullrev)
        let cs0=a:repo.changesets[s:nullrev]
    else
        let lines0=s:F.hg(a:repo, logbeg.'-r '.s:nullrev, 0, 'log')
        let cs0=s:F.parsecs(lines0, 0)[0]
    endif
    let llines=len(lines)
    let line=0
    let prevrev=-1
    while line<llines
        let [cs, line]=s:F.parsecs(lines, line)
        if cs.rev-prevrev!=1
            let css+=map(range(prevrev+1, cs.rev-1),
                        \'s:F.parsecs(s:F.hg(a:repo, logbeg."-r".v:val, 0, '.
                        \                   '"log"), 0)[0]')
        endif
        let css+=[cs]
        let prevrev=cs.rev
    endwhile
    let cs0.rev=len(css)
    let css+=[cs0]
    return css
endfunction
"▶2 getkeylist :: repo, key → [(name, rev)]
function s:F.getkeylist(repo, key)
    let lines=s:F.hg(a:repo, a:key, 0, 'key', a:key)[:-2]
    if len(lines)==1 && lines[0]!~#'\v\ [1-9]\d*\:\x{12}$'
        return []
    endif
    return map(copy(lines), 'matchlist(v:val, '.
                \                    '''\v^(.{-})\ +(\d+)\:\x{12}$'')[1:2]')
endfunction
"▲2
endif
"▶1 hg.updatechangesets :: repo → + repo
"▶2 python
if s:usepythondriver
    function s:F.getupdates(repo, start)
        let d={}
        try
            " XXX get_updates also modifies a:repo
            execute s:_r.py.cmd 'aurum.get_updates(vim.eval("a:repo.path"), '.
                        \                          a:start.')'
        endtry
        return d
    endfunction
"▶2 no python
else
    function s:F.getupdates(repo, start)
        let r={}
        let tip_hex=a:repo.functions.getrevhex(a:repo, 'tip')
        if a:start
            try
                let oldtip=a:repo.functions.getcs(a:repo, a:start)
                if tip_hex is# oldtip.hex
                    return r
                endif
                let startrev=oldtip.rev
            catch
                let startrev=0
            endtry
        else
            let startrev=0
        endif
        let r.startrev=startrev
        let r.css=s:F.getcslist(a:repo, startrev, -1)
        for key in ['tags', 'bookmarks']
            let list=s:F.getkeylist(a:repo, key)
            let r[key]={}
            for [name, rev] in filter(copy(list), 'v:val[1]<'.a:start)
                let r[key][name]=a:repo.cslist[rev].hex
            endfor
        endfor
        let a:repo.csnum=a:start+len(r.css)
        return r
    endfunction
endif
"▶2 hg.updatechangesets
" TODO test updating in cases of rollback
function s:hg.updatechangesets(repo)
    let d={}
    let start=len(a:repo.cslist)-2
    if start<0
        let start=0
    endif
    " XXX getupdates may also modify repo
    let d=s:F.getupdates(a:repo, start)
    if empty(d)
        return a:repo
    endif
    call map(d.css, 'extend(v:val, {"children": []})')
    if !empty(a:repo.cslist)
        call s:F.removechangesets(a:repo, d.startrev)
    endif
    for key in ['tags', 'bookmarks']
        call map(a:repo.cslist, 'extend(v:val, {key : []})')
        for [name, hex] in filter(items(d[key]),
                    \             'has_key(a:repo.changesets, v:val[1])')
            let cs=a:repo.changesets[hex]
            let cs[key]+=[name]
            call sort(cs[key])
        endfor
    endfor
    let a:repo.cslist+=d.css
    call s:F.addchangesets(a:repo, d.css)
    return a:repo
endfunction
"▶1 gettiphex :: repo → hex
function s:hg.gettiphex(repo)
    return a:repo.functions.getrevhex(a:repo, 'tip')
endfunction
"▶1 getworkhex :: repo → hex
function s:hg.getworkhex(repo)
    return a:repo.functions.getrevhex(a:repo, '.')
endfunction
"▶1 getwork :: repo → hex
function s:hg.getwork(repo)
    return a:repo.functions.getcs(a:repo, '.')
endfunction
"▶1 hg.repo :: path + ? → repo
if s:usepythondriver "▶2
function s:hg.repo(path)
    let repo={}
    try
        " execute s:_r.py.cmd 'import cProfile as profile'
        " execute s:_r.py.cmd 'profile.run("aurum.new_repo(vim.eval(''a:path''))", "python.profile")'
        execute s:_r.py.cmd 'aurum.new_repo(vim.eval("a:path"))'
    catch /\V\^Frawor:\[^:]\+:norepo:/
        return 0
    endtry
    let repo.hypsites=deepcopy(s:hypsites)
    return repo
endfunction
else "▶2
function s:hg.repo(path)
    let repo={'path': a:path, 'changesets': {}, 'cslist': [],
                \'local': (stridx(a:path, '://')==-1),
                \'functions': copy(s:hg),}
    return repo
endfunction
endif
"▶1 hg.getchangesets :: repo → changesets + repo.changesets
function s:hg.getchangesets(repo)
    call a:repo.functions.updatechangesets(a:repo)
    return a:repo.cslist
endfunction
"▶1 hg.getrevhex :: repo, rev → rev(hex)
if s:usepythondriver "▶2
function s:hg.getrevhex(repo, rev)
    try
        execute s:_r.py.cmd
                    \ 'vim.command(''return "''+'.
                    \    'aurum.g_cs(aurum.g_repo(vim.eval("a:repo.path")), '.
                    \               'vim.eval("a:rev")).hex()+''"'')'
    catch /\v^Frawor:/
        throw v:exception
    catch
        call s:_f.throw('norev', a:rev, a:repo.path)
    endtry
endfunction
else "▶2
let s:getrevhextemplate=shellescape('{node}')
function s:hg.getrevhex(repo, rev)
    if type(a:rev)==type('') && (has_key(a:repo.changesets, a:rev) ||
                \                a:rev=~#'\v^[0-9a-f]{40}$')
        return a:rev
    elseif type(a:rev)==type(0) && a:rev<len(a:repo.cslist)
        return a:repo.cslist[a:rev].hex
    endif
    let hex=get(s:F.hg(a:repo, 'log --template '.s:getrevhextemplate.' '.
                \                  '-r '.shellescape(a:rev), 0, 'log'), 0, 0)
    if hex is 0
        call s:_f.throw('norev', a:rev, a:repo.path)
    endif
    return hex
endfunction
endif
"▶1 hg.readfile :: repo, rev, file → [String]
if s:usepythondriver "▶2
function s:hg.readfile(repo, rev, file)
    let r=[]
    try
        execute s:_r.py.cmd 'aurum.get_file(vim.eval("a:repo.path"), '.
                    \                      'vim.eval("a:rev"), '.
                    \                      'vim.eval("a:file"))'
    endtry
    return r
endfunction
else "▶2
function s:hg.readfile(repo, rev, file)
    let r=s:F.hg(a:repo, 'cat -r '.shellescape(a:rev, 1).' -- '.
                \             shellescape(a:file, 1), 1, 'file', a:file)
    return r
endfunction
endif
"▶1 hg.annotate :: repo, rev, file → [(file, rev, linenumber)]
if s:usepythondriver "▶2
function s:hg.annotate(repo, rev, file)
    let r=[]
    try
        execute s:_r.py.cmd 'aurum.annotate(vim.eval("a:repo.path"), '.
                    \                      'vim.eval("a:rev"), '.
                    \                      'vim.eval("a:file"))'
    endtry
    return r
endfunction
else "▶2
function s:hg.annotate(repo, rev, file)
    let cmd='annotate -r '.shellescape(a:rev,1).' -fnl -- '.
                \     shellescape(a:file,1)
    let r=[]
    let lines=s:F.hg(a:repo, cmd, 1, 'ann', a:rev, a:file)
    for line in lines
        " XXX This won't work for files that start with spaces and also with 
        " some other unusual filenames that can be present in a repository
        let match=matchlist(line, '\v^\s*(\d+)\ +(.{-})\:\s*([1-9]\d*)\:\ ')
        if empty(match)
            call s:_f.throw('annfail', a:rev, a:file, line)
        endif
        let r+=[[match[2], str2nr(match[1]), str2nr(match[3])]]
    endfor
    return r
endfunction
endif
"▶1 hg.getcsprop :: repo, Either cs rev, propname → a
"▶2 setcsprop
if s:usepythondriver "▶3
function s:F.setcsprop(repo, cs, propname)
    try
        execute s:_r.py.cmd 'aurum.get_cs_prop(vim.eval("a:repo.path"), '.
                    \                         'vim.eval("a:cs.hex"), '.
                    \                         'vim.eval("a:propname"))'
    endtry
endfunction
else "▶3
function s:F.setcsprop(repo, cs, propname)
    if a:propname is# 'allfiles'
        let r=s:F.hg(a:repo, 'manifest -r '.a:cs.rev, 0,
                    \'csp', a:propname, a:cs.rev)[:-2]
    elseif a:propname is# 'children'
        " XXX str2nr('123:1f6de') will return number 123
        let r=map(split(s:F.hg(a:repo, 'log -r '.a:cs.rev.' --template '.
                    \                       shellescape('{children}'), 0,
                    \          'csp', a:propname, a:cs.rev)[0]),
                    \    'str2nr(v:val)')
        if empty(a:repo.cslist)
            call map(r, 'a:repo.functions.getrevhex(a:repo, v:val)')
        else
            call map(r, 'a:repo.cslist[v:val].hex')
        endif
    endif
    let a:cs[a:propname]=r
    return r
endfunction
endif
"▲2
function s:hg.getcsprop(repo, csr, propname)
    if type(a:csr)==type({})
        let cs=a:csr
    else
        let cs=a:repo.functions.getcs(a:repo, a:csr)
    endif
    if has_key(cs, a:propname)
        return cs[a:propname]
    endif
    call s:F.setcsprop(a:repo, cs, a:propname)
    " XXX There is much code relying on the fact that after getcsprop property 
    " with given name is added to changeset dictionary
    return cs[a:propname]
endfunction
"▶1 hg.getcs :: repo, rev → cs
"▶2 getcs
if s:usepythondriver "▶3
function s:F.getcs(repo, hex)
    let cs={}
    try
        execute s:_r.py.cmd 'aurum.get_cs(vim.eval("a:repo.path"), "'.a:hex.'")'
    endtry
    return cs
endfunction
else "▶3
function s:F.getcs(repo, hex)
    let csdata=s:F.hg(a:repo, 'log -r '.a:hex.' --style '.s:stylefile, 0,
                \     'cs', a:hex)
    let cs=s:F.parsecs(csdata, 0)[0]
    call map(cs.parents,
                \'type(v:val)=='.type(0).'? '.
                \   'a:repo.functions.getrevhex(a:repo, v:val): '.
                \   'v:val')
    return cs
endfunction
endif
"▲2
function s:hg.getcs(repo, rev)
    if !empty(a:repo.cslist)
        if type(a:rev)==type('') && has_key(a:repo.changesets, a:rev)
            return a:repo.changesets[a:rev]
        elseif type(a:rev)==type(0) && a:rev<a:repo.csnum
            return a:repo.cslist[a:rev]
        endif
    endif
    let hex=a:repo.functions.getrevhex(a:repo, a:rev)
    if has_key(a:repo.changesets, hex) && !empty(a:repo.cslist)
        return a:repo.changesets[hex]
    else
        let cs=s:F.getcs(a:repo, hex)
        let a:repo.changesets[hex]=cs
        return cs
    endif
endfunction
"▶1 diffopts :: opts → diffopts
let s:diffopts={
            \      'git': 'git',
            \  'reverse': 'reverse',
            \ 'ignorews': 'ignore_all_space',
            \'iwsamount': 'ignore_space_change',
            \  'iblanks': 'ignore_blank_lines',
            \ 'numlines': 'unified',
            \ 'showfunc': 'show_function',
            \  'alltext': 'text',
        \}
function s:F.diffopts(opts, defaultdiffopts)
    let opts=extend(copy(a:defaultdiffopts), a:opts)
    let r={}
    call map(filter(copy(s:diffopts), 'has_key(opts, v:key)'),
            \'extend(r, {v:val : opts[v:key]})')
    if has_key(opts, 'dates')
        let r.nodates=!opts.dates
    endif
    return r
endfunction
"▶1 hg.diff :: repo, rev1, rev2, [path], opts → diff::[String]
if s:usepythondriver "▶2
function s:hg.diff(repo, rev1, rev2, files, opts)
    let r=[]
    let opts=s:F.diffopts(a:opts, a:repo.diffopts)
    try
        execute s:_r.py.cmd 'aurum.diff(vim.eval("a:repo.path"), '.
                    \                  'vim.eval("a:rev1"), '.
                    \                  'vim.eval("a:rev2"), '.
                    \                  'vim.eval("a:files"), '.
                    \                  'vim.eval("opts"))'
    endtry
    return r
endfunction
else "▶2
"▶3 getdiffcmd
function s:F.getdiffcmd(repo, rev1, rev2, files, opts)
    let opts=s:F.diffopts(a:opts, a:repo.diffopts)
    let rev1=((empty(a:rev1))?(0):(shellescape(a:rev1, 1)))
    let rev2=((empty(a:rev2))?(0):(shellescape(a:rev2, 1)))
    let cmd='diff '
    if rev2 is 0
        if rev1 isnot 0
            let cmd.='-c '.rev1.' '
        endif
    else
        let cmd.='-r '.rev2.' '
        if rev1 isnot 0
            let cmd.='-r '.rev1.' '
        endif
    endif
    for [o, v] in items(opts)
        if o is# 'unified'
            let cmd.='--'.o.' '.v.' '
        elseif v
            let cmd.='--'.substitute(o, '_', '-', 'g').' '
        endif
    endfor
    let cmd.='-- '.join(map(copy(a:files), 'shellescape(v:val, 1)'))
    return cmd
endfunction
"▲3
function s:hg.diff(repo, rev1, rev2, files, opts)
    let cmd=s:F.getdiffcmd(a:repo, a:rev1, a:rev2, a:files, a:opts)
    let r=s:F.hg(a:repo, cmd, 1, 'diff', string(a:rev1), string(a:rev2),
                \                        join(a:files, ', '))
    return r+['']
endfunction
endif
"▶1 hg.difftobuffer :: repo, buf, rev1, rev2, [path], opts → [String]
if s:usepythondriver "▶2
function s:hg.difftobuffer(repo, buf, rev1, rev2, files, opts)
    let r=[]
    let oldbuf=bufnr('%')
    if oldbuf!=a:buf
        execute 'buffer' a:buf
    endif
    try
        let opts=s:F.diffopts(a:opts, a:repo.diffopts)
        execute s:_r.py.cmd 'aurum.diffToBuffer(vim.eval("a:repo.path"), '.
                    \                          'vim.eval("a:rev1"), '.
                    \                          'vim.eval("a:rev2"), '.
                    \                          'vim.eval("a:files"), '.
                    \                          'vim.eval("opts"))'
    finally
        if oldbuf!=a:buf
            execute 'buffer' oldbuf
        endif
    endtry
endfunction
else "▶2
function s:hg.difftobuffer(repo, buf, rev1, rev2, files, opts)
    let cmd=s:F.getdiffcmd(a:repo, a:rev1, a:rev2, a:files, a:opts)
    let oldbuf=bufnr('%')
    if oldbuf!=a:buf
        execute 'buffer' a:buf
    endif
    try
        execute '%!hg -R '.shellescape(a:repo.path, 1).' '.cmd
    finally
        if oldbuf!=a:buf
            execute 'buffer' oldbuf
        endif
    endtry
endfunction
endif
"▶1 hg.status :: repo[, rev1[, rev2[, files]]] → {type : [file]}
" type :: "modified" | "added" | "removed" | "deleted" | "unknown" | "ignored"
"       | "clean"
if s:usepythondriver "▶2
function s:hg.status(repo, ...)
    let revargs=join(map(copy(a:000), 'v:val is 0? "None": string(v:val)'), ',')
    let r={}
    try
        execute s:_r.py.cmd 'aurum.get_status(vim.eval("a:repo.path"), '.
                    \                         revargs.')'
    endtry
    return r
endfunction
else "▶2
let s:hgstatchars={
            \'M': 'modified',
            \'A': 'added',
            \'R': 'removed',
            \'!': 'deleted',
            \'?': 'unknown',
            \'I': 'ignored',
            \'C': 'clean',
        \}
let s:initstatdct={}
call map(values(s:hgstatchars), 'extend(s:initstatdct, {v:val : []})')
" TODO test whether zero revision may cause bugs in some commands
function s:hg.status(repo, ...)
    let cmd='status -marduic'
    let reverse=0
    if a:0
        if a:1 is 0
            if a:0>1 && a:2 isnot 0
                let reverse=1
            endif
        else
            let cmd.=' --rev '.shellescape(a:1)
        endif
        if a:0>1 && a:2 isnot 0
            let cmd.=' --rev '.shellescape(a:2)
        endif
        if a:0>2 && !empty(a:3)
            let cmd.=' -- '.join(map(copy(a:3),
                        \'shellescape(s:_r.os.path.join(a:repo.path, v:val))'))
        endif
    endif
    let slines=s:F.hg(a:repo, cmd, 0, 'stat')[:-2]
    if !empty(filter(copy(slines), '!has_key(s:hgstatchars, v:val[0])'))
        call s:_f.throw('statfail', a:repo.path, join(slines, "\n"))
    endif
    let r=deepcopy(s:initstatdct)
    call map(copy(slines), 'add(r[s:hgstatchars[v:val[0]]], '.
                \              's:F.refile(v:val[2:]))')
    if a:0>2 && !empty(a:3)
        call map(r, 'map(v:val, "a:repo.functions.reltorepo(a:repo, v:val)")')
    endif
    if reverse
        let [r.deleted, r.unknown]=[r.unknown, r.deleted]
        let [r.added,   r.removed]=[r.removed, r.added  ]
    endif
    return r
endfunction
endif
"▶1 hg.commit :: repo, message[, files[, user[, date[, closebranch[, force]]]]]
if s:usepythondriver "▶2
function s:hg.commit(repo, message, ...)
    let args  =  'text=vim.eval("a:message"), '.
                \'force='.((get(a:000, 3, 0))?('True'):('False')).', '.
                \join(map(['files', 'user', 'date', 'close_branch'],
                \         'v:val."=".(empty(a:000[v:key])?'.
                \                       '"None":'.
                \                       '"vim.eval(''a:".(v:key+1)."'')")'),
                \     ', ')
    try
        execute s:_r.py.cmd 'aurum.commit(vim.eval("a:repo.path"), '.args.')'
    endtry
endfunction
else "▶2
function s:hg.commit(repo, message, ...)
    let kwargs={}
    let usingfile=0
    if a:message=~#'\v[\r\n]'
        let tmpfile=tempname()
        call writefile(split(a:message, "\n", 1), tmpfile, 'b')
        let kwargs.logfile=tmpfile
        let usingfile=1
    else
        let kwargs.message=a:message
    endif
    let args=[]
    if a:0
        if !empty(a:1)
            let args+=a:1
            let kwargs.addremove=1
        endif
        if a:0>1 && !empty(a:2)
            let kwargs.user=a:2
        endif
        if a:0>2 && !empty(a:3)
            let kwargs.date=a:3
        endif
        if a:0>3 && !empty(a:4)
            let kwargs.close_branch=1
        endif
    endif
    try
        call s:F.runcmd(a:repo, 'commit', args, kwargs, 0)
    finally
        if usingfile && filereadable(tmpfile)
            call delete(tmpfile)
        endif
    endtry
endfunction
endif
"▶1 hg.update :: repo, rev, force
if s:usepythondriver "▶2
function s:hg.update(repo, rev, force)
    try
        execute s:_r.py.cmd 'aurum.update(vim.eval("a:repo.path"), '.
                    \                    'vim.eval("a:rev"), '.
                    \                    'int(vim.eval("a:force")))'
    endtry
endfunction
else "▶2
function s:hg.update(repo, rev, force)
    call s:F.runcmd(a:repo, 'update', [], {'clean': !empty(a:force),
                \                            'rev': ((type(a:rev)==type(0))?
                \                                       string(a:rev):
                \                                       a:rev)})
endfunction
endif
"▶1 hg.dirty :: repo, file → Bool
if s:usepythondriver "▶2
function s:hg.dirty(repo, file)
    try
        let r=0
        execute s:_r.py.cmd 'aurum.dirty(vim.eval("a:repo.path"), '.
                    \                   'vim.eval("a:file"))'
        return r
    endtry
endfunction
endif
"▶1 hg.diffre :: _, diffopts → regex
function s:hg.diffre(repo, diffopts)
    " XXX first characters must be identical for hg.getstats(), but it must not 
    " match lines not containing filename for getdifffile()
    if get(a:diffopts, 'git', 0)
        return '\m^diff \V--git a/\(\.\{-}\) b/'
    else
        return '\m^diff \v.*\-r\ \w+\s(.*)$'
    endif
endfunction
"▶1 hg.getstats :: _, diff, diffopts → stats
" stats :: { ( "insertions" | "deletions" ): UInt,
"            "files": { ( "insertions" | "deletions" ): UInt } }
function s:hg.getstats(repo, diff, diffopts)
    let diffre=a:repo.functions.diffre(a:repo, a:diffopts)
    let i=0
    let llines=len(a:diff)
    let stats={'files': {}, 'insertions': 0, 'deletions': 0}
    let file=0
    while i<llines
        let line=a:diff[i]
        if line[:3] is# 'diff'
            let file=get(matchlist(line, diffre[8:], 5), 1, 0)
            if file isnot 0
                let stats.files[file]={'insertions': 0, 'deletions': 0,}
                let i+=1
                let oldi=i
                let pmlines=2
                while pmlines && i<llines
                    let lstart=a:diff[i][:2]
                    if lstart is# '+++' || lstart is# '---'
                        let pmlines-=1
                    endif
                    let i+=1
                    if i-oldi>=4
                        let i=oldi
                        break
                    endif
                endwhile
                continue
            endif
        elseif file is 0
        elseif line[0] is# '+'
            let stats.insertions+=1
            let stats.files[file].insertions+=1
        elseif line[0] is# '-'
            let stats.deletions+=1
            let stats.files[file].deletions+=1
        endif
        let i+=1
    endwhile
    return stats
endfunction
"▶1 hg.getrepoprop :: repo, prop → a
if s:usepythondriver "▶2
function s:hg.getrepoprop(repo, prop)
    let d={}
    try
        execute s:_r.py.cmd 'aurum.get_repo_prop(vim.eval("a:repo.path"), '.
                    \                           'vim.eval("a:prop"))'
    endtry
    return a:repo[a:prop]
endfunction
else "▶2
function s:hg.getrepoprop(repo, prop)
    if a:prop is# 'tagslist' || a:prop is# 'brancheslist' || a:prop is# 'bookmarkslist'
        return map(copy(s:F.getkeylist(a:repo, a:prop[:-5])), 'v:val[0]')
    elseif a:prop is# 'url'
        let lines=s:F.hg(a:repo, 'showconfig paths', 0, 'sc')[:-2]
        let confs={}
        call map(lines, 'matchlist(v:val, ''\v^paths\.([^=]+)\=(.*)$'')[1:2]')
        call map(copy(lines), 'extend(confs, {v:val[0]: v:val[1]})')
        if has_key(confs, 'default-push')
            return confs['default-push']
        elseif has_key(confs, 'default')
            return confs.default
        endif
    endif
    call s:_f.throw('nocfg', a:prop, a:repo.path)
endfunction
endif
"▶1 runcmd :: repo, attr, args, kwargs → + ?
if s:usepythondriver "▶2
function s:F.runcmd(repo, attr, args, kwargs)
    execute s:_r.py.cmd 'aurum.call_cmd(vim.eval("a:repo.path"), '.
                \                      'vim.eval("a:attr"), '.
                \                      '*vim.eval("a:args"), '.
                \                      '**vim.eval("a:kwargs"))'
endfunction
else "▶2
" XXX Here all args must be paths
function s:F.runcmd(repo, attr, args, kwargs, ...)
    let cmd=a:attr
    if !empty(a:kwargs)
        let cmd.=' '.join(map(filter(items(a:kwargs), 'v:val[1] isnot 0'),
                \             '((v:val[1] is 1)?'.
                \               '("--".v:val[0]):'.
                \               '("--".v:val[0]." ".shellescape(v:val[1],1)))'))
    endif
    if !empty(a:args)
        let cmd.=' -- '.join(map(copy(a:args),
                \                'shellescape(s:_r.os.path.join(a:repo.path, '.
                \                                              'v:val), 1)'))
    endif
    let prevempty=0
    for line in s:F.hg(a:repo, cmd, a:0 && a:1, 'cmd', cmd)[:-2+(a:0 && a:1)]
        if empty(line)
            let prevempty+=1
        else
            if prevempty
                while prevempty
                    echomsg ' '
                    let prevempty-=1
                endwhile
            endif
            echomsg line
        endif
    endfor
endfunction
endif
"▶1 hg.move :: repo, force, source, target → + FS
function s:hg.move(repo, force, ...)
    return s:F.runcmd(a:repo, 'rename', a:000, a:force ? {'force': 1} : {})
endfunction
"▶1 hg.copy :: repo, force, source, target → + FS
function s:hg.copy(repo, force, ...)
    return s:F.runcmd(a:repo, 'copy', a:000, a:force ? {'force': 1} : {})
endfunction
"▶1 hg.forget :: repo, file → + FS
function s:hg.forget(repo, ...)
    return s:F.runcmd(a:repo, 'forget', a:000, {})
endfunction
"▶1 hg.remove :: repo, file → + FS
function s:hg.remove(repo, ...)
    return s:F.runcmd(a:repo, 'remove', a:000, {})
endfunction
"▶1 hg.add :: repo, file → + FS
function s:hg.add(repo, ...)
    return s:F.runcmd(a:repo, 'add', a:000, {})
endfunction
"▶1 addtosection :: repo, hgignore::path, section, line → + FS(hgignore)
function s:F.addtosection(repo, hgignore, section, line)
    let addsect=['syntax: '.a:section,
                \a:line,
                \'']
    if s:_r.os.path.exists(a:hgignore)
        if filewritable(a:hgignore)==1
            let lines=readfile(a:hgignore, 'b')
            let r=[]
            let addedline=0
            let foundsyntax=0
            for line in lines
                if !addedline
                    if line is# 'syntax: '.a:section
                        let foundsyntax=1
                    elseif line[:6] is# 'syntax:' && foundsyntax
                        if empty(r[-1])
                            call remove(r, -1)
                            let r+=[a:line, '']
                        else
                            let r+=[a:line]
                        endif
                        let addedline=1
                    endif
                endif
                let r+=[line]
            endfor
            if !addedline
                if foundsyntax
                    if empty(r[-1])
                        call remove(r, -1)
                        let r+=[a:line, '']
                    else
                        let r+=[a:line]
                    endif
                else
                    let r+=addsect
                endif
            endif
            return writefile(r, a:hgignore, 'b')
        else
            call s:_f.throw('nhgiwr', a:hgignore)
        endif
    elseif filewritable(a:repo.path)==2
        return writefile(addsect, a:hgignore, 'b')
    else
        call s:_f.throw('reponwr', a:repo.path)
    endif
endfunction
"▶1 hg.ignore :: repo, file → +FS
let s:usepython=0
if has_key(s:_r, 'py')
    try
        execute s:_r.py.cmd 'import json, re'
        let s:usepython=1
    catch
        " s:usepython stays equal to 0, errors are ignored
    endtry
endif
if s:usepython "▶2
function s:hg.ignore(repo, file)
    let d={}
    execute s:_r.py.cmd 'vim.eval("extend(d, {''pattern'': "+'.
                \              'json.dumps(re.escape(vim.eval("a:file")))+"})")'
    let hgignore=s:_r.os.path.join(a:repo.path, '.hgignore')
    let reline='^'.d.pattern.'$'
    return s:F.addtosection(a:repo, hgignore, 'regexp', reline)
endfunction
else "▶2
function s:hg.ignore(repo, file)
    let hgignore=s:_r.os.path.join(a:repo.path, '.hgignore')
    return s:F.addtosection(a:repo, hgignore, 'glob', escape(a:file, '\*[{}]?'))
endfunction
endif
"▶1 hg.ignoreglob :: repo, glob → + FS
function s:hg.ignoreglob(repo, glob)
    let hgignore=s:_r.os.path.join(a:repo.path, '.hgignore')
    return s:F.addtosection(a:repo, hgignore, 'glob', a:glob)
endfunction
"▶1 hg.grep :: repo, pattern, files, revisions, ignore_case, wdfiles → qflist
" revisions :: [Either rev (rev, rev)]
if s:usepythondriver "▶2
function s:hg.grep(repo, pattern, files, revisions, ignore_case, wdfiles)
    let r=[]
    execute s:_r.py.cmd 'aurum.grep(vim.eval("a:repo.path"), '.
                \                  'vim.eval("a:pattern"), '.
                \                  'vim.eval("a:files"), '.
                \                  'vim.eval("a:revisions"), '.
                \                  'bool(int(vim.eval("a:ignore_case"))), '.
                \                  'bool(int(vim.eval("a:wdfiles"))))'
    return r
endfunction
else "▶2
"▶3 checknotmodifiedsince
function s:F.checknotmodifiedsince(repo, rev, file, cache)
    let key=a:rev.':'.a:file
    if has_key(a:cache, key)
        return a:cache[key]
    endif
    let status=a:repo.functions.status(a:repo, a:rev, 0, [a:file])
    let r=(!empty(status.clean) && a:file is# status.clean[0])
    let a:cache[key]=r
    return r
endfunction
"▲3
function s:hg.grep(repo, pattern, files, revisions, ignore_case, wdfiles)
    let cmd='grep '.join(map(copy(a:revisions),
            \                '((type(v:val)=='.type([]).')?'.
            \                   '("-r".shellescape(join(v:val, ".."), 1)):'.
            \                   '("-r".shellescape(v:val, 1)))')).' '
    if a:ignore_case
        let cmd.='--ignore-case '
    endif
    let cmd.='--follow --line-number '
    let cmd.='-- '.join(map(copy([a:pattern]+a:files), 'shellescape(v:val, 1)'))
    let lines=s:F.hg(a:repo, cmd, 1, 0)
    if v:shell_error
        if lines ==# ['']
            return []
        else
            call s:_f.throw('grepfail', a:repo.path, join(lines, "\n"))
        endif
    endif
    let r=[]
    let cnmscache={}
    for line in lines
        let match=matchlist(line, '\v^(.{-})\:(0|[1-9]\d*)\:([1-9]\d*)\:(.*)$')
        if empty(match)
            call s:_f.throw('grepfail', a:repo.path, line)
        endif
        let [file, rev, lnum, text]=match[1:4]
        if a:wdfiles && s:F.checknotmodifiedsince(a:repo, rev, file, cnmscache)
            let filename=s:_r.os.path.normpath(s:_r.os.path.join(a:repo.path, file))
        else
            let filename=[rev, file]
        endif
        let r+=[{'filename': filename, 'lnum': lnum, 'text': text}]
        unlet filename
    endfor
    return r
endfunction
endif
"▶1 Post resource
call s:_f.postresource('mercurial', s:hg)
"▶1
call frawor#Lockvar(s:, '_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
