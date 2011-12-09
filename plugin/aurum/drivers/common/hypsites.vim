"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.0', {'@/resources': '0.0',}, 0)
    finish
elseif s:_pluginloaded
    finish
endif
"▶1 s:hypsites
let s:dport='domain.(empty(port)?"":":".port)'
let s:link='shellescape("http://".'.s:dport.'.path)'
" TODO cache
let s:dl=    '(executable("curl")?'.
            \   '(system("curl -L ".'.s:link.')):'.
            \'(executable("wget")?'.
            \   '(system("wget -O- ".'.s:link.'))'.
            \':'.
            \   '(0)))'
unlet s:link
let s:bbdict={
\       'html': '"https://".domain.path."/src/".cs.hex."/".file',      'hline': '"cl-".line',
\        'raw': '"https://".domain.path."/raw/".cs.hex."/".file',
\   'annotate': '"https://".domain.path."/annotate/".cs.hex."/".file', 'aline': '"line-".line',
\   'filehist': '"https://".domain.path."/history/".file',
\     'bundle': '"https://".domain.path."/get/".cs.hex.".tar.bz2"',
\  'changeset': '"https://".domain.path."/changeset/".cs.hex',
\        'log': '"https://".domain.path."/changesets"',
\      'clone': '"https://".domain.path',
\       'push': '"ssh://hg@".domain.path',
\}
let s:hyp={}
let s:gcproj='matchstr(domain, "\\v^[^.]+")'
"▶1 mercurial
"  https://bitbucket.org/ZyX_I/aurum / ssh://hg@bitbucket.org/ZyX_I/aurum
"  ssh://zyxsf@translit3.hg.sourceforge.net/hgroot/translit3/translit3 /
"       http://translit3.hg.sourceforge.net:8000/hgroot/translit3/translit3
"  https://vim-pyinteractive-plugin.googlecode.com/hg/
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
"t http://anonscm.debian.org/hg/minicom/
" len("hgroot")=6
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
let s:hgwebdict={
\       'html': '"http://".'.s:dport.'.path."/file/".cs.hex."/".file',     'hline': '"l".line',
\        'raw': '"http://".'.s:dport.'.path."/raw-file/".cs.hex."/".file',
\   'annotate': '"http://".'.s:dport.'.path."/annotate/".cs.hex."/".file', 'aline': '"l".line',
\   'filehist': '"http://".'.s:dport.'.path."/log/".cs.hex."/".file',
\  'changeset': '"http://".'.s:dport.'.path."/rev/".cs.hex',
\        'log': '"http://".'.s:dport.'.path."/graph"',
\      'clone': '"http://".'.s:dport.'.path',
\}
let s:hyp.mercurial=[
\['domain is? "bitbucket.org"', s:bbdict],
\['domain =~? "\\Vhg.sourceforge.net\\$"',
\ {     'html': '"http://".domain."/hgweb".path[7:]."/file/".cs.hex."/".file',     'hline': '"l".line',
\        'raw': '"http://".domain."/hgweb".path[7:]."/raw-file/".cs.hex."/".file',
\   'annotate': '"http://".domain."/hgweb".path[7:]."/annotate/".cs.hex."/".file', 'aline': '"l".line',
\   'filehist': '"http://".domain."/hgweb".path[7:]."/log/".cs.hex."/".file',
\  'changeset': '"http://".domain."/hgweb".path[7:]."/rev/".cs.hex',
\        'log': '"http://".domain."/hgweb".path[7:]."/graph"',
\      'clone': '"http://".domain.":8000".path',
\       'push': '"ssh://".user."@".domain.path',}],
\['domain =~? "\\Vgooglecode.com\\$" && path[:2] is? "/hg"',
\ {     'html': '"http://code.google.com/p/".'.s:gcproj.'."/source/browse/".file."?r=".cs.hex', 'hline': 'line',
\        'raw': '"http://".domain."/hg-history/".cs.hex."/".file',
\   'filehist': '"http://code.google.com/p/".'.s:gcproj.'."/source/list?path=/".file."&r=".cs.hex',
\  'changeset': '"http://code.google.com/p/".'.s:gcproj.'."/source/detail?r=".cs.hex',
\        'log': '"http://code.google.com/p/".'.s:gcproj.'."/source/list"',
\      'clone': 'url',
\       'push': 'url',}],
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
\ map(copy(s:hgwebdict), 'substitute(v:val, "http", "https", "")')],
\[ 'domain =~? ''\v^%(mercurial\.%(intuxication|tuxfamily)|hg\.mozdev|hg\.savannah\.%(non)?gnu)\.org$'' || '.
\ '(domain is? "anonscm.debian.org" && path[:2] is? "/hg") || '.
\ '('.s:dl.'=~#''\V<link rel="icon" href="\[^"]\*static/hgicon.png" type="image/png" />'')',
\ s:hgwebdict],
\]
unlet s:hgwebdict s:pkbase s:cpbase s:cbssh s:cbhttps
"▶1 git
"  ssh://git@github.com:MarcWeber/vim-addon-manager / git://github.com/MarcWeber/vim-addon-manager
"  git://vimpluginloader.git.sourceforge.net/gitroot/vimpluginloader/vam-test-repository
"       / ssh://zyxsf@vimpluginloader.git.sourceforge.net/gitroot/vimpluginloader/vam-test-repository
"  git://repo.or.cz/test2.git / http://repo.or.cz/r/test2.git /
"       ssh://repo.or.cz/srv/git/test2.git
"  git://gitorious.org/test4/test.git / https://git.gitorious.org/test4/test.git
"       / ssh://git@gitorious.org:test4/test.git
"  (unable to clone with hg-git) https://code.google.com/p/tortoisegit/
let s:ghpath='substitute(path, "\\v^[:/]|\\.git$", "", "g")'
let s:roproj='matchstr(path, ''\v\/@<=[^/]{-1,}%(%(\.git)?\/*$)@='').".git"'
let s:robase='"http://".domain."/w/".'.s:roproj
let s:godomain='substitute(domain, "^git\\.", "", "")'
let s:gobase='"http://".'.s:godomain.'."/".'.s:ghpath
let s:hyp.git=[
\['domain is? "bitbucket.org"', s:bbdict],
\['domain is? "github.com"',
\ {     'html': '"https://".domain."/".'.s:ghpath.'."/blob/".cs.hex."/".file',   'hline': '"L".line',
\        'raw': '"https://".domain."/".'.s:ghpath.'."/raw/". cs.hex."/".file',
\   'annotate': '"https://".domain."/".'.s:ghpath.'."/blame/". cs.hex."/".file', 'aline': '"LID".line',
\   'filehist': '"https://".domain."/".'.s:ghpath.'."/commits/".cs.hex."/".file',
\     'bundle': '"https://".domain."/".'.s:ghpath.'."/zipball/".cs.hex',
\  'changeset': '"https://".domain."/".'.s:ghpath.'."/commit/".cs.hex',
\        'log': '"https://".domain."/".'.s:ghpath.'."/commits"',
\      'clone': '"git://".domain."/".'.s:ghpath,
\       'push': '"ssh://git@".domain.":".'.s:ghpath.'.".git"',}],
\['domain =~? "\\Vgit.sourceforge.net\\$"',
\ {     'html': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=blob;hb=".cs.hex.";f=".file', 'hline': '"l".line',
\        'raw': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=blob_plain;hb=".cs.hex.";f=".file',
\   'filehist': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=history;hb=".cs.hex.";f=".file',
\  'changeset': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=commitdiff;hb=".cs.hex',
\        'log': '"http://".domain."/git/gitweb.cgi?p=".path[9:].";a=log"',
\      'clone': '"http://".domain.":8000".path',
\       'push': '"ssh://".user."@".domain.path',}],
\['domain is? "code.google.com"',
\ {     'html': '"http://code.google.com/".substitute(path, "/$", "", "")."/source/browse/".file."?r=".cs.hex',}],
\['domain =~? ''\v^%(git\.)?gitorious\.org$''',
\ {     'html': s:gobase.'."/blobs/".cs.hex."/".file',       'hline': '"line".line',
\        'raw': s:gobase.'."/blobs/raw/".cs.hex."/".file',
\   'annotate': s:gobase.'."/blobs/blame/".cs.hex."/".file', 'aline': '"line".line',
\   'filehist': s:gobase.'."/blobs/history/".cs.hex."/".file',
\  'changeset': s:gobase.'."/commit/".cs.hex',
\        'log': s:gobase.'."/commits/".cs.hex',
\      'clone': '"git://".'.s:godomain.'."/".'.s:ghpath,
\       'push': '"ssh://git@".'.s:godomain.'.":".'.s:ghpath.'.".git"',}],
\['domain is? "repo.or.cz"',
\ {     'html': s:robase.'."/blob/".cs.hex.":/".file',       'hline': '"l".line',
\        'raw': s:robase.'."/blob_plain/".cs.hex.":/".file',
\   'annotate': s:robase.'."/blame/".cs.hex.":/".file',      'aline': '"l".line',
\   'filehist': s:robase.'."/history/".cs.hex.":/".file',
\  'changeset': s:robase.'."/commit/".cs.hex',
\        'log': s:robase.'."/log/".cs.hex',
\      'clone': '"git://".domain."/".'.s:roproj,
\       'push': '"ssh://".domain."/srv/git/".'.s:roproj,}],
\]
unlet s:ghpath s:roproj s:robase s:godomain s:gobase
"▶1 subversion
"  https://vimpluginloader.svn.sourceforge.net/svnroot/vimpluginloader
"  http://conque.googlecode.com/svn/trunk
let s:svngcbase='"http://code.google.com/p/".'.s:gcproj
let s:svngcfile='path[5:]."/".file'
let s:hyp.svn=[
\['domain =~? "\\Vsvn.sourceforge.net\\$"',
\ {     'html': '"http://".domain."/viewvc".path[8:]."/".file."?view=log&pathrev=".cs.rev',
\        'raw': '"http://".domain."/viewvc".path[8:]."/".file."?pathrev=".cs.rev',
\   'annotate': '"http://".domain."/viewvc".path[8:]."/".file."?annotate=".cs.rev',
\     'bundle': '"http://".domain."/viewvc".path[8:]."?view=tar&pathrev=".cs.rev',
\        'log': '"http://".domain."/viewvc".path[8:]."?view=log"',
\      'clone': 'url',}],
\['domain =~? "\\Vgooglecode.com\\$" && path[:3] is? "/svn"',
\ {     'html': s:svngcbase.'."/source/browse/".'.s:svngcfile.'."?rev=".cs.rev', 'hline': 'line',
\        'raw': '"http://".domain."/svn-history/r".cs.rev.'.s:svngcfile,
\   'filehist': s:svngcbase.'."/source/list?path=/".'.s:svngcfile.'."&r=".cs.rev',
\        'log': s:svngcbase.'."/source/list"',
\      'clone': 'url',}],
\]
unlet s:svngcbase s:svngcfile
"▶1 post resource
unlet s:gcproj s:dl s:bbdict s:dport
call s:_f.postresource('hypsites', s:hyp)
unlet s:hyp
"▶1
call frawor#Lockvar(s:, '_pluginloaded')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
