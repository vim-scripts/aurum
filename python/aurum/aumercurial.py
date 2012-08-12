from mercurial import hg, ui, commands, match
try:
    from mercurial.repo import error
except ImportError:
    from mercurial import error
import vim
import os
import json
import re
import sys

if hasattr(error, 'RepoLookupError'):
    RepoLookupError=error.RepoLookupError
else:
    RepoLookupError=error.RepoError

def outermethod(func):
    """
        Decorator used to make functions omit showing python traceback in case vim_throw was used.
        Also transforms first argument (which is a path) to an repository object
    """
    def f(path, *args, **kwargs):
        try:
            repo=g_repo(path)
            try:
                func(repo, *args, **kwargs)
            finally:
                repo.ui.flush()
        except AurumError:
            pass
        except vim.error:
            pass
    return f

def nonutf_dumps(obj):
    todump=[('dump', obj)]
    r=''
    while todump:
        t, obj = todump.pop(0)
        if t == 'inject':
            r+=obj
        else:
            tobj=type(obj)
            if tobj is int:
                r+=str(obj)
            elif tobj is float:
                r += "%1.1e" % obj
            elif tobj is list or tobj is tuple:
                r+='['
                todump.insert(0, ('inject', ']'))
                for value in reversed(obj):
                    todump[:0]=[('dump', value), ('inject', ',')]
            elif tobj is dict:
                r+='{'
                todump.insert(0, ('inject', '}'))
                for key, value in obj.items():
                    todump[:0]=[('dump', key),
                                ('inject', ':'),
                                ('dump', value),
                                ('inject', ',')]
            else:
                r+='"'+str(obj).replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')+'"'
    return r

def pyecho(o, error=False):
    try:
        return (sys.stderr if error else sys.stdout).write(str(o))
    except UnicodeDecodeError:
        if error:
            vim.command('echohl ErrorMsg')
        for line in str(o).split("\n"):
            if not line:
                line=' '
            vim.command('echomsg '+utf_dumps(line))
        if error:
            vim.command('echohl None')

if hasattr(vim, 'bindeval'):
    ansi_esc_echo_func=None
    def register_ansi_esc_echo_func(func):
        global ansi_esc_echo_func
        ansi_esc_echo_func=func
        global echom
        echom=ansi_esc_echo

    def ansi_esc_echo(o, colinfo):
        if colinfo is None:
            return ansi_esc_echo_func(str(o), self={})
        else:
            return ansi_esc_echo_func(str(o), colinfo, self={})

echoe=lambda o, colinfo: pyecho(o, True )
echom=lambda o, colinfo: pyecho(o, False)

def utf_dumps(obj):
    return json.dumps(obj, encoding='utf8')

class AurumError(Exception):
    pass

class VIMEncode(json.JSONEncoder):
    def encode(self, obj, *args, **kwargs):
        if isinstance(obj, (dict, list, int)):
            return super(VIMEncode, self).encode(obj, *args, **kwargs)
        return '"'+str(obj).replace('\\', '\\\\').replace('"', '\\"')+'"'

class PrintUI(ui.ui):
    # ui.ui for some reason does not support outputting unicode
    def write(self, *args, **kwargs):
        if self._buffers:
            self._buffers[-1].extend([str(a) for a in args])
        else:
            colinfo=None
            for a in args:
                colinfo=echom(a, colinfo)

    def write_err(self, *args, **kwargs):
        colinfo=None
        for a in args:
            colinfo=echoe(a, colinfo)

class CaptureUI(PrintUI):
    def __init__(self):
        self._captured=[]
        super(CaptureUI, self).__init__()

    def write(self, *args, **kwargs):
        target=self._buffers[-1] if self._buffers else self._captured
        target.extend([str(a) for a in args])

    def _getCaptured(self, verbatim=False):
        if verbatim:
            return "".join(self._captured)
        r=[s.replace("\0", "\n") for s in ("".join(self._captured)).split("\n")]
        self._captured=[]
        return r

class CaptureToBuf(PrintUI):
    def __init__(self, buf):
        self._vimbuffer=buf
        super(CaptureToBuf, self).__init__()

    def write(self, *args, **kwargs):
        target=self._buffers[-1] if self._buffers else self._vimbuffer
        for a in args:
            lines=str(a).split("\n")
            target[-1]+=lines.pop(0)
            for line in lines:
                target.append(line)

def vim_throw(*args):
    vim.command('call s:_f.throw('+nonutf_dumps(args)[1:-1]+')')
    raise AurumError()

