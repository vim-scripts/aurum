"▶1
scriptencoding utf-8
if !exists('s:_pluginloaded')
    execute frawor#Setup('0.3', {'@/table': '0.1',
                \        '@aurum/cmdutils': '0.0',
                \   '@aurum/log/templates': '0.0',
                \       '@aurum/lineutils': '0.0',
                \         '@aurum/bufvars': '0.0',
                \            '@aurum/edit': '1.1',
                \                  '@/fwc': '0.3',
                \            '@aurum/repo': '3.0',
                \             '@/commands': '0.0',
                \            '@/functions': '0.0',
                \              '@/options': '0.0',}, 0)
    call FraworLoad('@/commands')
    call FraworLoad('@/functions')
    let s:logcomp=[]
    let s:logfunc={}
    call s:_f.command.add('AuLog', s:logfunc, {'nargs': '*',
                \                           'complete': s:logcomp})
    finish
elseif s:_pluginloaded
    finish
elseif !exists('s:_loading')
    call FraworLoad(s:_frawor.id)
    finish
endif
let s:F.glog={}
let s:F.graph={}
let s:_options={
            \'ignorefiles': {'default': [],
            \                'checker': 'list in [patch renames copies files]'},
            \'closewindow': {'default': 1, 'filter': 'bool'},
            \'procinput':   {'default': 1, 'checker': 'range 0 2'},
        \}
let s:_messages={
            \  'ebuf': 'Switched to another buffer: exiting',
        \}
" iterfuncs :: {fname: { "start": startfunc, "next": nextfunc }}
" startfunc (always) :: repo, opts, * → d
let s:iterfuncs={}
"▶1 graph
"▶2 graph.update_state :: graph, gstate → + graph
function s:F.graph.update_state(s)
    let self.prev_state=self.state
    let self.state=a:s
endfunction
"▶2 graph.ensure_capacity :: graph, num_columns → + graph
function s:F.graph.ensure_capacity(num_columns)
    let mdiff=(a:num_columns*2)-len(self.mapping)
    if mdiff>0
        let plist=repeat([-1], mdiff)
        let self.mapping+=plist
        let self.new_mapping+=plist
    endif
endfunction
"▶2 graph.insert_into_new_columns :: graph, hex, mapindex → mapindex + graph
function s:F.graph.insert_into_new_columns(hex, mapindex)
    let i=0
    for hex in self.new_columns
        if hex is# a:hex
            let self.mapping[a:mapindex]=i
            return a:mapindex+2
        endif
        let i+=1
    endfor
    let self.mapping[a:mapindex]=len(self.new_columns)
    call add(self.new_columns, a:hex)
    return a:mapindex+2
endfunction
"▶2 graph.update_columns :: graph → + graph
function s:F.graph.update_columns()
    let self.columns=self.new_columns
    let self.new_columns=[]
    let max_new_columns=len(self.columns)+self.num_parents
    call self.ensure_capacity(max_new_columns)
    let self.mapping_size=2*max_new_columns
    if !empty(self.mapping)
        call remove(self.mapping, 0, self.mapping_size-1)
    endif
    call extend(self.mapping, repeat([-1], self.mapping_size), 0)
    let seen=0
    let midx=0
    let is_cs_in_columns=1
    let num_columns=len(self.columns)
    for i in range(num_columns+1)
        if i==num_columns
            if seen
                break
            endif
            let is_cs_in_columns=0
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let oldmidx=midx
            let seen=1
            let self.commit_index=i
            for parent in self.interesting_parents
                let midx=self.insert_into_new_columns(parent, midx)
            endfor
            if midx==oldmidx
                let midx+=2
            endif
        else
            let midx=self.insert_into_new_columns(ccshex, midx)
        endif
    endfor
    while self.mapping_size>1 && self.mapping[self.mapping_size-1]==-1
        let self.mapping_size-=1
    endwhile
    let self.width=(len(self.columns)+self.num_parents+(self.num_parents<1)
                \  -(is_cs_in_columns))*2
endfunction
"▶2 graph.update :: graph, cs → + graph
function s:F.graph.update(cs)
    let self.cs=a:cs
    let self.interesting_parents=copy(a:cs.parents)
    let self.num_parents=len(self.interesting_parents)
    let self.prev_commit_index=self.commit_index
    call self.update_columns()
    let self.expansion_row=0
    if self.state isnot# 'padding'
        let self.state='skip'
    elseif self.num_parents>2 &&
                \self.commit_index<(len(self.columns)-1)
        let self.state='precommit'
    else
        let self.state='commit'
    endif
endfunction
"▶2 graph.is_mapping_correct :: graph → Bool
function s:F.graph.is_mapping_correct()
    return empty(filter(self.mapping[:(self.mapping_size-1)],
                \       '!(v:val==-1 || v:val==v:key/2)'))
endfunction
"▶2 graph.pad_horizontally :: graph, chars_written → String
" XXX Replace somehow?
function s:F.graph.pad_horizontally(chars_written)
    if a:chars_written>=self.width
        return ''
    endif
    return repeat(' ', self.width-a:chars_written)
endfunction
"▶2 graph.output_padding_line :: graph → String
function s:F.graph.output_padding_line()
    let lnc=len(self.new_columns)
    return repeat('| ', lnc).self.pad_horizontally(lnc*2)
endfunction
"▶2 graph.output_skip_line :: graph → String
function s:F.graph.output_skip_line()
    call self.update_state(((self.num_parents>2 &&
                \            self.commit_index<(len(self.columns)-1))?
                \               ('precommit'):
                \               ('commit')))
    return '...'.self.pad_horizontally(3)
