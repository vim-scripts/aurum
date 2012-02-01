
from mercurial import hg, ui, commands, match
from mercurial.repo import error
import vim
import os
import json
import re

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
    @staticmethod
    def _write(f, o, warning=False):
        try:
            return f.write(str(o))
        except UnicodeDecodeError:
            for line in str(o).split("\n"):
                if line == '':
                    line=' '
                if warning:
                    vim.command('echohl ErrorMsg')
                vim.command('echomsg '+utf_dumps(line))
                if warning:
                    vim.command('echohl None')

    # ui.ui for some reason does not support outputting unicode
    def write(self, *args, **kwargs):
        if self._buffers:
            self._buffers[-1].extend([str(a) for a in args])
        else:
            for a in args:
                self._write(self.fout, a)

    def write_err(self, *args, **kwargs):
        for a in args:
            self._write(self.ferr, a, True)

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
        if not hasattr(repo, '__getitem__'):
            vim.command('call s:_f.throw("csuns", '+nonutf_dumps(repo.path)+')')
            raise AurumError()
        return repo[rev]
    except error.RepoLookupError:
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
    except AttributeError:
        pass
    return cs_vim

def get_revlist(repo, startrev=0):
    cscount=len(repo)
    r=[set_rev_dict(g_cs(repo, i), {'rev': i,}) for i in range(startrev, cscount+1)]
    return r

def get_updates(path, oldtip=None):
    try:
        repo=g_repo(path)
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
        d_vim={      'css': r,
                'startrev': startrev,
                    'tags': tags_vim,
               'bookmarks': bookmarks_vim,}
        vim.eval('extend(a:repo, {"csnum": '+str(len(repo)+1)+'})')
        vim.eval('extend(d, '+utf_dumps(d_vim)+')')
    except AurumError:
        pass

def get_cs(path, rev):
    try:
        cs=g_cs(g_repo(path), rev)
        cs_vim=set_rev_dict(cs, {'rev': cs.rev()})
        vim.eval('extend(cs, '+utf_dumps(cs_vim)+')')
    except AurumError:
        pass

def new_repo(path):
    try:
        repo=g_repo(path)
        # TODO remove bookmark label type if it is not available
        vim_repo={'has_octopus_merges': 0,
                       'requires_sort': 0,
                          'changesets': {},
                              'cslist': [],
                               'local': 1 if repo.local() else 0,
                          'labeltypes': ['tag', 'bookmark'],
                 }
        if hasattr(repo, '__len__'):
            vim_repo['csnum']=len(repo)+1
        vim.eval('extend(repo, '+utf_dumps(vim_repo)+')')
    except AurumError:
        pass

def get_file(path, rev, filepath):
    try:
        fctx=g_fctx(g_cs(g_repo(path), rev), filepath)
        lines=[line.replace("\0", "\n") for line in fctx.data().split("\n")]
        vim.eval('extend(r, '+nonutf_dumps(lines)+')')
    except AurumError:
        pass

def annotate(path, rev, filepath):
    try:
        ann=g_fctx(g_cs(g_repo(path), rev), filepath).annotate(follow=True,
                                                               linenumber=True)
        ann_vim=[(line[0][0].path(), str(line[0][0].rev()), line[0][1])
                                                                for line in ann]
        vim.eval('extend(r, '+nonutf_dumps(ann_vim)+')')
    except AurumError:
        pass

def run_in_dir(dir, func, *args, **kwargs):
    workdir=os.path.abspath('.')
    try:
        os.chdir(dir)
    except AttributeError:
        pass
    except OSError:
        pass
    func(*args, **kwargs)
    os.chdir(workdir)

def dodiff(ui, path, rev1, rev2, files, opts):
    repo=g_repo(path)
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

def diff(*args, **kwargs):
    try:
        ui=CaptureUI()
        dodiff(ui, *args, **kwargs)
        vim.eval('extend(r, '+nonutf_dumps(ui._getCaptured())+')')
    except AurumError:
        pass

def diffToBuffer(*args, **kwargs):
    try:
        ui=CaptureToBuf(vim.current.buffer)
        dodiff(ui, *args, **kwargs)
        if len(vim.current.buffer)>1 and vim.current.buffer[-1] == '':
            vim.current.buffer[-1:]=[]
        else:
            vim.command('setlocal binary noendofline')
    except AurumError:
        pass

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
    vim.eval('extend(a:cs, '+nonutf_dumps({'renames': renames_vim,
                                            'copies': copies_vim})+')')