def g_repo(path):
    try:
        return hg.repository(PrintUI(), path)
    except error.RepoError:
        vim_throw('norepo', path)

def g_cs(repo, rev):
    try:
        return repo[rev]
    except RepoLookupError:
        vim_throw('norev', rev, repo.path)

def g_fctx(cs, filepath):
    try:
        return cs.filectx(filepath)
    except error.LookupError:
        vim_throw('nofile', filepath, cs.hex(), cs._repo.path)

def set_rev_dict(cs, cs_vim):
    cs_vim['hex']=cs.hex()
    cs_vim['time']=int(cs.date()[0])
    cs_vim['description']=cs.description()
    cs_vim['user']=cs.user()
    cs_vim['parents']=[parent.hex() for parent in cs.parents()]
    try:
        branch=cs.branch()
        cs_vim['branch']=branch
        cs_vim['tags']=cs.tags()
        cs_vim['bookmarks']=cs.bookmarks()
        # FIXME For some reason using cs.phasestr() here results in an exception
    except AttributeError:
        pass
    return cs_vim

def get_revlist(repo, startrev=0):
    cscount=len(repo)
    r=[set_rev_dict(g_cs(repo, i), {'rev': i,}) for i in range(startrev, cscount+1)]
    return r

if hasattr(vim, 'bindeval'):
    def vim_extend(val, var='d', utf=True, list=False):
        d_vim = vim.bindeval(var)
        if list:
            d_vim.extend(val)
        else:
            for key in val:
                d_vim[key] = val[key]
else:
    def vim_extend(val, var='d', utf=True, list=False):
        vim.eval('extend('+var+', '+((utf_dumps if utf else nonutf_dumps)(val))+')')

@outermethod
def get_updates(repo, oldtip=None):
    tipcs=repo['tip']
    if oldtip is not None:
        try:
            cs=repo[oldtip]
            if tipcs.hex()==cs.hex():
                return
            startrev=cs.rev()
        except error.RepoLookupError:
            startrev=0
    else:
        startrev=0
    r=get_revlist(repo, startrev)
    tags_vim={}
    for (tag, b) in repo.tags().items():
        tags_vim[tag]=repo[b].hex()
    bookmarks_vim={}
    if hasattr(repo, 'listkeys'):
        bookmarks_vim=repo.listkeys('bookmarks')
    vim_extend(var='a:repo', val={'csnum': (len(repo)+1)})
    vim_extend(val={'css': r,
               'startrev': startrev,
                   'tags': tags_vim,
              'bookmarks': bookmarks_vim,})
    if hasattr(tipcs, 'phase'):
        vim_extend(val={'phases': [repo[rev].phasestr() for rev in range(startrev)]})

def get_cs_tag_dict(l):
    r={}
    for hex, tag in l:
        if hex in r:
            r[hex].append(tag)
        else:
            r[hex]=[tag]
    for key in r:
        r[key].sort()
    return r

@outermethod
def get_tags(repo):
    tags=get_cs_tag_dict([(repo[val].hex(), key) for key, val
                          in repo.tags().items()])
    bookmarks={}
    if hasattr(repo, 'listkeys'):
        bookmarks=get_cs_tag_dict([(val, key) for key, val
                                   in repo.listkeys('bookmarks').items()])
    vim_extend(val={'tags': tags, 'bookmarks': bookmarks})

@outermethod
def get_phases(repo):
    vim_extend(val={'phasemap': dict((lambda cs: (cs.hex(), cs.phasestr()))(repo[rev])
                                                 for rev in repo)})

@outermethod
def get_cs(repo, rev):
    cs=g_cs(repo, rev)
    vim_extend(var='cs', val=set_rev_dict(cs, {'rev': cs.rev()}))

@outermethod
def new_repo(repo):
    # TODO remove bookmark label type if it is not available
    vim_repo={'has_octopus_merges': 0,
                   'requires_sort': 0,
                      'changesets': {},
                         'mutable': {'cslist': [], 'commands': {}},
                           'local': 1 if repo.local() else 0,
                      'labeltypes': ['tag',  'bookmark'],
                         'updkeys': ['tags', 'bookmarks'],
                    'hasbookmarks': 1,
                       'hasphases': int(hasattr(repo[None], 'phase')),
             }
    if hasattr(repo, '__len__'):
        vim_repo['csnum']=len(repo)+1
    if not hasattr(commands, 'bookmarks'):
        vim_repo['labeltypes'].pop()
        vim_repo['updkeys'].pop()
        vim_repo['hasbookmarks']=0
    vim_extend(var='repo', val=vim_repo)