endfunction
"▶2 graph.output_pre_commit_line :: graph → String
function s:F.graph.output_pre_commit_line()
    let num_expansion_rows=(self.num_parents-2)*2
    let seen=0
    let r=''
    let i=-1
    for hex in self.columns
        let i+=1
        if hex is# self.cs.hex
            let seen=1
            let r.='|'.repeat(' ', self.expansion_row)
        elseif seen && self.expansion_row==0
            let r.='|\'[self.prev_state is# 'postmerge' &&
                        \self.prev_commit_index<i]
        elseif seen && self.expansion_row>0
            let r.='\'
        else
            let r.='|'
        endif
        let r.=' '
    endfor
    let r.=self.pad_horizontally(len(r))
    let self.expansion_row+=1
    if self.expansion_row>num_expansion_rows
        call self.update_state('commit')
    endif
    return r
endfunction
"▶2 graph.output_commit_char :: graph → String
function s:F.graph.output_commit_char()
    if has_key(self.skipchangesets, self.cs.hex)
        return '*'
    endif
    return '@o'[index(self.workcss, self.cs.hex)==-1]
endfunction
"▶2 graph.draw_octopus_merge :: graph → String
function s:F.graph.draw_octopus_merge()
    let r=''
    for i in range(((self.num_parents-2)*2)-1)
        let r.='-'
    endfor
    let r.='.'
    return r
endfunction
"▶2 graph.output_commit_line :: graph → String
function s:F.graph.output_commit_line()
    let seen=0
    let r=''
    let lcolumns=len(self.columns)
    for i in range(lcolumns+1)
        if i==lcolumns
            if seen
                break
            endif
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let seen=1
            let r.=self.output_commit_char()
            if self.num_parents>2
                let r.=self.draw_octopus_merge()
            endif
        elseif seen && self.num_parents>2
            let r.='\'
        elseif seen && self.num_parents==2
            let r.='|\'[self.prev_state is# 'postmerge' &&
                        \self.prev_commit_index<i]
        else
            let r.='|'
        endif
        let r.=' '
    endfor
    let r.=self.pad_horizontally(len(r))
    call self.update_state(((self.num_parents>1)?
                \             ('postmerge'):
                \          ((self.is_mapping_correct())?
                \             ('padding')
                \          :
                \             ('collapsing'))))
    return r
endfunction
"▶2 graph.output_post_merge_line :: graph → String
function s:F.graph.output_post_merge_line()
    let seen=0
    let r=''
    let lcolumns=len(self.columns)
    for i in range(lcolumns+1)
        if i==lcolumns
            if seen
                break
            endif
            let ccshex=self.cs.hex
        else
            let ccshex=self.columns[i]
        endif
        if ccshex is# self.cs.hex
            let seen=1
            let r.='|'.repeat('\ ', self.num_parents-1)
        else
            let r.='|\'[seen].' '
        endif
    endfor
    let r.=self.pad_horizontally(len(r))
    call self.update_state(((self.is_mapping_correct())?
                \               ('padding'):
                \               ('collapsing')))
    return r
endfunction
"▶2 graph.output_collapsing_line :: graph → String
function s:F.graph.output_collapsing_line()
    let used_horizontal=0
    let horizontal_edge=-1
    let horizontal_edge_target=-1
    let self.new_mapping=repeat([-1], self.mapping_size)
    for [i, target] in map(self.mapping[:(self.mapping_size-1)],
                \          '[v:key, v:val]')
        if target==-1
            continue
        elseif i==target*2
            let self.new_mapping[i]=target
        elseif self.new_mapping[i-1]==-1
            let self.new_mapping[i-1]=target
            if horizontal_edge==-1
                let horizontal_edge=i
                let horizontal_edge_target=target
                let j=(target*2)+3
                while j<i-2
                    let self.new_mapping[j]=target
                    let j+=2
                endwhile
            endif
        elseif self.new_mapping[i-1]==target
        else
            let self.new_mapping[i-2]=target
            if horizontal_edge==-1
                let horizontal_edge=1
            endif
        endif
    endfor
    if self.mapping[self.mapping_size-1]==-1
        let self.mapping_size-=1
    endif
    let r=''
    for [i, target] in map(self.new_mapping[:(self.mapping_size-1)],
                \          '[v:key, v:val]')
        if target==-1
            let r.=' '
        elseif target*2==i
            let r.='|'
        elseif target==horizontal_edge_target && i!=horizontal_edge-1
            if i!=(target*2)+3
                let self.new_mapping[i]=-1
            endif
            let used_horizontal=1
            let r.='_'
        else
            if used_horizontal && i<horizontal_edge
                let self.new_mapping[i]=-1
            endif
            let r.='/'
        endif
    endfor
    let r.=self.pad_horizontally(len(r))
    let [self.mapping, self.new_mapping]=
                \[self.new_mapping, self.mapping]
    if self.is_mapping_correct()
        call self.update_state('padding')
    endif
    return r
endfunction
"▶2 graph.next_line :: graph → String
let s:gstatesfmap={
            \'padding':    s:F.graph.output_padding_line,
            \'skip':       s:F.graph.output_skip_line,
            \'precommit':  s:F.graph.output_pre_commit_line,
            \'commit':     s:F.graph.output_commit_line,
            \'postmerge':  s:F.graph.output_post_merge_line,
            \'collapsing': s:F.graph.output_collapsing_line,
        \}