def get_cs_prop(path, rev, prop):
    try:
        cs=g_cs(g_repo(path), rev)
        if prop=='files' or prop=='removes' or prop=='changes':
            am=[]
            r=[]
            c=cs.files()
            for f in c:
                if f in cs:
                    am.append(f)
                else:
                    r.append(f)
            vim.eval('extend(a:cs, {  "files": '+nonutf_dumps(am)+', '+
                                   '"removes": '+nonutf_dumps(r) +', '+
                                   '"changes": '+nonutf_dumps(c) +'})')
            return
        elif prop=='renames' or prop=='copies':
            get_renames(cs)
            return
        elif prop=='allfiles':
            r=[f for f in cs]
        elif prop=='children':
            r=[ccs.hex() for ccs in cs.children()]
        else:
            r=cs.__getattribute__(prop)()
        # XXX There is much code relying on the fact that after getcsprop
        #     property with given name is added to changeset dictionary
        vim.eval('extend(a:cs, {"'+prop+'": '+nonutf_dumps(r)+'})')
    except AurumError:
        pass

def get_status(path, rev1=None, rev2=None, files=None, clean=None):
    try:
        if rev1 is None and rev2 is None:
            rev1='.'
        repo=g_repo(path)
        if hasattr(repo, 'status'):
            if not files:
                m=None
            else:
                m=match.match(None, None, files, exact=True)
            status=repo.status(rev1, rev2, ignored=True, clean=clean,
                               unknown=True, match=m)
            vim.eval('extend(r, '+nonutf_dumps({'modified': status[0],
                                                   'added': status[1],
                                                 'removed': status[2],
                                                 'deleted': status[3],
                                                 'unknown': status[4],
                                                 'ignored': status[5],
                                                   'clean': status[6],
                                               })+')')
        else:
            vim_throw('statuns', repo.path)
    except AurumError:
        pass

def update(path, rev='tip', force=False):
    try:
        repo=g_repo(path)
        if not hasattr(repo, '__getitem__'):
            vim_throw('upduns', repo.path)
        rev=g_cs(repo, rev).hex()
        args=[PrintUI(), repo, rev]
        kwargs={'clean': bool(force)}
        run_in_dir(repo.root, commands.update, *args, **kwargs)
    except AurumError:
        pass

def dirty(path, filepath):
    try:
        repo=g_repo(path)
        if not hasattr(repo, '__getitem__'):
            vim_throw('statuns', repo.path)
        dirty=repo[None].dirty()
        if dirty and filepath in dirty:
            vim.command('let r=1')
    except AurumError:
        pass

def get_repo_prop(path, prop):
    try:
        repo=g_repo(path)
        r=None
        if prop=='tagslist':
            r=repo.tags().keys()
        elif prop=='brancheslist':
            r=repo.branchmap().keys()
        elif prop=='bookmarkslist':
            if hasattr(repo, 'listkeys'):
                r=repo.listkeys('bookmarks').keys()
            else:
                r=[]
        elif prop=='url':
            r=repo.ui.config('paths', 'default-push')
            if r is None:
                r=repo.ui.config('paths', 'default')
        if r is None:
            vim_throw('nocfg', prop, repo.path)
        else:
            vim.eval('extend(a:repo, {"'+prop+'": '+utf_dumps(r)+'})')
    except AurumError:
        pass

def call_cmd(path, attr, *args, **kwargs):
    try:
        repo=g_repo(path)
        if 'force' in kwargs:
            kwargs['force']=bool(kwargs['force'])
        else:
            kwargs['force']=False
        cargs=[PrintUI(), repo]
        cargs.extend(args)
        run_in_dir(repo.root, commands.__getattribute__(attr),
                   *cargs, **kwargs)
    except AurumError:
        pass

def grep(path, pattern, files, revisions=None, ignore_case=False, wdfiles=True):
    try:
        repo=g_repo(path)
        ui=CaptureUI()
        args=[ui, repo, pattern]
        args.extend(files)
        revisions=["..".join(rev) if type(rev) is list else rev
                                                    for rev in revisions]
        if not revisions:
            revisions=None
        kwargs={'rev': revisions, 'ignore_case': bool(ignore_case),
                'line_number': True, 'follow': True, 'print0': True}
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
        vim.eval('extend(r, '+nonutf_dumps(r_vim)+')')
    except AurumError:
        pass