@outermethod
def get_file(repo, rev, filepath):
    fctx=g_fctx(g_cs(repo, rev), filepath)
    lines=[line.replace("\0", "\n") for line in fctx.data().split("\n")]
    vim_extend(var='r', val=lines, utf=False, list=True)

@outermethod
def annotate(repo, rev, filepath):
    ann=g_fctx(g_cs(repo, rev), filepath).annotate(follow=True, linenumber=True)
    ann_vim=[(line[0][0].path(), str(line[0][0].rev()), line[0][1])
                                                            for line in ann]
    vim_extend(var='r', val=ann_vim, utf=False, list=True)

def run_in_dir(dir, func, *args, **kwargs):
    workdir=os.path.abspath('.')
    try:
        os.chdir(dir)
    except AttributeError:
        pass
    except OSError:
        pass
    try:
        func(*args, **kwargs)
    finally:
        os.chdir(workdir)

def dodiff(ui, repo, rev1, rev2, files, opts):
    if not hasattr(repo, '__getitem__'):
        vim_throw('diffuns', repo.path)
    args=[ui, repo]+files
    kwargs=opts
    if rev2:
        kwargs["rev"]=[rev2]
        if rev1:
            kwargs["rev"].append(rev1)
    else:
        if rev1:
            kwargs["change"]=rev1
    run_in_dir(repo.root, commands.diff, *args, **kwargs)

@outermethod
def diff(*args, **kwargs):
    ui=CaptureUI()
    dodiff(ui, *args, **kwargs)
    vim_extend(var='r', val=ui._getCaptured(), utf=False, list=True)

@outermethod
def diffToBuffer(*args, **kwargs):
    ui=CaptureToBuf(vim.current.buffer)
    dodiff(ui, *args, **kwargs)
    if len(vim.current.buffer)>1 and vim.current.buffer[-1] == '':
        vim.current.buffer[-1:]=[]
    else:
        vim.command('setlocal binary noendofline')

def get_renames(cs):
    def get_renames_value(rename):
        return rename[0] if rename else 0
    renames_vim={}
    copies_vim={}
    for f in cs:
        fctx=g_fctx(cs, f)
        rename=get_renames_value(fctx.renamed())
        if rename:
            if rename in cs:
                copies_vim[f]=rename
                renames_vim[f]=0
            else:
                copies_vim[f]=0
                renames_vim[f]=rename
        else:
            copies_vim[f]=0
            renames_vim[f]=0
    vim_extend(var='a:cs', val={'renames': renames_vim, 'copies': copies_vim},
               utf=False)

@outermethod
def get_cs_prop(repo, rev, prop):
    cs=g_cs(repo, rev)
    if prop=='files' or prop=='removes' or prop=='changes':
        am=[]
        r=[]
        c=cs.files()
        for f in c:
            if f in cs:
                am.append(f)
            else:
                r.append(f)
        vim_extend(var='a:cs', val={'files': am, 'removes': r, 'changes': c},
                   utf=False)
        return
    elif prop=='renames' or prop=='copies':
        get_renames(cs)
        return
    elif prop=='allfiles':
        r=[f for f in cs]
    elif prop=='children':
        r=[ccs.hex() for ccs in cs.children()]
    elif prop=='phase':
        if hasattr(cs, 'phasestr'):
            r=cs.phasestr()
        else:
            r='unknown'
    else:
        r=cs.__getattribute__(prop)()
    # XXX There is much code relying on the fact that after getcsprop
    #     property with given name is added to changeset dictionary
    vim_extend(var='a:cs', val={prop : r}, utf=False)

@outermethod
def get_status(repo, rev1=None, rev2=None, files=None, clean=None, ignored=None):
    if rev1 is None and rev2 is None:
        rev1='.'
    if hasattr(repo, 'status'):
        if not files:
            m=None
        else:
            m=match.match(None, None, files, exact=True)
        status=repo.status(rev1, rev2, match=m, clean=clean, ignored=ignored,
                           unknown=True)
        vim_extend(val={'modified': status[0],
                           'added': status[1],
                         'removed': status[2],
                         'deleted': status[3],
                         'unknown': status[4],
                         'ignored': status[5],
                           'clean': status[6],},
                   utf=False)
    else:
        vim_throw('statuns', repo.path)

