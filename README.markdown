
This plugin provides a vim <--> VCS (currently mercurial, git and subversion) 
integration for your projects. Features:

  - Partially committing changes ([:AuRecord](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line405-0)).

  - Viewing file state at particular revision ([aurum://file](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line684-0), [:AuFile](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line161-0)).

  - Viewing uncommited changes in a vimdiff, as well as changes between 
    specific revisions ([:AuVimDiff](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line448-0)). It is also possible to open multiple 
    tabs with all changes to all files viewed as side-by-side diffs.

  - Viewing revisions log ([:AuLog](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line260-0)). Output is highly customizable.

  - Viewing working directory status ([:AuStatus](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line409-0)).

  - Commiting changes ([:AuCommit](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line102-0)), commit messages are remembered in case of 
    rollback ([g:aurum_remembermsg](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line1067-0)).

  - Obtaining various URL’s out of remote repository URL (like URL of the HTML 
    version of the current file with URL fragment pointing to the current line 
    attached: useful for sharing) ([:AuHyperlink](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line203-0)). For mercurial it also 
    supports git and subversion revisions (in case you are using hg-git and 
    hgsubversion respectively).

  - [aurum#changeset()](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line504-0), [aurum#repository()](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line500-0) and [aurum#status()](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line508-0) functions 
    that are to be used from modeline.

  - Frontends for various other VCS commands.

Most commands can be reached with a set of mappings (see [aurum-mappings](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html#line846-0)), 
all mappings are customizable.


Plugin’s mercurial driver is able to use mercurial python API as well as its 
CLI, but remember that the former is much slower and less tested. In order to 
use mercurial python API you must have vim compiled with +python (mercurial 
currently does not support python 3) and have mercurial in python’s sys.path 
(note: on windows msi installer is not adding mercurial to sys.path, so you 
won’t be able to use its python API).


Plugin requires some additional plugins:

  - [frawor](https://bitbucket.org/ZyX_I/frawor)

(with their dependencies).


Note: aurum supports [VAM](https://github.com/MarcWeber/vim-addon-manager). It 
      is prefered that you use it for aurum installation.

Documentation is available online at [http://vimpluginloader.sourceforge.net/doc/aurum.txt.html](http://vimpluginloader.sourceforge.net/doc/aurum.txt.html).