function s:F.graph.next_line()
    return call(s:gstatesfmap[self.state], [], self)
endfunction
"▶2 graph.padding_line :: graph → String
function s:F.graph.padding_line()
    if self.state isnot# 'commit'
        return self.next_line()
    endif
    if self.num_parents<3
        let r.=repeat('| ', len(self.columns))
    else
        let r.=join(map(copy(self.columns),
                    \   '"|".((v:val is# "'.self.cs.hex.'")?'.
                    \           'repeat(" ", (self.num_parents-2)*2):'.
                    \           '" ")'), '')
    endif
    let r.=self.pad_horizontally(len(r))
    let self.prev_state='padding'
    return r
endfunction
"▶2 graph.show_commit :: graph → [String]
function s:F.graph.show_commit()
    let r=[]
    while 1
        try
            if self.state is# 'commit'
                break
            endif
        finally
            " XXX We need at least one iteration. :finally makes sure it will be 
            " done
            let r+=[self.next_line()]
        endtry
    endwhile
    return r
endfunction
"▶2 graph.show_remainder :: graph → [String]
function s:F.graph.show_remainder()
    let r=[]
    while self.state isnot# 'padding'
        let r+=[self.next_line()]
    endwhile
    return r
endfunction
"▶1 glog
"▶2 glog.utfedges
function s:F.glog.utfedges(seen, hex, parents)
    let nodeidx=index(a:seen, a:hex)
    if nodeidx==-1
        let nodeidx=len(a:seen)
        call add(a:seen, a:hex)
    endif
    let knownparents=[]
    let newparents=[]
    for parenthex in a:parents
        call add(((index(a:seen, parenthex)==-1)?
                    \   (newparents):
                    \   (knownparents)),
                    \parenthex)
    endfor
    let ncols=len(a:seen)
    call remove(a:seen, nodeidx)
    call extend(a:seen, newparents, nodeidx)
    let edges=map(knownparents, '['.nodeidx.', index(a:seen, v:val)]')
    if !empty(newparents)
        call add(edges, [nodeidx, nodeidx])
        if len(newparents)>1
            call add(edges, [nodeidx, nodeidx+1])
        endif
    endif
    let nmorecols=len(a:seen)-ncols
    return [nodeidx, edges, ncols, nmorecols]
endfunction
"▶2 glog.fix_long_right_edges
function s:F.glog.fix_long_right_edges(edges)
    call map(a:edges, '((v:val[1]>v:val[0])?([v:val[0], v:val[1]+1]):(v:val))')