@outermethod
def update(repo, rev='tip', force=False):
    if not hasattr(repo, '__getitem__'):
        vim_throw('upduns', repo.path)
    rev=g_cs(repo, rev).hex()
    args=[repo.ui, repo, rev]
    kwargs={'clean': bool(force)}
    run_in_dir(repo.root, commands.update, *args, **kwargs)

@outermethod
def dirty(repo, filepath):
    if not hasattr(repo, '__getitem__'):
        vim_throw('statuns', repo.path)
    dirty=repo[None].dirty()
    if dirty and filepath in dirty:
        vim.command('let r=1')

repo_props={
            'tagslist': lambda repo: repo.tags().keys(),
        'brancheslist': lambda repo: repo.branchmap().keys(),
       'bookmarkslist': lambda repo: repo.listkeys('bookmarks').keys()
                                        if hasattr(repo, 'listkeys') else [],
                 'url': lambda repo: repo.ui.config('paths', 'default-push') or
                                     repo.ui.config('paths', 'default'),
              'branch': lambda repo: repo.dirstate.branch(),
        }
@outermethod
def get_repo_prop(repo, prop):
    if prop in repo_props:
        r=repo_props[prop](repo)
        if r is None:
            vim_throw('failcfg', prop, repo.path)
        else:
            vim_extend(val={prop : r})
    else:
        vim_throw('nocfg', repo.path, prop)

@outermethod
def call_cmd(repo, attr, bkwargs, *args, **kwargs):
    if bkwargs:
        for kw in bkwargs:
            if kw in kwargs:
                kwargs[kw]=bool(int(kwargs[kw]))
    if 'force' in kwargs:
        kwargs['force']=bool(int(kwargs['force']))
    else:
        kwargs['force']=False
    for key in [key for key in kwargs if key.find('-')!=-1]:
        newkey=key.replace('-', '_')
        kwargs[newkey]=kwargs.pop(key)
    cargs=[repo.ui, repo]
    cargs.extend(args)
    run_in_dir(repo.root, commands.__getattribute__(attr),
               *cargs, **kwargs)

@outermethod
def grep(repo, pattern, files, revisions=None, ignore_case=False, wdfiles=True):
    ui=CaptureUI()
    args=[ui, repo, pattern]
    args.extend(files)
    revisions=[":".join(rev) if type(rev) is list else rev
                             for rev in revisions]
    if not revisions:
        revisions=None
    kwargs={'rev': revisions, 'ignore_case': bool(ignore_case),
            'line_number': True, 'print0': True}
    cs=g_cs(repo, '.')
    kwargs['follow']=not [f for f in files if f not in cs]
    run_in_dir(repo.root, commands.grep, *args, **kwargs)
    items=(ui._getCaptured(verbatim=True)).split("\0")
    # XXX grep uses "\0" as a terminator, thus last line ends with "\0"
    items.pop()
    r_vim=[]
    status_cache={}
    def check_not_modified_since(rev, file):
        key=rev+':'+file
        if key in status_cache:
            return status_cache[key]
        r=file in repo.status(node1=rev, clean=True,
                              match=match.match(None, None, [file],
                                                exact=True))[6]
        status_cache[key]=r
        return r
    while items:
        file=items.pop(0)
        rev=items.pop(0)
        lnum=int(items.pop(0))
        text=items.pop(0)
        if wdfiles and check_not_modified_since(rev, file):
            file=os.path.join(repo.root, file)
        else:
            file=(rev, file)
        r_vim.append({'filename': file, 'lnum': int(lnum), 'text': text})
    vim_extend(var='r', val=r_vim, utf=False, list=True)

@outermethod
def git_hash(repo, rev):
    hggitpath=None
    hggitname=None
    for hggitname in ['hggit', 'git']:
        hggitpath=repo.ui.config('extensions', hggitname)
        if hggitpath is not None:
            break
    if hggitpath is None:
        vim_throw('nohggitc')
    import sys
    sys.path.insert(0, hggitpath)
    try:
        try:
            if hggitname=='hggit':
                from hggit.git_handler import GitHandler
            elif hggitname=='git':
                from git.git_handler   import GitHandler
        except ImportError:
            vim_throw('nohggit')
        git=GitHandler(repo, repo.ui)
        cs=g_cs(repo, rev)
        r=git.map_git_get(cs.hex())
        if r is None:
            vim_throw('nogitrev', cs.hex(), repo.path)
        vim.command('return '+json.dumps(r))
    finally:
        sys.path.pop(0)

# vim: ft=python ts=4 sw=4 sts=4 et tw=100