endfunction
"▶2 glog.get_nodeline_edges_tail
function s:F.glog.get_nodeline_edges_tail(node_index, p_node_index, n_columns,
            \                             n_columns_diff, p_diff, fix_tail)
    if a:fix_tail && a:n_columns_diff==a:p_diff && a:n_columns_diff!=0
        if a:n_columns_diff==-1
            let start=max([a:node_index+1, a:p_node_index])
            return repeat(['|', ' '], (start-a:node_index-1))+
                        \repeat(['/', ' '], (a:n_columns-start))
        else
            return repeat(['\', ' '], (a:n_columns-a:node_index-1))
        endif
    else
        return repeat(['|', ' '], (a:n_columns-a:node_index-1))
    endif
endfunction
"▶2 glog.draw_edges
function s:F.glog.draw_edges(edges, nodeline, interline)
    for [start, end] in a:edges
        if start==end+1
            let a:interline[2*end   + 1]='/'
        elseif start==end-1
            let a:interline[2*start + 1]='\'
        elseif start==end
            let a:interline[2*start    ]='|'
        else
            let a:nodeline[2*end]='+'
            if start>end
                let [start, end]=[end, start]
            endif
            for i in range(2*start+1, 2*end-1)
                if a:nodeline[i] isnot# '+'
                    let a:nodeline[i]='-'
                endif
            endfor
        endif
    endfor
endfunction
"▶2 glog.get_padding_line
function s:F.glog.get_padding_line(ni, n_columns, edges)
    let c=' '
    if index(a:edges, [a:ni, a:ni-1])!=-1 || index(a:edges, [a:ni, a:ni])!=-1
        let c='|'
    endif
    return repeat('| ', a:ni).c.' '.repeat('| ', (a:n_columns-a:ni-1))
endfunction
"▶2 glog.addcols
function s:F.glog.addcols(special, cnum)
    let mapexpr='[v:val[0], v:val[1]+'.a:cnum.']+v:val[2:]'
    call map(a:special, 'v:key[-2:] is? "_r"?'.
                \             'map(v:val, '.string(mapexpr).'):'.
                \             mapexpr)
    return a:special
endfunction
"▶2 glog.gettext :: skip, cs, opts, repo, width → Text
let s:skiptext={'skip': 1, 'text': [], 'special': {}}
function s:F.glog.gettext(skip, ...)
    if a:skip
        return deepcopy(s:skiptext)
    else
        return call(a:2.templatefunc, a:000, {})
    endif
endfunction
"▶2 glog.utf
function s:F.glog.utf(state, type, coldata, char, skip, cs, opts, repo)
    let [idx, edges, ncols, coldiff]=a:coldata
    let text=s:F.glog.gettext(a:skip, a:cs, a:opts, a:repo, ncols)
    let add_padding_line=0
    let lnum = (has_key(text, 'text') ? len(text.text) : 0)
    if coldiff==-1
        call s:F.glog.fix_long_right_edges(edges)
        if lnum>2
            let add_padding_line=!empty(map(filter(copy(edges),
                        \                          '(v:val[0]+1)<v:val[1]'),
                        \                   'v:val[0]'))
        endif
    endif
    let fix_nodeline_tail = (lnum<=2 && add_padding_line)
    let shift_interline=repeat(['|', ' '], idx)
    let nodeline=shift_interline+[a:char, ' ']+
                \s:F.glog.get_nodeline_edges_tail(idx,     a:state[1], ncols,
                \                                 coldiff, a:state[0],
                \                                 fix_nodeline_tail)
    if coldiff==-1
        let n_spaces=1
        let edge_ch='/'
    elseif coldiff==0
        let n_spaces=2
        let edge_ch='|'
    else
        let n_spaces=3
        let edge_ch='\'
    endif
    let shift_interline+=repeat([' '], n_spaces)+
                \        repeat([edge_ch, ' '], (ncols-idx-1))
    call s:F.glog.draw_edges(edges, nodeline, shift_interline)
    let joined_nl=join(nodeline, '')
    let joined_sil=join(shift_interline, '')
    if has_key(text, 'skip')
        let text.text=[]
        if joined_nl!~#'\v^[*| ]+$'
            let text.text+=[joined_nl]
        endif
        if joined_sil!~#'\v^[| ]+$' &&
                    \joined_sil isnot# tr(joined_nl, a:char, '|')
            let text.text+=[joined_sil]
        endif
        return text
    endif
    let lines=[joined_nl]
    if add_padding_line
        call add(lines, s:F.glog.get_padding_line(idx, ncols, edges))
    endif
    call add(lines, joined_sil)
    let ltdiff=lnum-len(lines)
    if ltdiff>0
        let extra_interline=repeat('| ', ncols+coldiff)
        let lines+=repeat([extra_interline], ltdiff)
    else
        call extend(text.text, repeat([''], -ltdiff))
    endif
    let indentation_level=2*max([ncols, ncols+coldiff])
    let a:state[0]=coldiff
    let a:state[1]=idx
    call map(lines, 'printf("%-*s ", indentation_level, v:val)')
    let curspecial=text.special
    let shiftlen=len(lines[0])
    call s:F.glog.addcols(text.special, shiftlen)
    let text.block_r=[[0, shiftlen],
                \     [len(text.text)-1,
                \      max(map(copy(lines), 'len(v:val)'))]]
    let curspecial.bullet=[0, stridx(lines[0], a:char), a:char]
    call map(text.text, 'lines[v:key].v:val')
    return text
endfunction
"▶2 glog.graph_init :: repo, [cs] → graph
let s:defgraph={
            \'cs':                0,
            \'num_parents':       0,
            \'expansion_row':     0,
            \'state':             'padding',
            \'prev_state':        'padding',
            \'commit_index':      0,
            \'prev_commit_index': 0,
            \'columns':           [],
            \'new_columns':       [],
            \'mapping':           [],
            \'new_mapping':       [],
            \'mapping_size':      0,
            \'skipchangesets':    {},
        \}
function s:F.glog.graph_init(showparents, opts, repo)
    let graph=deepcopy(s:defgraph)
    let graph.opts=a:opts
    let graph.repo=a:repo
    let graph.workcss=a:showparents
    let graph.skipchangesets=a:opts.skipchangesets
    call extend(graph, s:F.graph)
    return graph
endfunction
"▶2 glog.show_log :: graph, cs, skip::Bool → Text
function s:F.glog.show_log(graph, cs, skip)
    let lines=((a:graph.cs is 0)?([]):(a:graph.show_remainder()))
    call a:graph.update(a:cs)
    let lines+=a:graph.show_commit()
    if a:skip && len(lines)==1 && lines[0]!~#'[^|* ]'
        return deepcopy(s:skiptext)
    endif
    let collen=len(lines[-1])
    let text=s:F.glog.gettext(a:skip, a:cs, a:graph.opts, a:graph.repo, collen)
    let text.block_r=[[0, collen],
                \     [len(text.text)-1,
                \      collen+max(map(copy(text.text), 'len(v:val)'))]]
    call s:F.glog.addcols(text.special, collen)
    let lines[-1]=lines[-1][:-2].' '.get(text.text, 0, '')
    let cchar=a:graph.output_commit_char()
    let bidx=stridx(lines[-1], cchar)
    if bidx!=-1
        let text.special.bullet=[0, bidx, cchar]
    endif
    for line in text.text[1:]
        let lines+=[a:graph.next_line()[:-2].' '.line]
    endfor
    let text.text=lines
    return text
endfunction
"▶2 s:DateCmp :: cs, cs → -1|0|1
function s:DateCmp(a, b)
    let a=a:a.time
    let b=a:b.time
    return ((a==b)?(0):((a>b)?(-1):(1)))
endfunction
let s:_functions+=['s:DateCmp']
"▶2 iterfuncs.csshow
let s:iterfuncs.csshow={}
"▶3 iterfuncs.csshow.setup :: procinput → d
function s:iterfuncs.csshow.setup(procinput)
    return {     'input': '',
           \ 'skipuntil': 0,
           \       'buf': bufnr('%'),
           \'lastw0line': -1,
           \ 'didredraw': 0,
           \ 'procinput': a:procinput,
           \ 'allowskip': 0,}
endfunction
"▶3 iterfuncs.csshow.next
function s:iterfuncs.csshow.next(d)
    if !a:d.didredraw
        let haschar=getchar(1)
        if haschar || (line('$')>=line('w0')+winheight(0))
            redraw
            let a:d.didredraw=!haschar
            let a:d.lastw0line=line('w0')
        endif
    endif
    if !a:d.procinput
        return
    endif
    while getchar(1)
        let char=getchar()
        if type(char)==type(0)
            let char=nr2char(char)
        endif
        let a:d.input.=char
        let skipped=0
        if a:d.skipuntil isnot 0
            if eval(a:d.skipuntil)
                let a:d.skipuntil=0
                let skipped=1
            endif
        endif
        if (skipped && !a:d.allowskip) || a:d.skipuntil isnot 0
        elseif stridx("gzy'`m[]@qZ\<C-w>tTfF", char)!=-1
            let a:d.skipuntil='len(a:d.input)>='.(len(a:d.input)+1)
            let a:d.allowskip=0
        elseif char is# '"'
            let a:d.skipuntil='len(a:d.input)>='.(len(a:d.input)+2)
            let a:d.allowskip=1
        elseif stridx('123456789', char)!=-1
            let a:d.skipuntil='a:d.input['.len(a:d.input).':]=~#"\\D"'
            let a:d.allowskip=1
        elseif stridx('/?:!', char)!=-1
            let a:d.skipuntil=
                        \'match(a:d.input, "[\n\r\e]", '.len(a:d.input).')!=-1'
            let a:d.allowskip=0
        endif
    endwhile
    if !empty(a:d.input) && (a:d.skipuntil is 0 || eval(a:d.skipuntil))
        let a:d.skipuntil=0
        execute 'normal' a:d.input
        let a:d.input=''
        if bufnr('%')==a:d.buf
            let lw0=line('w0')
            redraw!
            redrawstatus
            if lw0!=a:d.lastw0line
                let a:d.didredraw=(line('$')>=lw0+winheight(0))
                let a:d.lastw0line=lw0
            endif
        else
            if bufexists(a:d.buf)
                execute 'silent bwipeout!' a:d.buf
            endif
            call s:_f.throw('ebuf')
        endif
    endif
endfunction
"▶3 iterfuncs.csshow.finish
function s:iterfuncs.csshow.finish(d)
    if !empty(a:d.input)
        return feedkeys(a:d.input)
    endif
endfunction
"▶2 glog.graphlog
function s:F.glog.graphlog(repo, opts, csiterfuncs, bvar, read)
    "▶3 Get grapher
    if get(a:repo, 'has_octopus_merges', 1)
        let literfuncs=s:iterfuncs.git
    elseif get(a:repo, 'has_merges', 1)
        let literfuncs=s:iterfuncs.hg
    else
        let literfuncs=s:iterfuncs.simple
    endif
    "▶3 Initialize variables
    let haslimit=(has_key(a:opts, 'limit') && a:opts.limit)
    if haslimit
        let limit=a:opts.limit
    endif
    let foundfirst=0
    let csbuf=[]
    let reqprops=keys(a:opts.reqs)
    call filter(reqprops, 'index(a:repo.initprops, v:val)==-1')
    let a:opts.skipchangesets={}
    let skipchangesets=a:opts.skipchangesets
    let firstcs=1
    let lastline=0
    let r=[]
    "▶3 Initialize variables not required for reading
    if !a:read
        let specials={}
        let rectangles=[]
        let csstarts={}
        let a:bvar.rectangles=rectangles
        let a:bvar.specials=specials
        let a:bvar.csstarts=csstarts
        let sd=s:iterfuncs.csshow.setup(a:bvar.procinput)
    endif
    "▶3 Initialize iterator functions
    let ld=literfuncs.start(a:repo,a:opts,[a:repo.functions.getworkhex(a:repo)])
    let csd=a:csiterfuncs.start(a:repo, a:opts)
    let checkd=s:iterfuncs.check.start(a:repo, a:opts)
    "▲3
    while 1 && (!haslimit || limit)
        let cs=a:csiterfuncs.next(csd)
        if cs is 0 "▶3
            return r
        endif "▲3
        let skip=!s:iterfuncs.check.check(checkd, cs)
        "▶3 Add cs to skipchangesets or get its properties
        if skip
            let a:opts.skipchangesets[cs.hex]=cs
        else
            call map(copy(reqprops),
                        \'a:repo.functions.getcsprop(a:repo, cs, v:val)')
            let foundfirst=1
            if haslimit
                let limit-=1
            endif
        endif
        "▲3
        if foundfirst
            let csbuf+=[cs]
            if !skip
                for cs in csbuf
                    let [lines, rectangle, special]=literfuncs.proccs(ld, cs)
                    "▶3 Add various information to bvar
                    if !a:read && rectangle isnot 0
                        let rectangle[0][0]=lastline
                        let lastline+=len(lines)
                        let rectangle[1][0]=lastline-1
                        let rectangle+=[cs.hex]
                        call add(rectangles, rectangle)
                        let csstarts[cs.hex]=rectangle[0][0]
                        if special isnot 0
                            let specials[cs.hex]=special
                        endif
                    endif
                    "▶3 Add lines to returned list if reading
                    if a:read
                        let r+=lines
                    "▶3 Add lines to buffer if not, process user input
                    else
                        "▶4 Add lines to buffer
                        if firstcs
                            call setline(1, lines)
                            let firstcs=0
                        else
                            call append('$', lines)
                        endif
                        "▲4
                        call s:iterfuncs.csshow.next(sd)
                    endif
                    "▲3
                    unlet rectangle special
                endfor
                call remove(csbuf, 0, -1)
            endif
        endif
        unlet cs
    endwhile
    if !a:read
        call s:iterfuncs.csshow.finish(sd)
    endif
    return r
endfunction
"▶1 iterfuncs: loggers
"▶2 iterfuncs.git
let s:iterfuncs.git={}
function s:iterfuncs.git.start(repo, opts, ...)
    let graph=s:F.glog.graph_init(get(a:000, 0, []), a:opts, a:repo)
    return {'graph': graph, 'opts': a:opts, 'repo': a:repo}
endfunction
function s:iterfuncs.git.proccs(d, cs)
    let skip=has_key(a:d.opts.skipchangesets, a:cs.hex)
    let text=s:F.glog.show_log(a:d.graph, a:cs, skip)
    if skip
        return [text.text, 0, 0]
    else
        return [text.text, text.block_r, text.special]
    endif
endfunction
"▶2 iterfuncs.hg
let s:iterfuncs.hg={}
function s:iterfuncs.hg.start(repo, opts, ...)
    return {'seen': [], 'state': [0, 0], 'opts': a:opts,
                \'showparents': get(a:000, 0, []), 'repo': a:repo}
endfunction
function s:iterfuncs.hg.proccs(d, cs)
    let skip=has_key(a:d.opts.skipchangesets, a:cs.hex)
    if skip
        let char='*'
    else
        let char=((index(a:d.showparents, a:cs.hex)==-1)?('o'):('@'))
    endif
    let text=s:F.glog.utf(a:d.state, 'C',
                \     s:F.glog.utfedges(a:d.seen, a:cs.hex, a:cs.parents), char,
                \     skip, a:cs, a:d.opts, a:d.repo)
    if !has_key(text, 'text') || empty(text.text)
        return [[], 0, 0]
    endif
    if !skip
        return [text.text, text.block_r, text.special]
    else
        return [text.text, 0, 0]
    endif
endfunction
"▶2 iterfuncs.simple
let s:iterfuncs.simple={}
function s:iterfuncs.simple.start(repo, opts, ...)
    return {'opts': a:opts, 'repo': a:repo, 'showparents': get(a:000, 0, [])}
endfunction
function s:iterfuncs.simple.proccs(d, cs)
    if has_key(a:d.opts.skipchangesets, a:cs.hex)
        return [[], 0, 0]
    endif
    let text=a:d.opts.templatefunc(a:cs, a:d.opts, a:d.repo, 2)
    let text.block_r=[[0, 0],
                \     [len(text.text)-1,
                \      max(map(copy(text.text), 'len(v:val)'))]]
    let char='@o'[(index(a:d.showparents, a:cs.hex)==-1)]
    call map(text.text, '(v:key ? "|" : char)." ".v:val')
    call s:F.glog.addcols(text.special, 2)
    let text.special.bullet=[0, 0, char]
    return [text.text, text.block_r, text.special]
endfunction
"▶1 comparedates :: datesel, time → -1|0|1
let s:datechars='YmdHM'
function s:F.comparedates(datesel, time)
    let j=0
    for selnum in a:datesel
        if selnum isnot# '*'
            let spec='%'.s:datechars[j]
            if selnum is# '.'
                let selnum=str2nr(strftime(spec))
            endif
            let actnum=str2nr(strftime(spec, a:time))
            if actnum!=selnum
                if actnum<selnum
                    return -1
                else
                    return 1
                endif
            endif
        endif
        let j+=1
    endfor
    return 0
endfunction
"▶1 iterfuncs.check
" startfunc (here)  :: repo, opts → d
let s:fcheckpropslist=['renames', 'copies', 'changes', 'files']
let s:iterfuncs.check={}
"▶2 iterfuncs.check.start
"▶3 addcentury
function s:F.addcentury(year)
    if type(a:year)==type(0) && a:year<100
        let curyear=str2nr(strftime('%y'))
        let century=str2nr(strftime('%Y')[:-3])
        if a:year<=curyear
            let r=((century*100)+a:year)
        else
            let r=(((century-1)*100)+a:year)
        endif
        return r
    endif
    return a:year
endfunction
"▶3 redate
function s:F.redate(datespec)
    let date=map(split(a:datespec, '\v[^0-9*.]+'),
                \'v:val=~#"\\d" ? str2nr(v:val) : v:val')
    let date[0]=s:F.addcentury(date[0])
    return date
endfunction
"▲3
let s:keytoexpr={
            \'branch': '"a:cs.branch isnot# ".string(v:val)',
            \'merges': '(v:val)?("len(a:cs.parents)<=1"):'.
            \                  '("len(a:cs.parents)>1")',
            \'search': '"a:cs.description!~#".string(v:val)',
            \  'user':        '"a:cs.user!~#".string(v:val)',
        \}
function s:iterfuncs.check.start(repo, opts)
    let r={'repo': a:repo, 'hasfiles': 0, 'hasdaterange': 0, 'hasdate': 0}
    "▶3 Define variables for files filtering
    if has_key(a:opts, 'files')
        let r.hasfiles=1
        let r.csfiles={}
        let r.filepats=a:opts.filepats
        let r.tocheck={}
        let a:opts.csfiles=r.csfiles
    endif
    "▶3 Define variables for date filtering
    if has_key(a:opts, 'date')
        let idx=match(a:opts.date, '\V<=\?>')
        if idx==-1
            let r.hasdate=1
            let r.selector=(stridx('<>', a:opts.date[0])==-1)?(''):
                        \                                     (a:opts.date[0])
            let r.acceptexact=(empty(r.selector) || a:opts.date[1] is# '=')
            let r.date=s:F.redate(a:opts.date[empty(r.selector)?(0):
                        \                     (len(r.selector)+r.acceptexact):])
        else
            let r.hasdaterange=1
            let r.date1=s:F.redate(a:opts.date[:(idx-1)])
            let r.acceptexact=(a:opts.date[idx+1] is# '=')
            let r.date2=s:F.redate(a:opts.date[(idx+2+r.acceptexact):])
        endif
    endif
    "▶3 Determine other filters
    let r.expr=join(values(map(filter(copy(a:opts),
                \                     'has_key(s:keytoexpr, v:key)'),
                \              'eval(s:keytoexpr[v:key])')), '||')
    "▲3
    return r
endfunction
"▶2 iterfuncs.check.check
function s:iterfuncs.check.check(d, cs)
    "▶3 Check simple cases
    if !empty(a:d.expr) && eval(a:d.expr)
        return 0
    endif
    "▶3 Check files
    if a:d.hasfiles
        let copies =a:d.repo.functions.getcsprop(a:d.repo, a:cs, 'copies' )
        let renames=a:d.repo.functions.getcsprop(a:d.repo, a:cs, 'renames')
        let changes=a:d.repo.functions.getcsprop(a:d.repo, a:cs, 'changes')[:]
        let csfiles=[]
        let tcfiles=[]
        let a:d.csfiles[a:cs.hex]=csfiles
        if has_key(a:d.tocheck,a:cs.hex)
            let tc=a:d.tocheck[a:cs.hex]
            call filter(changes, '(index(tc, v:val)==-1)?(1):'.
                        \           '([0, add(csfiles, v:val)][0])')
            call filter(tc, 'index(csfiles, v:val)==-1')
            if !empty(tc)
                let allfiles=a:d.repo.functions.getcsprop(a:d.repo, a:cs,
                            \                             'allfiles')
                let tcfiles+=filter(copy(allfiles), 'index(tc, v:val)!=-1')
            endif
        endif
        for pattern in a:d.filepats
            let newchanges=[]
            call map(copy(changes), 'add(((v:val=~#'.string(pattern).')?'.
                        \                   '(csfiles):'.
                        \                   '(newchanges)), v:val)')
            if empty(newchanges)
                break
            endif
            let changes=newchanges
        endfor
        for file in csfiles
            let tcfiles+=map(filter(['renames', 'copies'],
                        \           'has_key({v:val}, file) && '.
                        \           '{v:val}[file] isnot 0'),
                        \    '{v:val}[file]')
        endfor
        if !empty(tcfiles)
            call map(copy(a:cs.parents), 'extend(a:d.tocheck, '.
                        \'{v:val : get(a:d.tocheck, v:val, [])+tcfiles})')
        endif
        if empty(csfiles)
            return 0
        endif
    endif
    "▶3 Check date
    if a:d.hasdate
        let cmpresult=s:F.comparedates(a:d.date, a:cs.time)
        if !((a:d.acceptexact && cmpresult==0) ||
                    \(a:d.selector is# '<' && cmpresult==-1) ||
                    \(a:d.selector is# '>' && cmpresult==1))
            return 0
        endif
    elseif a:d.hasdaterange
        let cmp1result=s:F.comparedates(a:d.date1, a:cs.time)
        let cmp2result=s:F.comparedates(a:d.date2, a:cs.time)
        if !((cmp1result==1 && cmp2result==-1) ||
                    \(a:d.acceptexact && (cmp1result==0 ||
                    \                     cmp2result==0)))
            return 0
        endif
    endif
    "▲3
    return 1
endfunction
"▶1 getblock :: bvar + cursor, bvar → block
"▶2 bisect :: [a], function + self → a
function s:F.bisect(list, function)
    let llist=len(a:list)
    let lborder=0
    let rborder=llist-1
    let lres=call(a:function, [a:list[lborder]], self)
    if lres<=0
        return a:list[lborder]
    endif
    let rres=call(a:function, [a:list[rborder]], self)
    if rres>=0
        return a:list[rborder]
    endif
    let totest='r'
    let cur=(((rborder+1)/2)-1)
    while lborder!=rborder
        let res=call(a:function, [a:list[cur]], self)
        if res==0
            return a:list[cur]
        else
            let shift=((rborder-lborder)/2)
            if shift==0
                let shift=1
            endif
            let {(res>0)?('l'):('r')}border=cur
            let cur=lborder+shift
        endif
    endwhile
    return a:list[lborder]
endfunction
"▶2 checkinblock :: block → -1|0|1
function s:F.checkinblock(block)
    let curline=line('.')-1
    return       ((curline<a:block[0][0])?(-1):
                \((curline>a:block[1][0])?( 1):
                \                         ( 0)))
endfunction
"▲2
function s:F.getblock(bvar)
    if empty(a:bvar.rectangles)
        call s:_f.throw('nocontents')
    endif
    return s:F.bisect(a:bvar.rectangles, s:F.checkinblock)
endfunction
"▶1 setup
function s:F.setup(read, repo, opts, ...)
    let opts=a:opts
    let bvar=get(a:000, 0, {'opts': opts})
    let bvar.getblock=s:F.getblock
    "▶2 Add `ignorefiles'
    let ignorefiles=(has_key(opts, 'ignfiles')?
                \               (opts.ignfiles):
                \               (s:_f.getoption('ignorefiles')))
    let opts.ignorefiles={}
    call map(copy(ignorefiles), 'extend(opts.ignorefiles, {v:val : 1})')
    unlet ignorefiles
    "▶2 Get cslist
    let csiterfuncsname=((has_key(opts, 'revision'))?
                \          ('ancestors'):
                \       ((has_key(opts, 'revrange'))?
                \          ('revrange')
                \       :
                \          ('changesets')))
    let csiterfuncs=a:repo.iterfuncs[csiterfuncsname]
    "▶2 Get template
    call s:_r.template.gettemplatelist(bvar)
    let [opts.reqs, opts.templatefunc]=s:_r.template.compile(bvar.templatelist,
                \                                            opts, a:repo)
    "▲2
    if !a:read
        let buf=bufnr('%')
        let bvar.procinput=(has_key(a:opts, 'procinput')?
                    \           (2*a:opts.procinput):
                    \           s:_f.getoption('procinput'))
        if bvar.procinput==1 && getchar(1)
            let bvar.procinput=0
        endif
    endif
    let bvar.cw=s:_f.getoption('closewindow')
    let text=s:F.glog.graphlog(a:repo, opts, csiterfuncs, bvar, a:read)
    if a:read
        call s:_r.lineutils.setlines(text, a:read)
    elseif bufnr('%')==buf
        setlocal readonly nomodifiable
    endif
    return bvar
endfunction
"▶1 logfunc
function s:logfunc.function(repopath, opts)
    let opts=copy(a:opts)
    if has_key(opts, 'files')
        if opts.files[0] is# ':'
            let curfile=s:_r.cmdutils.getrrf(opts, 'nocurf', 'getfile')[3]
            if curfile is 0
                call remove(opts.files, 0)
            else
                let opts.files[0]=s:_r.cmdutils.globescape(curfile)
            endif
        endif
        if a:repopath is# ':'
            let repo=s:_r.repo.get(opts.files[0])
        else
            let repo=s:_r.repo.get(a:repopath)
        endif
        call map(opts.files, 'repo.functions.reltorepo(repo, v:val)')
    else
        let repo=s:_r.repo.get(a:repopath)
    endif
    call s:_r.cmdutils.checkrepo(repo)
    if has_key(opts, 'cmd')
        let cmd=remove(opts, 'cmd')
    else
        let cmd='silent new'
    endif
    call s:_r.run(cmd, 'log', repo, opts)
    if !has_key(opts, 'cmd')
        setlocal bufhidden=wipe
    endif
endfunction
let s:datereg='%(\d\d%(\d\d)?|[*.])'.
            \ '%(\-%(\d\d?|[*.])'.
            \ '%(\-%(\d\d?|[*.])'.
            \ '%([ _]%(\d\d?|[*.])'.
            \ '%(\:%(\d\d?|[*.]))?)?)?)?'
let s:logfunc['@FWC']=['-onlystrings '.
            \          '['.s:_r.cmdutils.nogetrepoarg.']'.
            \          '{ *?files    (type "")'.
            \          '  *?ignfiles in [patch renames copies files] ~start'.
            \          '   ?date     match /\v[<>]?\=?'.s:datereg.'|'.
            \                                 s:datereg.'\<\=?\>'.s:datereg.'/'.
            \          '   ?search   isreg'.
            \          '   ?user     isreg'.
            \          '   ?branch   type ""'.
            \          '   ?limit    range 1 inf'.
            \          '   ?revision type ""'.
            \          ' +2?revrange type "" type ""'.
            \          '   ?style    in _r.template.tlist'.
            \          '   ?template idof variable'.
            \          '  !?merges'.
            \          '  !?patch'.
            \          '  !?stat'.
            \          '  !?showfiles'.
            \          '  !?showrenames'.
            \          '  !?showcopies'.
            \          '  !?procinput'.
            \          s:_r.repo.diffoptsstr.
            \          '   ?cmd      type ""'.
            \          '}', 'filter']
call add(s:logcomp, substitute(substitute(
            \substitute(substitute(substitute(substitute(s:logfunc['@FWC'][0],
            \'\V|*_r.repo.get',        '',                                  ''),
            \'\vfiles\s+\([^)]*\)',    'files path',                        ''),
            \'\Vcmd\s\+type ""',       'cmd first (in cmds, idof command)', ''),
            \'\vrevision\s+\Vtype ""', 'revision '.s:_r.comp.rev,           ''),
            \'\vbranch\s+\Vtype ""',   'branch '.s:_r.comp.branch,          ''),
            \'\vrevrange\s+\Vtype "" type ""',
            \                         'revrange '.s:_r.comp.rev.' '.
            \                                     s:_r.comp.rev,            ''))
"▶1 Create aurum://log
call s:_f.newcommand({
            \'function': s:F.setup,
            \ 'options': {'list': ['files', 'revrange', 'ignfiles'],
            \             'bool': ['merges', 'patch', 'stat', 'showfiles',
            \                      'showrenames', 'showcopies', 'procinput'],
            \              'num': ['limit']+s:_r.repo.diffoptslst,
            \              'str': ['date', 'search', 'user', 'branch',
            \                      'revision', 'style', 'template',
            \                      'crrestrict'],
            \             'pats': ['files'],
            \            },
            \'filetype': 'aurumlog',
            \'requiresbvar': 1,
            \})
"▶1
call frawor#Lockvar(s:, '_r')
" vim: ft=vim ts=4 sts=4 et fmr=▶,▲
